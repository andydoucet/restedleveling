-- Rested Leveling: saved data, events, snapshots and calibration for the logged-in character.

local addonName, ns = ...
local U, M, I, S = ns.Util, ns.Model, ns.Identity, ns.Snap

-- Internal events other modules listen to: "ROSTER_CHANGED", "LOGIN_DONE" (isLogin), "SESSION_CHANGED".
local CBH = LibStub("CallbackHandler-1.0")
ns.callbacks = CBH:New(ns)
function ns.Fire(event, ...) ns.callbacks:Fire(event, ...) end

local DB_VERSION = 3
local DEFAULTS = {
	style = "auto", compact = false, showGrey = true, minimap = { hide = false }, lowPct = 10,
}
ns.LOW_MIN, ns.LOW_MAX = 5, 50   -- the low-rest warning threshold, % of a full bar left

local POSITION_KEYS = { banner = true, toasts = true, menu = true }
local POINTS = { TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true, TOPLEFT = true, TOPRIGHT = true,
	BOTTOMLEFT = true, BOTTOMRIGHT = true }

local function tbl(v) return type(v) == "table" and v or {} end
local NUMS = { "xpMax", "xp", "rested", "level", "t", "ranks", "wasted", "sex" }

-- A saved character, repaired where it can be (numbers saved as strings), or nil when it is unusable.
local function normaliseChar(c)
	if type(c) ~= "table" then return nil end
	for _, k in ipairs(NUMS) do if c[k] ~= nil then c[k] = tonumber(c[k]) end end
	if type(c.full) ~= "string" then return nil end
	if not c.xpMax or c.xpMax <= 0 then
		if not c.atMax then return nil end
		c.xpMax = 1   -- a capped character keeps a nominal bar
	end
	return c
end

local loaded = false   -- normalised this session (never saved: a damaged file is repaired on every load)

-- The saved table, normalised once per load (keyed on d.version for migrations).
function ns.DB()
	if type(RestedLevelingDB) ~= "table" then RestedLevelingDB = {} end
	local d = RestedLevelingDB
	if loaded then return d end
	loaded = true
	d.__ready, d.xpTable, d.lastLogin, d.lastSeen = nil, nil, nil, nil   -- retired keys
	local from = tonumber(d.version) or 0
	if from < DB_VERSION then d.version = DB_VERSION end
	d.chars, d.calib, d.hidden, d.alertsOff, d.opts = tbl(d.chars), tbl(d.calib), tbl(d.hidden), tbl(d.alertsOff), tbl(d.opts)
	for k, v in pairs(DEFAULTS) do
		if d.opts[k] == nil or (type(v) == "table" and type(d.opts[k]) ~= "table") then
			d.opts[k] = (type(v) == "table") and U.Copy(v) or v
		end
	end
	-- v3 (ILL-1299): the minimap button shows with or without ElvUI. 1.2 hid it under ElvUI unless a second switch
	-- (default off, so nobody chose it) was on; that switch is gone. Only opts.minimap.hide, the player's own choice,
	-- hides it now, so the old flag is simply dropped.
	if from < 3 then d.opts.showMinimapWithElvUI = nil end
	-- v2 (ILL-1272): the low-rest threshold (whole %, 5..50) and the account filter (nil = all, "mine", or an id).
	local low = tonumber(d.opts.lowPct)
	d.opts.lowPct = low and U.Clamp(math.floor(low + 0.5), ns.LOW_MIN, ns.LOW_MAX) or DEFAULTS.lowPct
	-- Notification positions (Alerts/Move.lua): only usable entries are kept.
	if type(d.positions) ~= "table" then d.positions = nil end
	for k, pos in pairs(d.positions or {}) do
		if not (POSITION_KEYS[k] and type(pos) == "table" and POINTS[pos.point] and POINTS[pos.relPoint]
			and U.Num(pos.x) and U.Num(pos.y)) then d.positions[k] = nil end
	end
	if d.opts.view ~= "timeline" then d.opts.view = nil end   -- the main window's view: roster (nil) or timeline
	local acc = d.opts.accounts
	if acc ~= "mine" and not (type(acc) == "string" and acc:match("^%x%x%x%x%x%x$")) then d.opts.accounts = nil end
	-- One SavedVariables file per WoW account, so this 6-hex id names the account the roster lives on.
	if type(d.account) ~= "string" or not d.account:match("^%x%x%x%x%x%x$") then
		d.account = ("%06x"):format((math.random(0, 0xffffff) + (time() or 0)) % 0x1000000)
	end
	for key, c in pairs(d.chars) do d.chars[key] = normaliseChar(c) end
	I.Dedupe(d.chars, d.hidden)
	return d
