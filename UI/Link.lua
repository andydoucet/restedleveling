-- Rested Leveling: the inline "Link account..." field, no popup. Click the button and a name field opens in place;
-- Enter (or Link) runs the same code as "/rlvl link <Full Name>", Esc (or Cancel) closes it. Once linked it says
-- where the pairing stands ("Linked to Le Bankken. Waiting for them to link you back ...", then "Paired with Le
-- Bankken, synced 5m ago") with an Unlink button. Used in the first-run guide and in the main window's footer.

local _, ns = ...
local St, Wg, Wd = ns.Style, ns.Widgets, ns.Words
local Lk = {}
ns.Link = Lk

Lk.HINT = "Character name on your other account"
local EDIT_W = 280
local all = {}   -- every field built, so one link updates both

local function text(f, role, size, color)
	local t = Wg.Text(f, role, nil, size)
	if color then St.Color(t, color) end
	return t
end

-- w: the room the field has; the status text wraps onto a second line when it needs to.
function Lk.Create(parent, w)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, 26)
	f.open = St.MakeButton(f, 130, "Link account...")
	f.open:SetPoint("LEFT", 0, 0)
	f.unlink = St.MakeButton(f, 80, "Unlink")
	f.unlink:SetPoint("LEFT", 0, 0)
	f.status = text(f, "small", 13, St.SECOND)
	f.status:SetPoint("LEFT", f.open, "RIGHT", 12, 0)
	f.status:SetWidth(w - 142)
	f.status:SetWordWrap(true)

	f.edit = CreateFrame("EditBox", nil, f, "BackdropTemplate")
	f.edit:SetSize(EDIT_W, 24)
	f.edit:SetPoint("LEFT", 0, 0)
	St.Backdrop(f.edit, "sw_well", "sw_lip", 1)
	St.Font(f.edit, "body", 13)
	f.edit:SetTextColor(0.96, 0.91, 0.76)
	f.edit:SetTextInsets(8, 8, 0, 0)
	f.edit:SetAutoFocus(false)
	f.edit:SetMaxLetters(48)   -- "Le Bankken" with room to spare; the name is cleaned the same way as /rlvl link
	f.hint = text(f.edit, "body", 13, St.MUTED)   -- the field's hint, until something is typed
	f.hint:SetPoint("LEFT", 8, 0)
	f.hint:SetText(Lk.HINT)
	f.hint:SetAlpha(0.6)   -- a hint, not typed text
	f.ok = St.MakeButton(f, 64, "Link", true)
	f.ok:SetPoint("LEFT", f.edit, "RIGHT", 8, 0)
	f.cancel = St.MakeButton(f, 74, "Cancel")
	f.cancel:SetPoint("LEFT", f.ok, "RIGHT", 6, 0)
	f.err = text(f, "small", 12, St.SECOND)   -- why a link did not take, under the field; the typed name stays
	f.err:SetPoint("TOPLEFT", f.edit, "BOTTOMLEFT", 2, -2)
	f.err:SetTextColor(1, 0.45, 0.35)

	f.open:SetScript("OnClick", function() Lk.Edit(f) end)
	f.ok:SetScript("OnClick", function() Lk.Submit(f) end)
	f.cancel:SetScript("OnClick", function() Lk.Close(f) end)
	f.unlink:SetScript("OnClick", function()
		if f.link and ns.slash.unlink then ns.slash.unlink(f.link.name) end
		Lk.RefreshAll()
	end)
	f.edit:SetScript("OnEnterPressed", function() Lk.Submit(f) end)
	f.edit:SetScript("OnEscapePressed", function() Lk.Close(f) end)
	f.edit:SetScript("OnTextChanged", function(self) f.hint:SetShown((self:GetText() or "") == "") end)
	-- The window or guide closing mid-edit: drop the field and its focus, so it never reopens half-typed.
	f:SetScript("OnHide", function() if f.editing then Lk.Close(f) end end)
	all[#all + 1] = f
	Lk.Close(f)
	return f
end

local function editing(f, on)
	f.editing = on
	f.edit:SetShown(on)
	f.ok:SetShown(on)
	f.cancel:SetShown(on)
	f.status:SetShown(not on)
	f.err:Hide()
end

-- Open the name field in place.
function Lk.Edit(f)
	editing(f, true)
	f.open:Hide()
	f.unlink:Hide()
	f.edit:SetText("")
	f.hint:Show()
	f.edit:SetFocus()
end

function Lk.Close(f)
	if f.edit.ClearFocus then f.edit:ClearFocus() end
	editing(f, false)
	Lk.Refresh(f)
end

local function isLinked(name)
	local key = ns.Sync.NameKey(name)
	for _, l in ipairs(ns.Sync.Links()) do if ns.Sync.NameKey(l.name) == key then return true end end
	return false
end

-- Enter or Link: the same path as "/rlvl link <name>" (names with spaces). An empty field stays open, and so does one
-- whose link did not take (at most 8 links): the name stays and the reason shows under it.
function Lk.Submit(f)
	local name = ns.Sync and ns.Sync.CleanName(f.edit:GetText())
	if not name then f.edit:SetFocus() return end
	ns.slash.link(name)
	if not isLinked(name) then
		f.err:SetText(("Not linked: at most %d links. Unlink one first (/rlvl unlink <name>)."):format(ns.Sync.MAX_LINKS))
		f.err:Show()
		f.edit:SetFocus()
		return
	end
	Lk.Close(f)
	Lk.RefreshAll()
end

-- The state line: no link yet, waiting for the other side, or paired (and when it last synced).
function Lk.Refresh(f, now)
	if f.editing then return end
	local links = ns.Sync and ns.Sync.Links() or {}
	f.link = links[1]
	local me = ns.Me()
	f.open:SetShown(f.link == nil)
	f.unlink:SetShown(f.link ~= nil)
	f.status:ClearAllPoints()
	f.status:SetPoint("LEFT", f.link and f.unlink or f.open, "RIGHT", 12, 0)
	f.status:SetWidth(f:GetWidth() - (f.link and 92 or 142))
	local line = Wd.LinkLine(f.link, me and me.full, now or time())
	if #links > 1 then line = line .. (" (+%d more)"):format(#links - 1) end
	f.status:SetText(line)
end

function Lk.RefreshAll()
	for _, f in ipairs(all) do Lk.Refresh(f) end
end

ns.RegisterCallback(Lk, "LINK_CHANGED", function() Lk.RefreshAll() end)
ns.RegisterCallback(Lk, "SYNC_DONE", function() Lk.RefreshAll() end)
