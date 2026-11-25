-- Rested Leveling: the cross-account sync wire format and merge rules. Pure functions, tested headless.
--
-- Received data is only ever parsed, field by field, against a fixed schema: never executed (no loadstring), and
-- any record that breaks the schema is dropped whole. Unknown fields (from a newer version) are skipped, up to a
-- few per record, so VERSION changes only on a breaking change. Other modules add fields to the schema (Codec.FIELDS).

local _, ns = ...
local U, I, LD = ns.Util, ns.Identity, ns.LookData
local C = {}
ns.Codec = C

C.VERSION = "1"
C.MAX_STR = 48
C.MAX_UNKNOWN = 8   -- unknown fields skipped per record before the record is dropped

-- Field name -> type: "s" string, "n" number, "b" boolean. Short wire names keep messages small.
C.FIELDS = {
	key = { "k", "s" }, guid = { "g", "s" }, full = { "f", "s" }, first = { "fn", "s" }, surname = { "sn", "s" },
	realm = { "rm", "s" }, class = { "c", "s" }, race = { "ra", "s" }, sex = { "sx", "n" }, faction = { "fa", "s" },
	level = { "l", "n" }, xp = { "x", "n" }, xpMax = { "xm", "n" }, rested = { "r", "n" }, resting = { "rs", "b" },
	restKind = { "rk", "s" }, atMax = { "am", "b" }, t = { "t", "n" }, ranks = { "wr", "n" }, account = { "a", "s" },
	zone = { "z", "s" }, subzone = { "zz", "s" }, wasted = { "w", "n" }, online = { "o", "b" },
	-- the saved look (Core/Look.lua packs c.look into these four; an older version skips them as unknown), and
	-- lookCleared: the owner pressed Clear look (a record without the four fields keeps the look it had)
	lookFile = { "lf", "s" }, lookBox = { "lc", "s" }, lookAt = { "la", "n" }, lookAsked = { "lq", "n" },
	lookCleared = { "ln", "b" },
}

local function wireIndex()
	local out = {}
	for name, def in pairs(C.FIELDS) do out[def[1]] = { name, def[2] } end
	return out
end

-- Escaping keeps the separators (";" between fields, "=" inside one, "^" between records) out of values, and
-- "|" (the chat escape character) out of the message entirely.
local ESC = { ["~"] = "~~", [";"] = "~s", ["="] = "~e", ["^"] = "~r", ["|"] = "~p" }
local UNESC = { ["~"] = "~", s = ";", e = "=", r = "^", p = "|" }
local function esc(s) return (s:gsub("[~;=%^|]", ESC)) end
local function unesc(s)
	local bad = false
	local out = s:gsub("~(.?)", function(ch)
		local v = UNESC[ch]
		if not v then bad = true return "" end
		return v
	end)
	if bad then return nil end
	return out
end

local function fmtNum(n)
	if n == math.floor(n) and math.abs(n) < 1e15 then return ("%d"):format(n) end
	return ("%.6g"):format(n)
end

