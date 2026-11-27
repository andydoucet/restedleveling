-- Rested Leveling: the current-character strip. The logged-in character is not in the queue; this shows its live
-- rested XP, roughly how many double-XP kills are left and how much rest this session has used. It sits on the same
-- column grid as the roster rows below it, so its bar lines up with theirs. Click it for your own card.

local _, ns = ...
local St, Wg, Wd, S = ns.Style, ns.Widgets, ns.Words, ns.Snap
local Cur = {}
ns.Current = Cur

local X = 4   -- the roster rows sit 4 px inside the list well

function Cur.Create(parent, w, h)
	local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
	f:SetSize(w, h)
	St.Panel(f, "strip")
	-- Click: your own card (where "Save my look" is). Right-click: the same as a small menu.
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f:SetScript("OnClick", function(self, button)
		if button == "RightButton" then ns.Look.Menu(self) elseif ns.MyKey() then ns.ShowDetail(ns.MyKey()) end
	end)
	local C = Wg.COL
	f.rail = f:CreateTexture(nil, "ARTWORK")   -- the rows' state rail: red while this character banks nothing
	f.rail:SetPoint("TOPLEFT", 1, -1)
	f.rail:SetPoint("BOTTOMLEFT", 1, 1)
	f.rail:SetWidth(5)
	f.portrait = Wg.Portrait(f, 44)
	f.portrait:SetPoint("LEFT", X + C.portrait, 0)
	f.kicker = Wg.Text(f, "label", nil, 11)
	f.kicker:SetPoint("TOPLEFT", X + C.text, -7)
	f.kicker:SetText("NOW PLAYING")
	St.Color(f.kicker, St.GOLD)
	f.name = Wg.Text(f, "name", nil, 15)
	f.name:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -3)
	f.bar = Wg.BubbleBar(f, Wg.BAR_W, 13, 30)   -- the roster bars' width and height
	f.bar:SetPoint("TOPLEFT", X + C.bar, -12)
	f.left = Wg.Text(f, "small", nil, 13)
	f.left:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 1, -5)
	f.left:SetWidth(C.value + Wg.VALUE_W - C.bar)
	f.pill = Wg.Chip(f, 20)   -- the rows' chip, in the rows' STATE column
	f.pill:SetPoint("RIGHT", f, "LEFT", X + C.chip + Wg.CHIP_W, 0)   -- the rows' right edge
	f.detail = Wg.Text(f, "small", nil, 13)   -- under the name, in the text column
	f.detail:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
	f.detail:SetWidth(C.bar - C.text - 10)
	St.Color(f.detail, St.SECOND)
	f.left:ClearAllPoints()   -- the bar caption on the same baseline as "none used this session"
	f.left:SetPoint("LEFT", f.bar, "LEFT", 1, 0)
	f.left:SetPoint("BOTTOM", f.detail, "BOTTOM", 0, 0)
	return f
end

function Cur.Update(f)
	local me = ns.Me()
	local s = ns.Session()
	if not me or not s then
		f.name:SetText("|cff999999Not loaded yet|r")
		f.left:SetText("")
		f.detail:SetText("")
		f.pill:Hide()
		return
	end
	local d = ns.DB()
	local cap = ns.Model.Cap(me, d.calib)
	local pct = math.min(1, s.levels / cap)
	local resting = S.RestingNow()
	local state = me.atMax and "max" or (pct >= 1 and "full") or (pct >= ns.Model.NEAR and "near") or (resting and "resting" or "outside")
	Wg.SetPortrait(f.portrait, me, true, state)
	f.name:SetText(St.ClassText(me.class, me.full or "?") .. "|cffd4c4a8  ·  Lv " .. (me.level or "?") .. "|r")
	f.pill:Show()
	Wg.SetChip(f.pill, resting and "resting" or "outside", resting and "RESTING" or "NOT RESTING")
	Wg.SetBubbleBar(f.bar, pct, "cur", false)   -- rest left in a neutral blue; the chip says where you are
	if me.atMax then
		f.left:SetText("Max level")
		f.detail:SetText("")
		return
	end
	-- Under the name: where it is (the chip already says whether that is resting).
	St.Paint(f.rail, "st_" .. (resting and "resting" or "outside"))
	f.detail:SetText(resting and (Wd.ShortPlace(me) or "Resting") or ("Outside  ·  " .. (me.zone or "the open world")))
	-- The bar column: what is left (and the double-XP kills it buys), or, with nothing left, one plain line and no
	-- empty track.
	local used = (s.used or 0) / s.xpMax
	-- The rows' columns: the bar and its line under it. With nothing left, no empty track (it read as an input
	-- field): one line in the bar column (r3, which the council scored higher than the track).
	local none = s.levels < Wd.BANKED_MIN   -- under a twentieth of a level: nothing worth counting
	f.bar:SetShown(not none)
	f.left:ClearAllPoints()
	if none then   -- on the rows' bar line
		f.left:SetPoint("TOPLEFT", f, "TOPLEFT", X + Wg.COL.bar, -12)
	else
		f.left:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 1, -7)
	end
	if none then
		f.left:SetText("No rested XP: kills give normal XP")
		St.Color(f.left, St.CREAM)
		return
	end
	local parts = { Wd.Levels(s.levels) .. " left" }
	if s.kills then parts[#parts + 1] = ("~%d double-XP kill%s"):format(s.kills, s.kills == 1 and "" or "s") end
	if used >= 0.05 then parts[#parts + 1] = "used " .. Wd.Levels(used) end
	f.left:SetText(table.concat(parts, "  ·  "))
	St.Color(f.left, St.CREAM)
end
