-- Rested Leveling: small shared helpers. Every value read from the game goes through Safe() before use.
-- Forever can hand back "secret" values (realm, names, GUIDs under identity restrictions) that error when
-- compared or concatenated, so they are turned into nil here, in one place.

local _, ns = ...
local U = {}
ns.Util = U

-- A secret or otherwise unusable value becomes nil.
function U.Safe(v)
	if v == nil then return nil end
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

-- Calls a game function protected, and sanitizes up to six returns. Missing functions return nil.
function U.Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f = pcall(fn, ...)
	if not ok then return nil end
	local S = U.Safe
	return S(a), S(b), S(c), S(d), S(e), S(f)
end

-- A string that is real and not empty, else nil.
function U.Str(v)
	v = U.Safe(v)
	if type(v) ~= "string" or v == "" then return nil end
	return v
end

function U.Num(v)
	v = U.Safe(v)
	if type(v) ~= "number" or v ~= v then return nil end
	return v
end

-- "3d 4h", "6h 20m", "12m".
function U.Duration(s)
	s = math.max(0, math.floor(s or 0))
	local days, hours, mins = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
	if days > 0 then return days .. "d" .. (hours > 0 and (" " .. hours .. "h") or "") end
	if hours > 0 then return hours .. "h" .. (mins > 0 and (" " .. mins .. "m") or "") end
	return mins .. "m"
end

-- Long form for sentences: "2 days", "1 day 4 hours", "9 hours", "6 hours 20 min", "40 min".
function U.Long(s)
	s = math.max(0, math.floor(s or 0))
	local days, hours, mins = math.floor(s / 86400), math.floor(s % 86400 / 3600), math.floor(s % 3600 / 60)
	local function n(v, one, many) return v .. " " .. (v == 1 and one or many) end
	if days > 0 then return n(days, "day", "days") .. (hours > 0 and (" " .. n(hours, "hour", "hours")) or "") end
	if hours > 0 then return n(hours, "hour", "hours") .. (mins > 0 and (" " .. mins .. " min") or "") end
	return math.max(1, mins) .. " min"
end

-- Short form for tight columns: "2d", "9h", "40m".
function U.Short(s)
	s = math.max(0, math.floor(s or 0))
	if s >= 86400 then return math.floor(s / 86400) .. "d" end
	if s >= 3600 then return math.floor(s / 3600) .. "h" end
	return math.max(1, math.floor(s / 60)) .. "m"
end

-- A clock time for a future moment: "18:40" today, "tmrw 09:15", "Fri 14:20", "12 Dec".
-- `dateFn` and `now` are injectable for tests (the game's date/time otherwise).
function U.Clock(ts, now, dateFn)
	dateFn = dateFn or date
	now = now or time()
	ts = math.floor(ts)
	local t, today, tmrw = dateFn("*t", ts), dateFn("*t", now), dateFn("*t", now + 86400)
	local hm = ("%02d:%02d"):format(t.hour, t.min)
	if t.year == today.year and t.yday == today.yday then return hm end
	if t.year == tmrw.year and t.yday == tmrw.yday then return "tmrw " .. hm end
	if ts - now < 6 * 86400 then return dateFn("%a ", ts) .. hm end
	return dateFn("%d %b", ts)
end

-- "2d ago", "5h ago", "just now".
function U.Ago(s)
	if not s or s < 90 then return "just now" end
	return U.Short(s) .. " ago"
end

function U.Gold(copper)
	copper = math.floor(copper or 0)
	local g, s = math.floor(copper / 10000), math.floor(copper % 10000 / 100)
	if g > 0 then return g .. "g " .. s .. "s" end
	return s .. "s " .. (copper % 100) .. "c"
end

function U.Clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

-- Shallow copy.
function U.Copy(t)
	local out = {}
	for k, v in pairs(t or {}) do out[k] = v end
	return out
end

-- Stable string hash (djb2), for deterministic per-character choices.
function U.Hash(s)
	local h = 5381
	s = tostring(s or "")
	for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
	return h
end

function U.Print(msg)
	print("|cff7fd4ffRested Leveling|r: " .. msg)
end

-- Shorten a string to at most `max` bytes without splitting a UTF-8 character; prefer the end of a list item
-- ("Tailoring 145, Enchanting 120, ..." stops after a whole item).
function U.Truncate(s, max)
	if type(s) ~= "string" or #s <= max then return s end
	local cut = s:sub(1, max)
	local item = cut:match("^(.*), ")   -- the last whole list item
	if item and #item >= max / 2 then return item end
	local i = #cut
	while i > 0 and cut:byte(i) >= 0x80 and cut:byte(i) < 0xC0 do i = i - 1 end   -- continuation bytes
	if i > 0 and cut:byte(i) >= 0xC0 then
		local need = cut:byte(i) >= 0xF0 and 4 or (cut:byte(i) >= 0xE0 and 3 or 2)
		if #cut - i + 1 < need then i = i - 1 else i = #cut end   -- drop an incomplete last character
	else
		i = #cut
	end
	return cut:sub(1, i)
end

return U
