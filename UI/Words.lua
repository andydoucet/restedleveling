-- Rested Leveling: the plain-words lines shown in the window ("Full since 9h ago. 1.5 levels of double XP waiting.").
-- Pure functions, tested headless.

local _, ns = ...
local U = ns.Util
local Wd = {}
ns.Words = Wd

-- "1.5 levels", "1 level", "0.4 of a level".
function Wd.Levels(levels)
	levels = math.floor((levels or 0) * 10 + 0.5) / 10
	if levels < 1 then return ("%.1f of a level"):format(levels) end
	if levels == 1 then return "1 level" end
	if levels == math.floor(levels) then return ("%d levels"):format(levels) end
	return ("%.1f levels"):format(levels)
end

-- Rest under this many levels counts as nothing banked yet (the hero does not send you to a 0.0).
Wd.BANKED_MIN = 0.05

-- A future moment in real-life clock time: "today 18:40", "tomorrow 02:10", "Thu 4 Dec, 22:40".
-- Day and month names are ours, not the locale's, so every client reads the same. `dateFn` is injectable for tests.
local DAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
function Wd.When(ts, now, dateFn)
	dateFn = dateFn or date
	ts = math.floor(ts)
	local t, today, tmrw = dateFn("*t", ts), dateFn("*t", now), dateFn("*t", now + 86400)
	local hm = ("%02d:%02d"):format(t.hour, t.min)
	if t.year == today.year and t.yday == today.yday then return "today " .. hm end
	if t.year == tmrw.year and t.yday == tmrw.yday then return "tomorrow " .. hm end
	return ("%s %d %s, %s"):format(DAYS[t.wday], t.day, MONTHS[t.month], hm)
end

-- How much longer until fully rested, in real time, everywhere a character's rest shows (one formatter):
-- "Full in 9d 23h (Thu 4 Dec, 22:40)", "Full in 6h 20m (today 18:40)", and once full "Full since 2d 4h ago" (never
-- "Full for", which reads like time remaining).
function Wd.FullLine(p, now, dateFn)
	if not p then return "" end
	if p.left == 0 then
		local since = now - (p.fullSince or now)
		return since < 60 and "Full now" or ("Full since " .. U.Duration(since) .. " ago")
	end
	local left = math.max(60, p.left)
	return ("Full in %s (%s)"):format(U.Duration(left), Wd.When(now + left, now, dateFn))
end

-- Where a character was saved: "Goldshire inn", "Stormwind City", "sleeping bag in Duskwood", "outside in Westfall".
function Wd.Place(c)
	local where = c.subzone or c.zone
	local kind = c.restKind or (c.resting and "inn" or "outside")
	if kind == "city" then return c.zone or "a city" end
	if kind == "bag" then return "sleeping bag" .. (c.zone and (" in " .. c.zone) or "") end
	if kind == "inn" then return (where and (where .. " inn") or "an inn") end
	return "outside" .. (c.zone and (" in " .. c.zone) or "")
end

-- Shorter zone names for tight columns ("Stonetalon Mountains" -> "Stonetalon").
local SHORT = { ["Stonetalon Mountains"] = "Stonetalon", ["Alterac Mountains"] = "Alterac", ["Redridge Mountains"] = "Redridge",
	["Searing Gorge"] = "Searing Gorge", ["Swamp of Sorrows"] = "Swamp of Sorrows", ["Western Plaguelands"] = "W. Plaguelands",
	["Eastern Plaguelands"] = "E. Plaguelands", ["Stranglethorn Vale"] = "Stranglethorn", ["Hillsbrad Foothills"] = "Hillsbrad",
	["Silverpine Forest"] = "Silverpine", ["Tirisfal Glades"] = "Tirisfal", ["Dun Morogh"] = "Dun Morogh" }
function Wd.ShortZone(z) return z and (SHORT[z] or z) end

-- The place for a tight column: the inn's town, the city, or the zone (the chip already says not resting).
function Wd.ShortPlace(c)
	local kind = c.restKind or (c.resting and "inn" or "outside")
	if kind == "inn" then return c.subzone and (c.subzone .. " inn") or (Wd.ShortZone(c.zone) or "an inn") end
	if kind == "bag" then return "sleeping bag" end
	return Wd.ShortZone(c.zone)
end

