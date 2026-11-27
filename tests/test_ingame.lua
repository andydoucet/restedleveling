-- Andy's first in-game run of v1 (ILL-1274): button labels on hover, the inline link field, honest offline portraits,
-- nothing-banked hero, and professions listed once. Andy's setup: on Le Nette (level 1, out in the world), with
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
			game.C_Texture = { GetAtlasInfo = function(atlas)
				if atlas:find("^raceicon128%-") or atlas:find("^classicon%-") then return { width = 64, height = 64 } end
			end }
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
	local buttons = { main.compactBtn, main.hero.open, main.roster.guide.link.open, main.roster.guide.link.unlink,
		main.roster.guide.link.ok, main.roster.guide.link.cancel, main.rlClose }
	for i, b in ipairs(buttons) do
		T.eq(b.hl:GetDrawLayer(), "HIGHLIGHT", "button " .. i .. ": hover face on the highlight layer")
		T.ok(b.hl:GetParent() == b, "button " .. i .. ": hover face belongs to the button")
		local text = b.label or b.x
		local holder = text:GetParent()
		T.ok(holder ~= b, "button " .. i .. ": label not on the button itself")
		T.ok(holder:GetParent() == b, "button " .. i .. ": label on a child of the button")
		T.ok(holder:GetFrameLevel() > b:GetFrameLevel(), "button " .. i .. ": label frame above the button")
	end
	T.eq(main.roster.guide.link.open.label:GetText(), "Link account...", "label text kept")
	T.clean(h)
end

-- 2. "Link account..." links in place: click, type the full name, Enter. Same path as /rlvl link.
function cases.link_button_opens_an_inline_field_and_links()
	local h, state = andy()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	local link = main.roster.guide.link
	T.ok(main.roster.guide:IsShown(), "Andy's two-character roster shows the guide")
	T.ok(not main.link:IsShown(), "the footer field hides while the guide has its own")
	T.ok(not link.edit:IsShown(), "closed at first")
	T.eq(link.status:GetText(), "No other account linked yet.", "says nothing is linked")
	FakeWoW.RunScript(link.open, "OnClick")
	T.ok(link.edit:IsShown() and link.ok:IsShown() and link.cancel:IsShown(), "click opens the field in place")
	T.ok(link.edit:HasFocus(), "and puts the cursor in it")
	T.ok(link.hint:IsShown(), "hint while empty")
	T.eq(link.hint:GetText(), "Character name on your other account", "hint text")
	link.edit:SetText("  Le   Bankken  ")
	T.ok(not link.hint:IsShown(), "hint hides once typing starts")
	FakeWoW.RunScript(link.edit, "OnEnterPressed")
	local links = W.DB(h).sync.links
	T.ok(links["Le Bankken"], "linked the full name, spaces cleaned like /rlvl link")
	local hello = state.sent[#state.sent]
	T.eq(hello.channel, "WHISPER", "says hello to the other account at once")
	T.eq(hello.target, "Le Bankken", "to that name")
	T.ok(not link.edit:IsShown(), "field closes")
	T.eq(link.status:GetText(), "Linked to Le Bankken. Waiting for them to link you back (/rlvl link Le Nette on that account).",
		"waiting state, naming the character to link back")
	T.ok(link.unlink:IsShown() and not link.open:IsShown(), "Unlink offered")
	-- The other account links back: its whisper hello confirms, and the state becomes "paired".
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "Hbbbbbb;00000000;#3;1", "WHISPER", "Le Bankken")
	T.has(link.status:GetText(), "Paired with Le Bankken", "paired once they link back")
	W.DB(h).sync.peers.bbbbbb.lastSync = W.NOW - 5 * 60
	state.ns.Link.RefreshAll()
	T.eq(main.roster.guide.link.status:GetText(), "Paired with Le Bankken, synced 5m ago", "and when it last synced")
	FakeWoW.RunScript(link.unlink, "OnClick")
	T.ok(not W.DB(h).sync.links["Le Bankken"], "Unlink removes it")
	T.eq(link.status:GetText(), "No other account linked yet.", "back to no link")
	T.clean(h)
end

