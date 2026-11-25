-- Plain-words lines in the window: the hero's reason, time columns, places, the sync footer.

local W = dofile("tests/world.lua")
local H, D = 3600, 86400
local NOW = W.NOW

local function load()
	return W.Pure({ "Core/Util.lua", "Core/Model.lua", "Core/Identity.lua", "UI/Words.lua" })
end

local function row(state, p, c)
	c = c or {}
	c.full = c.full or "Le Nette"
	return { key = "N:" .. c.full .. "@?", c = c, p = p, state = state }
end

local cases = {}

function cases.levels_read_naturally()
	local ns = load()
	T.eq(ns.Words.Levels(1.5), "1.5 levels", "1.5")
	T.eq(ns.Words.Levels(1.0), "1 level", "1")
	T.eq(ns.Words.Levels(2), "2 levels", "2")
	T.eq(ns.Words.Levels(0.42), "0.4 of a level", "under one")
end

-- The game's date() is local time; tests read UTC so the clock times are the same on every machine.
-- W.NOW is Fri 13 Nov 2026, 20:00 UTC.
local function utc(fmt, t) return os.date("!" .. fmt, t) end

function cases.card_reason_for_each_state_ends_with_the_real_time_to_full()
	local ns = load()
	local Wd = ns.Words
	T.eq(Wd.Why(row("full", { pct = 1, levels = 1.5, left = 0, fullSince = NOW - 9 * H }), NOW, utc),
		"Full for 9h. 1.5 levels of double XP waiting.", "full")
	T.eq(Wd.Why(row("near", { pct = 0.93, levels = 1.4, left = 2 * H }), NOW, utc),
		"93% full. Full in 2h (today 22:00). 1.4 levels of double XP ready.", "near")
	T.eq(Wd.Why(row("resting", { pct = 0.5, levels = 0.75, left = 5 * H }, { resting = true, restKind = "inn", subzone = "Goldshire" }), NOW, utc),
		"Resting at Goldshire inn. 0.8 of a level banked. Full in 5h (tomorrow 01:00).", "resting")
	T.eq(Wd.Why(row("resting", { pct = 0, levels = 0, left = 240 * H }, { resting = true, restKind = "inn", subzone = "Feathermoon Stronghold" }), NOW, utc),
		"Resting at Feathermoon Stronghold inn. Nothing banked yet. Full in 10d (Mon 23 Nov, 20:00).", "empty in an inn")
	T.has(Wd.Why(row("outside", { pct = 0.2, levels = 0.3, left = 90 * H }, { zone = "Durotar" }), NOW, utc), "4x slower", "outside")
	T.has(Wd.Why(row("outside", { pct = 0.2, levels = 0.3, left = 90 * H }, { zone = "Durotar" }), NOW, utc),
		"Full in 3d 18h (Tue 17 Nov, 14:00)", "outside, real time")
end

function cases.hero_line_is_the_state_then_the_real_time_to_full()
	local Wd = load().Words
	T.eq(Wd.HeroWhy(row("full", { pct = 1, levels = 1.5, left = 0, fullSince = NOW - 2 * D - 4 * H }), NOW, utc),
		"Fully rested. Full for 2d 4h.", "full")
	T.eq(Wd.HeroWhy(row("resting", { pct = 0.5, levels = 0.75, left = 6 * H + 20 * 60 }), NOW - 2 * H, utc),
		"Resting. Full in 6h 20m (tomorrow 00:20).", "resting")   -- 18:00 + 6h 20m crosses midnight: says which day
	T.eq(Wd.HeroWhy(row("resting", { pct = 0.5, levels = 0.75, left = 6 * H + 20 * 60 }), NOW - 8 * H, utc),
		"Resting. Full in 6h 20m (today 18:20).", "resting, same day")
	T.eq(Wd.HeroWhy(row("outside", { pct = 0.2, levels = 0.3, left = 36 * D }), NOW, utc),
		"Not resting, fills 4x slower. Full in 36d (Sat 19 Dec, 20:00).", "outside")
