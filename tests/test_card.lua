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
-- The height a string's lines need, whatever height it is held to (a held string measures only what fits).
local function need(fs)
	local held = fs:GetHeight()
	fs:SetHeight(0)
	local h = fs:GetStringHeight()
	fs:SetHeight(held)
	return h
end
local function fits(Card, s, what)
	local b = s.bubble
	for _, fs in ipairs({ b.hook, b.text }) do
		local shown = fs:GetText()
		fs:SetText(b.line and (fs == b.hook and b.line[1] or b.line[2]) or shown)
		T.ok(fs:GetHeight() >= need(fs), what .. ": every line of " .. tostring(fs:GetText()) .. " has room")
		T.ok(fs:GetWidth() <= Card.BUBBLE_W, what .. ": inside the bubble width")
		local w, lines = fs:GetWidth(), need(fs)
		fs:SetWidth(Card.BUBBLE_W)
		T.eq(lines, need(fs), what .. ": no more lines than at the full width (no orphan): " .. tostring(fs:GetText()))
		fs:SetWidth(w)
		fs:SetText(shown)
	end
	T.ok(Card.BubbleRight(s) <= Card.FIG_LEFT - Card.GAP, what .. ": the bubble and its tail end 12 px left of the figure")
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
	T.ok(b.hook:GetHeight() >= need(b.hook), "room for every line of the hook (was one line: 'Give me 9 days 2...')")
	T.ok(b.text:GetHeight() >= need(b.text), "and of the follow-up (was 'Then I'm full at Thunder...')")
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

-- Andy's v1.1.1 card: "Then I'm full at / Feathermoon Stronghold..." The first fit held the text to two lines; when the
-- wider font settled a frame later, the re-fit measured the held string (two lines) and kept it cut.
function cases.a_refit_under_a_wider_font_lets_the_old_height_go()
	local h, state, f = card(1)
	local Card, b = state.ns.Card, f.stage.bubble
	Card.FitBubble(f.stage, "Give me 9 days 14 hours.", "Then I'm full at Feathermoon Stronghold inn.")
	b.text:SetText(b.line[2])   -- typed out
	local before = need(b.text)
	FakeWoW.fontScale = 1.35
	Card.FitBubble(f.stage)   -- the next frame's re-measure
	b.text:SetText(b.line[2])
	T.ok(need(b.text) > before, "the wider font takes another line")
	T.ok(b.text:GetHeight() >= need(b.text), "and the string is given it: 'inn.' is not cut")
	fits(Card, f.stage, "after the re-fit")
	FakeWoW.fontScale = nil
	T.clean(h)
end

