-- Rested Leveling: the 48-hour fill timeline, the main window's second view (the band's ROSTER | TIMELINE tabs).
-- x runs from now to 48 hours ahead, with the night hours shaded and a "now" line; one lane per character (portrait
-- and name), sorted by when each fills. A bar in the state colour grows to the moment that character is full, with a
-- marker and the clock time there; one already full sits on "now"; one that fills after the window runs to the edge
-- with an arrow, its date in the right gutter. Hover a lane for the exact "Full in ... (clock)".

local _, ns = ...
local St, Wg, Wd, U = ns.Style, ns.Widgets, ns.Words, ns.Util
local Tl = {}
ns.Timeline = Tl

Tl.SPAN = 48 * 3600
Tl.LABEL_W = 216        -- portrait, name and how full it is now
Tl.AXIS_H = 24          -- the tick labels over the plot
Tl.NIGHT_FROM, Tl.NIGHT_TO = 20, 6   -- local hours drawn as night
Tl.MAX_LANE_H = 46
Tl.GUTTER = 112         -- right of the plot: the date for a lane that fills after the window
local DAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- Pure layout ---------------------------------------------------------------------------------------------------------

-- The lanes: every row with a projection (not max level or hidden), soonest full first, then by name. Each lane:
-- { row, left (s to full), frac (0..1 of the window), beyond (fills after the window), still (parked outside: not
-- filling to speak of, so it sorts after every filling lane and is never "next", like Words.RowFull) }.
function Tl.Lanes(rows, span)
	span = span or Tl.SPAN
	local out = {}
	for _, r in ipairs(rows or {}) do
		if r.p and r.group ~= 5 then
			local left = r.p.left or 0
			local still = r.state == "outside" and left > 0
			out[#out + 1] = { row = r, left = left, frac = math.min(1, left / span), beyond = left > span, still = still }
		end
	end
	table.sort(out, function(a, b)
		if a.still ~= b.still then return b.still end
		if a.left ~= b.left then return a.left < b.left end
		return (a.row.c.full or "") < (b.row.c.full or "")
	end)
	return out
end

local function hourOf(ts, dateFn) return dateFn("*t", ts).hour end
local function isNight(hour) return hour >= Tl.NIGHT_FROM or hour < Tl.NIGHT_TO end

-- The night stretches in the window as { from, to } fractions, one per night, in order.
function Tl.Nights(now, span, dateFn)
	dateFn, span = dateFn or date, span or Tl.SPAN
	local out, cur = {}, nil
	local t = now
	while t < now + span do
		local t2 = math.min(now + span, (math.floor(t / 3600) + 1) * 3600)   -- the next whole hour (UTC-aligned zones)
		if isNight(hourOf(t, dateFn)) then
			if cur then cur.to = (t2 - now) / span else cur = { from = (t - now) / span, to = (t2 - now) / span } end
		elseif cur then
			out[#out + 1] = cur
			cur = nil
		end
		t = t2
	end
	if cur then out[#out + 1] = cur end
	return out
end

-- Tick marks every 6 hours on the local clock: { frac, label, day }. Midnight is labelled with the day ("Fri"),
-- the others with the time ("06:00").
function Tl.Ticks(now, span, dateFn)
	dateFn, span = dateFn or date, span or Tl.SPAN
	local out = {}
	local t = (math.floor(now / 3600) + 1) * 3600
	while t <= now + span do
		local d = dateFn("*t", t)
		if d.hour % 6 == 0 and d.min == 0 then
			local frac = (t - now) / span
			out[#out + 1] = { frac = frac, day = d.hour == 0,
				quiet = d.hour % 12 ~= 0,   -- a line every 6 hours, a label every 12: room for "Wed 25 Nov"
				label = d.hour == 0 and ("%s %d %s"):format(DAYS[d.wday], d.day, MONTHS[d.month]) or ("%02d:00"):format(d.hour) }
		end
		t = t + 3600
	end
	return out
end

-- What a lane says at its marker: the clock time it fills ("Thu 22:40"), "Full" for one already full, or the date for
-- one past the window ("Full Thu 4 Dec").
function Tl.Label(lane, now, dateFn)
	dateFn = dateFn or date
	if lane.left <= 0 then return "Full now" end
	local d = dateFn("*t", now + lane.left)
	local hm = ("%02d:%02d"):format(d.hour, d.min)
	if lane.beyond then   -- two lines in the gutter, so lanes full the same day still part: date, then time
		return ("%s %d %s\n%s"):format(DAYS[d.wday], d.day, MONTHS[d.month], hm)   -- the column says what it is
	end
	local today = dateFn("*t", now)
	if d.yday == today.yday and d.year == today.year then return hm end
	return DAYS[d.wday] .. " " .. hm
end

-- Widgets -------------------------------------------------------------------------------------------------------------

local function pool(list, i, make)
	list[i] = list[i] or make()
	list[i]:Show()
	return list[i]
end
local function hideFrom(list, n) for i = n, #list do list[i]:Hide() end end

local function lane(f)
	local l = CreateFrame("Frame", nil, f)
	l:EnableMouse(true)
	l.rule = l:CreateTexture(nil, "BACKGROUND", nil, 1)   -- a hairline between lanes
	St.Paint(l.rule, "sw_line")
	l.rule:SetPoint("BOTTOMLEFT", 0, 0)
	l.rule:SetPoint("BOTTOMRIGHT", 0, 0)
	l.rule:SetHeight(1)
	l.rule:SetAlpha(0.5)
	l.portrait = Wg.Portrait(l, 28)
	l.portrait:SetPoint("LEFT", 8, 0)
	l.name = Wg.Text(l, "name", nil, 13)
	l.name:SetPoint("LEFT", l.portrait, "RIGHT", 14, 0)
	l.name:SetWidth(Tl.LABEL_W - 92)
	l.pct = Wg.Text(l, "small", nil, 12)   -- how full now: the bars past the window differ only here
	l.pct:SetPoint("RIGHT", l, "LEFT", Tl.LABEL_W - 18, 0)
	l.pct:SetJustifyH("RIGHT")
	St.Color(l.pct, St.SECOND)
	l.track = l:CreateTexture(nil, "BORDER")   -- the lane's own path across the window
	St.Paint(l.track, "sw_well")
	l.track:SetHeight(10)
	l.bar = l:CreateTexture(nil, "ARTWORK")
	l.bar:SetHeight(10)
	l.cap = l:CreateTexture(nil, "ARTWORK", nil, 1)   -- past the window: an arrow cap, the bar carries on
	St.Paint(l.cap, "tail_r")
	l.cap:SetSize(9, 14)
	l.marker = l:CreateTexture(nil, "OVERLAY")
	l.marker:SetSize(16, 16)
	l.when = Wg.Text(l, "small", nil, 13)
	l.when:SetWordWrap(true)
	l:SetScript("OnEnter", function(self)
		local r = self.lane and self.lane.row
		if not r then return end
		GameTooltip:SetOwner(self, "ANCHOR_NONE")   -- inside the window, hanging just under its own lane
		local x = self.lane and not self.lane.beyond and self.lane.frac < 0.4 and (self.endX or 0) + 16 or 8
		GameTooltip:SetPoint("LEFT", self, "LEFT", Tl.LABEL_W + x, 0)   -- on its own lane, just right of the marker
		GameTooltip:AddLine(St.ClassText(r.c.class, r.c.full or "?"))
		local s = St.STATE[r.state] or St.STATE.max
		GameTooltip:AddLine(Wd.FullLine(r.p, self.now or time()), s.r, s.g, s.b)
		GameTooltip:AddLine(("%s banked · %s"):format(Wd.Levels(r.p.levels), Wd.Place(r.c)), 0.9, 0.85, 0.75)
		GameTooltip:Show()
	end)
	l:SetScript("OnLeave", function() GameTooltip:Hide() end)
	l:SetScript("OnMouseUp", function(self) if self.lane and ns.ShowDetail then ns.ShowDetail(self.lane.row.key) end end)
	return l
end

function Tl.Create(parent, w)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(w)
	-- More lanes than fit: the mouse wheel scrolls them, as it scrolls the roster.
	f.offset = 0
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(self, delta)
		self.offset = (self.offset or 0) - delta
		if self.rows then Tl.Update(self, self.rows, self.now, self:GetHeight()) end
	end)
	f.plotX, f.plotW = Tl.LABEL_W, w - Tl.LABEL_W - Tl.GUTTER - 8
	f.shades, f.ticks, f.lanes = {}, {}, {}
	f.nowLine = f:CreateTexture(nil, "OVERLAY", nil, 2)
	f.nowLine:SetWidth(2)
	f.nowLine:SetColorTexture(1, 0.84, 0.45, 0.9)
	f.nowLabel = Wg.Text(f, "label", nil, 12)
	f.nowLabel:SetText("NOW")
	f.nowLabel:SetTextColor(1, 0.84, 0.45)
	f.endLabel = Wg.Text(f, "label", nil, 12)
	f.endLabel:SetText("+48h")
	St.Color(f.endLabel, St.MUTED)
	f.gutter = Wg.Text(f, "label", nil, 12)   -- the right column's own heading, over a quiet separator
	f.gutter:SetText("FULL AFTER 48h")
	f.order = Wg.Text(f, "label", nil, 12)   -- the lanes' order, named, so it never looks like the roster's
	f.order:SetText("BY TIME TO FULL")
	St.Color(f.order, St.MUTED)
	St.Color(f.gutter, St.MUTED)
	f.gutterLine = f:CreateTexture(nil, "BACKGROUND", nil, 3)
	f.gutterLine:SetColorTexture(1, 0.9, 0.7, 0.18)
	f.gutterLine:SetWidth(1)
	f.empty = Wg.Text(f, "body", nil, 13)
	f.empty:SetPoint("CENTER")
	St.Color(f.empty, St.SECOND)
	f.empty:SetText("Nobody to show yet: log your alts in and out once.")
	return f
end

local function x(f, frac) return f.plotX + frac * f.plotW end

-- Draw the timeline for `rows` at `now` in `h` px (the list's height).
function Tl.Update(f, rows, now, h)
	f:SetHeight(h)
	local lanes = Tl.Lanes(rows)
	local n = math.min(#lanes, ns.Main.VISIBLE)
	f.rows, f.now = rows, now
	f.offset = math.max(0, math.min(f.offset or 0, #lanes - n))
	f.empty:SetShown(n == 0)
	local laneH = n > 0 and math.min(Tl.MAX_LANE_H, math.floor((h - Tl.AXIS_H - 4) / n)) or 0
	local plotTop, plotH = -Tl.AXIS_H, n * laneH
	-- Night bands behind every lane, and the 6-hour ticks with their labels.
	local nights = Tl.Nights(now)
	for i, nt in ipairs(nights) do
		local s = pool(f.shades, i, function()
			local t = f:CreateTexture(nil, "BACKGROUND")
			t:SetColorTexture(0.13, 0.13, 0.14, 0.45)   -- night: neutral grey, no fifth hue; the state colours lead
			return t
		end)
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", f, "TOPLEFT", x(f, nt.from), plotTop + 4)
		s:SetSize(math.max(1, (nt.to - nt.from) * f.plotW), plotH + 4)
	end
	hideFrom(f.shades, #nights + 1)
	local ticks = Tl.Ticks(now)
	for i, tk in ipairs(ticks) do
		local t = pool(f.ticks, i, function()
			local o = { line = f:CreateTexture(nil, "BACKGROUND", nil, 2), text = Wg.Text(f, "small", nil, 12) }
			function o:Show() self.line:Show() self.text:Show() end
			function o:Hide() self.line:Hide() self.text:Hide() end
			return o
		end)
		t.line:ClearAllPoints()
		t.line:SetPoint("TOPLEFT", f, "TOPLEFT", x(f, tk.frac), plotTop + 4)
		t.line:SetSize(1, plotH + 4)
		t.line:SetColorTexture(1, 0.9, 0.7, tk.day and 0.22 or 0.08)
		t.text:ClearAllPoints()
		t.text:SetPoint("BOTTOM", f, "TOPLEFT", x(f, tk.frac), plotTop + 6)
		t.text:SetText(tk.label)
		if tk.day then St.Color(t.text, St.CREAM) else St.Color(t.text, St.SECOND) end
		-- "NOW" and "+48H" own the ends of the axis: no tick label within 44 px of them.
		t.text:SetShown(not tk.quiet and tk.frac * f.plotW > 44 and (1 - tk.frac) * f.plotW > 60)
	end
	hideFrom(f.ticks, #ticks + 1)
	f.nowLine:ClearAllPoints()
	f.nowLine:SetPoint("TOPLEFT", f, "TOPLEFT", x(f, 0) - 1, plotTop + 4)
	f.nowLine:SetHeight(plotH + 4)
	f.nowLabel:ClearAllPoints()
	f.nowLabel:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x(f, 0) - 2, plotTop + 6)
	f.endLabel:ClearAllPoints()
	f.endLabel:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", x(f, 1), plotTop + 6)
	f.gutter:ClearAllPoints()
	f.gutter:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x(f, 1) + 16, plotTop + 6)
	f.gutterLine:ClearAllPoints()
	f.gutterLine:SetPoint("TOPLEFT", f, "TOPLEFT", x(f, 1) + 10, plotTop + 4)
	f.gutterLine:SetHeight(plotH + 4)
	f.order:ClearAllPoints()
	f.order:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 8, plotTop + 6)
	for _, t in ipairs({ f.nowLine, f.nowLabel, f.endLabel, f.gutter, f.gutterLine, f.order }) do t:SetShown(n > 0) end
	for i = 1, n do
		local ln, l = lanes[i + f.offset], pool(f.lanes, i, function() return lane(f) end)
		local r = ln.row
		l.lane, l.now, l.endX = ln, now, ln.frac * f.plotW
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", f, "TOPLEFT", 0, plotTop - (i - 1) * laneH)
		l:SetSize(f.plotX + f.plotW + 14, laneH)
		Wg.SetPortrait(l.portrait, r.c, false, r.state)
		l.name:SetText(St.ClassText(r.c.class, r.c.full or "?"))
		l.pct:SetText(math.floor(r.p.pct * 100) .. "%")
		local cy = 0   -- lane centre
		l.track:ClearAllPoints()
		l.track:SetPoint("LEFT", l, "LEFT", f.plotX, cy)
		l.track:SetWidth(f.plotW)
		St.Paint(l.track, "sw_well")
		l.track:SetHeight(10)
		l.track:SetShown(ln.left > 0)   -- a full one has no empty track behind "Full now"
		local state = St.STATE[r.state] and r.state or "max"
		local endX = ln.frac * f.plotW
		St.Paint(l.bar, "bar_" .. state)
		l.bar:ClearAllPoints()
		l.bar:SetPoint("LEFT", l, "LEFT", f.plotX, cy)
		l.bar:SetWidth(math.max(1, endX))
		l.bar:SetShown(ln.left > 0)
		l.cap:SetShown(ln.beyond)
		if ln.beyond then   -- solid to the edge, then an arrow: it carries on past the window
			local s = St.STATE[state]
			l.cap:SetVertexColor(s.r, s.g, s.b, 1)
			l.cap:ClearAllPoints()
			l.cap:SetPoint("LEFT", l.bar, "RIGHT", 0, 0)
		end
		if ln.left <= 0 then l.marker:SetTexture(St.STATE.full.icon) else St.Paint(l.marker, "pip_" .. state) end   -- full: a tick
		l.marker:ClearAllPoints()
		l.marker:SetPoint("CENTER", l, "LEFT", f.plotX + endX, cy)
		l.marker:SetShown(not ln.beyond)
		if r.state == "outside" and ln.left > 0 then   -- not filling: no bar promising progress; a thin red line, a stop at NOW
			l.bar:Hide()
			l.cap:Hide()
			l.track:SetHeight(2)
			l.track:SetColorTexture(0.82, 0.23, 0.16, 0.7)
			l.marker:ClearAllPoints()
			l.marker:SetPoint("CENTER", l, "LEFT", f.plotX, cy)
			l.marker:Show()
		end
		l.when:SetText(Tl.Label(ln, now))
		local s = St.STATE[state]
		l.when:SetTextColor(s.r * 0.5 + 0.45, s.g * 0.5 + 0.45, s.b * 0.5 + 0.4)
		l.when:ClearAllPoints()
		if ln.beyond then   -- the date in the gutter, past the arrow, never on the bar
			l.when:SetPoint("LEFT", l, "LEFT", f.plotX + f.plotW + 18, cy)
		elseif ln.frac > 0.8 then   -- near the right edge: the label sits left of the marker, above the bar
			l.when:SetPoint("BOTTOMRIGHT", l, "LEFT", f.plotX + endX - 6, cy + 7)
		else
			l.when:SetPoint("LEFT", l, "LEFT", f.plotX + endX + 14, cy)
		end
	end
	hideFrom(f.lanes, n + 1)
	return n
end

-- The band's heading over the timeline, with the next one to fill: "NEXT 48 HOURS  ·  Le Bankken full in 19h 11m".
function Tl.Header(rows)
	for _, ln in ipairs(Tl.Lanes(rows)) do
		if ln.left > 0 and not ln.still then return ("NEXT 48 HOURS  ·  %s full in %s"):format(ln.row.c.full or "?", U.Duration(ln.left)) end
	end
	return "NEXT 48 HOURS"
end

-- The band's two tabs: which view the main window shows (saved: d.opts.view, "timeline" or nil for the roster).
function Tl.View() return ns.DB().opts.view == "timeline" and "timeline" or "roster" end
function Tl.SetView(v)
	ns.DB().opts.view = v == "timeline" and "timeline" or nil
	if ns.Main and ns.Main.Refresh then ns.Main.Refresh() end
end
