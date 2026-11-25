-- Offline-render fixture for wow-ui-sim: Andy's real roster as saved data, the logged-in character's identity and
-- a pinned clock so renders are the same every run. Loaded only into the render sandbox (tools/render.sh), never
-- installed in the game. Everything it sets is input data; all drawing is the real addon.

local T0 = 1795514400          -- pinned "now" (Tue 24 Nov 2026, 04:00 local in the sim)
local H, D = 3600, 86400
local startGT = GetTime()
local realTime = time
time = function(t) if t then return realTime(t) end return T0 + math.floor(GetTime() - startGT) end

-- The logged-in character: Jacques Hammer, level 24 Orc shaman, out in the Barrens, not resting.
RLFIX = { rested = 15200, xp = 9100, xpMax = 25200, level = 24, resting = false, first = "Jacques", surname = "Hammer" }
if RLFIX_CASE == "andy" then   -- Andy's first in-game run (ILL-1274): on Le Nette, level 1, nothing rested, outside
	RLFIX = { rested = 0, xp = 120, xpMax = 400, level = 1, resting = false, first = "Le", surname = "Nette" }
end
local function wrap(name, fn) local orig = _G[name]; _G[name] = function(...) return fn(orig, ...) end end
wrap("UnitNameUnmodified", function(o, u, ...) if u == "player" then return RLFIX.first, RLFIX.surname end return o(u, ...) end)
wrap("UnitName", function(o, u, ...) if u == "player" then return RLFIX.first, RLFIX.surname end return o(u, ...) end)
wrap("UnitLevel", function(o, u, ...) if u == "player" then return RLFIX.level end return o(u, ...) end)
wrap("UnitXP", function(o, u, ...) if u == "player" then return RLFIX.xp end return o(u, ...) end)
wrap("UnitXPMax", function(o, u, ...) if u == "player" then return RLFIX.xpMax end return o(u, ...) end)
wrap("UnitRace", function(o, u, ...) if u == "player" then return "Orc", "Orc", 2 end return o(u, ...) end)
wrap("UnitFactionGroup", function(o, u, ...) if u == "player" then return "Horde", "Horde" end return o(u, ...) end)
wrap("GetXPExhaustion", function() return RLFIX.rested end)
wrap("IsResting", function() return RLFIX.resting end)
wrap("GetRealmName", function() return "" end)            -- Forever hides the realm
wrap("GetRealZoneText", function() return "The Barrens" end)
wrap("GetSubZoneText", function() return "Southern Barrens" end)
wrap("GetMaxPlayerLevel", function() return 60 end)
if GetMaxLevelForPlayerExpansion then wrap("GetMaxLevelForPlayerExpansion", function() return 60 end) end
if GetBindLocation then wrap("GetBindLocation", function() return "Crossroads" end) end
if GetMoney then wrap("GetMoney", function() return 412345 end) end

local A, B = "a7c2e1", "3fb904"   -- account ids: Andy's WoW accounts #2 and #3
local function char(key, t)
	t.key, t.account, t.t = key, t.account or A, T0 - t.ago
	t.ago, t.faction, t.realm = nil, "Horde", nil
	t.first, t.surname = t.full:match("^(%S+)%s+(.+)$")
	t.name = t.first
	return t
end

-- Rested levels -> raw rested XP for a given xpMax.
local function lv(levels, xpMax) return math.floor(levels * xpMax) end

