-- Rested Leveling: "Save my look" (ILL-1279). The game cannot draw an offline character's face (docs/API.md,
-- "Offline appearance"), but it can draw a screenshot back as a texture after a restart (the ILL-1276 probe). So on
-- the character you are on, one button: the UI hides (like Alt-Z), the character stands alone on a plain dark
-- backdrop, the game takes one screenshot, and everything comes back. Its other characters' portraits then show that
-- face inside the usual round ring, cropped from the screenshot.
--
-- The capture is one small state machine with a single way out (finish): success, a failed screenshot, Esc or a click,
-- combat starting, a loading screen or a timeout all restore UIParent, the screenshotFormat CVar and the stage.

local _, ns = ...
local St, U, LD = ns.Style, ns.Util, ns.LookData
local L = {}
ns.Look = L

L.WAIT, L.SETTLE, L.TIMEOUT = 1.0, 0.25, 6   -- s: shoot anyway if the model never says it loaded; after it does; give up
L.ZOOM, L.ROTATION = 0.6, -0.35   -- head and shoulders, turned a little toward the light: front three-quarter
L.WEAPON_SLOTS = { 16, 17, 18 }   -- main hand, off hand, ranged: undressed so the portrait is the character
L.BG = { 11 / 255, 9 / 255, 8 / 255 }   -- disc_dark, the portrait disc's own fill: the crop sits in the ring seamlessly
L.SAVED_NOTE = "Saved. Shows on other characters after you restart the game."

L.fresh = {}   -- keys saved this session (the file loads only after a restart)
local nameIndex = {}   -- per look file: which of its candidate names SetTexture took

-- Portraits -------------------------------------------------------------------------------------------------------

-- Draw `c`'s saved look in a portrait (Widgets.Portrait), over the class crest it already shows. Each candidate name
-- is tried in order until SetTexture takes one; a file that does not load leaves the crest showing. Returns true
-- when a look is drawn.
function L.Show(f, c, desaturate)
	local look = c and LD.Valid(c.look)
	if not look then f.look:Hide() return false end
	local names = LD.Names(look)
	for i = nameIndex[look.file] or 1, #names do
		if U.Call(f.look.SetTexture, f.look, LD.DIR .. names[i]) ~= false then
			nameIndex[look.file] = i
			f.look:SetTexCoord(look.l, look.r, look.t, look.b)
			f.look:SetDesaturated(desaturate and true or false)
			f.look:Show()
			return true
		end
	end
	nameIndex[look.file] = #names + 1   -- none loads: the crest, silently
	f.look:Hide()
	return false
end

-- The capture stage -----------------------------------------------------------------------------------------------

local run   -- the capture in progress, or nil
local events = CreateFrame("Frame")

local function stage()
	if L.stage then return L.stage end
	-- On WorldFrame, not UIParent: it stays on screen while UIParent is hidden (as nameplates do). In the simulator a
	-- frame with no parent is not drawn at all with UIParent hidden; a WorldFrame child is.
	local s = CreateFrame("Frame", "RestedLevelingLookStage", WorldFrame)
	s:SetAllPoints(WorldFrame)
	s:SetFrameStrata("FULLSCREEN_DIALOG")
	s.bg = s:CreateTexture(nil, "BACKGROUND")
	s.bg:SetAllPoints()
	s.bg:SetColorTexture(L.BG[1], L.BG[2], L.BG[3], 1)
	s.model = CreateFrame("DressUpModel", nil, s)
	s.model:SetPoint("CENTER")
	s.model:SetScript("OnModelLoaded", function()
		if run and not run.loaded then
			run.loaded = true
			local this = run
			C_Timer.After(L.SETTLE, function() L.Shoot(this) end)
		end
	end)
	s:EnableMouse(true)
	s:EnableKeyboard(true)   -- every key while it is up (about a second); Esc cancels
	s:SetScript("OnKeyDown", function(_, key) if key == "ESCAPE" and run then L.Finish(run, false, "cancelled") end end)
	s:SetScript("OnMouseDown", function() if run then L.Finish(run, false, "cancelled") end end)
	s:Hide()
	L.stage = s
	return s
