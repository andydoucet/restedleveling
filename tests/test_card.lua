-- The character card in the fake client: clicking the hero opens it, the character says its line, tidbits show.

local W = dofile("tests/world.lua")
local H, D = 3600, 86400

local function alt(full, class, levels, ago, resting)
	return { full = full, class = class, race = "Orc", sex = 2, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = resting, restKind = resting and "inn" or "outside",
		zone = "Durotar", subzone = "Razor Hill", t = W.NOW - ago, history = { { W.NOW - 2 * H, 0.4 }, { W.NOW - H, 0.5 } } }
end

local function world()
	local saved = { chars = {
		["N:Le Nette@?"] = alt("Le Nette", "MAGE", 1.5, 2 * D, true),
		["N:Le Dette@?"] = alt("Le Dette", "WARLOCK", 0.5, H, true),
		["N:Amdo Moto@?"] = alt("Amdo Moto", "ROGUE", 0.3, H, false),
	} }
	local state = { saved = saved, setup = function(game)
		game.UISpecialFrames = {}
		game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
		game.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
			ROGUE = { r = 1, g = 0.96, b = 0.41 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
		game.SetPortraitTexture = function() end
	end }
	local _, h = W.New(state)
	return h, state
end

local cases = {}

function cases.character_card_talks()
	local h = world()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	FakeWoW.RunScript(main.hero, "OnClick")
	local card = h.Env().RestedLevelingCard
	T.ok(card and card:IsShown(), "card open")
	FakeWoW.RunScript(card.typer, "OnUpdate", 10)
	local said = card.stage.bubble.text:GetText()
	T.ok(said and #said > 10, "speech line: " .. tostring(said))
	T.ok(card.tiles[1]:IsShown(), "tidbits")
	T.clean(h)
end

function cases.the_number_one_speaks_in_the_main_window()
	local h = world()
	h.Slash("RESTEDLEVELING", "")
	local hero = h.Env().RestedLevelingMain.hero
	T.ok(hero.say:IsShown(), "a speech bubble beside the name")
	T.ok(#(hero.sayText:GetText() or "") > 3, "its line: " .. tostring(hero.sayText:GetText()))
	T.clean(h)
end

function cases.card_has_no_timeline_and_wraps_without_orphans()
	local h = world()
	h.Slash("RESTEDLEVELING", "")
	FakeWoW.RunScript(h.Env().RestedLevelingMain.roster.rows[1], "OnClick")
	local card = h.Env().RestedLevelingCard
	T.ok(card.history == nil, "no 48h chart: the timeline is v1.1")
	T.ok(h.Env().RestedLevelingMain.roster.rows[1].sel[1]:IsShown(), "the row marks the open card at once")
	-- every character's card (the fixture's longest strings included): one balanced bubble width, and in every
	-- wrapped block the last line is at least half as wide as the widest line (no "Twice." alone)
	local main = h.Env().RestedLevelingMain
	for i = 0, #main.roster.rows do
		FakeWoW.RunScript(i == 0 and main.hero or main.roster.rows[i], "OnClick")
		local b = card.stage.bubble
		T.ok(b.hook:GetWidth() <= 196 and b.hook:GetWidth() == b.text:GetWidth(), "one balanced bubble width")
		for _, fs in ipairs({ b.hook, b.text, card.why }) do
			local w, field = fs:GetUnboundedStringWidth(), fs:GetWidth()
			if w > field then
				local lines = math.ceil(w / field)
				local widest = math.min(field, w / lines + 14)
				T.ok(w - (lines - 1) * widest >= widest / 2, "no orphan: " .. tostring(fs:GetText()))
			end
		end
	end
	T.clean(h)
end

function cases.card_line_rotates_and_never_repeats_the_hero()
	local h = world()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	local hero = main.hero.sayText:GetText()
	local seen = {}
	for _ = 1, 2 do
		FakeWoW.RunScript(main.hero, "OnClick")
		local card = h.Env().RestedLevelingCard
		FakeWoW.RunScript(card.typer, "OnUpdate", 10)
		local said = card.stage.bubble.hook:GetText()
		T.ok(said ~= hero, "not the hero's line: " .. tostring(said))
		seen[#seen + 1] = said
	end
	T.ok(seen[1] ~= seen[2], "a different line on the next open")
	T.clean(h)
end

return cases
