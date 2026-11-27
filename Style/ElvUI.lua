-- Rested Leveling: the ElvUI style. Our frames go through ElvUI's own Skins module (S:Handle*), its fonts and its
-- status-bar texture, so any ElvUI skin that hooks those calls (ElvUI_WC3 "Gatewood" paints oak, iron and rivets
-- over exactly these) styles Rested Leveling too, with no skin-specific code here. ElvUI's own frames and profiles
-- are never touched.

local _, ns = ...
local St = ns.Style
local X = { name = "elvui" }
St.backends.elvui = X

local E, S, LSM

local function engine()
	if E then return E end
	if type(ElvUI) ~= "table" then return nil end
	E = ElvUI[1]
	if type(E) ~= "table" or type(E.GetModule) ~= "function" then E = nil return nil end
	local ok, skins = pcall(E.GetModule, E, "Skins", true)
	S = ok and skins or nil
	LSM = E.Libs and E.Libs.LSM
	return E
end

function X.Available()
	return engine() ~= nil and S ~= nil
end

function X.Init() engine() end

local function handle(method, ...)
	if S and type(S[method]) == "function" then
		local ok = pcall(S[method], S, ...)
		return ok
	end
	return false
end

-- Andy's decision: with ElvUI installed, Rested Leveling inherits it. Every top-level window (main, card, compact
-- bar, tip, toasts, banner) goes through ElvUI's own skin calls (S:HandlePortraitFrame / S:HandleFrame), parented to
-- UIParent, exactly as ElvUI skins Blizzard's windows, so an ElvUI skin (ElvUI_WC3 paints oak planks, iron and rivets)
-- styles them. Nothing of ours is painted over the window: no body fill, no frame. Option "own" (opt-out) uses
-- Rested Leveling's own oak-and-iron frame instead.
function X.Own() return ns.DB().opts.elvuiWindow == "own" end
function X.HostFrame() return not X.Own() end

