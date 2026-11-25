-- The character card in the fake client: clicking the hero opens it, the character says its line, tidbits show.

local W = dofile("tests/world.lua")
local H, D = 3600, 86400

local function alt(full, class, levels, ago, resting)
	return { full = full, class = class, race = "Orc", sex = 2, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = resting, restKind = resting and "inn" or "outside",
		zone = "Durotar", subzone = "Razor Hill", t = W.NOW - ago, history = { { W.NOW - 2 * H, 0.4 }, { W.NOW - H, 0.5 } } }
end

local function world()
	FakeWoW.fontScale, FakeWoW.sizeAware = nil, nil   -- never inherit a wider font from a test that failed
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
	-- every character's card (the fixture's longest strings included): one bubble around both blocks, and in every
	-- wrapped block the last line is at least half as wide as the widest line (no "Twice." alone)
	local main = h.Env().RestedLevelingMain
	for i = 0, #main.roster.rows do
		FakeWoW.RunScript(i == 0 and main.hero or main.roster.rows[i], "OnClick")
		local b = card.stage.bubble
		T.ok(b.hook:GetWidth() <= 196 and b.text:GetWidth() <= 196, "each block balanced within the bubble width")
		T.eq(b:GetWidth(), math.max(b.hook:GetWidth(), b.text:GetWidth()) + 24, "one bubble around both")
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

