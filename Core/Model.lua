-- Rested Leveling: the rested-XP model. Pure functions only (no game calls), so all of it runs headless in tests.
--
-- Maths from Rested Watch 1.4.8 by doc_biddle (GPL-3.0), with thanks: 5% of a level per 8 hours resting
-- (a quarter of that outside an inn or city), capped at 1.5 levels, both raised 4% per rank of the Legacy perk
-- Well Rested. Each login compares the projection with the real value and corrects the rate or cap.

local _, ns = ...
local M = {}
ns.Model = M

M.BASE_RATE = 0.05 / (8 * 3600)   -- levels of rested XP per second while resting
M.BASE_CAP = 1.5                  -- levels of rested XP at the cap
M.OUTSIDE = 0.25                  -- logged out away from an inn, a city or a sleeping bag
M.NEAR = 0.9                      -- "nearly full" from 90% of the cap
M.EMPTY = 0.005                   -- below this many levels a character counts as empty
M.RANK_STEP = 0.04                -- each Well Rested rank adds 4% to rate and cap
M.MAX_RANK = 5

-- State names, in colour-precedence order. Fullness wins over resting state.
M.FULL, M.NEAR_FULL, M.RESTING, M.OUTSIDE_STATE, M.MAXED, M.DONE = "full", "near", "resting", "outside", "max", "done"

function M.Rank(c) return (c and c.ranks) or 0 end

-- Corrections are stored as multipliers so they carry across characters with different ranks.
function M.RateMul(c, calib)
	return (1 + M.RANK_STEP * M.Rank(c)) * ((calib and calib.rate) or 1)
end

function M.Cap(c, calib)
	return M.BASE_CAP * (1 + M.RANK_STEP * M.Rank(c)) * ((calib and calib.capMul) or 1)
end

-- Levels per second this character gains while logged out where it was saved.
function M.Rate(c, calib)
	return M.BASE_RATE * M.RateMul(c, calib) * ((c and c.resting) and 1 or M.OUTSIDE)
end

-- Where a character's rested XP stands at `now`. Returns nil for max-level or unusable records, else a table:
--   pct (0..1 of cap), levels (rested XP in levels), left (seconds to full, 0 when full),
--   fullSince (when it hit the cap, only when full), cap (levels), rate (levels/s).
function M.Project(c, now, calib)
	if not c or c.atMax or not c.t or not c.xpMax or c.xpMax <= 0 then return nil end
	local cap = M.Cap(c, calib)
	local rate = M.Rate(c, calib)
	local start = (c.rested or 0) / c.xpMax
	local elapsed = math.max(0, now - c.t)
	local levels = start + rate * elapsed
	if levels >= cap then
		-- Saved at or over the cap (a rank not read yet, say): full from that moment, never earlier.
		local fullSince = math.max(c.t, c.t + (cap - start) / rate)
		return { pct = 1, levels = cap, left = 0, fullSince = fullSince, cap = cap, rate = rate }
	end
	return { pct = levels / cap, levels = levels, left = (cap - levels) / rate, cap = cap, rate = rate }
end

-- The colour state. opts: maxLevel, target (a level; at or above it the character is "done").
function M.State(c, p, opts)
	opts = opts or {}
	if c.atMax or (opts.maxLevel and c.level and c.level >= opts.maxLevel) then return M.MAXED end
	if opts.target and c.level and c.level >= opts.target then return M.DONE end
	if not p then return M.MAXED end
	if p.left == 0 or p.pct >= 1 then return M.FULL end
	if p.pct >= M.NEAR then return M.NEAR_FULL end
	return c.resting and M.RESTING or M.OUTSIDE_STATE
end

-- Sort groups: 1 full, 2 nearly full, 3 resting/outside with rest, 4 empty, 5 grey (max level, done, hidden).
function M.Group(state, p, hidden)
	if hidden or state == M.MAXED or state == M.DONE then return 5 end
	if state == M.FULL then return 1 end
	if state == M.NEAR_FULL then return 2 end
	if not p or p.levels < M.EMPTY then return 4 end
	return 3
end

local function nameOf(r) return (r.c.full or r.c.name or r.key or ""):lower() end

