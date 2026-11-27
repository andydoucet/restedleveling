-- Rested Leveling: live roster sync between your WoW accounts, with hidden addon messages only.
--
-- Pairing is explicit and mutual: you type /rlvl link <Name> on each account (same realm and faction: Classic
-- blocks cross-faction addon whispers). A hello on GUILD/PARTY/RAID or from an unlinked whisper never links and never
-- sends anything; it only prints, once per sender per session, how to pair. Rosters go to, and are accepted from, a
-- name only when we linked it AND its whisper hello says it linked us (the confirm). On the confirm each side sends
-- its roster once (then again only when digests differ, at most every 5 minutes). Only the peer account's own
-- records are merged; a remote record never overwrites one of ours. Messages are chunked and sent from a token
-- bucket under the client's per-prefix limit. Received data is parsed against a schema (Sync/Codec.lua), never run.

local _, ns = ...
local U, C = ns.Util, ns.Codec
local S = {}
ns.Sync = S

S.PREFIX = "RLVL1"
S.CHUNK = 220            -- data bytes per message (the client allows 255 including our header)
S.BURST, S.REFILL = 6, 1.2   -- token bucket: up to 6 at once, then one message per 1.2 s
S.RESEND = 300           -- don't resend the same roster to the same peer within 5 minutes
S.MAX_CHUNKS = 120
S.MAX_WHISPERS = 12
S.MAX_LINKS = 8          -- linked names and known peer accounts
S.MAX_BUFFERS = 8        -- half-received rosters in flight, one per sender