function cases.link_field_cancels_with_esc_and_ignores_an_empty_name()
	local h = andy()
	h.Slash("RESTEDLEVELING", "")
	local link = h.Env().RestedLevelingMain.roster.guide.link
	FakeWoW.RunScript(link.open, "OnClick")
	FakeWoW.RunScript(link.edit, "OnEnterPressed")
	T.ok(link.edit:IsShown(), "an empty name keeps the field open")
	T.ok(next(W.DB(h).sync.links) == nil, "and links nothing")
	link.edit:SetText("Le Bankken")
	FakeWoW.RunScript(link.edit, "OnEscapePressed")
	T.ok(not link.edit:IsShown(), "Esc closes it")
	T.ok(next(W.DB(h).sync.links) == nil, "without linking")
	T.ok(link.open:IsShown(), "the button is back")
	T.clean(h)
end

-- The footer has the same field when the roster has rows (no guide).
function cases.footer_has_the_same_field_when_the_guide_is_not_shown()
	local chars = {}
	for i, name in ipairs({ "Le Jette", "Le Dette", "Amdo Moto" }) do
		chars["N:" .. name .. "@?"] = { full = name, class = "WARRIOR", race = "Orc", sex = 2, level = 20, xpMax = 10000,
			rested = 5000 * i, resting = true, restKind = "inn", zone = "Durotar", subzone = "Razor Hill", t = W.NOW - H }
	end
	local h = andy(nil, chars)
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	T.ok(not main.roster.guide:IsShown(), "rows, no guide")
	T.ok(main.link:IsShown(), "footer field shown")
	FakeWoW.RunScript(main.link.open, "OnClick")
	main.link.edit:SetText("Le Bankken")
	FakeWoW.RunScript(main.link.ok, "OnClick")
	T.ok(W.DB(h).sync.links["Le Bankken"], "the footer's Link button links too")
	T.has(main.link.status:GetText(), "Waiting for them to link you back", "and shows the state")
	T.clean(h)
end

-- 3. Offline characters: no stock face. The disc shows the class crest, the badge the race emblem, and the 3D stage is
-- only for the character you are on.
function cases.offline_portraits_show_crest_and_race_emblem_not_a_stock_face()
	local h, state = andy()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	local p = main.hero.portrait
	T.eq(p.tex.__atlas, "classicon-warrior", "Le Jette's disc is her class crest")
	T.ok(p.tex:GetTexture() == nil or not tostring(p.tex:GetTexture()):find("TemporaryPortrait"), "no stock race portrait")
	T.eq(p.crest.__atlas, "raceicon128-gnome-female", "her race emblem in the badge")
	T.ok(p.crest:IsShown(), "badge shown")
	T.ok(p.crestLift:IsShown() and p.crestLift.__atlas == p.crest.__atlas, "lifted by an additive copy, not a grey blob")
	T.ok(not p.live, "not a live portrait")
	local cur = main.current.portrait
	T.ok(cur.live, "Le Nette (logged in) keeps her real portrait")
	local drew = false
	for _, call in ipairs(state.portraits) do if call.tex == cur.tex and call.unit == "player" then drew = true end end
	T.ok(drew, "drawn with SetPortraitTexture(player)")
	T.eq(cur.crest.__atlas, "classicon-mage", "her class crest in the badge")
	T.ok(not cur.crestLift:IsShown(), "her own class crest drawn as is")
	T.clean(h)
end

function cases.race_emblem_is_skipped_when_the_client_lacks_the_atlas()
	local h = andy(function(game) game.C_Texture = { GetAtlasInfo = function() return nil end } end)
	h.Slash("RESTEDLEVELING", "")
	local p = h.Env().RestedLevelingMain.hero.portrait
	T.eq(p.tex.__atlas, "classicon-warrior", "crest still shown")
	T.ok(not p.crest:IsShown(), "no emblem rather than a missing texture")
	T.clean(h)
end

function cases.card_stage_is_live_only_for_the_character_you_are_on()
	local h = andy()
	h.Slash("RESTEDLEVELING", "")
	FakeWoW.RunScript(h.Env().RestedLevelingMain.hero, "OnClick")
	local card = h.Env().RestedLevelingCard
	T.ok(not card.stage.model:IsShown(), "no 3D lookalike for Le Jette")
	T.ok(card.stage.figure:IsShown(), "her crest instead")
	T.ok(card.stage.note:IsShown(), "with a note saying why")
	T.eq(card.stage.note:GetText(), "Last seen as a level 46 Gnome Warrior. Log in to see them.", "the note")
	T.clean(h)
end