RestedLevelingDB = {
	version = 1, account = A, accountLabels = { [A] = "#2", [B] = "#3" },
	calib = { rate = 1.0, n = 3 }, opts = { style = RLFIX_STYLE or "auto", showGrey = true, minimap = { hide = false } },
	xpTable = { [22] = 23200, [21] = 21300, [19] = 17700, [17] = 14400, [15] = 11400, [12] = 7600, [6] = 2800 },
	hidden = {}, alertsOff = {},
	sync = { links = { Lebankken = true }, confirmed = { lebankken = B }, peers = { [B] = { name = "Lebankken", seen = T0 - 2 * D, lastSync = T0 - 2 * D, label = "#3" } } },
	chars = {
		-- Full for ~2 days in Brill's inn.
		["N:Le Nette@?"] = char("N:Le Nette@?", { full = "Le Nette", class = "MAGE", race = "Scourge", sex = 3, level = 22,
			xpMax = 23200, rested = lv(1.33, 23200), resting = true, restKind = "inn", zone = "Tirisfal Glades", subzone = "Brill",
			ranks = 3, ago = 4 * D + 2 * H, guild = "Pig and Whistle", wasted = 6 * H }),
		-- Full for ~9 hours in Thunder Bluff.
		["N:Le Beouf@?"] = char("N:Le Beouf@?", { full = "Le Beouf", class = "DRUID", race = "Tauren", sex = 2, level = 19,
			xpMax = 17700, rested = lv(1.12, 17700), resting = true, restKind = "city", zone = "Thunder Bluff", ranks = 2,
			ago = 3 * D + 11 * H }),
		-- 94% in an inn: yellow.
		["N:Le Dette@?"] = char("N:Le Dette@?", { full = "Le Dette", class = "WARLOCK", race = "Scourge", sex = 2, level = 21,
			xpMax = 21300, rested = lv(1.194, 21300), resting = true, restKind = "inn", zone = "The Barrens", subzone = "Crossroads",
			ranks = 3, ago = 2 * D + 7 * H }),
		-- 91% but parked outside: still yellow (fullness wins).
		["N:Amdo Moto@?"] = char("N:Amdo Moto@?", { full = "Amdo Moto", class = "ROGUE", race = "Troll", sex = 2, level = 17,
			xpMax = 14400, rested = lv(1.342, 14400), resting = false, restKind = "outside", zone = "Stonetalon Mountains",
			ranks = 1, ago = 2 * D }),
		-- Resting in Orgrimmar, 0.8 levels: orange.
		["N:Le Bankke@?"] = char("N:Le Bankke@?", { full = "Le Bankke", class = "WARRIOR", race = "Tauren", sex = 3, level = 12,
			xpMax = 7600, rested = lv(0.225, 7600), resting = true, restKind = "city", zone = "Orgrimmar", ranks = 0, ago = 3 * D + 20 * H }),
		-- Logged out in the wild: red, "park me".
		["N:Colonol Sunders@?"] = char("N:Colonol Sunders@?", { full = "Colonol Sunders", class = "HUNTER", race = "Troll", sex = 2,
			level = 15, xpMax = 11400, rested = lv(0.26, 11400), resting = false, restKind = "outside", zone = "Durotar", ago = 5 * D + 3 * H }),
		-- Account #3, synced two days ago: empty and outside.
		["N:Le Bankken@?"] = char("N:Le Bankken@?", { full = "Le Bankken", class = "WARRIOR", race = "Orc", sex = 2, level = 6,
			xpMax = 2800, rested = 0, resting = false, restKind = "outside", zone = "Durotar", subzone = "Razor Hill",
			account = B, src = "sync", via = B, syncedAt = T0 - 2 * D, ago = 2 * D + 1 * H }),
		-- The main, at the level cap: grey.
		["N:Le Jette@?"] = char("N:Le Jette@?", { full = "Le Jette", class = "WARRIOR", race = "Orc", sex = 2, level = 60,
			xpMax = 0, atMax = true, ago = 6 * D, ranks = 5 }),
	},
}
RestedLevelingDB.chars["N:Le Jette@?"].xpMax = 1   -- saved data needs a positive xpMax to be kept

