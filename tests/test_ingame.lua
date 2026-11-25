-- Andy's first in-game run of v1 (ILL-1274): button labels on hover, real-life time to full, the nothing-banked
-- hero, and professions listed once. Andy's setup: on Le Nette (level 1, out in the world), with
-- Le Jette (level 46 gnome warrior) resting at the Feathermoon Stronghold inn with nothing banked yet.

local W = dofile("tests/world.lua")
local H, D = 3600, 86400

local function strip(s) return (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end

-- extra(game, state): more of the fake game for one test (skills, atlases).
local function andy(extra, chars)
	local saved = { chars = chars or {
		["N:Le Jette@?"] = { full = "Le Jette", class = "WARRIOR", race = "Gnome", sex = 3, level = 46, xpMax = 80000,
			rested = 400, resting = true, restKind = "inn", zone = "Feralas", subzone = "Feathermoon Stronghold",
			t = W.NOW - 5 * 60, profs = "Blacksmithing 185, Blacksmithing 185, Mining 201, Mining 201, Cooking 216" },
	} }
	local state = { first = "Le", surname = "Nette", class = "MAGE", level = 1, rested = 0, xpMax = 400, resting = false,
		saved = saved, setup = function(game, h, st)
			game.UISpecialFrames = {}
			game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
			game.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
			st.portraits = {}
			game.SetPortraitTexture = function(tex, unit) st.portraits[#st.portraits + 1] = { tex = tex, unit = unit } end
			if extra then extra(game, h, st) end
		end }
	local _, h = W.New(state)
	return h, state
end

local cases = {}

-- 1. Every button keeps its label readable on hover: the label is on a child frame, which the game draws above the
-- button's own HIGHLIGHT layer (where the hover face is).
function cases.button_labels_draw_above_the_hover_face()
	local h = andy()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	local buttons = { main.compactBtn, main.hero.open, main.roster.guide.link, main.rlClose }
	for i, b in ipairs(buttons) do
		T.eq(b.hl:GetDrawLayer(), "HIGHLIGHT", "button " .. i .. ": hover face on the highlight layer")
		T.ok(b.hl:GetParent() == b, "button " .. i .. ": hover face belongs to the button")
		local text = b.label or b.x
		local holder = text:GetParent()
		T.ok(holder ~= b, "button " .. i .. ": label not on the button itself")
		T.ok(holder:GetParent() == b, "button " .. i .. ": label on a child of the button")
		T.ok(holder:GetFrameLevel() > b:GetFrameLevel(), "button " .. i .. ": label frame above the button")
	end
	T.eq(main.roster.guide.link.label:GetText(), "Link account...", "label text kept")
	T.clean(h)
end

-- 4. The card's rest line ends with the real-life time to full and explains the maths on hover.
function cases.card_rest_line_shows_real_time_and_explains_itself()
	local h = andy()
	h.Slash("RESTEDLEVELING", "")
	FakeWoW.RunScript(h.Env().RestedLevelingMain.hero, "OnClick")
	local card = h.Env().RestedLevelingCard
	T.has(card.why:GetText(), "Resting at Feathermoon Stronghold inn. Nothing banked yet. Full in 9d 23h (", "real-life time to full")
	local tip = h.Env().GameTooltip
	local lines = {}
	tip.AddLine = function(_, text) lines[#lines + 1] = text end
	tip.SetOwner = function() end
	tip.Show = function() end
	FakeWoW.RunScript(card.whyHit, "OnEnter")
	local all = table.concat(lines, "\n")
	T.has(all, "Rest fills 5% of a level every 8h in an inn or city; full is 1.5 levels.", "the maths")
	T.has(all, "10 days in an inn, 40 days outside", "what that means from empty")
	T.clean(h)
end

-- 5. Nothing banked anywhere: no "PLAY NEXT", say who fills first and when; "hearth" only about Le Nette.
function cases.hero_does_not_send_you_to_an_empty_alt()
	local h = andy()
	h.Slash("RESTEDLEVELING", "")
	local hero = h.Env().RestedLevelingMain.hero
	T.eq(hero.kicker:GetText(), "NOBODY RESTED YET", "no play next")
	T.lacks(hero.kicker:GetText(), "PLAY NEXT", "kicker")
	T.eq(strip(hero.name:GetText()), "Le Jette", "who fills first")
	T.eq(hero.why:GetText(), "Nobody is rested yet. Le Jette fills first: Full in 9d 23h.", "says so")
	T.eq(hero.stat:GetText(), "9d 23h", "the big figure is the real-life wait")
	T.eq(hero.statSub:GetText(), "until full", "labelled")
	T.has(hero.ahead:GetText(), "full ", "with the clock time")
	local cta = strip(hero.cta:GetText())
	T.eq(cta, "Nobody to switch to yet. When you stop, log Le Nette out in an inn.", "the action is about Le Nette")
	T.lacks(cta, "play Le Jette", "not sent to Le Jette")
	T.clean(h)
end

function cases.hero_with_rest_names_the_current_character_in_first_hearth()
	local h = andy(nil, {
		["N:Le Jette@?"] = { full = "Le Jette", class = "WARRIOR", race = "Gnome", sex = 3, level = 46, xpMax = 80000,
			rested = 60000, resting = true, restKind = "inn", zone = "Feralas", subzone = "Feathermoon Stronghold", t = W.NOW - D },
	})
	h.Slash("RESTEDLEVELING", "")
	local hero = h.Env().RestedLevelingMain.hero
	T.eq(hero.kicker:GetText(), "#1  ·  PLAY NEXT", "rest banked: play next")
	T.eq(strip(hero.cta:GetText()), "First, take Le Nette to an inn (hearth). Then play Le Jette.", "hearth is about Le Nette")
	T.has(hero.why:GetText(), "Full in ", "real-life time to full")
	T.clean(h)
end

-- 6. Professions once each, highest rank kept, from the client and from saved data.
function cases.professions_are_listed_once()
	local h = andy(function(game)
		local lines = {
			{ name = "Professions", isHeader = true },
			{ name = "Blacksmithing", rank = 185, skillLineCategoryID = 11 },
			{ name = "Blacksmithing", rank = 185, skillLineCategoryID = 11 },
			{ name = "Mining", rank = 190, skillLineCategoryID = 11 },
			{ name = "Mining", rank = 201, skillLineCategoryID = 11 },
			{ name = "Cooking", rank = 216, skillLineCategoryID = 9 },
		}
		game.C_SkillInfo = { GetNumSkillLines = function() return #lines end, GetSkillLineInfo = function(i) return lines[i] end }
	end)
	local me = W.Char(h, "Le Nette")
	T.eq(me.profs, "Blacksmithing 185, Mining 201, Cooking 216", "each profession once, highest rank")
	T.eq(W.Char(h, "Le Jette").profs, "Blacksmithing 185, Mining 201, Cooking 216", "saved duplicates cleaned on login")
	T.clean(h)
end

return cases
