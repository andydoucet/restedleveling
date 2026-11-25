-- Rested Leveling: the main window. #1 PLAY NEXT hero card, the current-character strip, then the rest, best first.
-- Opens with /rlvl, the minimap button or a datatext click. Esc closes it.

local _, ns = ...
local St, Wg, Wd = ns.Style, ns.Widgets, ns.Words
local Main = {}
ns.Main = Main

Main.W, Main.VISIBLE = 776, 9
local PAD = 20   -- inside the frame band
local TOP = 56   -- below the title rail and its rule (or the host skin's title band)

-- The legend uses the chips' own icons and words, so it explains them.
local function legend(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(420, 16)
	f.parts = {}
	local prev
	for _, state in ipairs({ "full", "near", "resting", "outside" }) do   -- each item follows the last one's text
		local s = St.STATE[state]
		local icon = f:CreateTexture(nil, "ARTWORK")
		icon:SetTexture(s.icon)
		icon:SetSize(13, 13)
		if prev then icon:SetPoint("LEFT", prev, "RIGHT", 14, 0) else icon:SetPoint("LEFT", 0, 0) end
		local t = Wg.Text(f, "small", nil, 13)
		t:SetPoint("LEFT", icon, "RIGHT", 4, 0)
		t:SetTextColor(s.r, s.g, s.b)
		f.parts[state] = t
		prev = t
	end
	return f
end

local FOOT = St.FOOT + 14   -- the footer has room above and below it
local function chromeH(f, listH) return TOP + f.heroH + 8 + f.curH + 36 + listH + 8 + FOOT end

function Main.Create()
	if Main.frame then return Main.frame end
	St.Ensure()
	local ok, f = pcall(CreateFrame, "Frame", "RestedLevelingMain", UIParent, St.WindowTemplate())
	if not ok or not f then
		f = CreateFrame("Frame", "RestedLevelingMain", UIParent, "BackdropTemplate")
		St.Panel(f, "card")
	end
	f.heroH, f.curH = 234, 62
	f.fullHeroH = f.heroH
	f:SetSize(Main.W, chromeH(f, Main.VISIBLE * ns.Roster.ROW_H))
	f:SetPoint("CENTER", -160, 10)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	St.Window(f, "Rested Leveling")
	tinsert(UISpecialFrames, "RestedLevelingMain")

	St.Scale(f)
	f.compactBtn = St.MakeButton(f, 96, "Compact", false, St.HostFrame() and 22 or 24)
	-- On our own frame it sits on the title rail; under a host skin the title band is the skin's, so it goes in the
	-- footer, bottom right, as on the host's own skinned windows.
	if St.HostFrame() then   -- in the host's title bar, left of its close button
		f.compactBtn:SetPoint("TOPRIGHT", -36, -8)
	else
		f.compactBtn:SetPoint("TOPRIGHT", -48, -(St.BAND + (St.RAIL_H - 24) / 2))
	end
	f.compactBtn:SetScript("OnClick", function() if ns.Compact then ns.Compact.Toggle(true) end end)

	local inner = Main.W - PAD * 2
	f.hero = ns.Hero.Create(f, inner, f.heroH)
	f.hero:SetPoint("TOPLEFT", PAD, -TOP)
	f.current = ns.Current.Create(f, inner, f.curH)
	f.current:SetPoint("TOPLEFT", f.hero, "BOTTOMLEFT", 0, -8)

	f.headerBtn = CreateFrame("Frame", nil, f)
	f.headerBtn:SetSize(76, 20)
	f.headerBtn:SetPoint("TOPLEFT", f.current, "BOTTOMLEFT", 4 + Wg.COL.text, -9)   -- on the rows' name column
	f.header = Wg.Text(f.headerBtn, "label", nil, 11)   -- section labels are quiet; cream is for the #1
	f.header:SetPoint("LEFT")
	f.header:SetText("NEXT BEST")
	St.Color(f.header, St.MUTED)
	f.headerBtn:EnableMouse(true)
	f.headerBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("How the order works")
		GameTooltip:AddLine("Full first, the one full longest on top (its rest is being wasted). Then nearly full by %, "
			.. "then by levels of double XP banked, then empty. Max level and hidden come last.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	f.headerBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- The list's header band (both styles): NEXT BEST, the legend and STATE sit on it, so nothing floats.
	f.band = f:CreateTexture(nil, "BORDER")
	St.Paint(f.band, "sw_band")
	f.band:SetHeight(22)
	f.band:SetPoint("TOP", f.current, "BOTTOM", 0, -8)
	if St.HostFrame() then   -- under a host skin, cream section titles like its Options window
		St.Font(f.header, "name", 13)
		St.Color(f.header, St.CREAM)
	end
	f.legend = legend(f)
	f.legend:SetPoint("LEFT", f.headerBtn, "RIGHT", 10, 0)

	f.list = CreateFrame("Frame", nil, f, "BackdropTemplate")
	f.list:SetPoint("TOPLEFT", f.current, "BOTTOMLEFT", 0, -36)
	-- The Well Rested column says what its moons are.
	f.moonHead = CreateFrame("Frame", nil, f)
	f.moonHead:SetSize(Wg.CHIP_W, 18)   -- centred over the chip column
	f.moonHead:SetPoint("LEFT", f.list, "LEFT", 4 + Wg.COL.chip, 0)
	f.moonHead:SetPoint("TOP", f.headerBtn, "TOP", 0, 0)   -- on NEXT BEST's line
	f.moonLabel = Wg.Text(f.moonHead, "label", nil, 11)
	f.moonLabel:SetPoint("CENTER")
	f.moonLabel:SetText("STATE")   -- the moons explain themselves on hover
	St.Color(f.moonLabel, St.MUTED)
	f.moonHead:EnableMouse(true)
	f.moonHead:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Rest bonus: the Well Rested Legacy perk")
		GameTooltip:AddLine("Each row's tooltip and character card show its tier, up to 5. Each tier fills rest 4% faster "
			.. "and raises the cap 4%. It does not change the order.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	f.moonHead:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.list:SetSize(inner, Main.VISIBLE * ns.Roster.ROW_H + 8)
	f.band:SetPoint("LEFT", f.list, "LEFT", 0, 0)   -- exactly the list's width
	f.band:SetPoint("RIGHT", f.list, "RIGHT", 0, 0)
	St.Panel(f.list, "inset")
	f.roster = ns.Roster.Create(f.list, inner - 8, Main.VISIBLE)
	f.roster:SetPoint("TOPLEFT", 4, -4)

	-- The footer's link field (the guide has its own while it shows): status, Link account... / Unlink, and the
	-- inline name field in place.
	f.link = ns.Link.Create(f, Main.W - PAD * 2 - 236)
	f.link:SetPoint("BOTTOMLEFT", PAD + 8, 19)
	f.greyCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	f.greyCheck:SetSize(24, 24)
	f.greyCheck:SetPoint("BOTTOMRIGHT", -210, 20)
	St.Check(f.greyCheck)
	f.greyLabel = Wg.Text(f, "small", nil, 13)
	f.greyLabel:SetPoint("LEFT", f.greyCheck, "RIGHT", 2, 0)
	f.greyLabel:SetText("Show max level and hidden")
	St.Color(f.greyLabel, St.SECOND)
	f.greyCheck:SetScript("OnClick", function(self)
		ns.DB().opts.showGrey = self:GetChecked() and true or false
		Main.Refresh()
	end)

	f:SetScript("OnShow", function() Main.Refresh() end)
	Main.frame = f
	f:Hide()
	return f
end

function Main.Refresh()
	local f = Main.frame
	if not f or not f:IsShown() then return end
	local now = time()
	local rows = ns.Rows()
	local hero = rows[1]
	if hero and hero.group == 5 then hero = nil end
	-- Nothing banked anywhere: the hero shows who fills first instead of sending you to a 0.0.
	local empty = Wd.NothingBanked(hero)
	if empty then hero = Wd.FillsFirst(rows) or hero end
	ns.Hero.Update(f.hero, hero, now, ns.Me(), rows, empty)
	f.heroH = hero and f.fullHeroH or (f.fullHeroH - 50)   -- the welcome card has no action bar
	f.hero:SetHeight(f.heroH)
	ns.Current.Update(f.current)
	local list = {}
	for _, r in ipairs(rows) do if r ~= hero then list[#list + 1] = r end end
	ns.Roster.Update(f.roster, list, now, hero and 2 or 1)
	-- Fit the window to the roster: between 3 and 9 rows tall (the first-run guide needs about 4).
	local shown = math.max(3, math.min(Main.VISIBLE, #list))
	local listH = #list == 0 and (f.roster.guide:GetHeight() + 16) or shown * ns.Roster.ROW_H
	f.list:SetHeight(listH + 8)
	f:SetHeight(chromeH(f, listH))
	local n = { full = 0, near = 0, resting = 0, outside = 0 }
	for _, r in ipairs(rows) do if r.group ~= 5 and n[r.state] then n[r.state] = n[r.state] + 1 end end
	for state, t in pairs(f.legend.parts) do t:SetText(n[state] .. " " .. St.STATE[state].word:lower()) end
	f.legend:SetShown(#rows > 0)
	f.moonHead:SetShown(#rows > 0)
	f.header:SetText(#rows > 0 and "NEXT BEST" or "GETTING STARTED")
	f.link:SetShown(not f.roster.guide:IsShown())
	ns.Link.Refresh(f.link, now)
	f.greyCheck:SetChecked(ns.DB().opts.showGrey ~= false)
	f.greyCheck:SetShown(#rows > 0)   -- first run: nothing to filter yet
	f.greyLabel:SetShown(#rows > 0)
end

function ns.ToggleMain()
	local f = Main.Create()
	if ns.Compact and ns.DB().opts.compact then ns.Compact.Toggle(false) end
	f:SetShown(not f:IsShown())
end

ns.RegisterCallback(Main, "ROSTER_CHANGED", function() Main.Refresh() end)
ns.RegisterCallback(Main, "TICK", function() Main.Refresh() end)
ns.RegisterCallback(Main, "SESSION_CHANGED", function() Main.Refresh() end)
ns.RegisterCallback(Main, "GAME_EVENT", function() if Main.frame and Main.frame:IsShown() then ns.Current.Update(Main.frame.current) end end)