-- "Play the top one first."
function M.Less(a, b, now)
	if a.group ~= b.group then return a.group < b.group end
	if a.group == 1 then
		local fa, fb = now - (a.p.fullSince or now), now - (b.p.fullSince or now)
		if fa ~= fb then return fa > fb end            -- longest sitting full first
	elseif a.group == 2 then
		if a.p.pct ~= b.p.pct then return a.p.pct > b.p.pct end
	elseif a.group == 3 or a.group == 4 then
		local la, lb = a.p and a.p.levels or 0, b.p and b.p.levels or 0
		if la ~= lb then return la > lb end           -- most double XP waiting first
	elseif a.group == 5 then
		if (a.c.level or 0) ~= (b.c.level or 0) then return (a.c.level or 0) > (b.c.level or 0) end
	end
	return nameOf(a) < nameOf(b)
end

-- Rows for every saved character except `opts.me` (the logged-in one gets its own strip).
-- opts: me, hidden (set of keys), target, maxLevel, hideGrey (drop group 5 entirely), account (show only that
-- account's characters; a record without one belongs to opts.myAccount).
function M.BuildRows(chars, now, calib, opts)
	opts = opts or {}
	local rows = {}
	for key, c in pairs(chars or {}) do
		if key ~= opts.me and (not opts.account or (c.account or opts.myAccount) == opts.account) then
			local p = M.Project(c, now, calib)
			local hidden = opts.hidden and opts.hidden[key] or false
			local state = M.State(c, p, opts)
			local group = M.Group(state, p, hidden)
			if not (opts.hideGrey and group == 5) then
				rows[#rows + 1] = { key = key, c = c, p = p, state = state, group = group, hidden = hidden }
			end
		end
	end
	table.sort(rows, function(a, b) return M.Less(a, b, now) end)
	return rows
end

-- Counts for the datatext: full, resting (not full), outside (not full).
function M.Counts(rows)
	local full, resting, outside = 0, 0, 0
	for _, r in ipairs(rows) do
		if r.group ~= 5 then
			if r.state == M.FULL then full = full + 1
			elseif r.c.resting then resting = resting + 1
			else outside = outside + 1 end
		end
	end
	return full, resting, outside
end

-- At login, compare the projection for this character with what the game now reports and return corrected
-- calibration (a new table) plus a reason, or the old table and nil when nothing can be learnt.
-- `rankNow` is the Well Rested rank read now (nil if unreadable).
function M.Calibrate(c, actualRested, xpMax, level, now, rankNow, calib)
	calib = calib or {}
	if not c or not c.t or c.atMax or c.online or c.level ~= level or not c.xpMax or c.xpMax <= 0 then return calib end
	if not xpMax or xpMax <= 0 then return calib end
	local elapsed = now - c.t
	if elapsed < 2 * 3600 then return calib end
	if rankNow ~= nil and c.ranks ~= nil and rankNow ~= c.ranks then return calib end   -- rank changed while away
	local start = (c.rested or 0) / c.xpMax
	local actual = (actualRested or 0) / xpMax
	local gained = actual - start
	local expectedNoCap = start + M.Rate(c, calib) * elapsed
	local cap = M.Cap(c, calib)
	local baseCap = cap / (calib.capMul or 1)
	local out = { rate = calib.rate, capMul = calib.capMul, n = (calib.n or 0) }
	if actual > cap + 0.01 then
		out.capMul = actual / baseCap                                -- the real cap is higher
		out.n = out.n + 1
		return out, "cap-higher"
	elseif expectedNoCap < cap - 0.02 and gained > 0.005 then
		local ratio = gained / (expectedNoCap - start)                -- unfilled: learn the rate
		if ratio > 0.5 and ratio < 2 then
			out.rate = (calib.rate or 1) * (0.5 + 0.5 * ratio)
			out.n = out.n + 1
			return out, "rate"
		end
	elseif expectedNoCap > cap * 1.3 and actual < cap - 0.02 and actual > 0.5 then
		out.capMul = actual / baseCap                                -- long enough to be full: this is the cap
		out.n = out.n + 1
		return out, "cap-lower"
	end
	return calib
end

-- Time this character has sat full, including the current stretch.
function M.Wasted(c, p, now)
	return (c.wasted or 0) + ((p and p.left == 0 and p.fullSince) and math.max(0, now - p.fullSince) or 0)
end

return M
