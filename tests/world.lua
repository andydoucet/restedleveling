-- A fake game with Rested Leveling loaded from its TOC, logged in on one character. Shared by the test files.
-- `state` is live: tests change it (resting, rested, level, realm...) and fire events.

local W = {}

-- Every Lua file the TOC loads, in order.
function W.TocFiles()
	local files = {}
	for line in io.lines("RestedLeveling.toc") do
		line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" and not line:find("^#") and line:find("%.lua$") then files[#files + 1] = (line:gsub("\\", "/")) end
	end
	return files
end

local function exists(path)
	local f = io.open(path, "r")
	if f then f:close() end
	return f ~= nil
end

-- A fake client with only the pure modules loaded (for model tests). Files not in this checkout are skipped.
function W.Pure(files)
	local game, h = FakeWoW.New()
	local ns = {}
	for _, f in ipairs(files or { "Core/Util.lua", "Core/Model.lua", "Core/Identity.lua" }) do
		if exists(f) then h.Load(f, "RestedLeveling", ns) end
	end
	return ns, game, h
end

W.NOW = 1794600000

function W.New(state)
	state = state or {}
	local game, h = FakeWoW.New()
	local env = h.Env()
	env.__clock = state.now or W.NOW
	env.__now = 1000
	local timers, tickers = {}, {}
	state.timers, state.tickers = timers, tickers
	game.C_Timer = {
		After = function(_, fn) timers[#timers + 1] = fn end,
		NewTicker = function(_, fn) tickers[#tickers + 1] = fn; return { Cancel = function() end } end,
	}
	game.UnitName = function() return state.first or "Le", state.surname or "Jette" end
	game.UnitNameUnmodified = function() return state.first or "Le", state.surname or "Jette" end
	game.UnitGUID = function() return state.guid end
	game.GetRealmName = function()
		if state.secretRealm then return FakeWoW.Secret("realm") end
		return state.realm or ""
	end
	if state.saved then rawset(env, "RestedLevelingDB", state.saved) end   -- saved variables, not a client name
	game.UnitClass = function() return "Warrior", state.class or "WARRIOR" end
	game.UnitRace = function() return "Human", "Human" end
	game.UnitSex = function() return 2 end
	game.UnitFactionGroup = function() return "Alliance" end
	game.UnitLevel = function() return state.level or 30 end
	game.UnitXP = function() return state.xp or 2000 end
	game.UnitXPMax = function() if state.loggingOut then return 0 end return state.xpMax or 10000 end
	game.GetXPExhaustion = function() if state.loggingOut then return nil end return state.rested or 1000 end
	game.IsResting = function() return state.resting or false end
	game.GetMaxPlayerLevel = function() return 60 end
	game.GetRealZoneText = function() return state.zone or "Elwynn Forest" end
	game.GetSubZoneText = function() return state.subzone or "Goldshire" end
	game.C_UnitAuras = { GetPlayerAuraBySpellID = function(id)
		if id == 429959 and state.bagBuff then
			return { expirationTime = 1000 + state.bagBuff, duration = state.bagBuff + (state.bagApplied or 0) }
		end
	end }
	state.sent = {}
	if FakeWoW.Has("C_ChatInfo") then game.C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return 0 end,
		SendAddonMessage = function(prefix, text, channel, target)
			state.sent[#state.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
			return 0
		end,
	} end
	if FakeWoW.Has("IsInGuild") then
		game.IsInGuild = function() return state.guild or false end
		game.IsInGroup = function() return false end
		game.IsInRaid = function() return false end
	end
	if state.setup then state.setup(game, h, state) end

	state.ns = state.ns or {}
	for _, f in ipairs(state.files or W.TocFiles()) do h.Load(f, "RestedLeveling", state.ns) end
	h.Fire("ADDON_LOADED", "RestedLeveling")
	if state.noLogin then return game, h, state end
	W.Login(h, state, true)
	return game, h, state
end

-- Fire the login (or reload) sequence and run the delayed work.
function W.Login(h, state, isLogin)
	h.Fire("PLAYER_ENTERING_WORLD", isLogin and true or false, (not isLogin) and true or false)
	W.RunTimers(state)
end

function W.RunTimers(state)
	while #state.timers > 0 do
		local fn = table.remove(state.timers, 1)
		fn()
	end
end

function W.Tick(state) for _, fn in ipairs(state.tickers) do fn() end end

function W.Advance(h, seconds) h.Env().__clock = h.Env().__clock + seconds end

function W.DB(h) return h.Env().RestedLevelingDB end

-- The one character record matching a full name.
function W.Char(h, full)
	local found, n = nil, 0
	for _, c in pairs(W.DB(h).chars) do
		if c.full == full then found, n = c, n + 1 end
	end
	return found, n
end

return W