end

-- Portrait framing on the stage model: the player, idle, weapons off, head and shoulders.
local function frame(m)
	U.Call(m.SetUnit, m, "player")
	for _, slot in ipairs(L.WEAPON_SLOTS) do U.Call(m.UndressSlot, m, slot) end
	U.Call(m.SetPortraitZoom, m, L.ZOOM)
	U.Call(m.SetRotation, m, L.ROTATION)
	U.Call(m.SetAnimation, m, 0)
end

local function getFormat() return C_CVar and U.Call(C_CVar.GetCVar, "screenshotFormat") end

function L.Busy() return run ~= nil end

-- "Save my look": the logged-in character only, out of combat. Returns true when a capture started.
function L.Save()
	if run then return false end
	local key = ns.MyKey()
	if not key or not ns.Me() then return false end
	if U.Call(InCombatLockdown) then U.Print("Leave combat first.") return false end
	local s = stage()
	local card = ns.Card and ns.Card.frame
	-- hiding UIParent hides the card too (and its OnHide clears the selection): open it again after
	run = { key = key, ui = UIParent:IsShown(), card = card and card:IsShown() and ns.selectedKey or nil }
	for _, e in ipairs({ "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED", "PLAYER_REGEN_DISABLED", "PLAYER_LEAVING_WORLD" }) do
		events:RegisterEvent(e)
	end
	if run.ui then UIParent:Hide() end   -- like Alt-Z: allowed out of combat
	s:Show()
	local _, physH = U.Call(GetPhysicalScreenSize)
	local size = LD.ModelSize(physH, s:GetHeight())
	s.model:SetSize(size, size)
	frame(s.model)
	local this = run
	C_Timer.After(L.WAIT, function() L.Shoot(this) end)
	C_Timer.After(L.TIMEOUT, function() L.Finish(this, false, "timeout") end)
	return true
end

-- Take the screenshot (once): as .tga, the only format the client loads back, then the player's format again.
function L.Shoot(r)
	if run ~= r or r.asked then return end
	local s = L.stage
	frame(s.model)   -- again once loaded: undressing before the model loads does nothing
	local sl, sb, sw, sh = s:GetLeft() or 0, s:GetBottom() or 0, s:GetWidth(), s:GetHeight()
	local ml, mb, mw, mh = s.model:GetLeft(), s.model:GetBottom(), s.model:GetWidth(), s.model:GetHeight()
	if not ml then   -- not laid out: the model is centred
		ml, mb = sl + (sw - mw) / 2, sb + (sh - mh) / 2
	end
	r.l, r.r, r.t, r.b = LD.TexCoords({ left = sl, right = sl + sw, top = sb + sh, bottom = sb },
		{ left = ml, right = ml + mw, top = mb + mh, bottom = mb })
	local format = getFormat()
	if format ~= "tga" and C_CVar and C_CVar.SetCVar then
		r.restore = format or "jpeg"
		U.Call(C_CVar.SetCVar, "screenshotFormat", "tga")
	end
	r.asked = time()
	if not pcall(Screenshot) then L.Finish(r, false, "failed") end   -- an error here must not leave the UI hidden
end

-- The one way out: everything put back, whatever happened. ok: the screenshot was written.
function L.Finish(r, ok, why)
	if run ~= r then return end
	run = nil
	events:UnregisterAllEvents()
	if r.restore then U.Call(C_CVar.SetCVar, "screenshotFormat", r.restore) end
	if L.stage then
		L.stage:Hide()
		U.Call(L.stage.model.ClearModel, L.stage.model)
	end
	if r.ui and not UIParent:IsShown() then
		if U.Call(InCombatLockdown) then events:RegisterEvent("PLAYER_REGEN_ENABLED") else UIParent:Show() end
	end
	local c = ns.DB().chars[r.key]
	if ok and c then
		local at = time()
		c.look = { file = LD.FileName(at), l = r.l, r = r.r, t = r.t, b = r.b, at = at, asked = r.asked }
		L.fresh[r.key] = true
		U.Print(L.SAVED_NOTE)
		ns.Snapshot(true)   -- a fresh snapshot time, so the other account takes the record
	elseif why == "combat" then
		U.Print("Look not saved: you entered combat.")
	elseif why ~= "cancelled" then
		U.Print("Look not saved: the screenshot " .. (why == "timeout" and "took too long." or "failed."))
	end
	if r.card and ns.Card then ns.Card.Show(r.card) end
	ns.Fire("ROSTER_CHANGED")
