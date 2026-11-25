-- Rested Leveling: reading the logged-in character from the game.
-- The Well Rested rank reader and the Cozy Sleeping Bag logic come from Rested Watch 1.4.8 by doc_biddle (GPL-3.0).

local _, ns = ...
local U, I = ns.Util, ns.Identity
local S = {}
ns.Snap = S

-- The Legacy trees are a talent tree on the trait system (system 45). Find "Well Rested" and read its rank.
local LEGACY_SYSTEM = 45
local LEGACY_TREES = { 1186, 1187, 1188, 1189, 1190 }   -- the Adventure tree is 1188

local function entryName(configID, entryID)
	local entry = U.Call(C_Traits.GetEntryInfo, configID, entryID)
	local def = entry and entry.definitionID and U.Call(C_Traits.GetDefinitionInfo, entry.definitionID)
	local name = def and def.overrideName
	if (not name or name == "") and def then
		local spell = def.spellID or def.overriddenSpellID
		name = spell and C_Spell and U.Call(C_Spell.GetSpellName, spell)
	end
	return U.Str(name)
end

function S.ReadWellRested()
	if not (C_Traits and C_Traits.GetConfigIDBySystemID) then return nil end
	local configID = U.Call(C_Traits.GetConfigIDBySystemID, LEGACY_SYSTEM)
	if not configID or configID == 0 then return nil end
	local cfg = U.Call(C_Traits.GetConfigInfo, configID)
	local trees = (cfg and cfg.treeIDs) or {}
	if #trees == 0 then trees = LEGACY_TREES end
	for _, treeID in ipairs(trees) do
		for _, nodeID in ipairs(U.Call(C_Traits.GetTreeNodes, treeID) or {}) do
			local node = U.Call(C_Traits.GetNodeInfo, configID, nodeID)
			if node then
				local ids = {}
				if node.activeEntry and node.activeEntry.entryID then ids[#ids + 1] = node.activeEntry.entryID end
				for _, e in ipairs(node.entryIDs or {}) do ids[#ids + 1] = e end
				for _, entryID in ipairs(ids) do
					local name = entryName(configID, entryID)
					if name and name:lower():gsub("[^a-z]", "") == "wellrested" then
						return node.activeRank or node.currentRank or 0
					end
				end
			end
		end
	end
	return nil
end

-- The Cozy Sleeping Bag's buff, Well-Rested (spell 429959): stacks once a minute on the bag, lasts 2 hours.
-- Returns seconds left and seconds since the last stack.
S.BAG_SPELL = 429959
local BAG_FRESH = 90   -- a stack this recent means you're on the bag, which counts as an inn

function S.BagBuff()
	if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
	local a = U.Call(C_UnitAuras.GetPlayerAuraBySpellID, S.BAG_SPELL)
	if not a then return nil end
	local now = GetTime()
	local exp = U.Num(a.expirationTime) or 0
	local dur = U.Num(a.duration) or 0
	return math.max(0, exp - now), dur > 0 and (now - (exp - dur)) or nil
end

function S.OnBag()
	local left, since = S.BagBuff()
	return left ~= nil and left > 0 and since ~= nil and since <= BAG_FRESH
end

function S.RestingNow()
	return U.Call(IsResting) == true or S.OnBag()
end

-- Capital cities count as "city" for the location badge; any other resting place is an inn.
local CAPITALS = {
	["Stormwind City"] = true, ["Ironforge"] = true, ["Darnassus"] = true,
	["Orgrimmar"] = true, ["Thunder Bluff"] = true, ["Undercity"] = true,
}
function S.RestKind(zone)
	if S.OnBag() and U.Call(IsResting) ~= true then return "bag" end
	if U.Call(IsResting) ~= true then return "outside" end
	if zone and CAPITALS[zone] then return "city" end
	return "inn"
end

function S.MaxLevel()
	return U.Call(GetMaxLevelForPlayerExpansion) or U.Call(GetMaxPlayerLevel) or 60
end

function S.AtMaxLevel(level)
	return (level or U.Call(UnitLevel, "player") or 0) >= S.MaxLevel()
end

-- The realm, or nil when the game won't say (Forever: empty or secret).
function S.Realm()
	return U.Str(U.Call(GetRealmName))
end

-- Who the logged-in character is: guid, full, first, surname, realm, class, race, sex, faction.
-- The realm falls back to the last one this account saw (`db.realm`) when hidden.
function S.Who(db)
	local n1, n2 = U.Call(UnitNameUnmodified or UnitName, "player")
	if not n1 then n1, n2 = U.Call(UnitName, "player") end
	local realm = S.Realm()
	if realm then db.realm = realm end
	realm = realm or db.realm
	local full, first, surname = I.FullName(U.Str(n1), U.Str(n2), realm)
	local _, class = U.Call(UnitClass, "player")
	local _, race = U.Call(UnitRace, "player")
	return {
		guid = U.Str(U.Call(UnitGUID, "player")),
		full = full, first = first, surname = surname, realm = realm,
		class = class, race = race, sex = U.Call(UnitSex, "player"),
		faction = U.Str(U.Call(UnitFactionGroup, "player")),
	}
end

-- Write the logged-in character's rested state into `c`. Identity, level and max level are read on their own, so a
-- character that just hit the cap (no XP bar: UnitXPMax is 0) is recorded at its new level and greys out.
-- `levelHint` is PLAYER_LEVEL_UP's level (UnitLevel can lag it). Returns false when the game has already cleared XP
-- below the cap (during logout): then only the time and online flag move, and the last good reading is kept.
function S.Capture(c, who, online, now, levelHint)
	for k, v in pairs(who) do c[k] = v end
	c.name = who.first
	local level = U.Num(U.Call(UnitLevel, "player"))
	if level and level > 0 then c.level = math.max(level, levelHint or 0) end
	c.atMax = S.AtMaxLevel(c.level)
	local xpMax = U.Num(U.Call(UnitXPMax, "player"))
	if not xpMax or xpMax <= 0 then
		if c.atMax then   -- capped: nothing left to rest for; a nominal xpMax keeps the record valid everywhere
			c.xpMax, c.xp, c.rested = (c.xpMax and c.xpMax > 0) and c.xpMax or 1, 0, 0
			c.t, c.online = now, online
			return true
		end
		if c.xpMax and c.xpMax > 0 then c.t = now; c.online = online end
		return false
	end
	c.xpMax = xpMax
	c.xp = U.Num(U.Call(UnitXP, "player")) or 0
	c.rested = U.Num(U.Call(GetXPExhaustion)) or 0
	c.zone = U.Str(U.Call(GetRealZoneText)) or c.zone
	c.subzone = U.Str(U.Call(GetSubZoneText))
	c.restKind = S.RestKind(c.zone)
	c.resting = c.restKind ~= "outside"
	c.t = now
	c.online = online
	return true
end

return S
