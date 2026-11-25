-- The rested model: projection (inn, outside, cap, ranks), calibration, colour precedence and play-next sort.

local W = dofile("tests/world.lua")
local ns = W.Pure()
local M = ns.Model
local H = 3600
local NOW = W.NOW

-- A character saved `ago` seconds before NOW with `levels` of rested XP.
local function char(levels, ago, resting, extra)
	local c = { full = "Alt", level = 20, xpMax = 10000, rested = levels * 10000, resting = resting, t = NOW - ago }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end

local function near(a, b, what, eps)
	if math.abs(a - b) > (eps or 1e-6) then error(("%s: expected %s, got %s"):format(what, b, a), 2) end
end

local cases = {}

function cases.inn_gains_five_percent_of_a_level_per_eight_hours()
	local p = M.Project(char(0, 8 * H, true), NOW, {})
	near(p.levels, 0.05, "levels after 8h in an inn")
	near(p.pct, 0.05 / 1.5, "pct of cap")
end

function cases.outside_gains_a_quarter_as_fast()
	local p = M.Project(char(0, 8 * H, false), NOW, {})
	near(p.levels, 0.0125, "levels after 8h outside")
end

function cases.cap_is_one_and_a_half_levels_and_full_since_is_when_it_got_there()
	-- 1.4 levels + 0.1 needs 16h in an inn; saved 20h ago, so full for 4h.
	local p = M.Project(char(1.4, 20 * H, true), NOW, {})
	T.eq(p.left, 0, "full")
	T.eq(p.pct, 1, "pct")
	near(p.levels, 1.5, "levels at cap")
	near(NOW - p.fullSince, 4 * H, "full for 4h", 1)
end

function cases.saved_over_the_cap_is_full_from_the_snapshot_not_before()
	local p = M.Project(char(1.6, 600, true), NOW, {})
	T.eq(p.left, 0, "full")
	T.eq(NOW - p.fullSince, 600, "full since the snapshot")
end

function cases.well_rested_ranks_raise_rate_and_cap()
	local c = char(0, 8 * H, true, { ranks = 5 })
	local p = M.Project(c, NOW, {})
	near(p.levels, 0.05 * 1.2, "rate +20% at rank 5")
	near(p.cap, 1.5 * 1.2, "cap +20% at rank 5")
end

function cases.max_level_has_no_projection_and_is_grey()
	local c = char(0.5, H, true, { atMax = true, level = 60 })
	T.eq(M.Project(c, NOW, {}), nil, "no projection")
	T.eq(M.State(c, nil, { maxLevel = 60 }), M.MAXED, "grey")
end

function cases.colour_precedence_at_89_90_and_100_percent()
	local cap = 1.5
	local function state(pct, resting)
		local c = char(cap * pct, 0, resting)
		return M.State(c, M.Project(c, NOW, {}), { maxLevel = 60 })
	end
	T.eq(state(0.89, true), M.RESTING, "89% resting is orange")
	T.eq(state(0.89, false), M.OUTSIDE_STATE, "89% outside is red")
	T.eq(state(0.90, false), M.NEAR_FULL, "90% outside is yellow: fullness wins")
	T.eq(state(0.90, true), M.NEAR_FULL, "90% resting is yellow")
	T.eq(state(1.00, false), M.FULL, "100% outside is green")
	T.eq(state(0.999, true), M.NEAR_FULL, "just under cap is yellow")
end

function cases.target_level_and_above_is_done_and_sorts_last()
	local chars = {
		a = char(1.5, 10 * H, true, { full = "Done", level = 40 }),
		b = char(0.1, H, true, { full = "Low", level = 20 }),
	}
	local rows = M.BuildRows(chars, NOW, {}, { target = 40, maxLevel = 60 })
	T.eq(rows[1].c.full, "Low", "below target first")
	T.eq(rows[2].state, M.DONE, "at target is done")
	T.eq(rows[2].group, 5, "and sorts with the grey ones")
end

function cases.sort_puts_the_one_to_play_next_on_top()
	local chars = {
		fullShort = char(1.5, 2 * H, true, { full = "Full 2h" }),
		fullLong = char(1.5, 30 * H, true, { full = "Full 30h" }),
		near95 = char(1.5 * 0.95, 0, false, { full = "Near 95" }),
		near91 = char(1.5 * 0.91, 0, true, { full = "Near 91" }),
		rest08 = char(0.8, 0, true, { full = "Rest 0.8" }),
		out10 = char(1.0, 0, false, { full = "Out 1.0" }),
		empty = char(0, 0, false, { full = "Empty" }),
		maxed = char(0, 0, true, { full = "Maxed", atMax = true, level = 60 }),
		me = char(1.5, 50 * H, true, { full = "Me" }),
	}
	local rows = M.BuildRows(chars, NOW, {}, { me = "me", maxLevel = 60 })
	local order = {}
	for _, r in ipairs(rows) do order[#order + 1] = r.c.full end
	T.eq(table.concat(order, ","), "Full 30h,Full 2h,Near 95,Near 91,Out 1.0,Rest 0.8,Empty,Maxed", "order")
	local f, r, o = M.Counts(rows)
	T.eq(f .. "/" .. r .. "/" .. o, "2/2/3", "datatext counts")
end

function cases.hidden_rows_sink_and_can_be_dropped()
	local chars = { a = char(1.5, 30 * H, true, { full = "A" }), b = char(0.2, 0, true, { full = "B" }) }
	local rows = M.BuildRows(chars, NOW, {}, { hidden = { a = true }, maxLevel = 60 })
	T.eq(rows[1].c.full, "B", "visible first")
	T.eq(rows[2].group, 5, "hidden is grey")
	T.eq(#M.BuildRows(chars, NOW, {}, { hidden = { a = true }, maxLevel = 60, hideGrey = true }), 1, "switch hides it")
end

function cases.calibration_learns_a_faster_rate()
	-- Saved 0.1 levels in an inn 16h ago: expected 0.2; the game says 0.25, so the rate goes up.
	local c = char(0.1, 16 * H, true, { level = 30 })
	local calib, why = M.Calibrate(c, 2500, 10000, 30, NOW, nil, {})
	T.eq(why, "rate", "learned the rate")
	T.ok(calib.rate > 1, "rate raised")
	T.eq(calib.n, 1, "one sample")
end

function cases.calibration_learns_a_higher_cap()
	local c = char(1.4, 48 * H, true, { level = 30 })
	local calib, why = M.Calibrate(c, 16000, 10000, 30, NOW, nil, {})
	T.eq(why, "cap-higher", "learned the cap")
	near(calib.capMul, 1.6 / 1.5, "cap multiplier")
end

function cases.calibration_skips_short_breaks_level_changes_and_rank_changes()
	local c = char(0.1, H, true, { level = 30 })
	local _, why = M.Calibrate(c, 9000, 10000, 30, NOW, nil, {})
	T.eq(why, nil, "under 2h: nothing learnt")
	c = char(0.1, 16 * H, true, { level = 30 })
	_, why = M.Calibrate(c, 2500, 10000, 31, NOW, nil, {})
	T.eq(why, nil, "level changed: nothing learnt")
	c = char(0.1, 16 * H, true, { level = 30, ranks = 1 })
	_, why = M.Calibrate(c, 2500, 10000, 30, NOW, 2, {})
	T.eq(why, nil, "rank changed: nothing learnt")
end

return cases
