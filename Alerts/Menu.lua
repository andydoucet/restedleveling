-- Rested Leveling: the alert menu and the controls every alert shares. Right-click (or the gear) opens a small menu
-- flush under the alert, never a popup: "Dismiss this warning" or "Disable <kind> warnings...", which then says so
-- inline with Undo and Options. Also the close and options buttons. Used by Alerts/Alerts.lua.

local _, ns = ...
local St, Wg = ns.Style, ns.Widgets
local A = ns.Alerts or {}
ns.Alerts = A

local SHORT = { logout = "logout", menu = "Esc-menu", outrest = "ran-out", filled = "filled-up", bag = "sleeping bag" }

-- The right-click menu: two choices, flush under the alert, gone on a choice or after 6 s. Disabling keeps the
-- menu up for 6 s as "<Kind> warnings off · Undo · Options".
function A.OpenMenu(owner, kind)
	local m = A.Menu()
	m.owner, m.kind, m.age = owner, kind, 0
	m.items[2].text:SetText(("Disable future %s warnings..."):format(SHORT[kind] or "these"))
	for _, b in ipairs(m.items) do b:Show() end
	m.off:Hide()
	-- sized to its items, anchored under the control that opens it (the gear), with nothing empty beneath
	local w = 0
	for _, b in ipairs(m.items) do w = math.max(w, b.text:GetStringWidth()) end
	m:SetSize(w + 40, #m.items * 28 + 12)
	m:ClearAllPoints()
	m:SetPoint("TOPRIGHT", owner.options or owner, "BOTTOMRIGHT", 0, -4)
	m:Show()
end

function A.Menu()
	if A.menu then return A.menu end
	local m = CreateFrame("Frame", "RestedLevelingAlertMenu", UIParent, "BackdropTemplate")
	m:SetSize(226, 66)
	m:SetFrameStrata("FULLSCREEN_DIALOG")
	St.Panel(m, "tooltip")
	m.items = {}
	for i, label in ipairs({ "Dismiss this warning", "Disable these warnings..." }) do
		local b = CreateFrame("Button", nil, m)
		b:SetHeight(28)
		b:SetPoint("TOPLEFT", 10, -8 - (i - 1) * 28)
		b:SetPoint("RIGHT", -10, 0)
		b.hl = b:CreateTexture(nil, "HIGHLIGHT")
		b.hl:SetAllPoints()
		St.Paint(b.hl, "sw_btn_hi")
		b.text = Wg.Text(b, "body", nil, 13)
		b.text:SetPoint("LEFT", 6, 0)
		b.text:SetText(label)
		if i == 2 then St.Font(b.text, "small", 12) end   -- the lasting choice is quieter, so it is not mis-hit
		St.Color(b.text, i == 2 and St.MUTED or St.CREAM)
		m.items[i] = b
	end
	m.off = CreateFrame("Frame", nil, m)   -- after Disable: what happened, Undo, Options
	m.off:SetAllPoints()
	m.offText = Wg.Text(m.off, "body", nil, 13)
	m.offText:SetPoint("TOPLEFT", 16, -14)
	St.Color(m.offText, St.CREAM)
	m.undo = St.MakeButton(m.off, 70, "Undo", false, 22)
	m.undo:SetPoint("BOTTOMLEFT", 14, 10)
	m.opts = St.MakeButton(m.off, 90, "Options...", false, 22)
	m.opts:SetPoint("LEFT", m.undo, "RIGHT", 8, 0)
	m.items[1]:SetScript("OnClick", function() if m.owner then m.owner:Hide() end m:Hide() end)
	m.items[2]:SetScript("OnClick", function()
		ns.DB().alertsOff[m.kind] = true
		if m.owner then m.owner:Hide() end
		for _, b in ipairs(m.items) do b:Hide() end
		m.offText:SetText(((SHORT[m.kind] or "These") .. " warnings off."):gsub("^%l", string.upper))
		m.off:Show()
		m.age = 0
	end)
	m.undo:SetScript("OnClick", function()
		ns.DB().alertsOff[m.kind] = nil
		if m.owner then m.owner:Show() end
		m:Hide()
	end)
	m.opts:SetScript("OnClick", function() m:Hide(); if ns.OpenOptions then ns.OpenOptions() end end)
	m:SetScript("OnUpdate", function(self, e) self.age = (self.age or 0) + e; if self.age > 6 then self:Hide() end end)
	A.menu = m
	m:Hide()
	return m
end

function A.Dismissable(f, kind)
	f:EnableMouse(true)
	f:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then A.OpenMenu(self, kind) return end
		self:Hide()
	end)
end

-- Dismiss: in our own style, the bronze secondary button with an X (one family with Compact and View); under
-- ElvUI the host's skinned close. 24 px.
function A.CloseButton(f)
	local b
	if St.HostFrame() then
		b = St.MakeClose(f)
		b:ClearAllPoints()
	else
		b = St.MakeButton(f, 24, "X", false, 24)
		b:SetScript("OnClick", function() f:Hide() end)
	end
	b:SetPoint("TOPRIGHT", -8, -8)
	b:SetHitRectInsets(-4, -4, -4, -4)   -- a 32 px target around the 24 px cross
	return b
end

-- An options button (opens the same small menu as right-click), beside the close button.
function A.OptionsButton(f, kind)
	local b = CreateFrame("Button", nil, f)
	b:SetSize(24, 24)
	b:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
	b.icon = b:CreateTexture(nil, "ARTWORK")   -- 16 px and muted: it must not compete with the warning sign
	b.icon:SetSize(18, 18)   -- findable, still muted
	b.icon:SetPoint("CENTER")
	b.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	b.icon:SetDesaturated(true)
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints()
	b.hl:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	b.hl:SetBlendMode("ADD")
	b:SetScript("OnClick", function() A.OpenMenu(f, kind) end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Alert settings")
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end
