-- ILL-1299: the minimap button (shown with or without ElvUI), the title bar's X / cog / chevron, the Settings window
-- and the "Unlock notifications" toggle.

local W = dofile("tests/world.lua")
local D = 86400

local function alt(full, levels, ago, resting)
	return { full = full, class = "MAGE", race = "Scourge", sex = 3, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = resting, restKind = resting and "inn" or "outside", t = W.NOW - ago }
end

-- A minimal ElvUI whose Skins module accepts every S:Handle* call (failing: those named in it raise an error).
local function elvui(failing)
	local S = setmetatable({}, { __index = function(_, method)
		return function() if failing and failing[method] then error("skin failed") end end
	end })
	local E = { media = {} }
	function E:GetModule(name) if name == "Skins" then return S end end
	return { E }
end

local cases = {}

-- opts: saved options; version: the saved data's version; withElvUI: ElvUI loaded; positions: saved positions.
-- LibDBIcon is loaded from the TOC; its Show / Hide are recorded (in `minimap`, in order) before our login work runs.
local function stubbedWorld(opts, version, withElvUI, positions, failing)
	local saved = { version = version, opts = opts or {}, positions = positions, chars = {
		["N:Le Nette@?"] = alt("Le Nette", 1.5, 2 * D, true),
		["N:Le Dette@?"] = alt("Le Dette", 0.5, D, true),
	} }
	local minimap = {}
	local state = { saved = saved, noLogin = true, setup = function(game, h)
		if withElvUI then rawset(h.Env(), "ElvUI", elvui(failing)) end
		game.UISpecialFrames = {}
		game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
		game.SetPortraitTexture = function() end
		game.UIParent:SetSize(1920, 1080)   -- a real screen (the fake's default is 100 x 20)
	end }
	local _, h = W.New(state)
	local icon = h.Env().LibStub("LibDBIcon-1.0")
	icon.Register = function() end
	icon.IsRegistered = function() return true end
	icon.Show = function(_, name) minimap[#minimap + 1] = "Show " .. name end
	icon.Hide = function(_, name) minimap[#minimap + 1] = "Hide " .. name end
	W.Login(h, state, true)
	return h, state, minimap
end

function cases.minimap_button_shows_with_elvui_and_the_old_switch_is_gone()
	local h, state, minimap = stubbedWorld({ showMinimapWithElvUI = false, minimap = { hide = false } }, 2, true)
	local d = W.DB(h)
	T.eq(state.ns.Style.Pick("auto"), "elvui", "ElvUI is loaded")
	T.eq(minimap[#minimap], "Show RestedLeveling", "shown under ElvUI (1.2 hid it)")
	T.eq(d.version, 3, "saved data moved to version 3")
	T.eq(d.opts.showMinimapWithElvUI, nil, "the retired 'even with ElvUI' flag is dropped")
	for _, sw in ipairs(state.ns.Options.SWITCHES) do T.ok(sw.key ~= "minimapElv", "one minimap switch only") end
	h.Slash("RESTEDLEVELING", "minimap")
	T.ok(d.opts.minimap.hide, "/rlvl minimap hides it")
	T.eq(minimap[#minimap], "Hide RestedLeveling", "hidden")
	h.Slash("RESTEDLEVELING", "minimap")
	T.ok(not d.opts.minimap.hide, "and brings it back")
	T.eq(minimap[#minimap], "Show RestedLeveling", "shown")
	T.clean(h)
end

function cases.a_hidden_minimap_button_stays_hidden()
	local h, _, minimap = stubbedWorld({ minimap = { hide = true } }, 2, false)
	T.eq(minimap[#minimap], "Hide RestedLeveling", "the player's own choice is kept through the upgrade")
	T.clean(h)
end

function cases.minimap_clicks_and_tip()
	local h = stubbedWorld()
	local env = h.Env()
	local feed = env.LibStub("LibDataBroker-1.1"):GetDataObjectByName("RestedLeveling")
	T.has(feed.icon, "media\\icon", "the app icon")
	feed.OnClick(nil, "LeftButton")
	T.ok(env.RestedLevelingMain:IsShown(), "left-click opens the window")
	feed.OnClick(nil, "LeftButton")
	T.ok(not env.RestedLevelingMain:IsShown(), "and closes it")
	feed.OnClick(nil, "RightButton")
	T.ok(env.RestedLevelingSettings and env.RestedLevelingSettings:IsShown(), "right-click opens our settings window")
	local button = env.CreateFrame("Button", "LibDBIcon10_RestedLeveling", env.Minimap)
	feed.OnEnter(button)
	T.eq(env.RestedLevelingTip.hint:GetText(), "Left-click: open  ·  Right-click: settings  ·  Drag: move", "minimap hint")
	feed.OnEnter(env.CreateFrame("Frame", nil, env.UIParent))
	T.eq(env.RestedLevelingTip.hint:GetText(), "Left-click: open  ·  Right-click: settings", "a datatext can't be dragged")
	T.clean(h)
end

-- Right to left: X, cog, chevron; one size, 5 px apart, each centred on the one to its right.
function cases.title_bar_has_chevron_cog_and_close()
	local h = stubbedWorld()
	h.Slash("RESTEDLEVELING", "")
	local m = h.Env().RestedLevelingMain
	for _, b in ipairs({ m.rlClose, m.cogBtn, m.compactBtn }) do T.eq(b:GetWidth() .. "x" .. b:GetHeight(), "22x22", "22 px") end
	local p, rel, rp, x, y = m.cogBtn:GetPoint(1)
	T.ok(p == "RIGHT" and rel == m.rlClose and rp == "LEFT" and x == -5 and y == 0, "cog 5 px left of the X")
	p, rel, rp, x = m.compactBtn:GetPoint(1)
	T.ok(p == "RIGHT" and rel == m.cogBtn and rp == "LEFT" and x == -5, "chevron 5 px left of the cog")
	T.eq(m.compactBtn.glyph, "chevron_up", "a chevron, not a text button")
	T.has(m.compactBtn.icon:GetTexture(), "media\\chevron", "our chevron glyph")
	T.has(m.cogBtn.icon:GetTexture(), "media\\cog", "our cog glyph")
	T.has(m.rlClose.icon:GetTexture(), "media\\close", "our cross")
	FakeWoW.RunScript(m.cogBtn, "OnClick", "LeftButton")
	T.ok(h.Env().RestedLevelingSettings:IsShown(), "the cog opens the settings")
	FakeWoW.RunScript(m.cogBtn, "OnClick", "LeftButton")
	T.ok(not h.Env().RestedLevelingSettings:IsShown(), "and closes them")
	T.clean(h)
end

function cases.right_click_on_the_cog_unlocks_the_notifications()
	local h, state = stubbedWorld()
	h.Slash("RESTEDLEVELING", "")
	local m, Mv = h.Env().RestedLevelingMain, state.ns.Move
	FakeWoW.RunScript(m.cogBtn, "OnClick", "RightButton")
	T.ok(Mv.Active(), "right-click: move mode")
	FakeWoW.RunScript(m.cogBtn, "OnClick", "RightButton")
	T.ok(not Mv.Active(), "again: locked")
	T.clean(h)
end

function cases.settings_window_holds_the_same_page_and_toggles_move_mode()
	local h, state = stubbedWorld()
	local env, Mv = h.Env(), state.ns.Move
	h.Slash("RESTEDLEVELING", "options")
	local f = env.RestedLevelingSettings
	T.ok(f:IsShown(), "/rlvl options opens our window")
	local esc = false
	for _, name in ipairs(env.UISpecialFrames) do if name == "RestedLevelingSettings" then esc = true end end
	T.ok(esc, "Esc closes it")
	local keys = {}
	for _, cb in ipairs(env.RestedLevelingOptions.checks) do keys[#keys + 1] = cb.sw.key end
	local mine = {}
	for _, cb in ipairs(f.page.checks) do mine[#mine + 1] = cb.sw.key end
	T.eq(table.concat(mine, ","), table.concat(keys, ","), "the same switches as the Blizzard Settings page")
	local heads = {}
	for _, s in ipairs(f.page.sections) do heads[#heads + 1] = s.head:GetText() end
	T.eq(table.concat(heads, ","), "GENERAL,ACCOUNTS,ALERTS,POSITIONS,ABOUT", "the sections, top to bottom")
	T.eq(f.page.move.label:GetText(), "Unlock notifications", "locked at first")
	T.has(f.page.lock:GetTexture(), "media\\lock", "a closed lock")
	FakeWoW.RunScript(f.page.move, "OnClick")
	T.ok(Mv.Active(), "unlock: move mode")
	T.ok(f:IsShown(), "the window stays open")
	T.eq(f.page.move.label:GetText(), "Lock notifications", "the toggle says what it does next")
	T.has(f.page.lock:GetTexture(), "media\\unlock", "an open lock")
	local p, rel = f:GetPoint(1)
	T.ok(p == "LEFT" and rel == env.UIParent, "docked at the left edge, beside the placeholders")
	h.Slash("RESTEDLEVELING", "move")   -- /rlvl move while unlocked: still unlocked
	T.ok(Mv.Active(), "/rlvl move keeps it unlocked")
	FakeWoW.RunScript(f.page.move, "OnClick")
	T.ok(not Mv.Active(), "lock: move mode ends")
	T.eq(f.page.move.label:GetText(), "Unlock notifications", "back to unlock")
	T.eq((f:GetPoint(1)), "CENTER", "back where it was")
	T.clean(h)
end

-- Review r1: a window first opened while unlocked (cog right-click, then left-click) takes the move-mode layer too.
function cases.settings_opened_while_unlocked_sits_above_the_shade()
	local h, state = stubbedWorld()
	local env = h.Env()
	h.Slash("RESTEDLEVELING", "")
	local m = env.RestedLevelingMain
	FakeWoW.RunScript(m.cogBtn, "OnClick", "RightButton")
	T.ok(state.ns.Move.Active(), "unlocked first")
	FakeWoW.RunScript(m.cogBtn, "OnClick", "LeftButton")
	local f = env.RestedLevelingSettings
	T.ok(f:IsShown(), "then the settings")
	T.eq(f:GetFrameLevel(), 30, "over the shade, the placeholders and the move bar")
	T.eq((f:GetPoint(1)), "LEFT", "docked beside the placeholders")
	T.eq(f.page.move.label:GetText(), "Lock notifications", "and says it is unlocked")
	FakeWoW.RunScript(m.cogBtn, "OnClick", "RightButton")
	T.eq((f:GetPoint(1)), "CENTER", "locked: back in its place")
	T.clean(h)
end

-- Review r1: one change shows on every page on screen (our window and the Blizzard page), radios and slider too.
function cases.every_page_follows_a_change()
	local h = stubbedWorld()
	local env = h.Env()
	h.Slash("RESTEDLEVELING", "options")
	local mine, blizz = env.RestedLevelingSettings.page, env.RestedLevelingOptions
	FakeWoW.RunScript(mine.low, "OnValueChanged", 30)
	T.eq(W.DB(h).opts.lowPct, 30, "saved")
	T.has(blizz.low.value:GetText(), "30%", "the other page's slider follows")
	local default
	for _, b in ipairs(blizz.styleButtons) do if b.value == "default" then default = b end end
	FakeWoW.RunScript(default, "OnClick")
	for _, b in ipairs(mine.styleButtons) do T.eq(b:GetChecked(), b.value == "default", "style " .. b.value .. " on our window") end
	FakeWoW.RunScript(blizz.low, "OnValueChanged", 30)   -- a page being filled never writes an old value back
	T.eq(W.DB(h).opts.lowPct, 30, "still 30%")
	T.clean(h)
end

-- Review r1: on a 768-unit screen with bigger windows the page scrolls (mouse wheel) instead of running off screen.
function cases.settings_scroll_on_a_small_screen()
	local h = stubbedWorld({ scale = 1.15 })
	local env = h.Env()
	env.UIParent:SetSize(1366, 768)
	h.Slash("RESTEDLEVELING", "options")
	local f = env.RestedLevelingSettings
	T.ok(f:GetHeight() * 1.15 <= 768 - 40, "fits the screen")
	T.ok(f.scrollMax > 0 and f.thumb:IsShown(), "the page scrolls, with a thumb")
	FakeWoW.RunScript(f.scroll, "OnMouseWheel", -1)
	T.eq(f.scrollAt, 40, "the wheel scrolls 40")
	for _ = 1, 50 do FakeWoW.RunScript(f.scroll, "OnMouseWheel", -1) end
	T.eq(f.scrollAt, f.scrollMax, "never past the end")
	f:Hide()
	env.UIParent:SetSize(1920, 1080)
	W.DB(h).opts.scale = nil
	f:SetScale(1)
	f:Show()
	T.eq(f.scrollMax, 0, "a full-size screen: no scrolling")
	T.ok(not f.thumb:IsShown(), "and no thumb")
	T.clean(h)
end

function cases.settings_window_remembers_where_it_was_dragged()
	local h = stubbedWorld()
	local env = h.Env()
	env.UIParent:SetSize(1920, 1080)
	h.Slash("RESTEDLEVELING", "options")
	local f = env.RestedLevelingSettings
	f.__left, f.__bottom = 100, 300
	f:SetSize(668, 600)
	FakeWoW.RunScript(f, "OnDragStop")
	local pos = W.DB(h).positions.settings
	T.eq(pos.point, "TOPLEFT", "anchored to the nearest corner")
	T.eq(pos.x .. "," .. pos.y, "100,-180", "where it was left")
	local h2 = stubbedWorld(nil, nil, false, { settings = pos })
	h2.Slash("RESTEDLEVELING", "options")
	local p, rel, rp, x, y = h2.Env().RestedLevelingSettings:GetPoint(1)
	T.eq(table.concat({ p, rp, x, y }, ","), "TOPLEFT,TOPLEFT,100,-180", "opens there next session")
	T.ok(rel == h2.Env().UIParent, "against the screen")
	T.clean(h); T.clean(h2)
end

function cases.compact_bar_has_the_same_controls()
	local h = stubbedWorld()
	local env = h.Env()
	h.Slash("RESTEDLEVELING", "")
	FakeWoW.RunScript(env.RestedLevelingMain.compactBtn, "OnClick")
	local c = env.RestedLevelingCompact
	T.ok(c:IsShown() and not env.RestedLevelingMain:IsShown(), "chevron up: compact")
	T.eq(c.compactBtn.glyph, "chevron_down", "the bar's chevron points down")
	T.ok(c.cogBtn and c.rlClose, "cog and X on the bar too")
	FakeWoW.RunScript(c.rlClose, "OnClick")
	T.ok(not c:IsShown(), "X hides the bar")
	T.ok(W.DB(h).opts.compact, "compact mode stays on")
	h.Slash("RESTEDLEVELING", "")
	T.ok(c:IsShown() and not env.RestedLevelingMain:IsShown(), "/rlvl in compact mode brings the bar back")
	local feed = env.LibStub("LibDataBroker-1.1"):GetDataObjectByName("RestedLeveling")
	feed.OnClick(nil, "LeftButton")
	T.ok(not c:IsShown() and W.DB(h).opts.compact, "a minimap left-click hides it again, still compact")
	feed.OnClick(nil, "LeftButton")
	T.ok(c:IsShown() and not env.RestedLevelingMain:IsShown(), "and shows it")
	FakeWoW.RunScript(c.compactBtn, "OnClick")
	T.ok(env.RestedLevelingMain:IsShown() and not c:IsShown(), "chevron down: the full window")
	T.ok(not W.DB(h).opts.compact, "compact mode off")
	T.clean(h)
end

-- Under ElvUI the three are one visual size: 22 px squares, the X's 30 px button with its plate inset 4.
function cases.elvui_title_buttons_are_one_size()
	local h = stubbedWorld(nil, nil, true)
	h.Slash("RESTEDLEVELING", "")
	local m = h.Env().RestedLevelingMain
	T.eq(m.rlClose:GetHeight() - 2 * m.rlClose.rlInset, 22, "the X's plate: 22 px")
	T.eq(m.cogBtn:GetWidth() .. "x" .. m.cogBtn:GetHeight(), "22x22", "cog square")
	T.eq(m.compactBtn:GetWidth() .. "x" .. m.compactBtn:GetHeight(), "22x22", "chevron square")
	T.clean(h)
end

-- A skin call that throws part way: the half-skinned button is dropped (hidden, unparented), ours takes its place.
function cases.a_failing_skin_call_leaves_no_half_skinned_button()
	local h = stubbedWorld(nil, nil, true, nil, { HandleNextPrevButton = true })
	h.Slash("RESTEDLEVELING", "")
	local m = h.Env().RestedLevelingMain
	T.ok(m.cogBtn.hl and m.compactBtn.hl, "our own bronze buttons instead")
	T.ok(m.cogBtn:GetParent() == m and m.cogBtn:IsShown(), "on the title bar")
	local dropped = 0
	for _, f in ipairs(h.Frames()) do
		if f.__kind == "Button" and f:GetParent() == nil and not f:IsShown() then dropped = dropped + 1 end
	end
	T.ok(dropped >= 2, "the failed chevron and cog are hidden and unparented")
	T.clean(h)
end

function cases.toc_names_the_app_icon()
	local toc = io.open("RestedLeveling.toc"):read("*a")
	T.has(toc, "## IconTexture: Interface\\AddOns\\RestedLeveling\\media\\icon", "the addon list shows our icon")
	T.lacks(toc, "## IconAtlas", "no atlas")
	for _, f in ipairs({ "icon", "logo", "close", "chevron", "cog", "lock", "unlock" }) do
		local file = io.open("media/" .. f .. ".tga", "rb")
		T.ok(file, "media/" .. f .. ".tga exists")
		if file then file:close() end
	end
end

return cases
