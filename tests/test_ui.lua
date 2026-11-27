-- UI smoke tests in the fake client: every window builds and fills using only widget methods the real client has
-- (the fake rejects any other), and the play-next order reaches the screen.

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

function cases.main_window_shows_the_play_next_order()
	local h = world()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	T.ok(main and main:IsShown(), "window open")
	T.eq(main.hero.name:GetText():gsub("|c%x+", ""):gsub("|r", ""), "Le Nette", "hero is the full one")
	T.eq(main.hero.why:GetText(), "Full since 2d ago · more rest is wasted.", "hero says why, in real time")
	local first = main.roster.rows[1].name:GetText():gsub("|c%x+", ""):gsub("|r", "")
	T.eq(first, "Le Dette", "then the resting one")
	T.eq(main.roster.rows[2].chip.text:GetText(), "NOT RESTING", "the outside one says not resting")
	T.eq(main.roster.rows[2].time:GetText(), "~20%  ·  Full in 31d 23h", "its real-life time to full, slow outside (no clock time past two days)")
	T.eq(main.hero.acct:GetText(), "", "no account tag for this account's own characters")
	T.has(main.current.name:GetText(), "Le Jette", "current character strip")
	T.clean(h)
end

function cases.compact_mode_shows_a_pip_per_character()
	local h = world()
	h.Slash("RESTEDLEVELING", "")
	FakeWoW.RunScript(h.Env().RestedLevelingMain.compactBtn, "OnClick")
	local compact = h.Env().RestedLevelingCompact
	T.ok(compact:IsShown(), "compact bar shown")
	T.ok(not h.Env().RestedLevelingMain:IsShown(), "window hidden")
	T.ok(compact.pips[1]:IsShown() and compact.pips[3]:IsShown(), "a pip per character")
	T.ok(W.DB(h).opts.compact, "remembered")
	T.clean(h)
end

function cases.no_text_under_12_px_and_every_text_colour_reads()
	local h = world()
	FakeWoW.fontStrings = {}
	h.Slash("RESTEDLEVELING", "")
	FakeWoW.RunScript(h.Env().RestedLevelingMain.hero, "OnClick")
	local n = 0
	for _, fs in ipairs(FakeWoW.fontStrings) do
		if fs.__size then
			n = n + 1
			T.ok(fs.__size >= 12, ("text at %s px: %s"):format(fs.__size, tostring(fs.__text)))
		end
	end
	T.ok(n > 50, "checked the main window and the card")
	-- contrast of every text token against the darkest and lightest panels we draw text on (WCAG 4.5:1)
	local function lum(r, g, b)
		local function c(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
		return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b)
	end
	local tokens = { CREAM = { 0.92, 0.87, 0.80 }, SECOND = { 0.90, 0.84, 0.76 }, MUTED = { 0.81, 0.76, 0.66 }, GOLD = { 0.84, 0.71, 0.42 } }
	for name, c in pairs(tokens) do
		for _, bg in ipairs({ { 25 / 255, 21 / 255, 17 / 255 }, { 21 / 255, 16 / 255, 11 / 255 }, { 28 / 255, 23 / 255, 18 / 255 } }) do
			local ratio = (lum(c[1], c[2], c[3]) + 0.05) / (lum(bg[1], bg[2], bg[3]) + 0.05)
			T.ok(ratio >= 4.5, ("%s on its panel: %.1f:1"):format(name, ratio))
		end
	end
	T.clean(h)
end

function cases.one_button_family_and_quiet_rows()
	local h = world()
	h.Slash("RESTEDLEVELING", "")
	local row = h.Env().RestedLevelingMain.roster.rows[1]
	T.eq(row.chip:GetHeight(), 20, "chips are 20 px")
	T.eq(row.stripe:GetWidth(), 5, "a 5 px state rail")
	T.ok(row.pips == nil, "no moon meter in the rows (it is on the card and in the tooltip)")
	T.clean(h)
end

return cases
