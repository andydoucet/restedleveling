-- Rested Leveling: the plain-words lines shown in the window ("Full for 9h. 1.5 levels of double XP waiting.").
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

-- The time column: "full for 2d", "full in 6h 20m", plus the clock when it fills ("18:40").
function Wd.FullIn(p, now)
	if not p then return "", "" end
	if p.left == 0 then return "full for " .. U.Short(now - (p.fullSince or now)), "" end
	return "full in " .. U.Duration(p.left), U.Clock(now + p.left, now)
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

-- The hero card's reason, in plain words.
function Wd.Why(r, now)
	local p, c = r.p, r.c
	if not p then return "Max level. Nothing left to rest for." end
	local lv = Wd.Levels(p.levels)
	if r.state == "full" then
		return ("Fully rested for %s. %s of double XP waiting."):format(U.Long(now - (p.fullSince or now)), lv)
	elseif r.state == "near" then
		return ("%d%% full, tops off in %s. %s of double XP ready."):format(math.floor(p.pct * 100), U.Long(p.left), lv)
	elseif r.state == "resting" then
		return ("Resting at %s. %s banked, full %s."):format(Wd.Place(c), lv, U.Clock(now + p.left, now))
	end
	return ("Not resting: fills 4x slower. %s banked. Park it in an inn."):format(lv)
end

-- The roster's time line for a row: "93% · full in 14h 25m · 18:25"; outside rows say what to do instead of a far date.
function Wd.RowTime(r, now, calibrated)
	local p = r.p
	if not p then return r.state == "max" and "Max level. I keep the bench warm." or "" end
	local pct = (calibrated and "" or "~") .. math.floor(p.pct * 100) .. "%"
	if r.state == "outside" and p.left > 0 then
		return pct .. "  ·  park in an inn"   -- the slow fill estimate is in the tooltip
	end
	return pct .. "  ·  " .. (Wd.FullIn(p, now))   -- the exact day and time are in the tooltip
end

-- Why #1 beats #2, in one short line with the same rounding as the rows: "2d ahead of Le Beouf (full for 8h)".
function Wd.Ahead(rows, now)
	local a, b = rows[1], rows[2]
	if not (a and b and a.p and b.p) or a.group ~= b.group or a.group > 3 then return nil end
	local name = b.c.full or "?"
	if a.group == 1 then
		return ("Then %s, full for %s"):format(name, U.Short(now - (b.p.fullSince or now)))
	elseif a.group == 2 then
		return ("Then %s at %d%%"):format(name, math.floor(b.p.pct * 100))
	end
	return ("Then %s with %s"):format(name, Wd.Levels(b.p.levels))
end

-- A fill estimate for tooltips: "full for 2d", "full in 14h 25m", "full in ~27d" (rough when far away).
function Wd.FillTime(p, now)
	if not p then return "" end
	if p.left == 0 then return "full for " .. U.Short(now - (p.fullSince or now)) end
	if p.left >= 2 * 86400 then return "full in about " .. U.Short(p.left) end
	return "full in " .. U.Duration(p.left)
end

-- Short label for the state chip.
local CHIPS = { full = "FULL", near = "NEARLY FULL", resting = "RESTING", outside = "NOT RESTING", max = "MAX LEVEL", done = "AT TARGET" }
function Wd.Chip(r) return CHIPS[r.state] or "" end

-- The roster footer line about cross-account sync.
function Wd.SyncLine(status, now)
	if not status or #status == 0 then return "No other account linked yet." end
	local p = status[1]
	if p.lastSync then
		return ("Synced %s from Acct %s"):format(U.Ago(now - p.lastSync), p.label or "?")
	end
	return ("Seen Acct %s %s, not synced yet"):format(p.label or "?", U.Ago(now - (p.seen or now)))
end

return Wd
