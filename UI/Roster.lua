-- Rested Leveling: the roster list under the hero card ("NEXT BEST"), one row per character, best to play first.

local _, ns = ...
local St, Wg, Wd, U = ns.Style, ns.Widgets, ns.Words, ns.Util
local R = {}
ns.Roster = R

R.ROW_H = 58

local function rowTooltip(row)
	local r = row.data
	if not r then return end
	local c, p, now = r.c, r.p, time()
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(St.ClassText(c.class, c.full or "?"))
	local s = St.STATE[r.state] or St.STATE.max
	GameTooltip:AddDoubleLine("|T" .. s.icon .. ":14|t " .. s.word, Wd.Chip(r), s.r, s.g, s.b, 1, 1, 1)
	if p then
		local fullIn, clock = Wd.FullIn(p, now)
		GameTooltip:AddDoubleLine("Rested", Wd.Levels(p.levels) .. " of double XP", 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine("Fills", fullIn .. (clock ~= "" and (" (" .. clock .. ")") or ""), 0.8, 0.8, 0.8, 1, 1, 1)
	end
	GameTooltip:AddDoubleLine("Saved at", Wd.Place(c), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Last seen", U.Ago(now - (c.t or now)), 0.8, 0.8, 0.8, 1, 1, 1)
	GameTooltip:AddDoubleLine("Rest bonus (moons)", c.ranks and ("tier " .. c.ranks .. " of 5") or "not read yet", 0.8, 0.8, 0.8, 1, 1, 1)
	if c.account then
		local tag = ns.AccountLabel(c.account)
		if c.src == "sync" and c.syncedAt then tag = tag .. ", synced " .. U.Ago(now - c.syncedAt) end
		GameTooltip:AddDoubleLine("Account", tag, 0.8, 0.8, 0.8, 0.7, 0.85, 1)
	end
	if ns.TooltipExtra then ns.TooltipExtra(GameTooltip, c) end
	if r.state == "outside" then GameTooltip:AddLine("Park me: log in, hearth, log out. Fills 4x faster in an inn.", 1, 0.45, 0.3, true) end
	if ns.Lines then GameTooltip:AddLine("\"" .. ns.Lines.Short(r) .. "\"", 0.95, 0.89, 0.77, true) end
	GameTooltip:AddLine("Click for the character card.", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local function tex(f, layer, sub)
	local t = f:CreateTexture(nil, layer, nil, sub)
	t:SetTexture(WHITE)
	return t
end

-- Columns: rank | portrait | name + sub | bar + time | state chip with the Well Rested moons under it.
local COL = Wg.COL

local function createRow(parent, w)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(w, R.ROW_H - 2)
	f.base = tex(f, "BACKGROUND", 0)
	f.base:SetAllPoints()
	f.sep = tex(f, "BORDER", 0)   -- one quiet divider between rows
	f.sep:SetPoint("BOTTOMLEFT")
	f.sep:SetPoint("BOTTOMRIGHT")
	f.sep:SetHeight(1)
	St.Paint(f.sep, "sw_div")
	f.hl = tex(f, "HIGHLIGHT", 0)
	f.hl:SetAllPoints()
	f.hl:SetVertexColor(1, 0.85, 0.45, 0.07)
	f.outline = {}
	for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do   -- 1 px bronze outline on hover
		local o = tex(f, "HIGHLIGHT", 1)
		o:SetVertexColor(0.75, 0.58, 0.32, 0.9)
		if side == "TOP" or side == "BOTTOM" then
			o:SetPoint(side .. "LEFT"); o:SetPoint(side .. "RIGHT"); o:SetHeight(1)
		else
			o:SetPoint("TOP" .. side); o:SetPoint("BOTTOM" .. side); o:SetWidth(1)
		end
		f.outline[i] = o
	end
	f.stripe = tex(f, "ARTWORK", 0)
	f.stripe:SetPoint("TOPLEFT")
	f.stripe:SetPoint("BOTTOMLEFT")
	f.stripe:SetWidth(5)   -- the fastest scan cue
	f.sel = {}   -- the row whose card is open: a 1 px gold outline and a 3 px gold bar down the left
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT", "BAR" }) do
		local o = f:CreateTexture(nil, "OVERLAY", nil, 3)
		St.Paint(o, "sw_gold")
		if side == "TOP" or side == "BOTTOM" then
			o:SetPoint(side .. "LEFT"); o:SetPoint(side .. "RIGHT"); o:SetHeight(1)
		elseif side == "BAR" then
			o:SetPoint("TOPLEFT"); o:SetPoint("BOTTOMLEFT"); o:SetWidth(3)
		else
			o:SetPoint("TOP" .. side); o:SetPoint("BOTTOM" .. side); o:SetWidth(1)
		end
		f.sel[#f.sel + 1] = o
	end
	f.rank = Wg.Text(f, "number", nil, 18)
	f.rank:SetPoint("LEFT", COL.rank, 0)
	f.rank:SetWidth(24)
	f.rank:SetJustifyH("CENTER")
	f.rank:SetTextColor(0.91, 0.79, 0.50)
	f.portrait = Wg.Portrait(f, 44)
	f.portrait:SetPoint("LEFT", COL.portrait, 0)
	f.name = Wg.Text(f, "name", nil, 14)
	f.name:SetPoint("TOPLEFT", COL.text, -10)
	f.acct = Wg.Text(f, "label", nil, 11)   -- "Acct #3", only for the other account's characters
	f.acct:SetPoint("LEFT", f.name, "RIGHT", 8, 0)
	f.acct:SetTextColor(0.62, 0.78, 0.95)
	f.sub = Wg.Text(f, "small", nil, 13)
	f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -5)
	St.Color(f.sub, St.SECOND)
	f.bar = Wg.BubbleBar(f, COL.chip - COL.bar - 26, 11, 30)
	f.bar:SetPoint("TOPLEFT", COL.bar, -10)
	f.time = Wg.Text(f, "small", nil, 13)
	f.time:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 1, -5)
	f.time:SetWidth(COL.chip - COL.bar - 90)
	St.Color(f.time, St.CREAM)
	f.chip = Wg.Chip(f, 20)
	f.chip:SetPoint("LEFT", COL.chip, 0)
	f:SetScript("OnEnter", rowTooltip)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f:SetScript("OnClick", function(self) if self.data and ns.ShowDetail then ns.ShowDetail(self.data.key) end end)
	return f
end

-- First run: three steps instead of an empty list.
local STEPS = {
	{ "Interface\\Icons\\INV_Misc_Note_01", "Log each character in once", "Every character you log in and out joins the queue, best rested on top." },
	{ "Interface\\Icons\\INV_Drink_05", "Log out in an inn or a city", "Rest builds 4x faster there. The addon warns you before you log out anywhere else." },
	{ "Interface\\Icons\\INV_Letter_15", "Optional: link your other account", "With both online on the same realm and faction: |cffd6b56b/rlvl link <Name>|r." },
}
function R.Guide(parent, w)
	local g = CreateFrame("Frame", nil, parent)
	g:SetPoint("TOPLEFT", 8, -10)
	g:SetSize(w - 16, 3 * 58 + 22)
	for i, step in ipairs(STEPS) do
		local icon = g:CreateTexture(nil, "ARTWORK")
		icon:SetSize(34, 34)
		icon:SetPoint("TOPLEFT", 20, -(i - 1) * 58 - 8)
		icon:SetTexture(step[1])
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local n = Wg.Text(g, "hero", nil, 20)
		n:SetPoint("RIGHT", icon, "LEFT", -6, 0)
		local t = Wg.Text(g, "name", nil, 14)
		t:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, 0)
		t:SetText(i .. ".  " .. step[2])
		St.Color(t, St.GOLD)
		local d = Wg.Text(g, "body", nil, 12)
		d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
		d:SetWidth(w - 90)
		d:SetWordWrap(true)
		d:SetText(step[3])
		St.Color(d, St.CREAM)
	end
	g.link = St.MakeButton(g, 130, "Link account...")
	g.link:SetPoint("TOPLEFT", 66, -(3 * 58) - 4)   -- on the step text's left edge, 8 px under it
	g.link:SetScript("OnClick", function()
		U.Print("to link your other WoW account: log a character in on it (same realm, same faction), then type")
		print("  |cffd6b56b/rlvl link <that character's name>|r here. The rosters swap at once and every time both are online.")
	end)
	g:Hide()
	return g
end

function R.Create(parent, w, visible)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, visible * R.ROW_H)
	f.rows, f.offset, f.visible = {}, 0, visible
	for i = 1, visible do
		local row = createRow(f, w - 6)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * R.ROW_H)
		f.rows[i] = row
	end
	f.thumb = f:CreateTexture(nil, "OVERLAY")
	St.Paint(f.thumb, "sw_bronze")
	f.thumb:SetWidth(3)
	f.guide = R.Guide(f, w)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(self, delta)
		self.offset = math.max(0, math.min(#(self.list or {}) - self.visible, self.offset - delta))
		R.Update(self, self.list, self.now, self.first)
	end)
	return f
end

local function fillRow(row, r, n, now, calibrated, alt)
	local c, p = r.c, r.p
	row.data = r
	local grey = r.group == 5
	-- The whole row carries a faint state tint (baked into the row texture), alternating light and dark rows.
	local key = St.STATE[r.state] and r.state or "max"
	St.Paint(row.base, ("row_%s_%d"):format(key, alt and 1 or 0))
	row.base:SetShown(not St.HostFrame())   -- under a host skin no tinted rows: the rail and the chip carry state   -- under a host skin only a faint wash: the rail and chip carry state
	St.Paint(row.stripe, "st_" .. key)
	row.stripe:SetAlpha(grey and 0.5 or 1)
	row.rank:SetText(n)
	Wg.SetPortrait(row.portrait, c, false, r.state)
	row.portrait.ring:SetShown(ns.selectedKey == r.key and not St.HostFrame())   -- ordinary rows: just the thin state line, less chrome
	row.portrait:SetAlpha(grey and 0.55 or 1)
	row.name:SetText(St.ClassText(c.class, c.full or "?", true))
	row.name:SetAlpha(grey and 0.75 or 1)
	-- Lv and last seen always show in full; the place is shortened with "..." to keep clear of the bar column.
	local ago = U.Ago(now - (c.t or now))
	local place = Wd.ShortPlace(c)
	local room = COL.bar - COL.text - 14
	if place then
		row.sub:SetText(("Lv %d  ·    ·  %s"):format(c.level or 0, ago))
		local fixed = row.sub:GetStringWidth()
		local fitted = Wg.Fit(row.sub, place, math.max(30, room - fixed))
		row.sub:SetText(("Lv %d  ·  %s  ·  %s"):format(c.level or 0, fitted, ago))
	else
		row.sub:SetText(("Lv %d  ·  %s"):format(c.level or 0, ago))
	end
	row.bar:SetShown(p ~= nil and not grey)
	if p and not grey then Wg.SetBubbleBar(row.bar, p.pct, r.state, not calibrated) end
	row.time:SetWidth(COL.chip - COL.bar - 6)
	row.time:SetText(r.hidden and "hidden" or Wd.RowTime(r, now, calibrated))
	if r.state == "max" then St.Color(row.time, St.MUTED) else St.Color(row.time, St.CREAM) end   -- the joke is not data
	row:SetAlpha(grey and 0.7 or 1)   -- max level and hidden rows recede
	row.time:SetAlpha(grey and 0.7 or 1)
	Wg.SetChip(row.chip, r.state, Wd.Chip(r))
	local tag = St.AccountTag(c)
	row.acct:SetText(tag or "")
	for _, o in ipairs(row.sel) do o:SetShown(ns.selectedKey == r.key) end
	row:Show()
end

function R.Update(f, list, now, first)
	f.list, f.now, f.first = list or {}, now, first or 1
	f.offset = math.max(0, math.min(f.offset, #f.list - f.visible))
	local calibrated = ns.DB().calib.n ~= nil
	for i = 1, f.visible do
		local r = f.list[i + f.offset]
		if r then fillRow(f.rows[i], r, i + f.offset + f.first - 1, now, calibrated, (i + f.offset) % 2 == 0) else f.rows[i]:Hide() end
	end
	f.guide:SetShown(#f.list == 0)
	local over = #f.list - f.visible
	f.thumb:SetShown(over > 0)
	if over > 0 then
		local h = f:GetHeight() * f.visible / #f.list
		f.thumb:SetHeight(h)
		f.thumb:ClearAllPoints()
		f.thumb:SetPoint("TOPRIGHT", 0, -(f:GetHeight() - h) * f.offset / over)
	end
end
