-- Rested Leveling in a fake game: login, snapshots, logout keeping the last good reading, level-up and /reload.

local W = dofile("tests/world.lua")
local H = 3600

local cases = {}

function cases.logging_in_records_the_character_by_full_name()
	local _, h = W.New({ realm = "Forever" })
	local c, n = W.Char(h, "Le Jette")
	T.eq(n, 1, "one record")
	T.eq(c.level, 30, "level")
	T.eq(c.surname, "Jette", "surname")
	T.eq(c.restKind, "outside", "not resting")
	T.ok(c.account and #c.account == 6, "account id")
	T.clean(h)
end

function cases.guid_key_when_the_game_gives_one()
	local _, h = W.New({ guid = "Player-5-0001" })
	T.ok(W.DB(h).chars["G:Player-5-0001"], "keyed by guid")
	T.clean(h)
end

function cases.secret_realm_is_never_used()
	local _, h = W.New({ secretRealm = true, saved = { realm = "Forever" } })
	T.ok(W.DB(h).chars["N:Le Jette@Forever"], "last realm seen")
	T.clean(h)
end

function cases.logout_keeps_the_last_good_reading()
	local _, h, state = W.New({ resting = true, zone = "Stormwind City", rested = 4000 })
	state.loggingOut = true   -- the game has cleared XP by PLAYER_LOGOUT
	W.Advance(h, 30)
	h.Fire("PLAYER_LOGOUT")
	local c = W.Char(h, "Le Jette")
	T.eq(c.rested, 4000, "rested kept")
	T.eq(c.resting, true, "resting kept")
	T.eq(c.restKind, "city", "in a capital")
	T.eq(c.online, false, "offline from now")
	T.eq(c.t, W.NOW + 30, "time moved")
	T.clean(h)
end

function cases.camping_takes_a_snapshot()
	local _, h, state = W.New({ resting = false })
	state.resting, state.rested = true, 2500
	h.Fire("PLAYER_CAMPING")
	local c = W.Char(h, "Le Jette")
	T.eq(c.rested, 2500, "fresh rested")
	T.eq(c.restKind, "inn", "now in an inn")
	T.clean(h)
end

function cases.sleeping_bag_counts_as_resting_but_its_leftover_buff_does_not()
	local _, h = W.New({ bagBuff = 1800 })
	T.eq(W.Char(h, "Le Jette").restKind, "bag", "on the bag")
	local _, h2 = W.New({ bagBuff = 7100, bagApplied = 600 })
	T.eq(W.Char(h2, "Le Jette").restKind, "outside", "walked away from the bag")
end

function cases.level_up_and_reload_survive()
	local _, h, state = W.New({ level = 30, rested = 3000 })
	h.Fire("PLAYER_LEVEL_UP", 31)
	h.Fire("PLAYER_XP_UPDATE", "player")   -- UnitLevel still says 30 for a moment
	T.eq(W.Char(h, "Le Jette").level, 31, "level from the event")
	state.level, state.xpMax = 31, 11000
	h.Fire("PLAYER_LOGOUT")
	-- /reload: a fresh Lua state reading the same saved table.
	local saved = W.DB(h)
	local _, h2 = W.New({ level = 31, xpMax = 11000, rested = 3000, saved = saved, now = W.NOW + 5 })
	local c, n = W.Char(h2, "Le Jette")
	T.eq(n, 1, "still one record")
	T.eq(c.level, 31, "level kept")
	T.clean(h2)
end

function cases.hitting_the_level_cap_is_recorded_even_with_no_xp_bar()
	local _, h, state = W.New({ level = 59, xpMax = 10000, rested = 3000 })
	h.Fire("PLAYER_LEVEL_UP", 60)
	state.xpMax = 0   -- at the cap the game reports no XP bar; UnitLevel may still lag at 59
	h.Fire("PLAYER_XP_UPDATE", "player")
	local c = W.Char(h, "Le Jette")
	T.eq(c.level, 60, "the new level is recorded")
	T.ok(c.atMax, "and it is marked max level, so it is never recommended")
	T.ok(c.xpMax and c.xpMax > 0, "a capped record stays valid for saving and sync")
	state.level = 60
	h.Fire("PLAYER_LOGOUT")
	local _, h2 = W.New({ level = 60, xpMax = 0, saved = W.DB(h), now = W.NOW + 5 })
	T.ok(W.Char(h2, "Le Jette").atMax, "kept across a reload")
	T.clean(h2)
end

function cases.a_partial_or_damaged_saved_file_loads_cleanly()
	local saved = { __ready = true, version = "1", opts = { minimap = "bad", style = "auto" }, account = "not-hex",
		chars = {
			["N:Le Nette@?"] = { full = "Le Nette", class = "MAGE", level = "22", xpMax = "9000", rested = "4500",
				t = tostring(W.NOW - 3600) },   -- numbers saved as strings: repaired, kept
			["N:Broken@?"] = { class = "MAGE" },   -- unusable: dropped
			junk = 5,
		} }
	local _, h = W.New({ saved = saved })
	local d = W.DB(h)
	T.ok(d.__ready == nil, "no load flag is saved")
	T.eq(type(d.opts.minimap), "table", "a damaged minimap setting is reset")
	T.ok(d.account:match("^%x%x%x%x%x%x$"), "account id is 6 hex")
	local c = W.Char(h, "Le Nette")
	T.ok(c and c.xpMax == 9000 and c.level == 22, "usable characters kept, numbers repaired")
	T.ok(d.chars["N:Broken@?"] == nil and d.chars.junk == nil, "unusable entries dropped")
	T.clean(h)
end

function cases.login_calibrates_from_the_real_value()
	-- Saved at 0.1 levels in an inn 16h ago; the game now says 0.25 (projection said 0.2).
	local saved = { chars = { ["N:Le Jette@?"] = { full = "Le Jette", class = "WARRIOR", level = 30, xpMax = 10000,
		rested = 1000, resting = true, t = W.NOW - 16 * H, online = false } } }
	local _, h = W.New({ saved = saved, rested = 2500, resting = true })
	T.ok((W.DB(h).calib.rate or 1) > 1, "rate learnt")
	T.clean(h)
end

function cases.slash_lists_other_characters_and_never_the_current_one()
	local saved = { chars = { ["N:Le Nette@?"] = { full = "Le Nette", class = "MAGE", level = 22, xpMax = 9000,
		rested = 9000 * 1.5, resting = true, t = W.NOW - 9 * H } } }
	local _, h = W.New({ saved = saved })
	h.ClearPrinted()
	h.Slash("RESTEDLEVELING", "list")
	local out = table.concat(h.Printed(), "\n")
	T.has(out, "Le Nette", "alt listed")
	T.has(out, "Full since 9h ago", "full for 9h")
	T.lacks(out, "Le Jette", "current character not in the queue")
	T.clean(h)
end

function cases.slash_target_and_hide()
	local saved = { chars = { ["N:Le Nette@?"] = { full = "Le Nette", class = "MAGE", level = 22, xpMax = 9000,
		rested = 100, resting = true, t = W.NOW } } }
	local _, h = W.New({ saved = saved })
	h.Slash("RESTEDLEVELING", "target 20")
	T.eq(W.DB(h).opts.target, 20, "target saved")
	h.Slash("RESTEDLEVELING", "hide le nette")
	T.ok(W.DB(h).hidden["N:Le Nette@?"], "hidden")
	h.Slash("RESTEDLEVELING", "account #2")
	T.eq(W.DB(h).accountLabels[W.DB(h).account], "#2", "account label")
	T.clean(h)
end

function cases.session_counts_rested_used_and_kills_left()
	local _, h, state = W.New({ rested = 5000 })
	local env = h.Env()
	state.rested = 4800
	h.Fire("PLAYER_XP_UPDATE", "player")
	state.rested = 4600
	h.Fire("PLAYER_XP_UPDATE", "player")
	local s = env.RestedLevelingDB.session
	T.eq(s.used, 400, "used")
	T.eq(#s.bonuses, 2, "two kills seen")
	T.clean(h)
end

return cases
