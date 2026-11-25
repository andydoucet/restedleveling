-- Rested Leveling: who a character is. Pure functions (the game values are passed in already sanitized).
--
-- Forever hides the realm (empty string or a secret value since the Nov 2026 hotfix), which made Rested Watch
-- 1.4.7/1.4.8 save the same character twice. So a character is keyed by its GUID when the game will say it,
-- else by full name + the last realm seen. Records saved under an older or weaker key are folded into the
-- canonical one, newest snapshot winning, so the roster never shows a character twice.

local _, ns = ...
local I = {}
ns.Identity = I

-- Forever characters have surnames. UnitName/UnitNameUnmodified return (name, second); on Forever the second value
-- is the surname rather than a realm, and the name itself may already carry the surname after a separator.
-- Returns full ("Le Jette"), first ("Le"), surname ("Jette" or nil).
function I.FullName(n1, n2, realm)
	if type(n1) ~= "string" or n1 == "" then return nil end
	local first, sur = n1:match("^([^%s%-]+)[%s%-]+(.+)$")
	if not first then first = n1 end
	if not sur and type(n2) == "string" and n2 ~= "" and n2 ~= realm then sur = n2 end
	if sur then return first .. " " .. sur, first, sur end
	return first, first, nil
end

local function realmPart(realm) return realm or "?" end

-- The canonical key: "G:<guid>" when known, else "N:<full>@<realm or ?>".
function I.Key(guid, full, realm)
	if guid then return "G:" .. guid end
	return "N:" .. tostring(full) .. "@" .. realmPart(realm)
end

-- Two records are the same character when their GUIDs match, or (lacking a GUID on either side) their full
-- names and classes match and their realms match or one is unknown.
function I.Same(a, b)
	if a.guid and b.guid then return a.guid == b.guid end
	if not a.full or a.full ~= b.full then return false end
	if a.class and b.class and a.class ~= b.class then return false end
	return a.realm == nil or b.realm == nil or a.realm == b.realm
end

-- Merge two records of the same character: the newer snapshot wins, and anything it lacks is kept from the older.
function I.Merge(a, b)
	local new, old = a, b
	if (b.t or 0) > (a.t or 0) then new, old = b, a end
	local out = {}
	for k, v in pairs(old) do out[k] = v end
	for k, v in pairs(new) do out[k] = v end
	out.guid = new.guid or old.guid
	out.realm = new.realm or old.realm
	out.wasted = math.max(new.wasted or 0, old.wasted or 0)
	return out
end

-- Find (and fold together) every saved record that is this character, store it under the canonical key and
-- return that key. `info` carries guid, full, realm, class. Keys of folded records are moved in `hidden` too.
function I.Resolve(chars, info, hidden)
	local probe = { guid = info.guid, full = info.full, realm = info.realm, class = info.class }
	local key = I.Key(info.guid, info.full, info.realm)
	if not info.guid then
		-- GUID unreadable this session: keep using the GUID key this character was saved under before.
		for k, c in pairs(chars) do
			if c.guid and I.Same(probe, c) then key = k; break end
		end
	end
	local merged = chars[key]
	for k, c in pairs(chars) do
		if k ~= key and I.Same(probe, c) then
			merged = merged and I.Merge(merged, c) or c
			chars[k] = nil
			if hidden and hidden[k] then hidden[k], hidden[key] = nil, true end
		end
	end
	if merged then
		merged.guid = merged.guid or info.guid
		merged.realm = merged.realm or info.realm
		merged.key = key
		chars[key] = merged
	end
	return key
end

-- Fold any duplicates already in a roster (from older versions or from sync). Returns how many were removed.
function I.Dedupe(chars, hidden)
	local removed = 0
	local keys = {}
	for k in pairs(chars) do keys[#keys + 1] = k end
	table.sort(keys)   -- "G:" sorts before "N:", so GUID keys are kept as canonical
	for i = 1, #keys do
		local ka = keys[i]
		local a = chars[ka]
		if a then
			for j = i + 1, #keys do
				local kb = keys[j]
				local b = chars[kb]
				if b and I.Same(a, b) then
					a = I.Merge(a, b)
					a.key = ka
					chars[ka], chars[kb] = a, nil
					if hidden and hidden[kb] then hidden[kb], hidden[ka] = nil, true end
					removed = removed + 1
				end
			end
		end
	end
	return removed
end

return I