-- Has an ElvUI skin drawn its own window art on this frame? (Background textures from another addon's media that
-- are neither ElvUI's nor ours.) Then the frame's ElvUI template fill is made see-through so that art shows; with
-- plain ElvUI the fill stays. Only our own frames are touched.
local function skinArt(frame)
	for _, r in ipairs({ frame:GetRegions() }) do
		if r.IsObjectType and r:IsObjectType("Texture") and r:IsShown() and r:GetDrawLayer() == "BACKGROUND" then
			local t = r:GetTexture()
			t = type(t) == "string" and t:lower() or ""
			if t:find("interface\\addons\\", 1, true) and not t:find("\\elvui\\", 1, true)
				and not t:find("restedleveling", 1, true) then
				return true
			end
		end
	end
	return false
end
X.SkinArt = skinArt

local function reveal(frame)
	local center = frame.Center
	if center and center.SetAlpha then center:SetAlpha(skinArt(frame) and 0 or 1) end
end

local function skinTopLevel(frame, method)
	if frame.rlSkinned then reveal(frame) return end
	if not handle(method, frame) and method ~= "HandleFrame" then handle("HandleFrame", frame) end
	frame.rlSkinned = true
	frame:HookScript("OnShow", reveal)
	reveal(frame)
end

function X.Window(frame, title)
	if X.Own() then St.backends.default.Chrome(frame, title) return end
	-- Like the host's own skinned windows: the skin draws the frame; our title is plain 13 px text in its top band
	-- (no template title, so no plaque), and the close is the host's own close button.
	skinTopLevel(frame, frame.TitleContainer and "HandlePortraitFrame" or "HandleFrame")
	if not frame.rlHostTitle then
		frame.rlHostTitle = frame:CreateFontString(nil, "OVERLAY")
		X.Font(frame.rlHostTitle, "name", 16)
		frame.rlHostTitle:SetTextColor(0.94, 0.75, 0.30)   -- his gold (#F0D890 as rendered)   -- gold, like his Options and Character titles
		frame.rlHostTitle:SetPoint("TOP", 0, -12)
		if frame.CloseButton then handle("HandleCloseButton", frame.CloseButton)
		else   -- centred on the title line (TOP -12, 16 px type)
			frame.rlClose = X.MakeIconButton(frame, "close")
			frame.rlClose:SetPoint("TOPRIGHT", -4, -7)
		end
	end
	frame.rlHostTitle:SetText(title or "")
end

-- Action buttons inside our windows are our own enamel buttons (red for the main action, blue otherwise) in ElvUI
-- fonts: a skin's generic button art (in the simulator, end caps over the label) is not applied to them. The window
-- itself, its close button, check boxes and bars still go through the skin.
function X.MakeButton(parent, w, label, primary, h)
	-- Every button in the host's blue; the primary action has a gold rim (red means "not resting" only).
	local b = St.backends.default.MakeButton(parent, w, label, primary, h or (X.HostFrame() and 22 or nil), true)
	X.Font(b.label, "name", 13)
	return b
end

function X.MakeClose(parent)
	local b = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
	b:SetSize(24, 24)
	b:SetScript("OnClick", function() parent:Hide() end)
	handle("HandleCloseButton", b)
	return b
end

-- Window icon buttons (ILL-1299) through ElvUI's own skin calls, so a skin on top (WC3: a red enamel X in an iron
-- bezel, small forged-iron squares with cream glyphs) dresses them like its own: X is S:HandleCloseButton (ElvUI's
-- Close glyph, 30 px, whose plate a skin insets 4 px), the chevron is S:HandleNextPrevButton (ElvUI's ArrowUp, turned
-- for down) and the cog the same small icon button with our cog glyph (ElvUI has none). rlInset: how far inside the
-- button's rect its visible plate starts (spacing is measured between plates). Own-frame mode: our bronze family.
X.ICON, X.CLOSE = 22, 30   -- the chevron and cog squares; the X's plate (inset 4 in its 30 px button) matches them
local ARROW = { chevron_up = "up", chevron_down = "down" }
local function setGlyph(b, glyph)
	b.glyph = glyph
	local textures = { b:GetNormalTexture(), b:GetPushedTexture(), b:GetDisabledTexture() }
	local turns = S and type(S.ArrowRotation) == "table" and S.ArrowRotation
	local rot = ARROW[glyph] and turns and turns[ARROW[glyph]] or 0
	for _, t in ipairs(textures) do
		if glyph == "cog" then   -- our cog fills its texture; ElvUI's arrow has padding: inset it to match
			t:SetTexture(St.MEDIA .. "cog")
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", 4, -4)   -- a 14 px cog in the 22 px square
			t:SetPoint("BOTTOMRIGHT", -4, 4)
		end
		t:SetRotation(rot)
	end
end
function X.MakeIconButton(parent, glyph, size)
	if X.Own() then return St.backends.default.MakeIconButton(parent, glyph, size) end
	if glyph == "close" then
		local b = X.MakeClose(parent)
		b:SetSize(X.CLOSE, X.CLOSE)
		b.rlInset = 4
		return b
	end
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(X.ICON, X.ICON)
	if not handle("HandleNextPrevButton", b, ARROW[glyph] or "up", nil, false, nil, nil, X.ICON) then
		b:Hide()   -- the skin call failed part way: drop the half-skinned button, use our own
		b:SetParent(nil)
		return St.backends.default.MakeIconButton(parent, glyph, size)
	end
	b.SetGlyph = setGlyph
	setGlyph(b, glyph)
	return b
end

-- Inherit, don't invent (desk, council r4): ElvUI's own panel colours and texture, read at runtime from E.media
-- (backdropcolor, backdropfadecolor, bordercolor, blankTex). With a skin such as WC3 the windows wear its art (through
-- S:Handle*); our inner panels take ElvUI's backdrop, so stock ElvUI gives its near-black. nil when ElvUI has none.
local function rgb(t)
	if type(t) ~= "table" then return nil end
	local r, g, b = t.r or t[1], t.g or t[2], t.b or t[3]
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
	return r, g, b, t.a or t[4]
end
function X.HostColors(fade)
	local m = E and E.media
	if type(m) ~= "table" then return nil end
	local r, g, b, a = rgb(fade and m.backdropfadecolor or m.backdropcolor)
	if not r then return nil end
	local er, eg, eb = rgb(m.bordercolor)
	return { bg = { r, g, b, fade and (a or 0.8) or 1 }, edge = er and { er, eg, eb, 1 }, tex = m.blankTex }
end
-- The top-level window a frame sits in (its last ancestor below UIParent).
local function window(frame)
	local f, n = frame, 0
	while f and f.GetParent and n < 12 do
		local p = f:GetParent()
		if not p or p == UIParent then return f end
		f, n = p, n + 1
	end
	return f
end
-- Does a skin on top of ElvUI paint its own art on this frame's window? Then that skin sets the look, and its insets
-- are a warm recessed near-black (the r3 well, which the council matched to the in-game references); our wells take
-- that tone so the panels sit inside the skin's window as one family. With plain ElvUI: ElvUI's own colours.
local function skinnedWindow(frame)
	local w = window(frame)
	local yes = w ~= nil and w ~= frame and w.GetRegions ~= nil and skinArt(w)
	if yes then X.skinSeen = true end   -- a skin dresses our windows this session (pages built later follow it)
	return yes
end
X.SkinnedWindow = skinnedWindow

function X.Well(frame, fade)
	local c = X.HostColors(fade)
	if not (c and c.tex and frame.SetBackdrop) or skinnedWindow(frame) then
		St.Backdrop(frame, fade and "sw_host_stage" or "sw_host_well", "sw_host_line", 1)
		return
	end
	frame:SetBackdrop({ bgFile = c.tex, edgeFile = c.tex, edgeSize = 1 })   -- ElvUI's own 1 px template
	frame:SetBackdropColor(unpack(c.bg))
	if c.edge then frame:SetBackdropBorderColor(unpack(c.edge)) end
end

-- Floating surfaces are top-level windows too (HandleFrame, once per frame: it strips the frame's textures).
-- Inner panels are our own dark wells (baked fills), so the content keeps its contrast on any skin.
local FLOATING = { toast = true, tooltip = true, warn = true, top = true }
function X.Panel(frame, kind)
	if X.Own() then St.backends.default.Panel(frame, kind) return end
	if kind == "row" then return end
	if FLOATING[kind] then
		skinTopLevel(frame, "HandleFrame")
		return
	end
	-- Inner wells: ElvUI's own backdrop and border, like its own skinned windows.
	if kind == "card" or kind == "inset" or kind == "strip" then X.Well(frame) return end
	St.backends.default.Panel(frame, kind)
end

-- Rows and wells keep their own fills on every path.
function X.Skinned() return false end

function X.Button(btn) handle("HandleButton", btn) end
function X.Close(btn) handle("HandleCloseButton", btn) end
-- Check boxes go through ElvUI's skin; our own tick sits on a layer above the skin's backdrop so the checked state
-- always shows.
function X.Check(cb)
	handle("HandleCheckBox", cb)
	local holder = CreateFrame("Frame", nil, cb)
	holder:SetAllPoints()
	holder:SetFrameLevel(cb:GetFrameLevel() + 3)
	local tick = holder:CreateTexture(nil, "OVERLAY")
	tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	tick:SetPoint("TOPLEFT", 1, -1)
	tick:SetPoint("BOTTOMRIGHT", -1, 1)
	cb.rlTick = tick
	local function sync() tick:SetShown(cb:GetChecked() and true or false) end
	hooksecurefunc(cb, "SetChecked", sync)
	cb:HookScript("OnClick", sync)
	sync()
end
function X.Tab(tab) handle("HandleTab", tab) end

function X.ScrollBar(sb)
	if sb.ScrollBox or sb.Track then handle("HandleTrimScrollBar", sb) else handle("HandleScrollBar", sb) end
end

function X.Slider(sl)
	if not handle("HandleSliderFrame", sl) then St.backends.default.Slider(sl) end
end

function X.BarTexture()
	if E and E.media and E.media.normTex then return E.media.normTex end
	if LSM and E and E.private and E.private.general then
		local ok, tex = pcall(LSM.Fetch, LSM, "statusbar", E.private.general.normTex)
		if ok and tex then return tex end
	end
	return St.MEDIA .. "bar"
end

function X.Bar(bar)
	handle("HandleStatusBar", bar)
	bar:SetStatusBarTexture(X.BarTexture())
	-- Our bar holder already draws the background and border; ElvUI's extra backdrop frame is made invisible so it
	-- can never sit over the fill.
	if bar.backdrop and bar.backdrop.SetAlpha then bar.backdrop:SetAlpha(0) end
end

local SIZES = { title = 15, hero = 22, name = 15, body = 13, small = 12, number = 13, label = 11 }

function X.Font(fs, role, size)
	local file = E and E.media and E.media.normFont or "Fonts\\FRIZQT__.TTF"
	if (role == "number") and E and E.media and E.media.combatFont then file = E.media.normFont end
	local outline = (E and E.db and E.db.general and E.db.general.fontStyle) or "OUTLINE"
	if outline == "NONE" then outline = "" end
	fs:SetFont(file, St.Size(role, size or SIZES[role]), outline)   -- the host's own outline on every role
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 0.9)
end