function C.EncodeRecord(c)
	local parts = {}
	local names = {}
	for name in pairs(C.FIELDS) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		local def, v = C.FIELDS[name], c[name]
		if v ~= nil then
			local tv = type(v)
			if def[2] == "s" and tv == "string" then parts[#parts + 1] = def[1] .. "=" .. esc(U.Truncate(v, C.MAX_STR))
			elseif def[2] == "n" and tv == "number" and v == v then parts[#parts + 1] = def[1] .. "=" .. fmtNum(v)
			elseif def[2] == "b" and tv == "boolean" then parts[#parts + 1] = def[1] .. "=" .. (v and "1" or "0") end
		end
	end
	return table.concat(parts, ";")
end

-- Sanity limits a record must meet, beyond field types.
local function valid(c, now)
	if type(c.key) ~= "string" or not c.key:match("^[GN]:") then return false end
	if type(c.full) ~= "string" or type(c.t) ~= "number" or type(c.xpMax) ~= "number" then return false end
	if c.xpMax <= 0 or c.xpMax > 1e8 then return false end
	if c.level and (c.level < 1 or c.level > 100) then return false end
	if c.rested and (c.rested < 0 or c.rested > c.xpMax * 3) then return false end
	if c.ranks and (c.ranks < 0 or c.ranks > 10) then return false end
	if c.t < 1e9 or (now and c.t > now + 86400) then return false end
	if now and c.t > now then c.t = now end   -- clock skew: never newer than our own now
	if c.class and not c.class:match("^[A-Z]+$") then return false end
	return true
end

-- One record, or nil if anything about it is off.
function C.DecodeRecord(s, now)
	if type(s) ~= "string" or s == "" or #s > 2000 then return nil end
	local idx = wireIndex()
	local c, unknown = {}, 0
	for field in (s .. ";"):gmatch("([^;]*);") do
		local k, raw = field:match("^([%a]+)=(.*)$")
		if not k then return nil end                        -- malformed field
		local def = idx[k]
		if not def then   -- a field from a newer version: skip it, a few at most
			unknown = unknown + 1
			if unknown > C.MAX_UNKNOWN then return nil end
		else
			local name, kind = def[1], def[2]
			local v = unesc(raw)
			if v == nil or c[name] ~= nil then return nil end
			if kind == "n" then
				if not v:match("^%-?%d+%.?%d*e?[%-+]?%d*$") then return nil end
				v = tonumber(v)
				if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
			elseif kind == "b" then
				if v ~= "0" and v ~= "1" then return nil end
				v = (v == "1")
			elseif #v > C.MAX_STR then
				return nil
			end
			c[name] = v
		end
	end
	if not valid(c, now) then return nil end
	return LD.Unpack(c)   -- a look that fails its checks is dropped, the record kept
end

-- A whole roster: version, sender account, then records. Returns the string.
function C.EncodeRoster(chars, account)
	local out = { C.VERSION, esc(tostring(account or "?")) }
	local keys = {}
	for k in pairs(chars) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local c = LD.Pack(U.Copy(chars[k]))
		c.key = k
		out[#out + 1] = C.EncodeRecord(c)
	end
	return table.concat(out, "^")
end

-- Returns account, records (list) or nil for a wrong version / malformed header. Bad records are skipped.
function C.DecodeRoster(s, now)
	if type(s) ~= "string" then return nil end
	local parts = {}
	for p in (s .. "^"):gmatch("([^%^]*)%^") do parts[#parts + 1] = p end
	if parts[1] ~= C.VERSION or not parts[2] then return nil end
	local account = unesc(parts[2])
	if not account or not account:match("^[%w]+$") then return nil end
	local recs, dropped = {}, 0
	for i = 3, #parts do
		local c = C.DecodeRecord(parts[i], now)
		if c then recs[#recs + 1] = c else dropped = dropped + 1 end
	end
	return account, recs, dropped
end

-- Fold received records into `chars`: per character, the newer snapshot wins. Records of `myAccount`'s own
-- characters coming back keep their local tag. Returns how many changed.
function C.Merge(chars, recs, via, now, hidden, myAccount)
	local changed = 0
	for _, r in ipairs(recs) do
		local key = r.key
		local mine = chars[key]
		if not mine then
			-- Maybe saved under another key (hidden realm, GUID read later): resolve by identity first.
			for k, c in pairs(chars) do
				if I.Same(r, c) then key, mine = k, c break end
			end
		end
		local ours = myAccount and ((mine and mine.account == myAccount) or r.account == myAccount)
		if not ours and (not mine or (r.t or 0) > (mine.t or 0)) then   -- a remote record never overwrites ours
			local merged = mine and I.Merge(mine, r) or r
			merged.key = key
			-- The owner's look: a new one replaces it, Clear look clears it, and a record without one (an older
			-- version, or a sender that never had it) keeps the one we have.
			if r.look then
				merged.look, merged.lookCleared = r.look, nil
			elseif r.lookCleared then
				merged.look, merged.lookCleared = nil, true
			else
				merged.look, merged.lookCleared = mine and mine.look, mine and mine.lookCleared
			end
			if r.account and r.account == myAccount then
				merged.src, merged.via, merged.syncedAt = "local", nil, nil
			else
				merged.src, merged.via, merged.syncedAt = "sync", via, now
			end
			chars[key] = merged
			changed = changed + 1
		end
	end
	if changed > 0 then I.Dedupe(chars, hidden) end
	return changed
end

-- A short fingerprint of what a roster knows (each key with its snapshot time, in 15-minute steps so the online
-- character's constant updates do not defeat the resend guard, and when its look was saved). Equal digests: nothing
-- to swap.
function C.Digest(chars)
	local keys = {}
	for k, c in pairs(chars) do
		local look = type(c.look) == "table" and ("L" .. tostring(c.look.at)) or ""
		keys[#keys + 1] = k .. "@" .. tostring(math.floor((c.t or 0) / 900)) .. look
	end
	table.sort(keys)
	return ("%08x"):format(U.Hash(table.concat(keys, ",")))
end

-- Split a payload into chunks of at most `size` bytes.
function C.Chunk(payload, size)
	local out = {}
	for i = 1, #payload, size do out[#out + 1] = payload:sub(i, i + size - 1) end
	if #out == 0 then out[1] = "" end
	return out
end

return C
