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

function cases.hero_reason_for_each_state()
	local ns = load()
	local Wd = ns.Words
	T.eq(Wd.Why(row("full", { pct = 1, levels = 1.5, left = 0, fullSince = NOW - 9 * H }), NOW),
		"Fully rested for 9 hours. 1.5 levels of double XP waiting.", "full")
	T.has(Wd.Why(row("near", { pct = 0.93, levels = 1.4, left = 2 * H }), NOW), "93% full, tops off in 2 hours.", "near")
	T.has(Wd.Why(row("resting", { pct = 0.5, levels = 0.75, left = 5 * H }, { resting = true, restKind = "inn", subzone = "Goldshire" }), NOW),
		"Resting at Goldshire inn", "resting")
	T.has(Wd.Why(row("outside", { pct = 0.2, levels = 0.3, left = 90 * H }, { zone = "Durotar" }), NOW), "4x slower", "outside")
end

function cases.time_column_shows_full_for_or_full_in_with_a_clock()
	local ns = load()
	local a, b = ns.Words.FullIn({ left = 0, fullSince = NOW - 2 * D }, NOW)
	T.eq(a, "full for 2d", "full for")
	T.eq(b, "", "no clock when full")
	a, b = ns.Words.FullIn({ left = 6 * H + 20 * 60 }, NOW)
	T.eq(a, "full in 6h 20m", "full in")
	T.ok(b:match("%d%d:%d%d"), "clock " .. b)
end

function cases.places()
	local Wd = load().Words
	T.eq(Wd.Place({ restKind = "inn", subzone = "Brill", zone = "Tirisfal Glades" }), "Brill inn", "inn")
	T.eq(Wd.Place({ restKind = "city", zone = "Orgrimmar" }), "Orgrimmar", "city")
	T.eq(Wd.Place({ restKind = "bag", zone = "Duskwood" }), "sleeping bag in Duskwood", "bag")
	T.eq(Wd.Place({ restKind = "outside", zone = "Durotar" }), "outside in Durotar", "outside")
end

function cases.sync_footer_says_when_no_other_account_was_seen()
	local Wd = load().Words
	T.eq(Wd.SyncLine({}, NOW), "No other account linked yet.", "none")
	T.eq(Wd.SyncLine({ { label = "#3", lastSync = NOW - 2 * D } }, NOW), "Synced 2d ago from Acct #3", "synced")
end

function cases.outside_rows_say_what_to_do_instead_of_a_far_date()
	local Wd = load().Words
	local t = Wd.RowTime(row("outside", { pct = 0.3, levels = 0.45, left = 27 * D }), NOW, true)
	T.eq(t, "30%  ·  park in an inn", "outside")
	t = Wd.RowTime(row("near", { pct = 0.93, levels = 1.4, left = 2 * H }), NOW, false)
	T.has(t, "~93%  ·  full in 2h", "projected rows carry a ~")
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

function cases.far_fill_times_are_marked_rough()
	local Wd = load().Words
	T.eq(Wd.FillTime({ left = 27 * D + 3 * H }, NOW), "full in about 27d", "far")
	T.eq(Wd.FillTime({ left = 14 * H + 25 * 60 }, NOW), "full in 14h 25m", "near")
	T.eq(Wd.FillTime({ left = 0, fullSince = NOW - 2 * D }, NOW), "full for 2d", "full")
end

return cases
