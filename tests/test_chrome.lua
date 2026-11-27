-- ILL-1299: the minimap button (shown with or without ElvUI) and the title bar's X / cog / chevron.

local W = dofile("tests/world.lua")
local D = 86400

local function alt(full, levels, ago, resting)
	return { full = full, class = "MAGE", race = "Scourge", sex = 3, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = resting, restKind = resting and "inn" or "outside", t = W.NOW - ago }
end

-- A minimal ElvUI whose Skins module accepts every S:Handle* call.
local function elvui()
	local S = setmetatable({}, { __index = function() return function() end end })
	local E = { media = {} }
	function E:GetModule(name) if name == "Skins" then return S end end
	return { E }
end

local cases = {}

-- opts: saved options; version: the saved data's version; withElvUI: ElvUI loaded; positions: saved positions.
-- LibDBIcon is loaded from the TOC; its Show / Hide are recorded (in `minimap`, in order) before our login work runs.
local function stubbedWorld(opts, version, withElvUI, positions)
	local saved = { version = version, opts = opts or {}, positions = positions, chars = {
		["N:Le Nette@?"] = alt("Le Nette", 1.5, 2 * D, true),
		["N:Le Dette@?"] = alt("Le Dette", 0.5, D, true),
	} }
	local minimap = {}
	local state = { saved = saved, noLogin = true, setup = function(game, h)
		if withElvUI then rawset(h.Env(), "ElvUI", elvui()) end
		game.UISpecialFrames = {}
		game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
		game.SetPortraitTexture = function() end
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
	local h, state = stubbedWorld()
	local env = h.Env()
	local opened = 0
	state.ns.OpenOptions = function() opened = opened + 1 end
	local feed = env.LibStub("LibDataBroker-1.1"):GetDataObjectByName("RestedLeveling")
	T.has(feed.icon, "media\\icon", "the app icon")
	feed.OnClick(nil, "LeftButton")
	T.ok(env.RestedLevelingMain:IsShown(), "left-click opens the window")
	feed.OnClick(nil, "LeftButton")
	T.ok(not env.RestedLevelingMain:IsShown(), "and closes it")
	feed.OnClick(nil, "RightButton")
	T.eq(opened, 1, "right-click opens the settings")
	local button = env.CreateFrame("Button", "LibDBIcon10_RestedLeveling", env.Minimap)
	feed.OnEnter(button)
	T.eq(env.RestedLevelingTip.hint:GetText(), "Left-click: open  ·  Right-click: settings  ·  Drag: move", "minimap hint")
	feed.OnEnter(env.CreateFrame("Frame", nil, env.UIParent))
	T.eq(env.RestedLevelingTip.hint:GetText(), "Left-click: open  ·  Right-click: settings", "a datatext can't be dragged")
	T.clean(h)
end

-- Right to left: X, cog, chevron; one size, 5 px apart, each centred on the one to its right.
function cases.title_bar_has_chevron_cog_and_close()
	local h, state = stubbedWorld()
	local opened = 0
	state.ns.OpenOptions = function() opened = opened + 1 end
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
	T.eq(opened, 1, "the cog opens the settings")
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
	c:Show()
	FakeWoW.RunScript(c.compactBtn, "OnClick")
	T.ok(env.RestedLevelingMain:IsShown() and not c:IsShown(), "chevron down: the full window")
	T.ok(not W.DB(h).opts.compact, "compact mode off")
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