end

-- The label shown for an account: what the player set with /rlvl account, else a short id.
function ns.AccountLabel(id)
	local d = ns.DB()
	local labels = d.accountLabels or {}
	if labels[id] then return labels[id] end
	return "Acct " .. tostring(id or "?"):sub(1, 3):upper()
end

-- Every account that has characters in the roster, this one first, then by label: { id, label, mine, n }.
function ns.Accounts()
	local d, n = ns.DB(), {}
	n[d.account] = 0
	for _, c in pairs(d.chars) do
		local a = c.account or d.account
		n[a] = (n[a] or 0) + 1
	end
	local out = {}
	for id, count in pairs(n) do out[#out + 1] = { id = id, label = ns.AccountLabel(id), mine = id == d.account, n = count } end
	table.sort(out, function(a, b)
		if a.mine ~= b.mine then return a.mine end
		return a.label < b.label
	end)
	return out
end

-- The account the roster is filtered to, or nil for all. A filter naming an account that has no characters any more
-- (unlinked and pruned) shows all rather than an empty roster.
function ns.AccountFilter()
	local d = ns.DB()
	local f = d.opts.accounts
	if f == "mine" or f == d.account then return d.account end
	if not f then return nil end
	for _, c in pairs(d.chars) do if c.account == f then return f end end
	return nil
end

-- The one way an account is named on screen: "Account 3" for a "#3" label, else the label as set.
function ns.AccountName(id)
	local label = ns.AccountLabel(id)
	return label:match("^#(%d+)$") and ("Account " .. label:sub(2)) or label
end

-- "All accounts", "This account" or the peer's name, for the footer control, its tip and the options.
function ns.AccountFilterLabel()
	local f = ns.AccountFilter()
	if not f then return "All accounts" end
	if f == ns.DB().account then return "This account" end
	return ns.AccountName(f)
end

local myKey   -- canonical key of the logged-in character, once resolved
local ready = false

function ns.MyKey() return myKey end
function ns.Ready() return ready end
function ns.Me() return myKey and ns.DB().chars[myKey] or nil end

local function resolveKey()
	local d = ns.DB()
	local who = S.Who(d)
	if not who.full then return nil, who end
	myKey = I.Resolve(d.chars, who, d.hidden)
	return myKey, who
end

-- Record the logged-in character. `online` is false for the logout snapshot.
function ns.Snapshot(online)
	local d = ns.DB()
	local key, who = resolveKey()
	if not key then return end
	local c = d.chars[key] or { key = key }
	local now = time()
	if S.Capture(c, who, online, now, ns.levelOverride) then
		c.account = d.account
		c.src = "local"
	end
	d.chars[key] = c
	ns.Fire("ROSTER_CHANGED")
end

function ns.UpdateRank()
	local c = ns.Me()
	if not c then return end
	local rank = S.ReadWellRested()
	if rank == nil then return end
	if c.ranks ~= nil and rank ~= c.ranks then
		U.Print(("Well Rested on %s is now rank %d."):format(c.full or "?", rank))
	end
	c.ranks, c.rankRead = rank, true
end

-- Compare the saved projection with the real value at login, and learn the rate or cap from the difference.
local function calibrate()
	local d = ns.DB()
	local c = ns.Me()
	if not c then return end
	local new, reason = M.Calibrate(c, U.Num(U.Call(GetXPExhaustion)), U.Num(U.Call(UnitXPMax, "player")),
		U.Num(U.Call(UnitLevel, "player")), time(), S.ReadWellRested(), d.calib)
	if reason then d.calib = new end
end

-- This session on the logged-in character: rested used and the recent per-kill bonuses (Rested Watch).
function ns.SessionStart(fresh)
	local d = ns.DB()
	local s = d.session
	if fresh or not s or s.key ~= myKey then
		s = { key = myKey, start = time(), used = 0, bonuses = {} }
		d.session = s
	end
	s.last = U.Num(U.Call(GetXPExhaustion)) or 0
end

function ns.TrackRested(xpEvent)
	local s = ns.DB().session
	if not s or s.key ~= myKey or s.last == nil then return end
	local r = U.Num(U.Call(GetXPExhaustion)) or 0
	if r < s.last then
		if not xpEvent then return end   -- drops are counted when the XP arrives
		local used = s.last - r
		s.used = s.used + used
		s.bonuses[#s.bonuses + 1] = used
		if #s.bonuses > 20 then table.remove(s.bonuses, 1) end
		ns.Fire("SESSION_CHANGED", r, used)
	end
	s.last = r
end

-- Live numbers for the current-character strip: rested XP, levels, kills at double XP left, used this session.
function ns.Session()
	local d = ns.DB()
	local s = d.session
	local xpMax = U.Num(U.Call(UnitXPMax, "player"))
	if not xpMax or xpMax <= 0 then return nil end
	local r = U.Num(U.Call(GetXPExhaustion)) or 0
	local out = { rested = r, xpMax = xpMax, levels = r / xpMax, used = 0 }
	if s and s.key == myKey then
		out.used = s.used
		local sum = 0
		for _, b in ipairs(s.bonuses) do sum = sum + b end
		if #s.bonuses > 0 and sum > 0 then out.kills = math.ceil(r / (sum / #s.bonuses)) end
	end
	return out
end

local frame = CreateFrame("Frame")
ns.eventFrame = frame
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_LEAVING_WORLD",
	"PLAYER_UPDATE_RESTING", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "ZONE_CHANGED_NEW_AREA",
	"PLAYER_CAMPING", "PLAYER_QUITING", "TRAIT_CONFIG_UPDATED" }) do
	pcall(frame.RegisterEvent, frame, e)
