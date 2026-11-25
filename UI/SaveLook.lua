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
-- is tried in order until one has a file ID: in game SetTexture returns true even for a path that draws nothing, and
-- only GetTextureFileID told the two apart (docs/API.md, the ILL-1276 probe). A file that does not load leaves the
-- crest showing. Returns true when a look is drawn.
function L.Show(f, c, desaturate)
	local look = c and LD.Valid(c.look)
	if not look then f.look:Hide() return false end
	local names = LD.Names(look)
	for i = nameIndex[look.file] or 1, #names do
		U.Call(f.look.SetTexture, f.look, nil)   -- no file ID left over from the last character drawn here
		local ran, ok = pcall(f.look.SetTexture, f.look, LD.DIR .. names[i])
		local id = ran and ok ~= false and U.Call(f.look.GetTextureFileID, f.look)
		if id and id ~= 0 then
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
	s:EnableKeyboard(true)   -- Esc cancels
	s:SetScript("OnKeyDown", function(self, key)
		-- every other key still reaches the game (movement, push-to-talk); setting this is protected in combat
		if not U.Call(InCombatLockdown) then U.Call(self.SetPropagateKeyboardInput, self, key ~= "ESCAPE") end
		if key == "ESCAPE" and run then L.Finish(run, false, "cancelled") end
	end)
	s:SetScript("OnMouseDown", function() if run then L.Finish(run, false, "cancelled") end end)
	s:Hide()
	L.stage = s
	return s
end

