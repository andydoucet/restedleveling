-- Rested Leveling: character tidbits for the card and tooltips (/played, hearth, gold, professions, guild, title,
-- gear quality, equipped items for the model). Only the logged-in character can be read; each is saved with it.

local _, ns = ...
local U = ns.Util
local Tb = {}
ns.Tidbits = Tb

-- Synced with the other account too (Sync/Codec.lua schema). Equipped item links stay local (too long to send).
if ns.Codec then
	local F = ns.Codec.FIELDS
	F.bind, F.money, F.played = { "hb", "s" }, { "m", "n" }, { "p", "n" }
	F.guild, F.title, F.profs, F.gearQ = { "gu", "s" }, { "ti", "s" }, { "pr", "s" }, { "gq", "s" }
end

local PROF_CATEGORIES = { [9] = true, [11] = true }   -- secondary skills, professions
local PROF_NAMES = { Alchemy = 1, Blacksmithing = 1, Enchanting = 1, Engineering = 1, Herbalism = 1, Leatherworking = 1,
	Mining = 1, Skinning = 1, Tailoring = 1, Cooking = 1, ["First Aid"] = 1, Fishing = 1 }
local NOT_PROFS = { Riding = true }   -- listed among secondary skills, but not a profession (saved lists carry it too)

-- One entry per profession name, in first-seen order, keeping the highest rank. Forever lists some skills more than
-- once (Andy's card read "Blacksmithing 185, Blacksmithing 185, ..."). items: { { name, rank }, ... }.
local function dedupe(items)
	local out, at = {}, {}
	for _, it in ipairs(items) do
		local name, rank = it[1], it[2] or 0
		if at[name] then
			if rank > out[at[name]][2] then out[at[name]][2] = rank end
		elseif not NOT_PROFS[name] then
			out[#out + 1] = { name, rank }
			at[name] = #out
		end
	end
	local parts = {}
	for i, it in ipairs(out) do parts[i] = ("%s %d"):format(it[1], it[2]) end
	return #parts > 0 and table.concat(parts, ", ") or nil
end

-- "Mining 175, Herbalism 150" (primary first, then secondary), each profession once.
function Tb.Professions()
	local items = {}
	if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
		for i = 1, U.Call(C_SkillInfo.GetNumSkillLines) or 0 do
			local s = U.Call(C_SkillInfo.GetSkillLineInfo, i)
			local name = s and U.Str(s.name)
			if name and not s.isHeader and (PROF_CATEGORIES[s.skillLineCategoryID] or PROF_NAMES[name]) then
				items[#items + 1] = { name, U.Num(s.rank) or 0 }
			end
		end
	end
	return dedupe(items)
end

-- A saved "Blacksmithing 185, Blacksmithing 185, Mining 201" read back once per profession.
function Tb.CleanProfs(text)
	if type(text) ~= "string" then return nil end
	local items = {}
	for part in text:gmatch("[^,]+") do
		local name, rank = part:match("^%s*(.-)%s+(%d+)%s*$")
		if name and name ~= "" then items[#items + 1] = { name, tonumber(rank) } end
	end
	return dedupe(items) or text
end

-- Equipped item quality counts ("2 epic, 3 rare, 8 uncommon") and links (for dressing a model).
local QUALITY = { [5] = "legendary", [4] = "epic", [3] = "rare", [2] = "uncommon" }
function Tb.Gear()
	local counts, links = {}, {}
	for slot = 1, 19 do
		local q = U.Call(GetInventoryItemQuality, "player", slot)
		if q then counts[q] = (counts[q] or 0) + 1 end
		local link = U.Str(U.Call(GetInventoryItemLink, "player", slot))
		if link then links[slot] = link end
	end
	local parts = {}
	for q = 5, 2, -1 do if counts[q] then parts[#parts + 1] = counts[q] .. " " .. QUALITY[q] end end
	return #parts > 0 and table.concat(parts, ", ") or nil, links
end

function Tb.Capture()
	local c = ns.Me()
	if not c then return end
	c.bind = U.Str(U.Call(GetBindLocation)) or c.bind
	c.money = U.Num(U.Call(GetMoney)) or c.money
	c.guild = U.Str((U.Call(GetGuildInfo, "player"))) or nil
	local titleID = U.Num(U.Call(GetCurrentTitle))
	c.title = titleID and titleID > 0 and U.Str(U.Call(GetTitleName, titleID)) or nil
	c.profs = Tb.Professions() or c.profs
	c.gearQ, c.gear = Tb.Gear()
end

-- /played: ask once per session and hide the chat echo for our request only.
local asked = false
local function chatFrames()
	local out = {}
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local f = _G["ChatFrame" .. i]
		if f and f.IsEventRegistered and f:IsEventRegistered("TIME_PLAYED_MSG") then out[#out + 1] = f end
	end
	return out
end
function Tb.RequestPlayed()
	if asked or not RequestTimePlayed then return end
	asked = true
	local muted = chatFrames()
	for _, f in ipairs(muted) do f:UnregisterEvent("TIME_PLAYED_MSG") end
	Tb.muted = muted
	RequestTimePlayed()
	C_Timer.After(5, function() Tb.Unmute() end)   -- in case the answer never comes
end
function Tb.Unmute()
	for _, f in ipairs(Tb.muted or {}) do f:RegisterEvent("TIME_PLAYED_MSG") end
	Tb.muted = nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("TIME_PLAYED_MSG")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:SetScript("OnEvent", function(_, event, total)
	if event == "TIME_PLAYED_MSG" then
		local c = ns.Me()
		if c and U.Num(total) then c.played = U.Num(total) end
		C_Timer.After(0, Tb.Unmute)
	elseif ns.Ready() then
		Tb.Capture()
	end
end)

ns.RegisterCallback(Tb, "LOGIN_DONE", function()
	for _, c in pairs(ns.DB().chars) do c.profs = c.profs and Tb.CleanProfs(c.profs) end   -- saved before the dedupe
	Tb.Capture()
	C_Timer.After(10, Tb.RequestPlayed)
end)

-- Rows of label/value for the card and the roster tooltip.
function Tb.List(c, now)
	local out = {}
	local function add(label, value) if value and value ~= "" then out[#out + 1] = { label, value } end end
	add("Hearth", c.bind)
	add("Logged out in", c.subzone and c.zone and (c.subzone .. ", " .. c.zone) or c.zone)
	add("/played", c.played and U.Duration(c.played))
	add("Gold", c.money and U.Gold(c.money))
	add("Professions", Tb.CleanProfs(c.profs))   -- synced records may still carry duplicates
	add("Guild", c.guild)
	add("Gear", c.gearQ)
	add("Title", c.title)
	add("Rest bonus", c.ranks and (c.ranks .. " of 5") or nil)
	local p = ns.Model.Project(c, now, ns.DB().calib)
	local atFull = ns.Model.Wasted(c, p, now)   -- past stretches plus the current one, so it agrees with "full for"
	add("Time at full", atFull >= 3600 and (U.Duration(atFull) .. " in all") or nil)
	return out
end

function ns.TooltipExtra(tt, c)
	local list = Tb.List(c, time())
	if #list == 0 then return end
	tt:AddLine(" ")
	for i = 1, math.min(#list, 5) do tt:AddDoubleLine(list[i][1], list[i][2], 0.6, 0.6, 0.6, 0.95, 0.9, 0.75) end
end