-- Tidbits saved the last time each was logged in, and an hourly rest history (levels) for the card's sparkline.
local function history(c, startLevels, perHour, hours)
	c.history = {}
	for i = hours, 1, -1 do c.history[#c.history + 1] = { T0 - i * H, math.min(1.68, startLevels + perHour * (hours - i)) } end
end
local nette = RestedLevelingDB.chars["N:Le Nette@?"]
nette.played, nette.bind, nette.money = 3 * D + 4 * H + 12 * 60, "Brill", 1834512
nette.profs, nette.gearQ, nette.title = "Tailoring 145, Enchanting 120", "2 rare, 9 uncommon", nil
history(nette, 1.68, 0, 48)   -- full (cap 1.68 at Well Rested 3) for the whole 48 hours, as the roster says
local sunders = RestedLevelingDB.chars["N:Colonol Sunders@?"]
sunders.played, sunders.bind, sunders.money = D + 6 * H, "Razor Hill", 23400
sunders.profs, sunders.gearQ, sunders.guild = "Skinning 92, Leatherworking 88", "6 uncommon", "Pig and Whistle"
history(sunders, 0.2, 0.0016, 30)
local dette = RestedLevelingDB.chars["N:Le Dette@?"]
dette.played, dette.bind, dette.money, dette.profs = 2 * D + 19 * H, "Crossroads", 912300, "Herbalism 160, Alchemy 155"
if RLFIX_EMPTY then
	-- First run: only the account itself, nothing saved or synced yet.
	RestedLevelingDB = { version = 1, account = A, opts = { style = RLFIX_STYLE or "auto", minimap = { hide = false } } }
end
if RLFIX_CASE == "andy" then
	-- Andy's roster when he first ran v1: Le Jette, a level 46 gnome warrior, parked in the Feathermoon Stronghold inn
	-- five minutes ago with nothing banked yet, and her professions saved twice (the duplicate the card showed).
	RestedLevelingDB = { version = 1, account = A, accountLabels = { [A] = "#2" }, calib = { rate = 1.0, n = 1 },
		opts = { style = RLFIX_STYLE or "auto", showGrey = true, minimap = { hide = false } }, hidden = {}, alertsOff = {},
		chars = {
			["N:Le Jette@?"] = char("N:Le Jette@?", { full = "Le Jette", class = "WARRIOR", race = "Gnome", sex = 3, level = 46,
				xpMax = 80000, rested = 400, resting = true, restKind = "inn", zone = "Feralas", subzone = "Feathermoon Stronghold",
				ranks = 3, ago = 5 * 60, bind = "Feathermoon Stronghold", played = 5 * D + 15 * H, money = 63800,
				guild = "Exodar", gearQ = "5 rare, 11 uncommon",
				profs = "Blacksmithing 185, Blacksmithing 185, Mining 201, Mining 201, Cooking 216, Cooking 216, First Aid 276, First Aid 276, Fishing 183, Fishing 183, Riding 75" }),
		},
	}
end
if RLFIX_CASE == "look" then
	-- Saved looks (ILL-1279): Le Nette and Le Beouf each saved one. The sim has no screenshots and draws no 3D model,
	-- so each "screenshot" is a stand-in made the way the capture stage lays out (look_*.tga, 960x540: the stage's
	-- dark #0B0908 backdrop with a stock race portrait in the centred model square, at half the 1920x1080 size; the
	-- texcoords are fractions, so the size does not matter). Texture:SetTexture is redirected for those two names only.
	local box = { l = 0.3667, r = 0.6333, t = 0.263, b = 0.737 }
	local function look(file, ago)
		local t = { file = file, at = T0 - ago, asked = T0 - ago - 1 }
		for k, v in pairs(box) do t[k] = v end
		return t
	end
	RestedLevelingDB.chars["N:Le Nette@?"].look = look("WoWScrnShot_112026_211430.tga", 4 * D + 2 * H)
	RestedLevelingDB.chars["N:Le Beouf@?"].look = look("WoWScrnShot_112026_174502.tga", 3 * D + 11 * H)
	local FIX = "Interface\\AddOns\\!RLSimFixture\\"
	local stand = { ["WoWScrnShot_112026_211430.tga"] = FIX .. "look_nette.tga", ["WoWScrnShot_112026_174502.tga"] = FIX .. "look_beouf.tga" }
	local idx = getmetatable(UIParent:CreateTexture()).__index
	local set = idx.SetTexture
	local fileID = idx.GetTextureFileID
	idx.SetTexture = function(self, file, ...)
		local name = type(file) == "string" and file:match("^Screenshots\\(WoWScrnShot_[%d_]+%.tga)$")
		self.rlStand = name and stand[name] and true or nil
		return set(self, (name and stand[name]) or file, ...)
	end
	-- The sim gives a loose .tga no file ID; in game the screenshot has one (-18422 in the ILL-1276 probe), and
	-- SaveLook draws a look only when it does. Only the two stand-ins get one here.
	idx.GetTextureFileID = function(self, ...)
		if self.rlStand then return -18422 end
		return fileID and fileID(self, ...)
	end
end