-- The speech bubble never truncates (Andy, ILL-1276: "Give me 9 days 2..." / "Then I'm full at Thunder..." under
-- ElvUI's wider font). It wraps, grows down the stage, drops one font step only if it would reach the note.
local function card(scale)
	local h, state = world()
	h.Slash("RESTEDLEVELING", "")
	state.ns.Card.Show("N:Amdo Moto@?")   -- offline: the note under the bubble takes stage room
	local f = h.Env().RestedLevelingCard
	FakeWoW.fontScale = scale
	return h, state, f
end
local function fits(Card, s, what)
	local b = s.bubble
	for _, fs in ipairs({ b.hook, b.text }) do
		local shown = fs:GetText()
		fs:SetText(b.line and (fs == b.hook and b.line[1] or b.line[2]) or shown)
		T.ok(fs:GetHeight() >= fs:GetStringHeight(), what .. ": every line of " .. tostring(fs:GetText()) .. " has room")
		T.ok(fs:GetWidth() <= Card.BUBBLE_W, what .. ": inside the bubble width")
		local w, lines = fs:GetWidth(), fs:GetStringHeight()
		fs:SetWidth(Card.BUBBLE_W)
		T.eq(lines, fs:GetStringHeight(), what .. ": no more lines than at the full width (no orphan): " .. tostring(fs:GetText()))
		fs:SetWidth(w)
		fs:SetText(shown)
	end
	T.ok(10 + b.hook:GetHeight() + 4 + b.text:GetHeight() + 10 <= Card.BubbleRoom(s) + 4 or b.size == #Card.BUBBLE_SIZES,
		what .. ": the bubble stays above the note")
	T.lacks((b.hook:GetText() or "") .. (b.text:GetText() or ""), "...", what .. ": never an ellipsis")
	T.ok(b:GetWidth() >= math.max(b.hook:GetWidth(), b.text:GetWidth()) + 24, what .. ": the bubble holds both blocks across")
	T.ok(b:GetHeight() >= 10 + b.hook:GetHeight() + 4 + b.text:GetHeight() + 10 - 0.5, what .. ": and down")
end

function cases.bubble_wraps_andys_line_under_a_wider_font()
	local h, state = world()
	state.ns.Lines.Parts = function() return "Give me 9 days 23 hours.", "Then I'm full at Thunder Bluff inn." end
	h.Slash("RESTEDLEVELING", "")
	FakeWoW.sizeAware = true   -- the hook is 17 px: wider than the 13 px facts
	state.ns.Card.Show("N:Amdo Moto@?")   -- measured with the font the card opened with
	local f = h.Env().RestedLevelingCard
	FakeWoW.fontScale = 1.35   -- then ElvUI's wider font settles, a frame later
	W.RunTimers(state)
	FakeWoW.RunScript(f.typer, "OnUpdate", 10)   -- typed out
	local b = f.stage.bubble
	T.eq(b.hook:GetText(), "Give me 9 days 23 hours.", "the whole hook")
	T.eq(b.text:GetText(), "Then I'm full at Thunder Bluff inn.", "the whole follow-up")
	T.ok(b.hook:GetHeight() >= b.hook:GetStringHeight(), "room for every line of the hook (was one line: 'Give me 9 days 2...')")
	T.ok(b.text:GetHeight() >= b.text:GetStringHeight(), "and of the follow-up (was 'Then I'm full at Thunder...')")
	T.ok(b.hook:GetHeight() >= 28, "the hook took a second line instead of '...'")
	T.ok(b.hook:GetWidth() < state.ns.Card.BUBBLE_W, "balanced lines, not one long and an orphan 'hours.'")
	fits(state.ns.Card, f.stage, "Andy's line")
	FakeWoW.fontScale, FakeWoW.sizeAware = nil, nil
	T.clean(h)
end

function cases.bubble_never_adds_a_line_for_long_words()
	local h, state, f = card(1.35)
	local Card = state.ns.Card
	Card.FitBubble(f.stage, "Comfy here.", "Feathermoon Stronghold inn suits me.")
	fits(Card, f.stage, "Le Jette's line")
	T.clean(h)
end

function cases.bubble_fits_every_line_in_the_bank()
	local h, state, f = card(1.35)
	local Card, L = state.ns.Card, state.ns.Lines
	local long = { time = "9 days 23 hours", levels = "1.5 levels", pct = "93%", left = "9 days 23 hours",
		clock = "Fri 4 Dec, 03:12", place = "Feathermoon Stronghold inn", zone = "Stranglethorn Vale", level = "60" }
	local function fill(t) return (t:gsub("{(%w+)}", long)) end
	local n = 0
	for state_, bank in pairs(L.BANK) do
		for i, pair in ipairs(bank) do
			Card.FitBubble(f.stage, fill(pair[1]), fill(pair[2]))
			fits(Card, f.stage, state_ .. " " .. i)
			n = n + 1
		end
	end
	for class, pool in pairs(L.CLASS) do
		for i, hook in ipairs(pool) do
			Card.FitBubble(f.stage, hook, fill("Then I'm full at {place}."))
			fits(Card, f.stage, class .. " " .. i)
			n = n + 1
		end
	end
	T.ok(n > 40, "every bank line checked")
	FakeWoW.fontScale = nil
	T.clean(h)
end

function cases.bubble_drops_one_font_step_only_when_it_must()
	local h, state, f = card(1)
	local Card = state.ns.Card
	FakeWoW.sizeAware = true
	Card.FitBubble(f.stage, "Give me 9 days 23 hours.", "Then I'm full at Thunder Bluff inn.")
	T.eq(f.stage.bubble.size, 1, "Andy's line fits at the normal size")
	FakeWoW.fontScale = 1.35
	Card.FitBubble(f.stage, "Give me 9 days 23 hours.", "Then I'm full at Thunder Bluff inn.")
	T.eq(f.stage.bubble.size, 1, "and under the wider font")
	local hook = "Polymorphed the innkeeper's cat twice and the innkeeper's dog once, and it is not even noon."
	Card.FitBubble(f.stage, hook, "Out here in Stranglethorn Vale I fill four times slower than in any inn at all.")
	T.eq(f.stage.bubble.size, 2, "a much longer line drops one step")
	fits(Card, f.stage, "long line, one step down")
	FakeWoW.sizeAware, FakeWoW.fontScale = nil, nil
	T.clean(h)
end

return cases