-- Portrait framing on the stage model: standing still, weapons off, head and shoulders. SetUnit("player") only once
-- per capture: calling it again reloads the model (weapons back on, half drawn).
-- The stand animation frozen on its first frame (CharacterModelBase:FreezeAnimation(anim, variation, frame), as
-- Blizzard's TransmogSetBaseModelMixin does with 0, 0, 0): a playing stand runs its idle variations, and Andy's first
-- look caught one mid-shrug with her eyes shut. Without FreezeAnimation the stand animation starts over here and the
-- shot is taken one frame later (L.Shoot), before an idle variation can begin.
function L.Pose(m)
	for _, slot in ipairs(L.WEAPON_SLOTS) do U.Call(m.UndressSlot, m, slot) end
	U.Call(m.SetSheathed, m, true, true)   -- DressUpModel: sheathed and hidden, for anything UndressSlot left
	U.Call(m.SetPortraitZoom, m, L.ZOOM)
	U.Call(m.SetRotation, m, L.ROTATION)
	U.Call(m.SetAnimation, m, 0)
	if type(m.FreezeAnimation) == "function" then pcall(m.FreezeAnimation, m, 0, 0, 0) end
end
local pose = L.Pose

local function getFormat() return C_CVar and U.Call(C_CVar.GetCVar, "screenshotFormat") end

function L.Busy() return run ~= nil end

-- Open Blizzard windows that UIParent:Hide() would close: their OnHide ends the NPC interaction (the merchant,
-- the bank, the mailbox...) and a hidden StaticPopup runs its OnHide (a group invite is declined). Names
-- from the Forever FrameXML; the trainer and auction house load on demand, so any of them may be nil.
local function blocker()
	if not UIParent:IsShown() then return nil end   -- already hidden (Alt-Z): hiding it again closes nothing
	local open = {
		{ MerchantFrame, "the merchant window" }, { BankFrame, "the bank" }, { MailFrame, "the mailbox" },
		{ GossipFrame, "the conversation window" }, { QuestFrame, "the quest window" }, { LootFrame, "the loot window" },
		{ TradeFrame, "the trade window" }, { ItemTextFrame, "the book" }, { TaxiFrame, "the flight map" },
		{ ClassTrainerFrame, "the trainer window" }, { AuctionHouseFrame, "the auction house" },
		{ PetitionFrame, "the petition" }, { GuildRegistrarFrame, "the guild registrar" },
		{ StaticPopup1, "the open dialog" }, { StaticPopup2, "the open dialog" }, { StaticPopup3, "the open dialog" },
		{ StaticPopup4, "the open dialog" },
	}
	for _, o in ipairs(open) do
		local f = o[1]
		if type(f) == "table" and U.Call(f.IsShown, f) then return o[2] end
	end
end

-- The player's screenshot format, kept in the saved data while it is set to tga: a crash mid-capture would otherwise
-- leave every later screenshot a .tga. Put back on the next login.
function L.Recover()
	local d = ns.DB()
	local saved = d.lookFormat
	if saved == nil or run then return end
	d.lookFormat = nil
	if type(saved) == "string" and getFormat() == "tga" and C_CVar and C_CVar.SetCVar then
		U.Call(C_CVar.SetCVar, "screenshotFormat", saved)
	end
end
ns.RegisterCallback(L, "LOGIN_DONE", function() L.Recover() end)

-- "Save my look": the logged-in character only, out of combat. Returns true when a capture started.
function L.Save()
	if run then return false end
	local key = ns.MyKey()
	if not key or not ns.Me() then return false end
	if U.Call(InCombatLockdown) then U.Print("Leave combat first.") return false end
	local open = blocker()
	if open then U.Print("Close " .. open .. " first.") return false end
	local s = stage()
	local card = ns.Card and ns.Card.frame
	-- hiding UIParent hides the card too (and its OnHide clears the selection): open it again after
	run = { key = key, ui = UIParent:IsShown(), card = card and card:IsShown() and ns.selectedKey or nil }
	local this = run
	C_Timer.After(L.TIMEOUT, function() L.Finish(this, false, "timeout") end)   -- first: whatever happens next
	for _, e in ipairs({ "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED", "PLAYER_REGEN_DISABLED", "PLAYER_LEAVING_WORLD" }) do
		events:RegisterEvent(e)
	end
	local ok = pcall(function()
		if this.ui then UIParent:Hide() end   -- like Alt-Z: allowed out of combat
		s:Show()
		local _, physH = U.Call(GetPhysicalScreenSize)
		local size = LD.ModelSize(physH, s:GetHeight())
		s.model:SetSize(size, size)
		U.Call(s.model.SetUnit, s.model, "player")
		pose(s.model)
	end)
	if not ok then L.Finish(this, false, "failed") return false end   -- an error here must not leave the UI hidden
	C_Timer.After(L.WAIT, function() L.Shoot(this) end)
	return true
end

-- Take the screenshot (once): as .tga, the only format the client loads back, then the player's format again.
function L.Shoot(r)
	if run ~= r or r.posed then return end
	r.posed = true
	pose(L.stage.model)   -- again once loaded: undressing before the model loads does nothing
	C_Timer.After(0, function() L.Snap(r) end)   -- one frame for the new pose to draw
end

function L.Snap(r)
	if run ~= r or r.asked then return end
	local s = L.stage
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
		ns.DB().lookFormat = r.restore   -- L.Recover puts it back after a crash
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
	if r.restore then
		U.Call(C_CVar.SetCVar, "screenshotFormat", r.restore)
		ns.DB().lookFormat = nil
	end
	if L.stage then
		L.stage:Hide()
		U.Call(L.stage.model.ClearModel, L.stage.model)
	end
	if r.ui and not UIParent:IsShown() then
		if U.Call(InCombatLockdown) then events:RegisterEvent("PLAYER_REGEN_ENABLED") else UIParent:Show() end
	end
	local key = ns.MyKey() or r.key   -- the key can move during the capture (N: to G: once the GUID reads)
	local c = ns.DB().chars[key]
	local at = time()
	local look = ok and LD.Valid({ file = LD.FileName(at), l = r.l, r = r.r, t = r.t, b = r.b, at = at, asked = r.asked })
	if look and c then
		c.look, c.lookCleared = look, nil
		L.fresh[key] = true
		U.Print(L.SAVED_NOTE)
		ns.Snapshot(true)   -- a fresh snapshot time, so the other account takes the record
	elseif ok and not look then   -- the crop came out empty or outside the screenshot: keep the look there was
		U.Print("Look not saved: couldn't frame the character.")
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
	c.look, c.lookCleared, L.fresh[key] = nil, true, nil   -- the token tells the other account to clear it too
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

-- The card's controls (Detail/Card.lua): "Save my look" and "Clear look" side by side, the note above them, for the
-- character you are on. In the bubble's column, under it: the figure column stays clear for the live model. The card
-- anchors the box by its bottom left; the box grows up as the note appears.
L.CONTROLS_W, L.BUTTON_H = 210, 22
function L.CardControls(s)
	local box = CreateFrame("Frame", nil, s)
	box:SetSize(L.CONTROLS_W, L.BUTTON_H)
	box.save = St.MakeButton(box, 124, "Save my look", false, L.BUTTON_H)
	box.save:SetPoint("BOTTOMLEFT")
	box.save:SetScript("OnClick", function() L.Save() end)
	box.clear = St.MakeButton(box, 80, "Clear look", false, L.BUTTON_H)
	box.clear:SetPoint("LEFT", box.save, "RIGHT", 6, 0)
	box.clear:SetScript("OnClick", function() L.Clear(ns.MyKey()) end)
	box.note = ns.Widgets.Text(box, "small", "OVERLAY", 12)
	box.note:SetWidth(L.CONTROLS_W)
	box.note:SetWordWrap(true)
	box.note:SetPoint("BOTTOMLEFT", box.save, "TOPLEFT", 0, 6)
	St.Color(box.note, St.CREAM)
	return box
end

function L.UpdateCardControls(box, key, isMe)
	box:SetShown(isMe)
	local c = ns.DB().chars[key]
	local has = isMe and c and c.look ~= nil
	box.clear:SetShown(has and true or false)
	local fresh = isMe and L.fresh[key] and true or false
	box.note:SetText(fresh and L.SAVED_NOTE or "")
	box.note:SetShown(fresh)
	box:SetHeight(L.BUTTON_H + (fresh and (box.note:GetStringHeight() + 6) or 0))
end