end

events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_ENABLED" then   -- UIParent left hidden because combat came first: show it now
		self:UnregisterEvent(event)
		if not run then UIParent:Show() end
		return
	end
	if not run then return end
	if event == "SCREENSHOT_SUCCEEDED" then
		if run.asked then L.Finish(run, true) end   -- not someone else's screenshot taken before ours
	elseif event == "SCREENSHOT_FAILED" then
		if run.asked then L.Finish(run, false, "failed") end
	elseif event == "PLAYER_REGEN_DISABLED" then   -- fires before the lockdown starts: UIParent can still be shown
		L.Finish(run, false, "combat")
	else
		L.Finish(run, false, "left")
	end
end)

function L.Clear(key)
	local c = key and ns.DB().chars[key]
	if not (c and c.look) then return end
	c.look, L.fresh[key] = nil, nil
	if ns.MyKey() == key then ns.Snapshot(true) end
	if ns.Card and ns.Card.frame and ns.Card.frame:IsShown() and ns.selectedKey == key then ns.Card.Show(key) end
	ns.Fire("ROSTER_CHANGED")
end

-- Right-click on the now-playing strip: the same two actions, and the card. The client's own context menu, when it
-- has one (Blizzard_Menu); otherwise a right-click just opens the card, where the buttons are.
function L.Menu(owner)
	local key = ns.MyKey()
	if not key then return end
	if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.ShowDetail(key) return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateButton("Open my card", function() ns.ShowDetail(key) end)
		root:CreateButton("Save my look", function() L.Save() end)
		local c = ns.DB().chars[key]
		if c and c.look then root:CreateButton("Clear look", function() L.Clear(key) end) end
	end)
end

-- The card's controls (Detail/Card.lua): "Save my look", "Clear look" and the note, for the character you are on.
function L.CardControls(s)
	local box = CreateFrame("Frame", nil, s)
	box:SetSize(180, 80)
	box:SetPoint("TOPRIGHT", -12, -12)
	box.save = St.MakeButton(box, 124, "Save my look", false)
	box.save:SetPoint("TOPRIGHT")
	box.save:SetScript("OnClick", function() L.Save() end)
	box.clear = St.MakeButton(box, 90, "Clear look", false, 20)
	box.clear:SetPoint("TOPRIGHT", box.save, "BOTTOMRIGHT", 0, -6)
	box.clear:SetScript("OnClick", function() L.Clear(ns.MyKey()) end)
	box.note = ns.Widgets.Text(box, "small", "OVERLAY", 12)
	box.note:SetWidth(170)
	box.note:SetWordWrap(true)
	box.note:SetJustifyH("RIGHT")
	box.note:SetPoint("TOPRIGHT", box.clear, "BOTTOMRIGHT", 0, -6)
	St.Color(box.note, St.CREAM)
	return box
end

function L.UpdateCardControls(box, key, isMe)
	box:SetShown(isMe)
	local c = ns.DB().chars[key]
	local has = isMe and c and c.look ~= nil
	box.clear:SetShown(has and true or false)
	box.note:ClearAllPoints()
	box.note:SetPoint("TOPRIGHT", has and box.clear or box.save, "BOTTOMRIGHT", 0, -6)
	box.note:SetText((isMe and L.fresh[key]) and L.SAVED_NOTE or "")
	box.note:SetShown(isMe and L.fresh[key] and true or false)
end
