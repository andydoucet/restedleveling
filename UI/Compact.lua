-- Rested Leveling: compact mode. One line of coloured state pips (best to play first, left to right) plus the
-- play-next name; hover a pip for that character, click it for the card, click the icon to open the full window.

local _, ns = ...
local St, Wg, Wd = ns.Style, ns.Widgets, ns.Words
local Cp = {}
ns.Compact = Cp

local PIP, MAX = 20, 14

local function pipTooltip(pip)
	local r = pip.data
	if not r then return end
	GameTooltip:SetOwner(pip, "ANCHOR_BOTTOM")
	GameTooltip:AddLine(St.ClassText(r.c.class, r.c.full or "?") .. "  |cffbbbbbb" .. (r.c.level or "") .. "|r")
	local s = St.STATE[r.state] or St.STATE.max
	GameTooltip:AddLine("|T" .. s.icon .. ":14|t " .. s.word .. "  " .. Wd.Chip(r), s.r, s.g, s.b)
	if r.p then
		local fullIn, clock = Wd.FullIn(r.p, time())
		GameTooltip:AddLine(("%d%% rested  ·  %s"):format(math.floor(r.p.pct * 100), fullIn .. (clock ~= "" and (" (" .. clock .. ")") or "")), 1, 1, 1)
		GameTooltip:AddLine(Wd.Levels(r.p.levels) .. " of double XP", 0.85, 0.85, 0.85)
	end
	GameTooltip:AddLine(Wd.Place(r.c), 0.75, 0.72, 0.66)
	GameTooltip:Show()
end

function Cp.Create()
	if Cp.frame then return Cp.frame end
	St.Ensure()
	local f = CreateFrame("Frame", "RestedLevelingCompact", UIParent, "BackdropTemplate")
	f:SetSize(340, 36)
	f:SetPoint("TOP", 0, -120)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	St.Panel(f, "top")   -- a small top-level window: our oak and iron, or the ElvUI skin's window
	f.icon = CreateFrame("Button", nil, f)
	f.icon:SetSize(24, 24)
	f.icon:SetPoint("LEFT", 9, 0)
	f.icon.tex = f.icon:CreateTexture(nil, "ARTWORK")
	f.icon.tex:SetAllPoints()
	f.icon.tex:SetTexture(St.MEDIA .. "icon")
	f.icon:SetScript("OnClick", function() Cp.Toggle(false); ns.ToggleMain() end)
	f.icon:SetScript("OnEnter", function() ns.Tip.Show(f) end)
	f.icon:SetScript("OnLeave", function() ns.Tip.Hide() end)
	f.pips = {}
	for i = 1, MAX do
		local p = CreateFrame("Button", nil, f)
		p:SetSize(PIP, PIP)
		p:SetPoint("LEFT", f.icon, "RIGHT", 6 + (i - 1) * (PIP + 3), 0)
		p.tex = p:CreateTexture(nil, "ARTWORK")
		p.tex:SetAllPoints()
		p.tex:SetTexture(St.MEDIA .. "pip")
		p.mark = p:CreateTexture(nil, "OVERLAY")
		p.mark:SetSize(PIP - 6, PIP - 6)
		p.mark:SetPoint("CENTER")
		p:SetScript("OnEnter", pipTooltip)
		p:SetScript("OnLeave", function() GameTooltip:Hide() end)
		p:SetScript("OnClick", function(self) if self.data and ns.ShowDetail then ns.ShowDetail(self.data.key) end end)
		f.pips[i] = p
	end
	f.next = Wg.Text(f, "body", nil, 13)
	f.next:SetTextColor(0.9, 0.88, 0.8)
	Cp.frame = f
	f:Hide()
	return f
end

-- A small glyph inside each pip, so the state reads without colour: tick full, dot nearly, zZ resting, ! outside.
local MARKS = {
	full = "Interface\\RaidFrame\\ReadyCheck-Ready", near = "Interface\\COMMON\\Indicator-Yellow",
	resting = "Interface\\Icons\\Spell_Nature_Sleep", outside = "Interface\\RaidFrame\\ReadyCheck-NotReady",
}

function Cp.Refresh()
	local f = Cp.frame
	if not f or not f:IsShown() then return end
	local rows = ns.Rows({ hideGrey = true })
	local n = math.min(#rows, MAX)
	for i = 1, MAX do
		local p, r = f.pips[i], rows[i]
		p.data = r
		if r then
			St.Paint(p.tex, "pip_" .. (St.STATE[r.state] and r.state or "max"))
			p.mark:SetTexture(MARKS[r.state])
			p.mark:SetAlpha(r.state == "resting" and 0.55 or 0.9)
			p:Show()
		else
			p:Hide()
		end
	end
	f.next:ClearAllPoints()
	f.next:SetPoint("LEFT", n > 0 and f.pips[n] or f.icon, "RIGHT", 8, 0)
	local top = rows[1]
	if top then
		local st = St.STATE[top.state] or St.STATE.max
		f.next:SetText(("Next: %s  ·  |c%s%s|r"):format(St.ClassText(top.c.class, top.c.full or "?"), St.Hex(st.r, st.g, st.b), st.word))
	else
		f.next:SetText("No alts yet")
	end
	f:SetWidth(math.max(340, 46 + n * (PIP + 3) + f.next:GetStringWidth() + 22))
end

-- on: true shows the compact bar (and hides the window), false hides it.
function Cp.Toggle(on)
	local f = Cp.Create()
	ns.DB().opts.compact = on and true or false
	if on and ns.Main.frame then ns.Main.frame:Hide() end
	f:SetShown(on)
	Cp.Refresh()
end

ns.RegisterCallback(Cp, "ROSTER_CHANGED", function() Cp.Refresh() end)
ns.RegisterCallback(Cp, "TICK", function() Cp.Refresh() end)
ns.RegisterCallback(Cp, "LOGIN_DONE", function() if ns.DB().opts.compact then Cp.Toggle(true) end end)