end

local function login(isLogin)
	local d = ns.DB()
	resolveKey()
	local mine = ns.Me()
	if isLogin and mine and mine.t then
		-- Count the time this character sat full while logged out, for the "wasted" tidbit.
		local p = M.Project(mine, time(), d.calib)
		if p and p.left == 0 and p.fullSince then mine.wasted = (mine.wasted or 0) + math.max(0, time() - p.fullSince) end
		calibrate()
		mine.lastLogoutOutside = mine.resting == false
	end
	ready = true
	ns.Snapshot(true)
	ns.SessionStart(isLogin)
	ns.UpdateRank()
	C_Timer.After(15, ns.UpdateRank)   -- the Legacy tree can load late
	ns.Fire("LOGIN_DONE", isLogin)
end

frame:SetScript("OnEvent", function(_, event, a1, a2)
	if event == "ADDON_LOADED" then
		if a1 == addonName then ns.DB() end
		return
	elseif event == "PLAYER_ENTERING_WORLD" then
		if a1 or a2 then
			C_Timer.After(2, function() login(a1 and true or false) end)
		elseif ready then
			ns.Snapshot(true)
		end
		return
	elseif event == "TRAIT_CONFIG_UPDATED" then
		ns.UpdateRank()
	elseif event == "PLAYER_LEVEL_UP" then
		ns.levelOverride = U.Num(a1)   -- UnitLevel can lag the event by a moment
	end
	if not ready then return end
	if event == "PLAYER_XP_UPDATE" or event == "UPDATE_EXHAUSTION" then
		ns.TrackRested(event == "PLAYER_XP_UPDATE")
	end
	if event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
		ns.Snapshot(false)
	else
		-- Camping/quitting included: XP is already gone by PLAYER_LOGOUT, so this is the last good reading.
		ns.Snapshot(true)
	end
	ns.Fire("GAME_EVENT", event)
end)

C_Timer.NewTicker(60, function()
	if ready then ns.Snapshot(true) end
	ns.Fire("TICK")
end)

-- Rows for display: everyone but the logged-in character, sorted play-next first, on the shown account(s) only
-- (hero, roster, compact, datatext, timeline). The account filter is a view filter: alerts pass allAccounts, so a fill
-- or "play next" is never held back (or replayed later) because of what the window was showing.
function ns.Rows(opts)
	local d = ns.DB()
	opts = opts or {}
	return M.BuildRows(d.chars, opts.now or time(), d.calib, {
		me = myKey, hidden = d.hidden, target = d.opts.target, maxLevel = S.MaxLevel(),
		account = not opts.allAccounts and ns.AccountFilter() or nil, myAccount = d.account,
		hideGrey = opts.hideGrey ~= nil and opts.hideGrey or not d.opts.showGrey,
	})
end