-- Andy (ILL-1279 round 2): the bubble ran into her head. Two columns: the bubble left, the figure right, the bubble
-- (tail included) ending Card.GAP px left of the figure column, on your own card (live model) and anyone else's.
function cases.the_bubble_stays_left_of_the_figure_on_every_card()
	local h, state = world()
	h.Slash("RESTEDLEVELING", "")
	local Card, L = state.ns.Card, state.ns.Lines
	local f = Card.Create()
	local s = f.stage
	-- the live model's frame is the figure column, cut above the name plate: waist up
	local pts = {}
	for _, p in ipairs(s.model.__points) do pts[p[1]] = p end
	T.ok(pts.BOTTOMLEFT and pts.BOTTOMLEFT[4] == Card.FIG_LEFT, "the model starts at the figure column")
	T.ok(pts.TOPRIGHT, "and runs to the stage's right edge")
	T.ok(pts.BOTTOMLEFT[5] >= 40, "its foot where the portrait stands: the model is cut at the waist, not the feet")
	-- the disc's ring starts at the figure column too
	local fig = s.figure.__points[#s.figure.__points]
	T.ok(416 / 2 + fig[2] - s.figure:GetWidth() * 1.1 / 2 >= Card.FIG_LEFT, "the portrait's ring inside the figure column")
	-- the card's buttons sit in the bubble's column
	T.ok(Card.BUBBLE_LEFT + state.ns.Look.CONTROLS_W <= Card.FIG_LEFT - Card.GAP, "Save my look in the left column")
	FakeWoW.fontScale = 1.35
	local long = { time = "9 days 23 hours", levels = "1.5 levels", pct = "93%", left = "9 days 23 hours",
		clock = "Fri 4 Dec, 03:12", place = "Feathermoon Stronghold inn", zone = "Stranglethorn Vale", level = "60" }
	local function fill(t) return (t:gsub("{(%w+)}", long)) end
	for _, key in ipairs({ state.ns.MyKey(), "N:Amdo Moto@?" }) do
		Card.Show(key)
		local live = key == state.ns.MyKey()
		T.eq(s.model:IsShown(), live, key .. ": the live model only for the character you are on")
		for state_, bank in pairs(L.BANK) do
			for i, pair in ipairs(bank) do
				Card.FitBubble(s, fill(pair[1]), fill(pair[2]))
				fits(Card, s, key .. " " .. state_ .. " " .. i)
			end
		end
	end
	FakeWoW.fontScale = nil
	T.clean(h)
end

function cases.the_live_model_is_framed_waist_up_whenever_it_loads()
	local h, state = world()
	h.Slash("RESTEDLEVELING", "")
	local Card = state.ns.Card
	local f = Card.Create()
	local calls = {}
	f.stage.model.SetPortraitZoom = function(_, z) calls[#calls + 1] = "zoom:" .. z end
	f.stage.model.SetCamDistanceScale = function(_, d) calls[#calls + 1] = "dist:" .. d end
	Card.Show(state.ns.MyKey())
	T.eq(table.concat(calls, ","), "dist:1,zoom:" .. Card.MODEL_ZOOM, "framed on show")
	FakeWoW.RunScript(f.stage.model, "OnModelLoaded")
	T.eq(#calls, 4, "and again once the model has loaded (loading resets the camera)")
	T.ok(Card.MODEL_ZOOM > 0 and Card.MODEL_ZOOM < 0.6, "between the full body and Blizzard's head-and-shoulders")
	T.clean(h)
end

-- The hero's action line above NOW PLAYING was cut at the button under a wider font ("Then pl"). It fits whole: a
-- smaller size, or two balanced lines; never "..." and never under the button.
function cases.the_hero_action_line_is_never_cut()
	local h, state = world()
	h.Slash("RESTEDLEVELING", "")
	local Hero, hero = state.ns.Hero, h.Env().RestedLevelingMain.hero
	T.ok(hero.steps[1].text:GetText() and #hero.steps[1].text:GetText() > 10, "the plan's first step")
	local lines = {
		"First: log |cffc69b6dLe Jedde|r out here. Then: play |cffc69b6dLe Jette|r.",
		"First: hearth |cffc69b6dColonol Sunders|r to an inn. Then: play |cff3fc7ebAmdo Moto|r.",
		"Nobody to switch to yet. When you stop, log |cffc69b6dColonol Sunders|r out in an inn.",
	}
	for _, scale in ipairs({ 1, 1.35, 1.6 }) do
		FakeWoW.fontScale, FakeWoW.sizeAware = scale, true
		for _, line in ipairs(lines) do
			local size, n = Hero.FitAction(hero, line)
			local cta, what = hero.cta, ("x%.2f %s"):format(scale, line)
			T.eq(cta:GetText(), line, what .. ": the whole line")
			T.ok(cta:GetWidth() <= hero.ctaW, what .. ": short of the button")
			if n == 1 then
				T.ok(cta:GetUnboundedStringWidth() <= hero.ctaW, what .. ": one line that fits")
			else
				T.ok(cta.__wrap, what .. ": wraps on words")
				T.ok(need(cta) <= 2 * 14, what .. ": two lines at most, inside the 41 px bar")
				T.eq(size, Hero.ACTION_SIZES[#Hero.ACTION_SIZES], what .. ": only after the smaller sizes")
			end
		end
	end
	FakeWoW.fontScale, FakeWoW.sizeAware = nil, nil
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

-- Council r2: one place, one tile. Hearth and the logout place merge when they name the same town.
function cases.hearth_and_logout_place_merge_when_they_match()
	local _, _, state = W.New({})
	local Tb = state.ns.Tidbits
	local function labels(c)
		local out = {}
		for _, t in ipairs(Tb.List(c, W.NOW)) do out[#out + 1] = t[1] .. "=" .. t[2] end
		return table.concat(out, "|")
	end
	T.has(labels({ bind = "Thunder Bluff", zone = "Thunder Bluff" }), "Hearth · logged out=Thunder Bluff", "merged")
	T.lacks(labels({ bind = "Thunder Bluff", zone = "Thunder Bluff" }), "Logged out in", "not twice")
	local apart = labels({ bind = "Goldshire", zone = "Elwynn Forest", subzone = "Northshire" })
	T.has(apart, "Hearth=Goldshire", "different places: the hearth")
	T.has(apart, "Logged out in=Northshire, Elwynn Forest", "and where it logged out")
end

return cases