end

-- One formatter for "how much longer until fully rested", at its boundaries.
function cases.full_line_at_its_boundaries()
	local Wd = load().Words
	local function at(left) return Wd.FullLine({ left = left }, NOW, utc) end
	T.eq(at(59 * 60), "Full in 59m (today 20:59)", "59m")
	T.eq(at(H), "Full in 1h (today 21:00)", "1h")
	T.eq(at(23 * H + 59 * 60), "Full in 23h 59m (tomorrow 19:59)", "23h59m")
	T.eq(at(D), "Full in 1d (tomorrow 20:00)", "1d")
	T.eq(at(9 * D + 23 * H), "Full in 9d 23h (Mon 23 Nov, 19:00)", "9d23h")
	T.eq(at(10), "Full in 1m (today 20:01)", "under a minute rounds up to 1m")
	T.eq(Wd.FullLine({ left = 0, fullSince = NOW - 2 * D - 4 * H }, NOW, utc), "Full for 2d 4h", "full")
	T.eq(Wd.FullLine({ left = 0, fullSince = NOW - 30 }, NOW, utc), "Full now", "just filled")
	T.eq(Wd.FullLine(nil, NOW, utc), "", "max level: nothing to fill")
end

-- Andy asked whether ~10 days from empty is right: 5% of a level per 8h, cap 1.5 levels = 240h in an inn; 4x that
-- outside; Well Rested ranks scale rate and cap together, so the time is the same.
function cases.empty_to_full_is_ten_days_in_an_inn_forty_outside()
	local ns = load()
	local M = ns.Model
	local inn = M.Project({ t = NOW, xpMax = 1000, rested = 0, resting = true }, NOW, {})
	T.eq(math.floor(inn.left / H + 0.5), 240, "inn: 240h")
	local out = M.Project({ t = NOW, xpMax = 1000, rested = 0, resting = false }, NOW, {})
	T.eq(math.floor(out.left / D + 0.5), 40, "outside: 40 days")
	local ranked = M.Project({ t = NOW, xpMax = 1000, rested = 0, resting = true, ranks = 5 }, NOW, {})
	T.eq(math.floor(ranked.left / H + 0.5), 240, "Well Rested 5: still 240h (rate and cap both +20%)")
end

function cases.nothing_banked_means_nobody_to_play_next()
	local Wd = load().Words
	local jette = row("resting", { pct = 0, levels = 0.01, left = 239 * H }, { full = "Le Jette", resting = true })
	jette.group = 4
	T.ok(Wd.NothingBanked(jette), "0.01 levels in an inn is nothing to switch to")
	local some = row("resting", { pct = 0.1, levels = 0.15, left = 200 * H })
	some.group = 3
	T.ok(not Wd.NothingBanked(some), "0.15 levels is worth playing")
	local full = row("full", { pct = 1, levels = 1.5, left = 0 })
	full.group = 1
	T.ok(not Wd.NothingBanked(full), "full")
	T.ok(not Wd.NothingBanked(nil), "no hero")
	local far = row("outside", { pct = 0, levels = 0.02, left = 900 * H }, { full = "Far" })
	far.group = 4
	T.eq(Wd.FillsFirst({ far, jette }), jette, "fills first: least time to full, not the list order")
end

function cases.action_line_only_says_hearth_about_the_character_you_are_on()
	local Wd = load().Words
	T.eq(Wd.Action("Le Jette", "Le Nette", false, false), "First, take Le Nette to an inn (hearth). Then play Le Jette.", "outside")
	T.eq(Wd.Action("Le Jette", "Le Nette", true, false), "Next, log Le Nette out here. Then play Le Jette.", "resting")
	T.eq(Wd.Action("Le Jette", "Le Nette", false, true), "Nobody to switch to yet. When you stop, log Le Nette out in an inn.", "empty, outside")
	T.eq(Wd.Action("Le Jette", "Le Nette", true, true), "Nobody to switch to yet. Keep playing Le Nette; it rests here too.", "empty, resting")
	T.lacks(Wd.Action("Le Jette", "Le Nette", false, true), "play Le Jette", "nobody to send you to")
