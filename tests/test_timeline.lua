-- The 48-hour fill timeline (ILL-1272): lanes sorted by when each fills, night shading and 6-hour ticks on the local
-- clock, marker labels, and the main window's ROSTER | TIMELINE tabs (saved, migrated).

local W = dofile("tests/world.lua")
local H, D = 3600, 86400

-- A fixed clock: hours in UTC, so the tests read the same in any time zone.
local function utc(fmt, t) return os.date("!" .. fmt, t) end
local NOW = 1794600000 - (1794600000 % 86400) + 15 * H + 20 * 60   -- some day, 15:20

local function row(full, left, state, group)
	return { key = full, c = { full = full, class = "MAGE" }, p = { left = left, levels = 1, pct = 0.5 }, state = state,
		group = group or 3 }
end

local function alt(full, levels, resting)
	return { full = full, class = "MAGE", race = "Scourge", sex = 3, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = resting, restKind = resting and "inn" or "outside", t = W.NOW - H }
end

local cases = {}

function cases.lanes_sort_by_fill_time_and_flag_the_ones_past_the_window()
	local _, _, state = W.New({})
	local Tl = state.ns.Timeline
	local lanes = Tl.Lanes({ row("Later", 30 * H, "resting"), row("Beyond", 9 * D, "outside"), row("Done", 0, "full"),
		row("Max", 0, "max", 5), row("Soon", 4 * H, "near") })
	local order = {}
	for i, l in ipairs(lanes) do order[i] = l.row.c.full end
	T.eq(table.concat(order, ","), "Done,Soon,Later,Beyond", "soonest first; max level and hidden left out")
	T.eq(lanes[1].frac, 0, "full sits on now")
	T.ok(math.abs(lanes[3].frac - 30 / 48) < 1e-9, "30h is 30/48 of the way")
	T.ok(lanes[4].beyond and lanes[4].frac == 1, "past 48h: to the edge, flagged")
end

function cases.nights_and_ticks_follow_the_local_clock()
	local _, _, state = W.New({})
	local Tl = state.ns.Timeline
	local nights = Tl.Nights(NOW, 48 * H, utc)
	T.eq(#nights, 2, "two nights in 48 hours from 15:20")
	-- First night 20:00 -> 06:00: from 4h40m in to 14h40m in.
	T.ok(math.abs(nights[1].from - (4 * H + 40 * 60) / (48 * H)) < 1e-9, "starts at 20:00")
	T.ok(math.abs(nights[1].to - (14 * H + 40 * 60) / (48 * H)) < 1e-9, "ends at 06:00")
	local ticks = Tl.Ticks(NOW, 48 * H, utc)
	T.eq(ticks[1].label, "18:00", "first tick at 18:00")
	T.eq(#ticks, 8, "every 6 hours")
	local days = 0
	for _, t in ipairs(ticks) do if t.day then days = days + 1 end end
	T.eq(days, 2, "two midnights, labelled with the day")
	local mid = NOW + 8 * H + 40 * 60
	T.eq(ticks[2].label, utc("%a ", mid) .. tonumber(utc("%d", mid)) .. utc(" %b", mid), "midnight shows day, date and month")
	T.ok(ticks[1].quiet and not ticks[2].quiet, "a label every 12 hours (18:00 is a quiet tick)")
end

function cases.marker_labels_say_when()
	local _, _, state = W.New({})
	local Tl = state.ns.Timeline
	T.eq(Tl.Label({ left = 0 }, NOW, utc), "Full now", "already full")
	T.eq(Tl.Label({ left = 2 * H }, NOW, utc), "17:20", "today: the time")
	T.eq(Tl.Label({ left = 20 * H }, NOW, utc), utc("%a", NOW + 20 * H) .. " 11:20", "another day: day and time")
	T.has(Tl.Label({ left = 9 * D, beyond = true }, NOW, utc), "\n", "past the window: the date, then the time")
end

function cases.main_window_switches_to_the_timeline_and_remembers_it()
	local saved = { opts = { view = "bogus" }, chars = {
		["N:Le Nette@?"] = alt("Le Nette", 1.2, true), ["N:Le Dette@?"] = alt("Le Dette", 0.3, false) } }
	local state = { saved = saved, setup = function(game)
		game.UISpecialFrames = {}
		game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
		game.GameTooltip.SetOwner, game.GameTooltip.AddLine = function() end, function() end
		game.SetPortraitTexture = function() end
	end }
	local _, h = W.New(state)
	T.eq(W.DB(h).opts.view, nil, "a bad saved view is the roster")
	h.Slash("RESTEDLEVELING", "")
	local f = state.ns.Main.frame
	T.ok(f.roster:IsShown() and not f.timeline:IsShown(), "the roster first")
	local tab
	for _, b in ipairs(f.tabs) do if b.view == "timeline" then tab = b end end
	FakeWoW.RunScript(tab, "OnClick")
	T.eq(W.DB(h).opts.view, "timeline", "remembered")
	T.ok(f.timeline:IsShown() and not f.roster:IsShown(), "the timeline replaces the roster")
	T.eq(f.header:GetText(), "NEXT 48 HOURS", "the band says what it shows")
	local shown = 0
	for _, l in ipairs(f.timeline.lanes) do if l:IsShown() then shown = shown + 1 end end
	T.eq(shown, 2, "one lane per character")
	FakeWoW.RunScript(f.timeline.lanes[1], "OnEnter")
	T.clean(h)
end

return cases