function cases.card_for_the_character_you_are_on_is_the_live_model()
	local h, state = andy()
	h.Slash("RESTEDLEVELING", "")
	state.ns.ShowDetail(state.ns.MyKey())
	local card = h.Env().RestedLevelingCard
	T.ok(card.stage.model:IsShown(), "Le Nette stands on the stage as herself")
	T.ok(not card.stage.figure:IsShown(), "no crest figure")
	T.ok(not card.stage.note:IsShown(), "no offline note")
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
	T.eq(hero.statSub:GetText(), "UNTIL FULL", "labelled")
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

-- 7. Review of ILL-1274: when the hero is the one that fills first (not rows[1]), the rest are numbered in sort order
-- from 1, so the most-banked empty alt is not shown as #2 under a hero that has no number.
function cases.roster_numbers_from_one_when_the_hero_is_not_rows_1()
	local h = andy(nil, {
		["N:Le Jette@?"] = { full = "Le Jette", class = "WARRIOR", race = "Gnome", sex = 3, level = 46, xpMax = 80000,
			rested = 400, resting = true, restKind = "inn", zone = "Feralas", subzone = "Feathermoon Stronghold", t = W.NOW },
		["N:Aa Outside@?"] = { full = "Aa Outside", class = "WARRIOR", race = "Orc", sex = 2, level = 20, xpMax = 10000,
			rested = 375, resting = false, restKind = "outside", zone = "Durotar", t = W.NOW },
		["N:Bb Empty@?"] = { full = "Bb Empty", class = "WARRIOR", race = "Orc", sex = 2, level = 20, xpMax = 10000,
			rested = 0, resting = false, restKind = "outside", zone = "Durotar", t = W.NOW },
	})
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	T.eq(strip(main.hero.name:GetText()), "Le Jette", "the hero is who fills first")
	T.eq(strip(main.roster.rows[1].name:GetText()), "Aa Outside", "then the roster in sort order")
	T.eq(tostring(main.roster.rows[1].rank:GetText()), "1", "numbered from 1")
	T.eq(strip(main.roster.rows[2].name:GetText()), "Bb Empty", "in sort order")
	T.eq(tostring(main.roster.rows[2].rank:GetText()), "2", "then 2")
	T.clean(h)
end

-- 8. The link field closes when its window hides mid-edit, and a link that did not take keeps the field open.
function cases.link_field_closes_on_hide_and_stays_open_when_the_link_fails()
	local h, state = andy()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	local link = main.roster.guide.link
	FakeWoW.RunScript(link.open, "OnClick")
	link.edit:SetText("Le Bank")
	T.ok(link.editing and link.edit:HasFocus(), "editing")
	main:Hide()
	FakeWoW.RunScript(link, "OnHide")
	T.ok(not link.editing and not link.edit:IsShown(), "hiding the window closes the field")
	T.ok(not link.edit:HasFocus(), "and drops the focus")
	main:Show()
	-- Eight links already (made with /rlvl link): a ninth from the field does not take.
	local links = W.DB(h).sync.links
	for i = 1, state.ns.Sync.MAX_LINKS do links["Alt" .. i] = true end
	FakeWoW.RunScript(link.open, "OnClick")
	link.edit:SetText("Le Bankken")
	FakeWoW.RunScript(link.edit, "OnEnterPressed")
	T.ok(not links["Le Bankken"], "not linked: at the cap")
	T.ok(link.edit:IsShown(), "the field stays open")
	T.eq(link.edit:GetText(), "Le Bankken", "with the name kept")
	T.ok(link.err:IsShown(), "and the reason shown")
	T.has(link.err:GetText(), "at most 8 links", "the reason")
	FakeWoW.RunScript(link.cancel, "OnClick")
	T.ok(not link.err:IsShown(), "cancel clears it")
	T.clean(h)
end

-- 9. Riding is not a profession: dropped from the client's list and from saved lists.
function cases.riding_is_not_listed_as_a_profession()
	local h, state = andy(function(game)
		local lines = {
			{ name = "Cooking", rank = 216, skillLineCategoryID = 9 },
			{ name = "Riding", rank = 75, skillLineCategoryID = 9 },
		}
		game.C_SkillInfo = { GetNumSkillLines = function() return #lines end, GetSkillLineInfo = function(i) return lines[i] end }
	end)
	T.eq(W.Char(h, "Le Nette").profs, "Cooking 216", "no Riding from the client")
	T.eq(state.ns.Tidbits.CleanProfs("Cooking 216, Riding 75, Fishing 183"), "Cooking 216, Fishing 183", "nor from saved data")
	T.clean(h)
end

return cases
