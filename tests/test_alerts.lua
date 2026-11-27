-- Alerts: the logout warning fires only when it costs rest (inn, world, capital /camp, max level, already full),
-- every alert is dismissable and can be turned off, plus ran-out, filled-up and digest messages.

local W = dofile("tests/world.lua")
local H, D = 3600, 86400

local function alt(full, levels, ago, resting, extra)
	local c = { full = full, class = "MAGE", race = "Scourge", sex = 3, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = resting, restKind = resting and "inn" or "outside", t = W.NOW - ago }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end

local function world(state)
	state = state or {}
	local sounds = {}
	state.setup = function(game)
		game.PlaySound = function(id) sounds[#sounds + 1] = id end
		game.SOUNDKIT = { RAID_WARNING = 8959 }
		game.GameMenuFrame = game.CreateFrame("Frame", "GameMenuFrame")
		game.GameMenuFrame:Hide()
	end
	local game, h = W.New(state)
	return game, h, state, sounds
end

local function banner(h) local b = h.Env().RestedLevelingBanner; return b and b:IsShown() end
local function printed(h, needle)
	for _, l in ipairs(h.Printed()) do if l:find(needle, 1, true) then return true end end
	return false
end

local cases = {}

function cases.camping_in_the_world_warns_with_sound_and_chat()
	local _, h, _, sounds = world({ resting = false, rested = 1000 })
	h.Fire("PLAYER_CAMPING")
	T.ok(banner(h), "banner shown")
	T.eq(h.Env().RestedLevelingBanner.title:GetText(), "Cancel logout, then rest in an inn", "the safety step is the headline")
	T.has(h.Env().RestedLevelingBanner.text:GetText(), "is outside a rest area", "then who, and where")
	T.eq(#sounds, 1, "one sound")
	T.ok(printed(h, "logging out outside"), "chat line")
	h.Fire("LOGOUT_CANCEL")
	T.ok(not banner(h), "moving cancels: banner gone")
	T.clean(h)
end

function cases.no_warning_in_an_inn_or_a_capital()
	local _, h, _, sounds = world({ resting = true, zone = "Orgrimmar" })
	h.Fire("PLAYER_CAMPING")
	h.Fire("PLAYER_QUITING")
	T.ok(not banner(h), "no banner")
	T.eq(#sounds, 0, "no sound")
	T.clean(h)
end

function cases.no_warning_at_max_level_or_already_full()
	local _, h = world({ resting = false, level = 60 })
	h.Fire("PLAYER_CAMPING")
	T.ok(not banner(h), "max level")
	local _, h2 = world({ resting = false, rested = 15000 })
	h2.Fire("PLAYER_CAMPING")
	T.ok(not banner(h2), "already full")
end

function cases.right_click_offers_dismiss_or_disable()
	local _, h = world({ resting = false })
	h.Fire("PLAYER_CAMPING")
	FakeWoW.RunScript(h.Env().RestedLevelingBanner, "OnMouseUp", "RightButton")
	local menu = h.Env().RestedLevelingAlertMenu
	T.ok(menu and menu:IsShown(), "a small menu, not a popup")
	T.ok(banner(h), "the warning stays until a choice")
	T.has(menu.items[2].text:GetText(), "Disable future logout warnings", "names the kind it turns off")
	FakeWoW.RunScript(menu.items[2], "OnClick")
	T.ok(not banner(h), "dismissed")
	T.ok(W.DB(h).alertsOff.logout, "kind turned off")
	T.ok(menu:IsShown() and menu.undo:IsShown(), "says so inline, with Undo")
	FakeWoW.RunScript(menu.undo, "OnClick")
	T.ok(not W.DB(h).alertsOff.logout and banner(h), "Undo turns it back on and brings the warning back")
	FakeWoW.RunScript(h.Env().RestedLevelingBanner, "OnMouseUp", "RightButton")
	FakeWoW.RunScript(menu.items[2], "OnClick")
	h.Fire("PLAYER_CAMPING")
	T.ok(not banner(h), "not shown again")
	h.Slash("RESTEDLEVELING", "alerts logout")
	T.ok(not W.DB(h).alertsOff.logout, "switched back on by command")
	T.clean(h)
end

function cases.dismiss_from_the_menu_keeps_the_kind_on()
	local _, h = world({ resting = false })
	h.Fire("PLAYER_CAMPING")
	FakeWoW.RunScript(h.Env().RestedLevelingBanner, "OnMouseUp", "RightButton")
	FakeWoW.RunScript(h.Env().RestedLevelingAlertMenu.items[1], "OnClick")
	T.ok(not banner(h), "dismissed")
	T.ok(not W.DB(h).alertsOff.logout, "still on")
	T.clean(h)
end

function cases.esc_menu_strip_only_when_not_resting()
	local _, h, state = world({ resting = false })
	local menu = h.Env().GameMenuFrame
	menu:Show()
	FakeWoW.RunScript(menu, "OnShow")
	T.ok(h.Env().RestedLevelingMenuStrip:IsShown(), "strip under the menu")
	state.resting = true
	FakeWoW.RunScript(menu, "OnShow")
	T.ok(not h.Env().RestedLevelingMenuStrip:IsShown(), "hidden while resting")
	T.clean(h)
end

function cases.running_out_says_who_is_next()
	local saved = { chars = { ["N:Le Nette@?"] = alt("Le Nette", 1.5, 2 * D, true) } }
	local _, h, state = world({ saved = saved, rested = 300 })
	state.rested = 0
	h.Fire("PLAYER_XP_UPDATE", "player")
	local shown
	for _, f in ipairs(h.Frames()) do
		local t = f.text and f.text.GetText and (f.text:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		if t and f:IsShown() and t:find("Play Le Nette  ·  1.5 levels banked", 1, true) then shown = true end
	end
	T.ok(shown, "toast: rested used up, play next Le Nette")
	T.clean(h)
end

function cases.alts_filling_up_are_announced_once_and_batched()
	local saved = { chars = {
		["N:A@?"] = alt("Alt One", 1.49, 0, true),
		["N:B@?"] = alt("Alt Two", 1.49, 0, true),
	} }
	local _, h, state = world({ saved = saved })
	W.Advance(h, 24 * H)
	W.Tick(state)
	local toasts = 0
	local text
	for _, f in ipairs(h.Frames()) do
		if f.kicker and f:IsShown() and (f.kicker:GetText() or ""):find("FULLY RESTED", 1, true) then
			toasts, text = toasts + 1, f.text:GetText()
		end
	end
	T.eq(toasts, 1, "one toast for both")
	T.has(text, "Alt One", "names batched")
	T.has(text, "Alt Two", "names batched")
	for _, f in ipairs(h.Frames()) do if f.text and f:IsShown() and f.age then f:Hide() end end
	W.Tick(state)
	for _, f in ipairs(h.Frames()) do
		if f.kicker and f:IsShown() and (f.kicker:GetText() or ""):find("FULLY RESTED", 1, true) then
			error("announced twice")
		end
	end
	T.clean(h)
end

function cases.login_digest_in_chat()
	local saved = { chars = { ["N:Le Nette@?"] = alt("Le Nette", 1.5, 2 * D, true), ["N:B@?"] = alt("Le Dette", 0.5, 0, true) } }
	local _, h, state = world({ saved = saved })
	W.RunTimers(state)
	T.ok(printed(h, "1 full: Le Nette."), "who is full")
	T.ok(printed(h, "Next to fill: Le Dette"), "who fills next")
	T.clean(h)
end

function cases.one_warning_at_a_time_while_logging_out()
	local saved = { chars = { ["N:Le Nette@?"] = alt("Le Nette", 1.5, 2 * D, true) } }
	local _, h, state = world({ saved = saved, rested = 300 })
	h.Fire("PLAYER_CAMPING")
	T.ok(banner(h), "banner up")
	local menu = h.Env().GameMenuFrame
	menu:Show()
	FakeWoW.RunScript(menu, "OnShow")
	T.ok(not h.Env().RestedLevelingMenuStrip:IsShown(), "no Esc strip while the banner is up")
	state.rested = 0
	h.Fire("PLAYER_XP_UPDATE", "player")
	local function toastUp()
		for _, f in ipairs(h.Frames()) do if f.kicker and f:IsShown() and f.timer then return true end end
		return false
	end
	T.ok(not toastUp(), "toast waits behind the banner")
	h.Fire("LOGOUT_CANCEL")
	T.ok(not banner(h), "banner gone")
	T.ok(toastUp(), "the waiting toast shows once the banner is gone")
	T.clean(h)
end

function cases.banner_uses_the_one_button_family()
	local saved = { chars = { ["N:Le Nette@?"] = alt("Le Nette", 1.5, 2 * D, true) } }
	local _, h = world({ saved = saved, resting = false })
	h.Fire("PLAYER_CAMPING")
	local banner = h.Env().RestedLevelingBanner
	T.eq(banner.close.label and banner.close.label:GetText(), "X", "the dismiss is the bronze secondary button, not a yellow X")
	T.eq(banner.altBtn:GetHeight(), 22, "the next character is secondary to the warning")
	T.eq(banner.altBtn.label:GetText(), "View details", "the main window's View details")
	T.has(banner.altText:GetText(), "Next: Le Nette · Full", "a line that says who is next and why")
	T.clean(h)
end

-- The anchors a frame has now: { point, relativeTo, relativePoint, x, y } each.
local function points(f) return f.__points or {} end
-- The anchor named `name`, as { point, relativeTo, relativePoint, x, y } (SetPoint(point, x, y) is relative to the
-- parent's same point).
local function pointOf(f, name)
	for _, pt in ipairs(points(f)) do
		if pt[1] == name then
			if type(pt[2]) == "number" then return { pt[1], f:GetParent(), pt[1], pt[2], pt[3] } end
			return pt
		end
	end
end

-- Andy (ILL-1274): on the first Esc the card was wider than the menu, overlapped its bottom, and Details overhung the
-- card's right edge; once straightened, Details still sat off the row and off the close X's edge.
function cases.esc_strip_lays_out_from_its_own_edges_the_same_on_every_show()
	local saved = { chars = { ["N:Le Nette Bergamotte-Longname@?"] = alt("Le Nette Bergamotte-Longname", 1.5, 2 * D, true) } }
	local _, h, state = world({ saved = saved, resting = false })
	local menu = h.Env().GameMenuFrame
	menu:SetWidth(280)
	menu:Show()
	FakeWoW.RunScript(menu, "OnShow")
	local f = h.Env().RestedLevelingMenuStrip
	T.ok(f:IsShown(), "strip shown")
	local A = state.ns.Alerts
	-- Sized from the menu, hung under it with a gap.
	T.eq(f:GetWidth(), 364, "a little wider than the 280 px menu (280 x 1.3)")
	local top = pointOf(f, "TOP")
	T.ok(top and top[2] == menu and top[3] == "BOTTOM" and top[5] == -A.STRIP_GAP, "TOP under the menu's BOTTOM, with a gap")
	T.eq(#points(f), 1, "one anchor: nothing else pulls it over the menu")
	-- Details: on the card's right edge with the close X's inset, 22 px, top level with the 22 px portrait.
	local btn, close = f.altBtn, f.close
	local bp, cp = pointOf(btn, "TOPRIGHT"), pointOf(close, "TOPRIGHT")
	T.ok(bp and bp[2] == f and bp[3] == "TOPRIGHT", "Details anchored to the card's right edge")
	T.eq(bp[4], -A.INSET, "Details' right edge = card right - inset")
	T.eq(bp[4], cp[4], "the same right inset as the close X")
	T.eq(btn:GetHeight(), 22, "22 px, like the other inline buttons")
	local ap = pointOf(f.alt, "TOPLEFT")
	T.eq(ap[5], bp[5], "same top as the portrait: centred on one row")
	T.eq(f.alt:GetHeight(), btn:GetHeight(), "and the same height")
	-- The Esc card has no View details (the menu is open): the line runs to the card's inset, shortened to fit.
	T.ok(not btn:IsShown(), "no button on the Esc card")
	local tr = pointOf(f.altText, "RIGHT")
	T.ok(tr and tr[2] == f and tr[3] == "RIGHT" and tr[4] == -A.INSET, "text ends at the card's right inset")
	local room = f:GetWidth() - 48 - 22 - 12 - A.INSET
	T.ok(f.altText:GetStringWidth() <= room, "the long line is shortened to fit")
	T.has(f.altText:GetText(), "...", "with an ellipsis")
	-- The first show matches the next: the queued relayout and a second Esc change nothing.
	local function snapshot()
		local out = { f:GetWidth(), f:GetHeight(), f.altText:GetText() }
		for _, fr in ipairs({ f, f.alt, btn, f.altText }) do
			for _, pt in ipairs(points(fr)) do
				for i = 1, 5 do out[#out + 1] = tostring(type(pt[i]) == "table" and (pt[i] == f and "f" or pt[i] == menu and "menu" or "x") or pt[i]) end
			end
		end
		return table.concat(out, "|")
	end
	local first = snapshot()
	W.RunTimers(state)   -- the one-frame-later relayout
	T.eq(snapshot(), first, "relayout after a frame is a no-op once settled")
	menu:Hide()
	menu:Show()
	FakeWoW.RunScript(menu, "OnShow")
	W.RunTimers(state)
	T.eq(snapshot(), first, "a second Esc lays out exactly like the first")
	T.clean(h)
end

function cases.esc_strip_width_stays_between_min_and_max()
	local _, h, state = world({ resting = false })
	local menu = h.Env().GameMenuFrame
	local A = state.ns.Alerts
	for _, case in ipairs({ { 100, A.STRIP_MIN }, { 0, A.STRIP_MIN }, { 600, A.STRIP_MAX } }) do
		menu:SetWidth(case[1])
		menu:Show()
		FakeWoW.RunScript(menu, "OnShow")
		T.eq(h.Env().RestedLevelingMenuStrip:GetWidth(), case[2], "menu " .. case[1] .. " px")
		menu:Hide()
	end
	T.clean(h)
end

-- The logout banner shares the row: same right edge as its close X, and nobody offered when nobody is rested.
function cases.banner_row_shares_the_layout_and_never_offers_an_empty_alt()
	local saved = { chars = { ["N:Le Dette@?"] = alt("Le Dette", 0.01, 5 * 60, true) } }   -- the player is Le Jette
	local _, h, state = world({ saved = saved, resting = false })
	h.Fire("PLAYER_CAMPING")
	local b = h.Env().RestedLevelingBanner
	local bp = pointOf(b.altBtn, "TOPRIGHT")
	T.ok(bp and bp[2] == b and bp[4] == -state.ns.Alerts.INSET, "Details on the banner's right edge, the close X's inset")
	T.eq(pointOf(b.close, "TOPRIGHT")[4], bp[4], "lined up with the close X")
	T.lacks(b.altText:GetText(), "Next:", "no Next: Le Dette, 0.0 banked")
	T.eq(b.altText:GetText(), "Le Dette fills first: full in 9d 22h", "says who fills first and how long (0.01 banked, 5 min resting)")
	T.clean(h)
end

-- Nobody has rest banked: the Esc card and the logout banner name the one that fills first (least time to full), the
-- same as the hero, not rows[1] (sorted by banked levels, then name). Review of ILL-1274.
local function fillsFirstLine(saved, state)
	state = state or {}
	state.saved, state.resting, state.rested = saved, false, 0
	local _, h = world(state)
	h.Fire("PLAYER_CAMPING")
	local bannerLine = h.Env().RestedLevelingBanner.altText:GetText()
	h.Fire("LOGOUT_CANCEL")
	local menu = h.Env().GameMenuFrame
	menu:SetWidth(400)
	menu:Show()
	FakeWoW.RunScript(menu, "OnShow")
	local strip = h.Env().RestedLevelingMenuStrip
	T.ok(strip:IsShown(), "Esc card shown")
	return bannerLine, strip.altText:GetText(), h, state
end

function cases.nothing_banked_alerts_name_who_fills_first_like_the_hero()
	local saved = { chars = {
		["N:Aa Outside@?"] = alt("Aa Outside", 0.0375, 0, false),   -- more banked, but outside: 4x slower
		["N:Zz Resting@?"] = alt("Zz Resting", 0.0126, 0, true),
	} }
	local bannerLine, stripLine, h, state = fillsFirstLine(saved)
	local Wd = state.ns.Words
	local rows = state.ns.Rows({ hideGrey = true })
	T.eq(rows[1].c.full, "Aa Outside", "rows[1] is the one with more banked")
	T.eq(Wd.FillsFirst(rows).c.full, "Zz Resting", "the hero's fills-first is the resting one")
	T.eq(bannerLine, "Zz Resting fills first: full in 9d 21h", "banner: the same alt as the hero")
	T.eq(stripLine, "Zz Resting fills first: full in 9d 21h", "Esc card: the same alt as the hero")
	T.clean(h)
end

function cases.nothing_banked_ties_at_zero_still_pick_the_resting_one()
	local saved = { chars = {
		["N:Aa Outside@?"] = alt("Aa Outside", 0, 0, false),
		["N:Zz Resting@?"] = alt("Zz Resting", 0, 0, true),
	} }
	local bannerLine, stripLine, h = fillsFirstLine(saved)
	T.eq(bannerLine, "Zz Resting fills first: full in 10d", "banner: 0.0 each, the inn fills first")
	T.eq(stripLine, "Zz Resting fills first: full in 10d", "Esc card: the same")
	T.clean(h)
end

-- Council r3: the Esc card has its own shape, so it never reads as a second banner.
function cases.esc_card_has_its_own_shape()
	local _, h = world({ resting = false, saved = { chars = { ["N:Le Nette@?"] = alt("Le Nette", 1.5, 2 * D, true) } } })
	FakeWoW.RunScript(h.Env().GameMenuFrame, "OnShow")
	local strip = h.Env().RestedLevelingMenuStrip
	T.ok(strip:IsShown(), "shown under the menu")
	T.eq(strip.tag:GetText(), "ESC MENU", "tagged")
	T.ok(not strip.altBtn:IsShown(), "no View details button: the menu is open")
	T.ok(not strip.who:IsShown(), "one instruction, not the banner's three lines")
	T.has(strip.altText:GetText(), "Le Nette", "still names who is next")
	T.clean(h)
end

return cases
