-- "Save my look" (ILL-1279): the capture state machine (combat refused; UIParent, the screenshotFormat CVar and the
-- stage restored on success, failure, Esc, combat and timeout), the crop maths, the file names, drawing a saved look
-- in the portrait ring with a silent fallback to the crest, sync of the look, Clear look, and the probe's removal.

local W = dofile("tests/world.lua")
local H = 3600

local function strip(s) return (s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end

local JETTE = "N:Le Jette@?"
local function jette(look)
	return { full = "Le Jette", class = "WARRIOR", race = "Gnome", sex = 3, level = 46, xpMax = 80000, rested = 40000,
		resting = true, restKind = "inn", zone = "Feralas", subzone = "Feathermoon Stronghold", t = W.NOW - H, look = look }
end

-- On Le Nette (logged in), with Le Jette offline. st.combat, st.cvars and st.shots drive and record the client.
local function world(opts)
	opts = opts or {}
	local saved = { chars = { [JETTE] = jette(opts.look) } }
	local state = { first = "Le", surname = "Nette", class = "MAGE", saved = saved, cvars = { screenshotFormat = "jpeg" },
		shots = 0, setup = function(game, h, st)
			game.UISpecialFrames = {}
			game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
			game.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
			st.portraits = {}
			game.SetPortraitTexture = function(tex, unit) st.portraits[#st.portraits + 1] = { tex = tex, unit = unit } end
			game.Screenshot = function() st.shots = st.shots + 1 end
			game.InCombatLockdown = function() return st.combat or false end
			game.GetPhysicalScreenSize = function() return 2880, 1620 end
			game.C_Texture = { GetAtlasInfo = function(atlas)
				if atlas:find("^raceicon128%-") or atlas:find("^classicon%-") then return { width = 64, height = 64 } end
			end }
			game.C_CVar = {
				GetCVar = function(name) return st.cvars[name] end,
				SetCVar = function(name, value) st.cvars[name] = value end,
			}
			if opts.extra then opts.extra(game, h, st) end
		end }
	local _, h = W.New(state)
	return h, state
end

-- Run only the next queued C_Timer callback (the capture queues its shot, then its timeout).
local function nextTimer(state) local fn = table.remove(state.timers, 1) if fn then fn() end end

local function printed(h, needle)
	for _, l in ipairs(h.Printed()) do if strip(l):find(needle, 1, true) then return l end end
end

local function me(h, state) return W.DB(h).chars[state.ns.MyKey()] end

-- Nothing of the capture is left behind.
local function restored(h, state, format)
	local env = h.Env()
	T.ok(env.UIParent:IsShown(), "UIParent shown again")
	T.eq(state.cvars.screenshotFormat, format or "jpeg", "the player's screenshot format put back")
	T.ok(not env.RestedLevelingLookStage:IsShown(), "the stage is gone")
	T.ok(not state.ns.Look.Busy(), "no capture in progress")
end

local cases = {}

-- Capture --------------------------------------------------------------------------------------------------------

function cases.save_is_refused_in_combat()
	local h, state = world()
	state.combat = true
	T.eq(state.ns.Look.Save(), false, "not started")
	T.ok(printed(h, "Leave combat first"), "says why")
	T.ok(h.Env().UIParent:IsShown(), "UIParent untouched")
	T.ok(h.Env().RestedLevelingLookStage == nil, "no stage")
	W.RunTimers(state)
	T.eq(state.shots, 0, "no screenshot")
	T.clean(h)
end

function cases.save_hides_the_ui_shoots_a_tga_and_puts_everything_back()
	local h, state = world()
	local env = h.Env()
	T.ok(state.ns.Look.Save(), "started")
	local stage = env.RestedLevelingLookStage
	T.ok(not env.UIParent:IsShown(), "UIParent hidden, like Alt-Z")
	T.ok(stage:IsShown(), "our stage up")
	T.ok(stage:GetParent() == env.WorldFrame, "the stage is on WorldFrame, not under UIParent")
	T.eq(stage.model:GetObjectType(), "DressUpModel", "a dress-up model of the player")
	local calls = {}
	stage.model.SetUnit = function(_, unit) calls.unit = unit end
	stage.model.UndressSlot = function(_, slot) calls[#calls + 1] = slot end
	stage.model.SetPortraitZoom = function(_, z) calls.zoom = z end
	T.eq(state.shots, 0, "waits for the model before shooting")
	nextTimer(state)
	T.eq(state.shots, 1, "one screenshot")
	T.eq(state.cvars.screenshotFormat, "tga", "as .tga for this shot")
	T.eq(calls.unit, "player", "the player")
	T.eq(table.concat(calls, ","), "16,17,18", "weapons off")
	T.ok(calls.zoom and calls.zoom > 0, "portrait framing")
	T.ok(not env.UIParent:IsShown(), "still hidden until the client says it wrote the file")
	h.Fire("SCREENSHOT_SUCCEEDED")
	restored(h, state)
	local look = me(h, state).look
	T.ok(look, "look saved on the character you are on")
	T.eq(look.file, "WoWScrnShot_" .. os.date("%m%d%y_%H%M%S", look.at) .. ".tga", "the client's file name")
	T.ok(look.l < look.r and look.t < look.b, "a crop box")
	T.ok(printed(h, "Shows on other characters after you restart the game"), "says when it will show")
	W.RunTimers(state)   -- the timeout, after the fact: nothing more happens
	T.eq(state.shots, 1, "still one")
	restored(h, state)
	T.clean(h)
end

function cases.a_failed_screenshot_restores_everything_and_saves_nothing()
	local h, state = world()
	state.cvars.screenshotFormat = "png"
	state.ns.Look.Save()
	nextTimer(state)
	h.Fire("SCREENSHOT_FAILED")
	restored(h, state, "png")
	T.ok(me(h, state).look == nil, "nothing saved")
	T.ok(printed(h, "Look not saved"), "said so")
	T.clean(h)
end

function cases.an_error_from_screenshot_still_restores_everything()
	local h, state = world({ extra = function(game) game.Screenshot = function() error("no screenshots here") end end })
	state.ns.Look.Save()
	nextTimer(state)
	restored(h, state)
	T.ok(me(h, state).look == nil, "nothing saved")
	T.ok(printed(h, "Look not saved"), "said so")
	h.ClearPrinted()
	T.clean(h)
end

function cases.escape_cancels_before_the_shot()
	local h, state = world()
	state.ns.Look.Save()
	local stage = h.Env().RestedLevelingLookStage
	FakeWoW.RunScript(stage, "OnKeyDown", "W")
	T.ok(stage:IsShown(), "other keys do nothing")
	FakeWoW.RunScript(stage, "OnKeyDown", "ESCAPE")
	restored(h, state)
	W.RunTimers(state)
	T.eq(state.shots, 0, "the queued shot never fires")
	T.ok(me(h, state).look == nil, "nothing saved")
	T.ok(not printed(h, "Look not saved"), "a cancel is quiet")
	T.clean(h)
end

function cases.escape_after_the_shot_still_restores_the_format()
	local h, state = world()
	state.ns.Look.Save()
	nextTimer(state)
	FakeWoW.RunScript(h.Env().RestedLevelingLookStage, "OnMouseDown")
	restored(h, state)
	h.Fire("SCREENSHOT_SUCCEEDED")   -- the shot lands after the cancel: ignored
	T.ok(me(h, state).look == nil, "nothing saved")
	T.clean(h)
end

function cases.combat_starting_mid_capture_ends_it()
	local h, state = world()
	state.ns.Look.Save()
	h.Fire("PLAYER_REGEN_DISABLED")
	restored(h, state)
	T.ok(printed(h, "entered combat"), "said why")
	W.RunTimers(state)
	T.eq(state.shots, 0, "no screenshot")
	T.clean(h)
end

function cases.combat_lockdown_first_shows_the_ui_when_it_ends()
	local h, state = world()
	state.ns.Look.Save()
	state.combat = true   -- the lockdown started before our event
	h.Fire("PLAYER_LEAVING_WORLD")
	T.ok(not h.Env().UIParent:IsShown(), "not shown during lockdown")
	state.combat = false
	h.Fire("PLAYER_REGEN_ENABLED")
	restored(h, state)
	T.clean(h)
end

function cases.a_screenshot_that_never_reports_times_out()
	local h, state = world()
	state.ns.Look.Save()
	nextTimer(state)   -- shot
	nextTimer(state)   -- timeout
	restored(h, state)
	T.ok(printed(h, "took too long"), "said so")
	T.clean(h)
end

function cases.the_model_loading_shoots_without_waiting_the_full_second()
	local h, state = world()
	state.ns.Look.Save()
	local stage = h.Env().RestedLevelingLookStage
	FakeWoW.RunScript(stage.model, "OnModelLoaded")
	FakeWoW.RunScript(stage.model, "OnModelLoaded")   -- twice: one shot
	local settle = table.remove(state.timers)   -- queued last
	settle()
	T.eq(state.shots, 1, "shot once loaded")
	W.RunTimers(state)   -- the 1 s fallback, then the timeout
	T.eq(state.shots, 1, "never twice")
	restored(h, state)
	T.clean(h)
end

function cases.another_screenshot_before_ours_is_not_taken_for_it()
	local h, state = world()
	state.ns.Look.Save()
	h.Fire("SCREENSHOT_SUCCEEDED")   -- e.g. the player pressed Print Screen first
	T.ok(state.ns.Look.Busy(), "still waiting for ours")
	T.ok(me(h, state).look == nil, "not saved from someone else's file")
	nextTimer(state)
	h.Fire("SCREENSHOT_SUCCEEDED")
	T.ok(me(h, state).look, "saved from ours")
	T.clean(h)
end

function cases.ui_already_hidden_with_alt_z_stays_hidden()
	local h, state = world()
	h.Env().UIParent:Hide()
	state.ns.Look.Save()
	nextTimer(state)
	h.Fire("SCREENSHOT_SUCCEEDED")
	T.ok(not h.Env().UIParent:IsShown(), "left as the player had it")
	T.clean(h)
end

-- Crop maths and names -------------------------------------------------------------------------------------------

-- A parentless frame over WorldFrame is 768 units high. Each screen: the model square is 512 physical px (80% of
-- the height on a small screen), centred, and the texcoords cut exactly that square out of the full screenshot.
function cases.texcoords_cut_the_model_square_out_of_the_screenshot()
	local ns = W.Pure({ "Core/Util.lua", "Core/Look.lua" })
	local LD = ns.LookData
	for _, s in ipairs({ { 1920, 1080 }, { 2880, 1620 }, { 2560, 1440 }, { 3440, 1440 }, { 1280, 720 }, { 800, 600 } }) do
		local pw, ph = s[1], s[2]
		local uh = 768
		local uw = uh * pw / ph
		local size = LD.ModelSize(ph, uh)
		local ml, mb = (uw - size) / 2, (uh - size) / 2
		local l, r, t, b = LD.TexCoords({ left = 0, right = uw, top = uh, bottom = 0 },
			{ left = ml, right = ml + size, top = mb + size, bottom = mb })
		local want = math.min(512, math.floor(ph * 0.8))
		local tag = pw .. "x" .. ph
		T.ok(math.abs((r - l) * pw - want) < 1, tag .. ": " .. want .. " px wide, got " .. (r - l) * pw)
		T.ok(math.abs((b - t) * ph - want) < 1, tag .. ": " .. want .. " px high, got " .. (b - t) * ph)
		T.ok(math.abs((l + r) / 2 - 0.5) < 0.001 and math.abs((t + b) / 2 - 0.5) < 0.001, tag .. ": centred")
	end
	-- off centre, offset stage: top of the image is the top of the screen
	local l, r, t, b = LD.TexCoords({ left = 10, right = 110, top = 220, bottom = 20 },
		{ left = 10, right = 60, top = 220, bottom = 120 })
	T.eq(l, 0, "left edge")
	T.eq(r, 0.5, "half way")
	T.eq(t, 0, "top of the image")
	T.eq(b, 0.5, "half way down")
end

function cases.file_name_and_candidates()
	local ns = W.Pure({ "Core/Util.lua", "Core/Look.lua" })
	local LD = ns.LookData
	local at = W.NOW
	T.eq(LD.FileName(at), "WoWScrnShot_" .. os.date("%m%d%y_%H%M%S", at) .. ".tga", "the client's pattern, .tga")
	local names = LD.Names({ file = LD.FileName(at), at = at, asked = at - 1 })
	T.eq(names[1], LD.FileName(at), "the success second first")
	T.eq(#names, 4, "then each second from before the ask to after the write, once each")
	T.eq(names[2], LD.FileName(at - 2), "a second early")
	T.eq(names[4], LD.FileName(at + 1), "a second late")
	T.eq(#LD.Names({ file = LD.FileName(at), at = at, asked = at - 3600 }), 1, "a nonsense range adds nothing")
	-- only screenshot names reach SetTexture
	local box = { l = 0.1, r = 0.3, t = 0.2, b = 0.6 }
	local function with(file) local t = { file = file } for k, v in pairs(box) do t[k] = v end return t end
	T.ok(LD.Valid(with(LD.FileName(at))), "a screenshot name")
	T.ok(not LD.Valid(with("..\\Interface\\AddOns\\x.tga")), "no paths")
	T.ok(not LD.Valid(with("WoWScrnShot_112526_051821.jpg")), "tga only")
	T.ok(not LD.Valid(with("WoWScrnShot_112526_051821.tga\\..\\x")), "nothing after the name")
	local bad = with(LD.FileName(at))
	bad.l, bad.r = 0.5, 0.2
	T.ok(not LD.Valid(bad), "an inside-out box")
	bad = with(LD.FileName(at))
	bad.b = 1.5
	T.ok(not LD.Valid(bad), "outside the image")
end

-- Display --------------------------------------------------------------------------------------------------------

local LOOK = { file = "WoWScrnShot_112526_051821.tga", l = 0.4111, r = 0.5889, t = 0.342, b = 0.658, at = W.NOW - H, asked = W.NOW - H }

local function tracking(f)
	f.look.SetTexCoord = function(self, ...) self.__coords = { ... } end
end

function cases.a_saved_look_shows_in_the_ring_wherever_an_offline_portrait_does()
	local h, state = world({ look = LOOK })
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	local hero = main.hero.portrait
	T.ok(hero.look:IsShown(), "the hero shows her look")
	T.eq(hero.look:GetTexture(), "Screenshots\\WoWScrnShot_112526_051821.tga", "through the path form that loads")
	T.eq(hero.tex.__atlas, "classicon-warrior", "the crest stays under it (the fallback)")
	T.eq(hero.crest.__atlas, "raceicon128-gnome-female", "the race emblem badge stays")
	tracking(hero)
	state.ns.Widgets.SetPortrait(hero, W.DB(h).chars[JETTE], false, "resting")
	T.eq(table.concat(hero.look.__coords, ","), "0.4111,0.5889,0.342,0.658", "cropped to the model")
	FakeWoW.RunScript(main.hero, "OnClick")
	local card = h.Env().RestedLevelingCard
	T.ok(card.stage.figure.look:IsShown(), "the card's figure")
	T.eq(card.stage.note:GetText(), "Last seen as a level 46 Gnome Warrior.", "no 'log in to see them' under her own face")
	T.ok(not card.stage.lookBox:IsShown(), "no Save my look on an offline character")
	T.ok(not main.current.portrait.look:IsShown(), "the character you are on keeps its live portrait")
	T.clean(h)
end

function cases.a_look_that_does_not_load_falls_back_to_the_crest_silently()
	local h = world({ look = LOOK, extra = function(game)
		local create = game.CreateFrame
		game.CreateFrame = function(...)
			local f = create(...)
			local ct = f.CreateTexture
			f.CreateTexture = function(self, ...)
				local t = ct(self, ...)
				t.SetTexture = function(tx, file)
					if type(file) == "string" and file:find("^Screenshots") then return false end
					tx.__tex = file
				end
				return t
			end
			return f
		end
	end })
	h.Slash("RESTEDLEVELING", "")
	local p = h.Env().RestedLevelingMain.hero.portrait
	T.ok(not p.look:IsShown(), "nothing drawn over the crest")
	T.eq(p.tex.__atlas, "classicon-warrior", "the crest")
	T.ok(p.crest:IsShown(), "and the race badge")
	T.clean(h)
end

function cases.a_bad_look_from_saved_data_is_never_drawn()
	local bad = {}
	for k, v in pairs(LOOK) do bad[k] = v end
	bad.file = "..\\..\\WTF\\Config.wtf"
	local h = world({ look = bad })
	h.Slash("RESTEDLEVELING", "")
	local p = h.Env().RestedLevelingMain.hero.portrait
	T.ok(not p.look:IsShown(), "not drawn")
	T.eq(p.look:GetTexture(), nil, "never passed to SetTexture")
	T.clean(h)
end

-- The card and the now-playing strip -----------------------------------------------------------------------------

function cases.card_buttons_save_and_clear_on_the_character_you_are_on()
	local h, state = world()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	FakeWoW.RunScript(main.current, "OnClick", "LeftButton")   -- the now-playing strip opens your own card
	local card = h.Env().RestedLevelingCard
	local box = card.stage.lookBox
	T.ok(card:IsShown() and card.stage.model:IsShown(), "your card, the live model")
	T.ok(box:IsShown() and box.save:IsShown(), "Save my look")
	T.eq(box.save.label:GetText(), "Save my look", "its label")
	T.ok(not box.clear:IsShown(), "no Clear look before there is one")
	T.ok(not box.note:IsShown(), "no note yet")
	W.RunTimers(state)   -- the card's own re-measure
	FakeWoW.RunScript(box.save, "OnClick")
	nextTimer(state)
	h.Fire("SCREENSHOT_SUCCEEDED")
	T.ok(card:IsShown(), "the card is back after the shot")
	T.ok(box.note:IsShown(), "the note")
	T.eq(box.note:GetText(), "Saved. Shows on other characters after you restart the game.", "one line")
	T.ok(box.clear:IsShown(), "Clear look")
	T.ok(card.stage.model:IsShown(), "still the live model")
	FakeWoW.RunScript(box.clear, "OnClick")
	T.ok(me(h, state).look == nil, "cleared")
	T.ok(not box.clear:IsShown(), "Clear look gone")
	T.ok(not box.note:IsShown(), "and the note")
	T.clean(h)
end

function cases.right_click_on_now_playing_offers_the_same_actions()
	local h, state = world({ extra = function(game, _, st)
		game.MenuUtil = { CreateContextMenu = function(owner, gen)
			local root = { items = {} }
			function root:CreateButton(text, fn) self.items[#self.items + 1] = { text = text, fn = fn } end
			gen(owner, root)
			st.menu = root.items
		end }
	end })
	h.Slash("RESTEDLEVELING", "")
	local cur = h.Env().RestedLevelingMain.current
	FakeWoW.RunScript(cur, "OnClick", "RightButton")
	local texts = {}
	for _, it in ipairs(state.menu) do texts[#texts + 1] = it.text end
	T.eq(table.concat(texts, ","), "Open my card,Save my look", "no Clear look without one")
	state.menu[2].fn()
	T.ok(state.ns.Look.Busy(), "Save my look started a capture")
	nextTimer(state)
	h.Fire("SCREENSHOT_SUCCEEDED")
	FakeWoW.RunScript(cur, "OnClick", "RightButton")
	T.eq(state.menu[3] and state.menu[3].text, "Clear look", "then Clear look")
	state.menu[3].fn()
	T.ok(me(h, state).look == nil, "cleared")
	T.clean(h)
end

-- Sync -----------------------------------------------------------------------------------------------------------

local function codec()
	return W.Pure({ "Core/Util.lua", "Core/Model.lua", "Core/Identity.lua", "Core/Look.lua", "Sync/Codec.lua" })
end

local function rec(full, t, look)
	return { full = full, class = "WARRIOR", level = 46, xpMax = 80000, rested = 400, t = t, account = "bbbbbb", look = look }
end

function cases.the_look_travels_to_the_other_account()
	local C = codec().Codec
	local _, recs = C.DecodeRoster(C.EncodeRoster({ [JETTE] = rec("Le Jette", W.NOW, LOOK) }, "bbbbbb"), W.NOW)
	local look = recs[1].look
	T.ok(look, "decoded")
	for _, k in ipairs({ "file", "l", "r", "t", "b", "at", "asked" }) do T.eq(look[k], LOOK[k], k) end
	T.ok(recs[1].lookFile == nil and recs[1].lookBox == nil, "wire fields folded back into c.look")
	local chars = {}
	C.Merge(chars, recs, "Lebankken", W.NOW, nil, "aaaaaa")
	T.eq(chars[JETTE].look.file, LOOK.file, "merged")
	-- cleared on the owner's side: the newer record without a look clears it here
	local _, recs2 = C.DecodeRoster(C.EncodeRoster({ [JETTE] = rec("Le Jette", W.NOW + 60) }, "bbbbbb"), W.NOW + 60)
	C.Merge(chars, recs2, "Lebankken", W.NOW + 60, nil, "aaaaaa")
	T.ok(chars[JETTE].look == nil, "cleared here too")
end

function cases.a_saved_look_changes_the_digest_so_it_is_sent()
	local C = codec().Codec
	local chars = { [JETTE] = rec("Le Jette", W.NOW) }
	local before = C.Digest(chars)
	chars[JETTE].look = LOOK
	T.ok(C.Digest(chars) ~= before, "a new look is something to swap")
end

function cases.an_older_version_skips_the_look_and_keeps_the_record()
	local ns = codec()
	local C = ns.Codec
	local payload = C.EncodeRoster({ [JETTE] = rec("Le Jette", W.NOW, LOOK) }, "bbbbbb")
	T.has(payload, "lf=WoWScrnShot_112526_051821.tga", "on the wire")
	for _, k in ipairs({ "lookFile", "lookBox", "lookAt", "lookAsked" }) do C.FIELDS[k] = nil end   -- v1 without looks
	local _, recs, dropped = C.DecodeRoster(payload, W.NOW)
	T.eq(#recs, 1, "the record kept")
	T.eq(dropped, 0, "nothing dropped")
	T.ok(recs[1].look == nil, "no look")
end

function cases.a_bad_look_on_the_wire_is_dropped_and_the_record_kept()
	local C = codec().Codec
	local good = C.EncodeRecord({ key = JETTE, full = "Le Jette", xpMax = 80000, t = W.NOW, lookFile = "..\\x.tga",
		lookBox = "0.1,0.2,0.3,0.4" })
	local c = C.DecodeRecord(good, W.NOW)
	T.ok(c, "record kept")
	T.ok(c.look == nil, "path refused")
	local box = C.EncodeRecord({ key = JETTE, full = "Le Jette", xpMax = 80000, t = W.NOW, lookFile = LOOK.file,
		lookBox = "1,0,0,1" })
	T.ok(C.DecodeRecord(box, W.NOW).look == nil, "inside-out box refused")
end

-- The experiment is over ----------------------------------------------------------------------------------------

function cases.shotprobe_is_gone()
	local h, state = world()
	T.ok(state.ns.slash.shotprobe == nil, "no /rlvl shotprobe")
	T.ok(state.ns.ShotProbe == nil, "no probe module")
	h.Slash("RESTEDLEVELING", "shotprobe take")
	T.eq(state.shots, 0, "no screenshot")
	T.ok(h.Env().RestedLevelingShotProbe == nil, "no test frame")
	T.clean(h)
end

return cases
