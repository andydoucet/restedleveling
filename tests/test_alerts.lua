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
	T.eq(h.Env().RestedLevelingBanner.title:GetText(), "Cancel the logout first", "the safety step is the headline")
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
	T.eq(banner.altBtn.label:GetText(), "Details", "a small Details button")
	T.has(banner.altText:GetText(), "Next: Le Nette  ·  Full", "a line that says who is next and why")
	T.clean(h)
end

return cases
