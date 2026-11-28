-- 1.3.1 (ILL-1299 follow-up): the main window is one fixed height, with five rows under the hero, and a real scrollbar
-- (drag the thumb, click the track to page, wheel a row) when there are more. The timeline shares the widget.

local W = dofile("tests/world.lua")
local H, D = 3600, 86400

local function alt(full, levels, ago)
	return { full = full, class = "MAGE", race = "Gnome", sex = 3, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = true, restKind = "inn", zone = "Dun Morogh",
		subzone = "Kharanos", t = W.NOW - (ago or H) }
end

-- `n` saved alts, the first full (the hero), the rest less rested each: the list under the hero holds n - 1.
local function world(n, opts)
	local chars = {}
	for i = 1, n do
		chars[("N:Alt %02d@?"):format(i)] = alt(("Alt %02d"):format(i), i == 1 and 1.5 or (1.2 - 0.05 * i), D)
	end
	local cursor = { x = 0, y = 0, down = false }
	local state = { saved = { opts = opts or {}, chars = chars }, setup = function(game)
		game.UISpecialFrames = {}
		game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
		game.SetPortraitTexture = function() end
		game.GetCursorPosition = function() return cursor.x, cursor.y end
		game.IsMouseButtonDown = function() return cursor.down end
	end }
	local _, h = W.New(state)
	h.Slash("RESTEDLEVELING", "")
	return h, state, cursor
end