local queue, tokens, lastRefill = {}, S.BURST, nil
local buffers = {}       -- the one partial roster in flight per sender
local hinted = {}        -- senders told how to pair, this session
local replied = {}       -- sender -> time of our last confirming hello
local echoed = {}        -- linked name -> time we last whispered it a hello (Announce, or an echo to a peer's hello)
local recentWhisper = {} -- names whispered recently, to hide "player not found" for offline ones
local sentTo = {}        -- peer name -> { digest, t }
local msgSeq = 0

local function sync()
	local d = ns.DB()
	d.sync = d.sync or {}
	d.sync.links = d.sync.links or {}
	d.sync.peers = d.sync.peers or {}
	d.sync.confirmed = d.sync.confirmed or {}   -- linked name -> the account id it confirmed with
	return d.sync
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- A character name as typed or as the game reports a sender: trimmed, inner spaces collapsed ("Le  Bankken" ->
-- "Le Bankken": Forever names have a surname). A "-Realm" suffix is dropped when it is our own realm (or ours cannot
-- be read) and kept when it names another realm, so a same-named character elsewhere never matches a link. Forever
-- reports senders without a realm, so there this changes nothing. S.NameKey is its lower-case form; every link,
-- confirm and per-sender table is compared through it.
local function ownRealm()
	local r = U.Str(U.Call(GetNormalizedRealmName))
	return r and r:gsub("[%s%-]", ""):lower()
end
function S.CleanName(name)
	if type(name) ~= "string" then return nil end
	local base, realm = name:match("^([^%-]*)%-(.*)$")
	name = base or name
	realm = realm and realm:gsub("[%s%-]", "")
	local mine = realm and realm ~= "" and ownRealm()
	name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
	if name == "" then return nil end
	if mine and realm:lower() ~= mine then name = name .. "-" .. realm end
	return name
end
function S.NameKey(name)
	local n = S.CleanName(name)
	return n and n:lower()
end

-- The linked name (as stored, to whisper) matching `name`, or nil.
local function linked(name)
	local key = S.NameKey(name)
	if not key then return nil end
	for n in pairs(sync().links) do if S.NameKey(n) == key then return n end end
	return nil
end
local function validAccount(a) return type(a) == "string" and a:match("^%x%x%x%x%x%x$") ~= nil end

local function restricted()
	return C_ChatInfo.AreOutgoingAddonChatMessagesRestricted
		and U.Call(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) == true
end

local function enqueue(text, channel, target)
	queue[#queue + 1] = { text = text, channel = channel, target = target }
end

-- Send what the bucket allows. Throttled sends stay queued; any other failure drops the message.
function S.Pump(now)
	now = now or GetTime()
	lastRefill = lastRefill or now
	tokens = math.min(S.BURST, tokens + (now - lastRefill) / S.REFILL)
	lastRefill = now
	if restricted() then return end
	while #queue > 0 and tokens >= 1 do
		local m = queue[1]
		local ok, res = pcall(C_ChatInfo.SendAddonMessage, S.PREFIX, m.text, m.channel, m.target)
		if ok and (res == 3 or res == 8) then return end   -- AddonMessageThrottle / ChannelThrottle: retry later
		table.remove(queue, 1)
		tokens = tokens - 1
		if m.channel == "WHISPER" and m.target then recentWhisper[m.target] = now end
	end
end

function S.QueueLength() return #queue end

-- The hello: account, digest, label, and "1" when we have linked the name it is whispered to (the confirm).
local function hello(target)
	local d = ns.DB()
	return ("H%s;%s;%s;%s"):format(d.account, C.Digest(d.chars), (ns.AccountLabel(d.account):gsub("[;|]", "")),
		(target and linked(target)) and "1" or "0")
end

local function sendRoster(target)
	local d = ns.DB()
	local digest = C.Digest(d.chars)
	local tkey = S.NameKey(target)
	local last = sentTo[tkey]
	if last and last.digest == digest and time() - last.t < S.RESEND then return end
	local chunks = C.Chunk(C.EncodeRoster(d.chars, d.account), S.CHUNK)
	if #chunks > S.MAX_CHUNKS then   -- too big to send: say so once, and never record it as sent
		if not S.warnedSize then S.warnedSize = true; U.Print("the roster is too large to sync in one go; sync skipped.") end
		return
	end
	sentTo[tkey] = { digest = digest, t = time() }
	msgSeq = (msgSeq % 999) + 1
	for i, part in ipairs(chunks) do
		enqueue(("D%d;%d;%d;%s"):format(msgSeq, i, #chunks, part), "WHISPER", target)
	end
end

-- Say hello on every shared channel and to linked names and known peers. A name that has confirmed the link (mutual)
-- also gets our roster now when it changed (sendRoster skips an unchanged one), so a login or /rlvl sync never waits
-- for the 15-minute ticker. A one-way link only gets the hello: the trust model is unchanged.
function S.Announce()
	local s, msg = sync(), hello()
	if U.Call(IsInGuild) then enqueue(msg, "GUILD") end
	if U.Call(IsInRaid) then enqueue(msg, "RAID") elseif U.Call(IsInGroup) then enqueue(msg, "PARTY") end
	local n = 0
	for name in pairs(s.links) do
		if n < S.MAX_WHISPERS then
			enqueue(hello(name), "WHISPER", name); n = n + 1
			echoed[S.NameKey(name)] = time()
			if s.confirmed[S.NameKey(name)] then sendRoster(name) end
		end
	end
	S.Pump()
end

local function onHello(body, sender, channel)
	local account, digest, label, flag = body:match("^(%x+);(%x+);([^;]*);?([01]?)$")
	local d, s = ns.DB(), sync()
	if not validAccount(account) or account == d.account then return end
	local key, name = S.NameKey(sender), S.CleanName(sender)
	if not key then return end
	if not linked(sender) then   -- not paired from our side: a hint for a whisper, once, and nothing else
		if channel == "WHISPER" and not hinted[key] then
			hinted[key] = true
			U.Print(("%s runs Rested Leveling: /rlvl link %s to pair your accounts."):format(name, name))
		end
		return
	end
	if channel ~= "WHISPER" or flag ~= "1" then   -- we linked them, they have not confirmed: send our confirm, bounded
		if not replied[key] or time() - replied[key] > 60 then
			replied[key] = time()
			enqueue(hello(sender), "WHISPER", sender)
			S.Pump()
		end
		return
	end
	-- Mutual: we linked them and they linked us.
	local newly = s.confirmed[key] ~= account
	if newly and not s.confirmed[key] and count(s.confirmed) >= S.MAX_LINKS then return end
	s.confirmed[key] = account
	if not s.peers[account] and count(s.peers) >= S.MAX_LINKS then return end
	s.peers[account] = s.peers[account] or {}
	local peer = s.peers[account]
	label = label:gsub("|", ""):sub(1, 12)
	peer.name, peer.seen, peer.label = sender, time(), label ~= "" and label or nil
	d.accountLabels = d.accountLabels or {}
	if peer.label and not d.accountLabels[account] then d.accountLabels[account] = peer.label end
	if newly then
		enqueue(hello(sender), "WHISPER", sender)   -- confirm back once, so they send theirs too
		echoed[key] = time()
		ns.Fire("LINK_CHANGED")
	elseif not echoed[key] or time() - echoed[key] > S.RESEND then
		-- A confirmed peer just logged in and said hello: say hello back, so it compares digests and sends its roster
		-- now rather than on its next 15-minute announce. Bounded: the hello we answer with is not answered again.
		echoed[key] = time()
		enqueue(hello(sender), "WHISPER", sender)
	end
	if newly or digest ~= C.Digest(d.chars) then sendRoster(sender) end
	S.Pump()
end

local function onData(body, sender)
	local s = sync()
	local key = S.NameKey(sender)
	local peerAccount = key and linked(sender) and s.confirmed[key]
	if not peerAccount then return end   -- only from a mutually linked name
	local id, seq, total, data = body:match("^(%d+);(%d+);(%d+);(.*)$")   -- digits only: a "1.5" index never matches
	id, seq, total = tonumber(id), tonumber(seq), tonumber(total)
	if not id or seq < 1 or total < 1 or seq > total or total > S.MAX_CHUNKS then return end
	local b = buffers[key]   -- one roster in flight per sender; a new id replaces it
	if not b or b.id ~= id or b.total ~= total then
		if not b and count(buffers) >= S.MAX_BUFFERS then return end
		b = { id = id, total = total, got = 0, parts = {}, stamp = 0 }
		buffers[key] = b
	end
	if b.parts[seq] then return end
	b.parts[seq], b.got = data, b.got + 1
	-- Expire a roster 60 s after its LAST chunk (a long roster at 1.2 s a chunk takes longer than 60 s in all).
	b.stamp = b.stamp + 1
	local stamp = b.stamp
	C_Timer.After(60, function() if buffers[key] == b and b.stamp == stamp then buffers[key] = nil end end)
	if b.got < total then return end
	buffers[key] = nil
	local payload = table.concat(b.parts, "", 1, total)
	local d, now = ns.DB(), time()
	local account, recs = C.DecodeRoster(payload, now)
	if account ~= peerAccount then return end
	local theirs = {}   -- only the peer account's own characters
	for _, r in ipairs(recs) do if r.account == peerAccount then theirs[#theirs + 1] = r end end
	local changed = C.Merge(d.chars, theirs, account, now, d.hidden, d.account)
	local peer = s.peers[account] or {}
	s.peers[account] = peer
	peer.name, peer.seen, peer.lastSync = sender, now, now
	if changed > 0 then ns.Fire("ROSTER_CHANGED") end
	ns.Fire("SYNC_DONE", account, changed)
end

function S.OnMessage(prefix, text, channel, sender)
	if prefix ~= S.PREFIX then return end
	text, sender, channel = U.Str(text), U.Str(sender), U.Str(channel)
	if not text or not sender or #text > 255 then return end
	local kind, body = text:sub(1, 1), text:sub(2)
	if kind == "H" then onHello(body, sender, channel)
	elseif kind == "D" then onData(body, sender) end
end

-- For the UI: peers seen, newest first, and whether any other account was ever seen.
function S.Status()
	local out = {}
	for account, p in pairs(sync().peers) do
		out[#out + 1] = { account = account, name = p.name, seen = p.seen, lastSync = p.lastSync, label = ns.AccountLabel(account) }
	end
	table.sort(out, function(a, b) return (a.seen or 0) > (b.seen or 0) end)
	return out
end

-- For the inline link field: every linked name, confirmed (paired) ones first, then by name.
-- Each: { name, confirmed (they linked us back), account, lastSync }.
function S.Links()
	local s, out = sync(), {}
	for name in pairs(s.links) do
		local account = s.confirmed[S.NameKey(name)]
		local peer = account and s.peers[account]
		out[#out + 1] = { name = name, confirmed = account ~= nil, account = account, lastSync = peer and peer.lastSync }
	end
	table.sort(out, function(a, b)
		if a.confirmed ~= b.confirmed then return a.confirmed end
		return S.NameKey(a.name) < S.NameKey(b.name)
	end)
	return out
end

-- Hide the client's "No player named X is currently playing" for our own hello whispers to offline names.
local function filterSystem(_, _, msg)
	if type(msg) ~= "string" or type(ERR_CHAT_PLAYER_NOT_FOUND_S) ~= "string" then return false end
	for name, t in pairs(recentWhisper) do
		if GetTime() - t > 10 then recentWhisper[name] = nil
		elseif msg == ERR_CHAT_PLAYER_NOT_FOUND_S:format(name) then return true end
	end
	return false
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "CHAT_MSG_ADDON" then S.OnMessage(...)
	elseif event == "GROUP_ROSTER_UPDATE" and ns.Ready() then
		if not S.groupTimer then
			S.groupTimer = true
			C_Timer.After(5, function() S.groupTimer = nil; S.Announce() end)
		end
	end
end)

U.Call(C_ChatInfo.RegisterAddonMessagePrefix, S.PREFIX)
local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if addFilter then addFilter("CHAT_MSG_SYSTEM", filterSystem) end

ns.RegisterCallback(S, "LOGIN_DONE", function() C_Timer.After(8, S.Announce) end)
C_Timer.NewTicker(0.5, function() if #queue > 0 then S.Pump() end end)
C_Timer.NewTicker(900, function() if ns.Ready() then S.Announce() end end)

ns.slash.link = function(arg)
	local name = S.CleanName(arg)   -- the whole name: "Le Bankken"
	if not name then U.Print("usage: /rlvl link <character on your other account>") return end
	local s = sync()
	if linked(name) then s.links[linked(name)] = nil end   -- one entry per name, whatever its case
	if count(s.links) >= S.MAX_LINKS then U.Print("at most 8 links; /rlvl unlink one first.") return end
	s.links[name] = true
	enqueue(hello(name), "WHISPER", name)
	S.Pump()
	U.Print("linked " .. name .. ". Type /rlvl link <this character> on the other account too; then the rosters swap.")
	ns.Fire("LINK_CHANGED")
end
ns.slash.unlink = function(arg)
	local name, s = S.CleanName(arg), sync()
	local stored = name and linked(name)
	if not stored then U.Print("not linked: " .. tostring(name)) return end
	local account = s.confirmed[S.NameKey(name)]
	s.links[stored], s.confirmed[S.NameKey(name)] = nil, nil
	-- Free the peer slot too (at most 8), unless another link still confirms that account. Its characters stay.
	local still = false
	for _, a in pairs(s.confirmed) do if a == account then still = true end end
	if account and not still then s.peers[account] = nil end
	U.Print("unlinked " .. stored .. ".")
	ns.Fire("LINK_CHANGED")
end
ns.slash.sync = function()
	S.Announce()
	local st = S.Status()
	if #st == 0 then U.Print("no other account seen yet. Same realm and faction needed; try /rlvl link <Name>.") return end
	for _, p in ipairs(st) do
		print(("  %s (via %s): seen %s, synced %s"):format(p.label, p.name or "?", U.Ago(time() - (p.seen or 0)),
			p.lastSync and U.Ago(time() - p.lastSync) or "never"))
	end
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl link <Name> - pair with a character on your other account (same realm and faction)"
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl sync - say hello now and show linked accounts"
