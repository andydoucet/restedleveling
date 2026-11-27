-- Rested Leveling: the Default style. Our own chrome (a dark body with a faint oak grain, a slim oak frame with one
-- bronze lip and corner studs, one quiet oak title rail), Friz Quadrata and Morpheus, our textures for bars and rings. Must look right with nothing
-- else loaded. Windows are built on the client's portrait-frame template; its stock art is hidden here.

local _, ns = ...
local St = ns.Style
local D = { name = "default" }
St.backends.default = D

local FONT_BODY = "Fonts\\FRIZQT__.TTF"
local FONT_TITLE = "Fonts\\MORPHEUS.TTF"
local FONT_NUM = "Fonts\\ARIALN.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"

St.BAND = 10   -- the frame band (oak, bronze lip) on every side: content starts inside it
St.RAIL_H = 36 -- the title rail inside the band
St.RAIL = St.BAND + St.RAIL_H + 1   -- top of the content area: band + rail + its rule, shared by both styles
St.FOOT = 46   -- footer height above the bottom edge

-- One surface recipe for every panel: a dark oak-brown fill with the iron-and-bronze edge (media/edge_surface).
-- Sections inside the window are plain wells with one quiet rule, so the hardware stays on the outside.
local PANELS = {   -- fill, edge file (nil = 1 px swatch line), edge size
	card    = { "sw_panel", "sw_bronze" },   -- the hero leads with a bronze edge; other panels are quieter
	inset   = { "sw_inset", "sw_edge" },
	strip   = { "sw_strip", "sw_edge" },
	toast   = { "wood_dark", "edge_surface", 16 },   -- floating panels: the window's own oak, frame in miniature
	tooltip = { "wood_dark", "edge_surface", 16 },
	warn    = { "wood_dark", "edge_surface", 16 },
	top     = { "wood_dark", "edge_surface", 16 },   -- small top-level windows (the compact bar)
	bubble  = { "sw_parch", "sw_rule" },
}

local function tex(frame, layer, sub, file)
	local t = frame:CreateTexture(nil, layer, nil, sub)
	t:SetTexture(file or WHITE)
	return t
end

-- Window chrome: one slim 9-slice frame (media/frame_edge: an oak band, one bronze lip, a small bronze stud in each
-- corner) drawn by a backdrop on a frame just above the window, over a dark oak body. The title rail is one quiet oak
-- board; plain 1 px rules (not straps) separate it and the footer from the content, so the gold stays for headings
-- and selection.
local EDGE = 16
local function rule(f, layer)
	local t = tex(f, layer, 2)
	St.Paint(t, "sw_line")
	t:SetHeight(1)
	return t
end

local function chrome(f)
	local c = {}
	c.body = tex(f, "BACKGROUND", -8, St.MEDIA .. "wood_dark")
	c.body:SetPoint("TOPLEFT", 4, -4)
	c.body:SetPoint("BOTTOMRIGHT", -4, 4)
	c.rail = tex(f, "BACKGROUND", -7, St.MEDIA .. "rail")
	c.rail:SetPoint("TOPLEFT", St.BAND, -St.BAND)
	c.rail:SetPoint("TOPRIGHT", -St.BAND, -St.BAND)
	c.rail:SetHeight(St.RAIL_H)
	c.railRule = rule(f, "BORDER")   -- a bronze rule under the title bar, inset 12 px: the frame has a header
	St.Paint(c.railRule, "sw_rule")
	c.railRule:SetHeight(2)
	c.railRule:SetPoint("TOPLEFT", c.rail, "BOTTOMLEFT", 12, 0)
	c.railRule:SetPoint("TOPRIGHT", c.rail, "BOTTOMRIGHT", -12, 0)
	c.railShade = tex(f, "BORDER", 0, St.MEDIA .. "shade")
	c.railShade:SetPoint("TOPLEFT", c.railRule, "BOTTOMLEFT")
	c.railShade:SetPoint("TOPRIGHT", c.railRule, "BOTTOMRIGHT")
	c.railShade:SetHeight(8)
	c.railShade:SetTexCoord(0, 1, 1, 0)
	c.footRule = rule(f, "BORDER")
	c.footRule:SetPoint("BOTTOMLEFT", St.BAND, St.FOOT)
	c.footRule:SetPoint("BOTTOMRIGHT", -St.BAND, St.FOOT)
	c.edge = CreateFrame("Frame", nil, f, "BackdropTemplate")   -- the 9-slice frame, above the window's own art
	c.edge:SetAllPoints()
	c.edge:SetFrameLevel(f:GetFrameLevel() + 1)
	c.edge:SetBackdrop({ edgeFile = St.MEDIA .. "frame_edge", edgeSize = EDGE })
	c.edge:SetBackdropBorderColor(1, 1, 1, 1)
	return c