local function name(row) return (row.name:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- The thumb's height and its top (px down the track), from its anchor.
local function thumb(bar)
	local t = bar.ThumbTexture
	return t:GetHeight(), -t.__points[1][5]
end

local cases = {}

function cases.the_window_is_one_height_for_any_roster()
	local heights = {}
	for _, n in ipairs({ 0, 3, 5, 12 }) do
		local _, state = world(n)
		local main = state.ns.Main
		heights[#heights + 1] = main.frame:GetHeight()
		T.eq(main.frame:GetHeight(), main.Height(main.frame), n .. " characters: the fixed height")
	end
	T.eq(heights[1], heights[4], "0 and 12 characters: the same window")
	T.eq(heights[2], heights[3], "3 and 5 characters: the same window")
	T.eq(heights[1], heights[2], "and every size between")
	local _, state = world(12)
	T.eq(state.ns.Main.VISIBLE, 5, "five rows under the hero")
	T.eq(state.ns.Main.frame.list:GetHeight(), 5 * state.ns.Roster.ROW_H + 8, "the list well holds five rows")
end

function cases.fewer_than_five_leave_blank_slots_and_no_scrollbar()
	local _, state = world(3)
	local roster = state.ns.Main.frame.roster
	T.eq(#roster.list, 2, "two under the hero")
	T.ok(roster.rows[1]:IsShown() and roster.rows[2]:IsShown(), "their rows")
	T.ok(not roster.rows[3]:IsShown() and not roster.rows[5]:IsShown(), "the other slots stay blank")
	T.ok(not roster.bar:IsShown(), "no scrollbar, no track")
	local _, state6 = world(6)
	T.eq(#state6.ns.Main.frame.roster.list, 5, "exactly five")
	T.ok(not state6.ns.Main.frame.roster.bar:IsShown(), "still no scrollbar at five")
end

function cases.first_run_guide_fits_the_same_list()
	local _, state = world(0)
	local f = state.ns.Main.frame
	T.ok(f.roster.guide:IsShown(), "the first-run guide")
	T.ok(f.roster.guide:GetHeight() + 10 <= f.list:GetHeight() - 8, "inside the list well")
	T.ok(not f.roster.bar:IsShown(), "no scrollbar")
end

function cases.the_thumb_is_sized_and_placed_for_twelve()
	local _, state = world(13)
	local roster = state.ns.Main.frame.roster
	local bar = roster.bar
	T.eq(#roster.list, 12, "twelve under the hero")
	T.ok(bar:IsShown(), "a scrollbar")
	local trackH = 5 * state.ns.Roster.ROW_H - 2
	T.eq(bar:GetHeight(), trackH, "the track runs the rows' full height")
	local h, top = thumb(bar)
	T.eq(h, math.floor(trackH * 5 / 12 + 0.5), "thumb: visible / total of the track")
	T.eq(top, 0, "at the top")
	state.ns.Roster.Scroll(roster, 3)
	h, top = thumb(bar)
	T.ok(math.abs(top - (trackH - h) * 3 / 7) < 1e-9, "in the middle: 3 of 7 down the free track")
	T.eq(name(roster.rows[1]), roster.list[4].c.full, "and the fourth character on top")
	T.eq(roster.rows[1].rank:GetText(), 5, "ranked as in the whole list (the hero is #1)")
	state.ns.Roster.Scroll(roster, 7)
	h, top = thumb(bar)
	T.eq(top + h, trackH, "at the end: the thumb's bottom on the track's")
	T.eq(name(roster.rows[5]), roster.list[12].c.full, "the last character in the last slot")
	-- never under 24 px, however long the list
	local Wg = state.ns.Widgets
	T.eq((Wg.ScrollThumb(308, 5, 200, 0)), 24, "a long list: the 24 px minimum")
	T.eq(select(2, Wg.ScrollThumb(308, 5, 200, 195)), 308 - 24, "and it still reaches the end")
end

function cases.dragging_the_thumb_scrolls_the_list()
	local _, state, cursor = world(13)
	local roster = state.ns.Main.frame.roster
	local bar = roster.bar
	bar.__top = 600   -- placed: the track's top at y 600 (scale 1)
	local trackH = bar:GetHeight()
	local h = thumb(bar)
	cursor.x, cursor.y, cursor.down = 10, 600 - 10, true
	FakeWoW.RunScript(bar.grab, "OnMouseDown", "LeftButton")
	T.ok(bar.grab.hl:IsShown(), "lit while dragged")
	local free = trackH - h
	cursor.y = 590 - free * 3 / 7   -- 3/7 of the free track down
	FakeWoW.RunScript(bar, "OnUpdate", 0.02)
	T.eq(roster.offset, 3, "the drag maps to the row under it")
	T.eq(select(2, thumb(bar)), free * 3 / 7, "the thumb follows")
	cursor.y = 590 - free * 3.4 / 7
	FakeWoW.RunScript(bar, "OnUpdate", 0.02)
	T.eq(roster.offset, 3, "to the nearest row")
	cursor.y = 590 - free - 400   -- far below the track
	FakeWoW.RunScript(bar, "OnUpdate", 0.02)
	T.eq(roster.offset, 7, "no further than the last row")
	cursor.y = 900   -- far above
	FakeWoW.RunScript(bar, "OnUpdate", 0.02)
	T.eq(roster.offset, 0, "nor above the first")
	FakeWoW.RunScript(bar.grab, "OnMouseUp", "LeftButton")
	T.ok(not bar.dragging and bar:GetScript("OnUpdate") == nil, "let go: the drag ends")
	T.ok(not bar.grab.hl:IsShown(), "and the light goes off")
	-- a button released outside the thumb still ends the drag
	FakeWoW.RunScript(bar.grab, "OnMouseDown", "LeftButton")
	cursor.down = false
	FakeWoW.RunScript(bar, "OnUpdate", 0.02)
	T.ok(not bar.dragging, "released anywhere: the drag ends")
	FakeWoW.RunScript(bar.grab, "OnEnter")
	T.ok(bar.grab.hl:IsShown(), "hover lights the thumb")
	FakeWoW.RunScript(bar.grab, "OnLeave")
	T.ok(not bar.grab.hl:IsShown(), "and leaving dims it")
end

function cases.a_click_on_the_track_pages_by_five()
	local _, state, cursor = world(13)
	local roster = state.ns.Main.frame.roster
	local bar = roster.bar
	bar.__top = 600
	local h = thumb(bar)
	cursor.y = 600 - h - 20   -- under the thumb
	FakeWoW.RunScript(bar, "OnMouseDown", "LeftButton")
	T.eq(roster.offset, 5, "a page down: five rows")
	cursor.y = 600 - bar:GetHeight() + 2   -- the track's foot, under the thumb again
	FakeWoW.RunScript(bar, "OnMouseDown", "LeftButton")
	T.eq(roster.offset, 7, "the next page stops at the end")
	cursor.y = 600 - 4   -- above the thumb, now at the bottom
	FakeWoW.RunScript(bar, "OnMouseDown", "LeftButton")
	T.eq(roster.offset, 2, "a page up")
	local _, top = thumb(bar)
	cursor.y = 600 - top - h / 2   -- on the thumb itself
	FakeWoW.RunScript(bar, "OnMouseDown", "LeftButton")
	T.eq(roster.offset, 2, "a click on the thumb does not page")
	FakeWoW.RunScript(bar, "OnMouseDown", "RightButton")
	T.eq(roster.offset, 2, "right-click does nothing")
end

function cases.the_wheel_scrolls_one_row_and_clamps()
	local _, state = world(13)
	local roster = state.ns.Main.frame.roster
	FakeWoW.RunScript(roster, "OnMouseWheel", -1)
	T.eq(roster.offset, 1, "one row a notch")
	FakeWoW.RunScript(roster.bar, "OnMouseWheel", -1)
	T.eq(roster.offset, 2, "on the scrollbar too")
	FakeWoW.RunScript(roster, "OnMouseWheel", -20)
	T.eq(roster.offset, 7, "clamped at the end")
	FakeWoW.RunScript(roster, "OnMouseWheel", 20)
	T.eq(roster.offset, 0, "and at the top")
	local _, state3 = world(3)
	local short = state3.ns.Main.frame.roster
	FakeWoW.RunScript(short, "OnMouseWheel", -1)
	T.eq(short.offset, 0, "a short list does not move")
end

function cases.position_is_kept_on_refresh_clamped_on_shrink_and_reset_on_open()
	local h, state = world(13)
	local Main = state.ns.Main
	local roster = Main.frame.roster
	state.ns.Roster.Scroll(roster, 4)
	local top = name(roster.rows[1])
	W.Tick(state)
	Main.Refresh()
	T.eq(roster.offset, 4, "a refresh keeps the place")
	T.eq(name(roster.rows[1]), top, "on the same character")
	state.ns.Roster.Scroll(roster, 7)
	local chars = W.DB(h).chars
	for i = 10, 13 do chars[("N:Alt %02d@?"):format(i)] = nil end   -- the list shrinks to 8
	Main.Refresh()
	T.eq(#roster.list, 8, "eight under the hero now")
	T.eq(roster.offset, 3, "clamped: the last row still in the last slot")
	T.ok(roster.rows[5]:IsShown(), "no blank slot at the bottom")
	for i = 6, 9 do chars[("N:Alt %02d@?"):format(i)] = nil end   -- and to 4
	Main.Refresh()
	T.eq(roster.offset, 0, "everyone fits: back to the top")
	T.ok(not roster.bar:IsShown(), "and the scrollbar goes")
	local h2, state2 = world(13)
	local f = state2.ns.Main.frame
	state2.ns.Roster.Scroll(f.roster, 6)
	f:Hide()
	h2.Slash("RESTEDLEVELING", "")
	T.ok(f:IsShown(), "opened again")
	T.eq(f.roster.offset, 0, "from the top")
	T.clean(h2)
end

function cases.chips_keep_their_right_edge_beside_the_scrollbar()
	local _, state = world(13)
	local f, Wg = state.ns.Main.frame, state.ns.Widgets
	local roster = f.roster
	local chipRight = Wg.COL.chip + Wg.CHIP_W
	T.ok(roster.rowW >= chipRight + 2, "the chip sits inside the narrower row")
	T.eq(roster.rows[1]:GetWidth(), roster:GetWidth() - Wg.SCROLL_W - Wg.SCROLL_GAP, "rows leave the scrollbar its strip")
	T.ok(chipRight < roster:GetWidth() - Wg.SCROLL_W, "the chip ends left of the scrollbar")
	T.eq(f.current.pill.__points[#f.current.pill.__points][4], 4 + chipRight, "on NOW PLAYING's chip edge (both 4 px in)")
	local _, state3 = world(3)
	T.eq(state3.ns.Main.frame.roster.rows[1]:GetWidth(), roster.rows[1]:GetWidth(), "the same width with no scrollbar")
end

function cases.the_timeline_shows_five_lanes_with_the_same_scrollbar()
	local _, state, cursor = world(13, { view = "timeline" })
	local Main, Wg = state.ns.Main, state.ns.Widgets
	local tl = Main.frame.timeline
	T.ok(tl:IsShown(), "the timeline view")
	T.eq(Main.frame:GetHeight(), Main.Height(Main.frame), "the same fixed height")
	local shown = 0
	for _, l in ipairs(tl.lanes) do if l:IsShown() then shown = shown + 1 end end
	T.eq(shown, 5, "five lanes")
	T.ok(tl.bar:IsShown(), "a scrollbar for the rest")
	T.eq(tl.bar.SetRange, Wg.SetScrollRange, "the roster's scrollbar widget")
	T.eq(tl.bar.total, 13, "every lane in the range (the hero too: the timeline has no hero)")
	T.eq(tl.bar:GetHeight(), 5 * tl.lanes[1]:GetHeight(), "the track runs the lanes' height")
	T.ok(tl.plotX + tl.plotW + 18 + state.ns.Timeline.GUTTER - 10 <= tl:GetWidth() - Wg.SCROLL_W - Wg.SCROLL_GAP,
		"the gutter's dates end left of the scrollbar")
	local first = tl.lanes[1].lane.row.c.full
	tl.bar.__top = 500
	cursor.y = 500 - tl.bar:GetHeight() + 2   -- the bottom of the track, under the thumb
	FakeWoW.RunScript(tl.bar, "OnMouseDown", "LeftButton")
	T.eq(tl.offset, 5, "a track click pages five lanes")
	T.ok(tl.lanes[1].lane.row.c.full ~= first, "another lane on top")
	FakeWoW.RunScript(tl, "OnMouseWheel", -20)
	T.eq(tl.offset, 8, "the wheel stops at the last lane")
	local _, state5 = world(5, { view = "timeline" })
	T.ok(not state5.ns.Main.frame.timeline.bar:IsShown(), "five lanes or fewer: no scrollbar")
end

function cases.settings_page_uses_the_same_scrollbar()
	local _, state = world(3)
	local Wg = state.ns.Widgets
	local Se = state.ns.Settings
	local f = Se.Create()
	T.eq(f.bar.SetRange, Wg.SetScrollRange, "the shared widget")
	T.eq(f.bar.step, 40, "the wheel moves 40 px of the page")
end

return cases