end

function cases.places()
	local Wd = load().Words
	T.eq(Wd.Place({ restKind = "inn", subzone = "Brill", zone = "Tirisfal Glades" }), "Brill inn", "inn")
	T.eq(Wd.Place({ restKind = "city", zone = "Orgrimmar" }), "Orgrimmar", "city")
	T.eq(Wd.Place({ restKind = "bag", zone = "Duskwood" }), "sleeping bag in Duskwood", "bag")
	T.eq(Wd.Place({ restKind = "outside", zone = "Durotar" }), "outside in Durotar", "outside")
end

function cases.link_line_for_each_pairing_state()
	local Wd = load().Words
	T.eq(Wd.LinkLine(nil, "Le Nette", NOW), "No other account linked yet.", "none")
	T.eq(Wd.LinkLine({ name = "Le Bankken", confirmed = false }, "Le Nette", NOW),
		"Linked to Le Bankken. Waiting for them to link you back (/rlvl link Le Nette on that account).", "waiting")
	T.eq(Wd.LinkLine({ name = "Le Bankken", confirmed = true, lastSync = NOW - 5 * 60 }, "Le Nette", NOW),
		"Paired with Le Bankken, synced 5m ago", "paired")
	T.eq(Wd.LinkLine({ name = "Le Bankken", confirmed = true }, "Le Nette", NOW), "Paired with Le Bankken, not synced yet", "paired, no data yet")
end

function cases.rows_show_the_real_time_to_full_even_outside()
	local Wd = load().Words
	local t = Wd.RowTime(row("outside", { pct = 0.3, levels = 0.45, left = 27 * D }), NOW, true, utc)
	T.eq(t, "30%  ·  Full in 27d (Thu 10 Dec, 20:00)", "outside")
	t = Wd.RowTime(row("near", { pct = 0.93, levels = 1.4, left = 2 * H }), NOW, false, utc)
	T.eq(t, "~93%  ·  Full in 2h (today 22:00)", "projected rows carry a ~")
end

function cases.long_durations_read_as_words()
	local U = load().Util
	T.eq(U.Long(2 * D), "2 days", "days")
	T.eq(U.Long(D + 4 * H), "1 day 4 hours", "day and hours")
	T.eq(U.Long(6 * H + 20 * 60), "6 hours 20 min", "hours and minutes")
	T.eq(U.Long(40 * 60), "40 min", "minutes")
end

function cases.one_word_per_state_on_every_chip()
	local Wd = load().Words
	T.eq(Wd.Chip(row("near")), "NEARLY FULL", "near")
	T.eq(Wd.Chip(row("outside")), "NOT RESTING", "outside")
	T.eq(Wd.Chip(row("max")), "MAX LEVEL", "max")
end

function cases.hero_says_why_number_one_beats_number_two()
	local Wd = load().Words
	local a = row("full", { pct = 1, levels = 1.7, left = 0, fullSince = NOW - 2 * D }, { full = "Le Nette" })
	local b = row("full", { pct = 1, levels = 1.6, left = 0, fullSince = NOW - 8 * H }, { full = "Le Beouf" })
	a.group, b.group = 1, 1
	T.eq(Wd.Ahead({ a, b }, NOW), "Then Le Beouf, full for 8h", "both full")
	local c = row("resting", { pct = 0.5, levels = 0.8, left = H }, { full = "Le Bankke" })
	c.group = 3
	T.eq(Wd.Ahead({ a, c }, NOW), nil, "different groups need no explanation")
end

return cases