end

-- The window chrome, used by the Default style and by the ElvUI style's own-frame mode.
function D.Chrome(frame, title)
	for _, k in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "TitleContainer" }) do
		if frame[k] and frame[k].Hide then frame[k]:Hide() end
	end
	if frame.portrait and frame.portrait.Hide then frame.portrait:Hide() end
	frame.rlChrome = frame.rlChrome or chrome(frame)
	if not frame.rlTitle then
		frame.rlTitle = frame:CreateFontString(nil, "OVERLAY")
		frame.rlTitle:SetPoint("CENTER", frame, "TOP", 11, -(St.BAND + St.RAIL_H / 2) + 1)   -- the icon-and-title group is centred
		frame.rlTitle:SetTextColor(0.94, 0.78, 0.38)   -- gold on the rail
		frame.rlMoon = frame:CreateTexture(nil, "OVERLAY")
		frame.rlMoon:SetTexture(St.MEDIA .. "icon")
		frame.rlMoon:SetSize(20, 20)
		frame.rlMoon:SetPoint("RIGHT", frame.rlTitle, "LEFT", -10, 0)
	end
	St.Font(frame.rlTitle, "title", 15)
	frame.rlTitle:SetText(title or "")
	if frame.CloseButton then frame.CloseButton:Hide() end
	frame.rlClose = frame.rlClose or St.MakeClose(frame)
	frame.rlClose:ClearAllPoints()
	frame.rlClose:SetPoint("TOPRIGHT", -(St.BAND + 6), -(St.BAND + (St.RAIL_H - 24) / 2))
end

function D.Window(frame, title) D.Chrome(frame, title) end