-- Shorter forms of a place, longest first: "Thunderbrew Distillery inn", "Thunderbrew inn", "Thunderbrew".
function Wd.PlaceForms(place)
	local out = { place }
	local base, suffix = place:match("^(.-)( inn)$")
	base = base or place
	local first = base:match("^(%S%S%S%S%S%S+)%s")   -- a first word of 6+ letters ("Thunderbrew"), never "Dun"
	if first then out[#out + 1] = first .. (suffix or "") end
	if suffix then out[#out + 1] = first or base end
	return out
end

-- "0.8 of a level banked", or "Nothing banked yet" under a twentieth of a level.
local function banked(levels)
	if levels < Wd.BANKED_MIN then return "Nothing banked yet" end
	return Wd.Levels(levels) .. " banked"
end

-- The card's reason, in plain words, with the real-life time to full.
function Wd.Why(r, now, dateFn)
	local p, c = r.p, r.c
	if not p then return "Max level. Nothing left to rest for." end
	local full = Wd.FullLine(p, now, dateFn)
	if r.state == "full" then
		return ("%s. %s of double XP waiting."):format(full, Wd.Levels(p.levels))
	elseif r.state == "near" then
		return ("%d%% full. %s. %s of double XP ready."):format(math.floor(p.pct * 100), full, Wd.Levels(p.levels))
	elseif r.state == "resting" then
		return ("Resting at %s. %s. %s."):format(Wd.Place(c), banked(p.levels), full)
	end
	return ("Not resting: fills 4x slower. %s. %s. Park it in an inn."):format(banked(p.levels), full)
end

-- The hero's one line under its bar: the state in a word or two, then the real-life time to full.
function Wd.HeroWhy(r, now, dateFn)
	local p = r.p
	if not p then return "Max level. Nothing left to rest for." end
	local full = Wd.FullLine(p, now, dateFn)
	if r.state == "full" then   -- not a countdown: it has been full that long, and the rest since is wasted
		local since = now - (p.fullSince or now)
		if since < 60 then return "Fully rested just now." end
		return ("Full since %s ago · more rest is wasted."):format(U.Duration(since))
	end
	if r.state == "near" then return ("%d%% full. %s."):format(math.floor(p.pct * 100), full) end
	if r.state == "resting" then return ("Resting. %s."):format(full) end
	return ("Not resting, fills 4x slower. %s."):format(full)
end

-- Nobody has rest worth switching to: the best alt is not (nearly) full and has under BANKED_MIN levels.
function Wd.NothingBanked(r)
	return r ~= nil and r.p ~= nil and r.group ~= nil and r.group >= 3 and r.group <= 4 and r.p.levels < Wd.BANKED_MIN
end

-- The one that fills first (least time to full) among rows with rest to project, or nil.
function Wd.FillsFirst(rows)
	local best
	for _, r in ipairs(rows or {}) do
		if r.p and r.group and r.group < 5 and (not best or r.p.left < best.p.left) then best = r end
	end
	return best
end

-- The hero's plan as two numbered steps, each led by the character it is about (so its class colour leads):
-- "Le Jette: hearth to an inn", "Le Dette: play next". nil when there is nobody to switch to (Action says why).
function Wd.Steps(name, meName, restingNow, empty)
	if empty then return nil end
	meName = meName or "This character"
	return ("%s: %s"):format(meName, restingNow and "log out here" or "hearth to an inn"), ("%s: play now"):format(name)
end

-- The hero's action bar. The "first, ..." part is always about the character you are on (`meName`), never the
-- one to play next. empty: nobody is rested yet, so there is nobody to switch to.
function Wd.Action(name, meName, restingNow, empty)
	meName = meName or "this character"
	if empty then
		if restingNow then return ("Nobody to switch to yet. Keep playing %s; it rests here too."):format(meName) end
		return ("Nobody to switch to yet. When you stop, log %s out in an inn."):format(meName)
	end
	if restingNow then return ("First: log %s out here. Then: play %s."):format(meName, name) end
	return ("First: hearth %s to an inn. Then: play %s."):format(meName, name)
end

-- The roster's time line for a row: "93%  ·  Full in 14h 25m (today 18:25)". Over two days away the clock time is
-- dropped ("~30%  ·  Full in 27d 22h") so the line never clips; the tooltip and the card keep it.
Wd.ROW_CLOCK_MAX = 2 * 86400
function Wd.RowTime(r, now, calibrated, dateFn)
	local p = r.p
	if not p then return r.state == "max" and "Max level. I keep the bench warm." or "" end
	local full = p.left > Wd.ROW_CLOCK_MAX and ("Full in " .. U.Duration(p.left)) or Wd.FullLine(p, now, dateFn)
	-- Parked outside, the wait holds only while it stays outside (4x slower): say so, not a bare promise.
	return (calibrated and "" or "~") .. math.floor(p.pct * 100) .. "%  ·  " .. full .. (r.state == "outside" and " outside" or "")
end

-- Why #1 beats #2, in one short line with the same rounding as the rows: "2d ahead of Le Beouf (full for 8h)".
function Wd.Ahead(rows, now)
	local b = rows[2]
	if not (rows[1] and b and b.p and b.group and b.group <= 4) then return nil end
	local name = b.c.full or "?"
	if b.p.left == 0 then return ("Then %s, full since %s ago"):format(name, U.Short(now - (b.p.fullSince or now))) end
	if b.group == 2 then return ("Then %s, full in %s"):format(name, U.Short(b.p.left)) end
	return ("Then %s with %s"):format(name, Wd.Levels(b.p.levels))
end

-- Short label for the state chip.
local CHIPS = { full = "FULL", near = "NEARLY FULL", resting = "RESTING", outside = "NOT RESTING", max = "MAX LEVEL", done = "AT TARGET" }
function Wd.Chip(r) return CHIPS[r.state] or "" end

-- The link state in words, for the inline link field (guide and footer). link: one entry of ns.Sync.Links().
-- meName: the character you are on, which the other account has to link back.
function Wd.LinkLine(link, meName, now)
	if not link then return "No other account linked yet." end
	if not link.confirmed then
		return ("Linked to %s. Waiting for them to link you back (/rlvl link %s on that account)."):format(link.name,
			meName or "<your name>")
	end
	return ("Paired: %s  ·  %s"):format(link.name, link.lastSync and ("synced " .. U.Ago(now - link.lastSync)) or "not synced yet")
end

return Wd