function D.Panel(frame, kind)
	if kind == "row" then return end
	local p = PANELS[kind] or PANELS.card
	if p[3] then
		frame:SetBackdrop({ bgFile = St.MEDIA .. p[1], edgeFile = St.MEDIA .. p[2], edgeSize = p[3],
			insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		frame:SetBackdropColor(1, 1, 1, 1)
		frame:SetBackdropBorderColor(1, 1, 1, 1)
	else
		St.Backdrop(frame, p[1], p[2], 1)
	end
end

function D.Button(btn) end
function D.Close(btn) end

-- One button family per theme: bronze on our oak, the host's blue enamel under ElvUI, with a cream label, 24 px tall
-- (h overrides, e.g. 22 under a host skin). The main action is the same button with a 1 px gold rim instead of the
-- dark lip, so it leads without a second colour. Red is kept for the "not resting" state alone.
-- enamel: secondary buttons in blue enamel (the ElvUI path); otherwise they are quiet bronze ghosts on our oak.
function D.MakeButton(parent, w, label, primary, h, enamel)
	local face = enamel and "btn_blue" or "sw_bronze_btn"
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(w, h or 24)
	St.Backdrop(b, face, primary and "sw_gold" or "sw_lip", 1)
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetPoint("TOPLEFT", 1, -1)
	b.hl:SetPoint("BOTTOMRIGHT", -1, 1)
	St.Paint(b.hl, (face == "sw_bronze_btn") and "sw_bronze_hi" or (face .. "_hi"))
	if face == "sw_bronze_btn" then b.hl:SetVertexColor(1, 1, 1, 0.35) end
	do   -- a restrained bevel on every button: lit top edge, dark bottom edge, so each reads as one finished family
		b.top = b:CreateTexture(nil, "ARTWORK")
		St.Paint(b.top, "sw_bevel_hi")
		b.top:SetPoint("TOPLEFT", 1, -1); b.top:SetPoint("TOPRIGHT", -1, -1); b.top:SetHeight(1)
		b.low = b:CreateTexture(nil, "ARTWORK")
		St.Paint(b.low, "sw_bevel_lo")
		b.low:SetPoint("BOTTOMLEFT", 1, 1); b.low:SetPoint("BOTTOMRIGHT", -1, 1); b.low:SetHeight(1)
	end
	-- The label lives on a child frame: a child draws above every layer of its parent, including the HIGHLIGHT
	-- layer (which draws above OVERLAY), so the hover face never covers the text.
	b.face = CreateFrame("Frame", nil, b)
	b.face:SetAllPoints()
	b.label = b.face:CreateFontString(nil, "OVERLAY")
	D.Font(b.label, "name", 13)
	b.label:SetPoint("CENTER", 0, 1)
	b.label:SetTextColor(0.96, 0.91, 0.76)
	b.label:SetText(label)
	b.minW = w
	function b:SetLabel(t)
		self.label:SetText(t)
		self:SetWidth(math.max(self.minW, self.label:GetStringWidth() + 32))
	end
	return b
end

-- The close button: a cream cross on the bronze button face with a gold rim, 24 px, with a 30 px hit area.
function D.MakeClose(parent)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(24, 24)
	b:SetHitRectInsets(-3, -3, -3, -3)
	St.Backdrop(b, "sw_bronze_btn", "sw_gold", 1)
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetPoint("TOPLEFT", 1, -1)
	b.hl:SetPoint("BOTTOMRIGHT", -1, 1)
	St.Paint(b.hl, "sw_bronze_hi")
	b.hl:SetVertexColor(1, 1, 1, 0.35)
	b.face = CreateFrame("Frame", nil, b)   -- the cross above the hover face, as on every button
	b.face:SetAllPoints()
	b.x = b.face:CreateFontString(nil, "OVERLAY")
	D.Font(b.x, "number", 15)
	b.x:SetPoint("CENTER", 0, 1)
	b.x:SetText("X")
	b.x:SetTextColor(0.96, 0.89, 0.77)
	b:SetScript("OnClick", function() parent:Hide() end)
	return b
end
function D.Check(cb) end
-- A horizontal slider: a dark well with a bronze lip and a gold thumb.
function D.Slider(sl)
	St.Backdrop(sl, "sw_well", "sw_lip", 1)
	local thumb = sl:CreateTexture(nil, "OVERLAY")
	St.Paint(thumb, "sw_bronze_btn")
	thumb:SetSize(12, 20)
	sl:SetThumbTexture(thumb)
end
function D.Tab(tab) end
function D.ScrollBar(sb) end

function D.BarTexture() return St.MEDIA .. "bar" end

function D.Bar(bar)
	bar:SetStatusBarTexture(D.BarTexture())
end

local SIZES = { title = 16, hero = 22, name = 15, body = 14, small = 13, number = 14, label = 11 }

function D.Font(fs, role, size)
	local file = (role == "title" or role == "hero") and FONT_TITLE or (role == "number" and FONT_NUM) or FONT_BODY
	fs:SetFont(file, math.max(St.MIN_TEXT, size or SIZES[role] or 12), (role == "hero" or role == "label") and "OUTLINE" or "")
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 0.9)
end
