-- Cross-account sync transport: mutual pairing syncs both ways in the handshake, strangers can neither link nor push
-- data, and sends stay under the throttle. The codec and merge rules are in test_codec.lua.

local W = dofile("tests/world.lua")
local H = 3600

local function rec(full, t, extra)
	local c = { full = full, class = "MAGE", level = 20, xpMax = 9000, rested = 4500, resting = true, t = t, account = "bbbbbb" }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end

local cases = {}
local function pair(noGuild)
	local net = {}
	local function client(name, first, surname, class, extraChars)
		local state = { first = first, surname = surname, class = class, realm = "",
			saved = { account = name, chars = extraChars or {} } }
		state.setup = function(game)
			game.C_ChatInfo = {
				RegisterAddonMessagePrefix = function() return 0 end,
				SendAddonMessage = function(prefix, text, channel, target)
					net[#net + 1] = { from = name, prefix = prefix, text = text, channel = channel, target = target }
					return 0
				end,
				AreOutgoingAddonChatMessagesRestricted = function() return false end,
			}
			game.IsInGuild = function() return not noGuild end
			game.IsInGroup = function() return false end
			game.IsInRaid = function() return false end
		end
		local _, h = W.New(state)
		return { h = h, state = state, name = first .. " " .. surname }   -- Forever names have a surname: "Le Bankken"
	end
	local a = client("aaaaaa", "Le", "Jette", "WARRIOR", {
		["N:Le Nette@?"] = rec("Le Nette", W.NOW - 5 * H, { account = "aaaaaa" }),
	})
	local b = client("bbbbbb", "Le", "Bankken", "WARRIOR", {
		["N:Le Nette@?"] = rec("Le Nette", W.NOW - 9 * H, { account = "aaaaaa", rested = 1 }),   -- stale copy
	})
	local function deliver(rounds)
		for _ = 1, rounds or 50 do
			for _, c in ipairs({ a, b }) do
				c.h.Env().__now = c.h.Env().__now + 2
				c.state.ns.Sync.Pump()
			end
			if #net == 0 then break end
			local batch = net
			net = {}
			for _, m in ipairs(batch) do
				local to = m.from == "aaaaaa" and b or a
				local from = m.from == "aaaaaa" and a or b
				to.h.Fire("CHAT_MSG_ADDON", m.prefix, m.text, m.channel, from.name)
			end
		end
	end
	return a, b, deliver, function() return net end
end

function cases.mutual_link_syncs_both_ways_in_the_handshake()
	local a, b, deliver = pair()
	W.RunTimers(a.state); W.RunTimers(b.state)   -- the guild hellos after login: hints only
	deliver()
	T.ok(not W.Char(a.h, "Le Bankken"), "a guild hello alone syncs nothing")
	a.h.Slash("RESTEDLEVELING", "link " .. b.name)
	deliver()
	T.ok(not W.Char(a.h, "Le Bankken"), "one side linking is not enough")
	b.h.Slash("RESTEDLEVELING", "link " .. a.name)   -- now mutual: both send on the confirm
	deliver()
	local na, nb = W.Char(a.h, "Le Bankken"), W.Char(b.h, "Le Jette")
	T.ok(na, "account a now knows Le Bankken")
	T.ok(nb, "account b now knows Le Jette")
	T.eq(na.src, "sync", "tagged synced")
	T.eq(W.Char(b.h, "Le Nette").rested, 4500, "b's stale copy of a's character replaced by a's newer snapshot")
	T.ok(W.Char(a.h, "Le Nette").src ~= "sync", "a's own character is not marked synced")
	T.ok(a.h.Env().RestedLevelingDB.sync.peers.bbbbbb.lastSync, "a recorded the sync")
	T.clean(a.h); T.clean(b.h)
end

local function lone()
	local sent = {}
	local state = { saved = { account = "aaaaaa", chars = { ["N:Le Nette@?"] = rec("Le Nette", W.NOW - H, { account = "aaaaaa" }) } },
		setup = function(game)
			game.C_ChatInfo = {
				RegisterAddonMessagePrefix = function() return 0 end,
				SendAddonMessage = function(_, text, channel, target) sent[#sent + 1] = { text = text, channel = channel, target = target } return 0 end,
			}
			game.IsInGuild = function() return true end
			game.IsInGroup = function() return false end
			game.IsInRaid = function() return false end
		end }
	local _, h = W.New(state)
	return h, state, sent
end

function cases.strangers_cannot_link_or_push_data()
	local h, state, sent = lone()
	local C = state.ns.Codec
	state.ns.Sync.Pump()
	local before = #sent   -- our own login hello
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "Hbbbbbb;00000000;Other;0", "GUILD", "Stranger")
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "Hbbbbbb;00000000;Other;1", "WHISPER", "Stranger")
	state.ns.Sync.Pump()
	local s = W.DB(h).sync
	T.ok(not s.links.Stranger and next(s.peers) == nil, "a hello never creates a link or a peer")
	T.eq(#sent, before, "and never sends anything")
	local hinted = false
	for _, line in ipairs(h.Printed()) do if line:find("Stranger runs Rested Leveling", 1, true) then hinted = true end end
	T.ok(hinted, "it only says how to pair")
	local payload = C.EncodeRoster({ ["N:Evil@?"] = rec("Evil One", W.NOW, { account = "bbbbbb" }) }, "bbbbbb")
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "D1;1;1;" .. payload, "WHISPER", "Stranger")
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "D2;1;1;" .. payload, "GUILD", "Stranger")
	T.ok(not W.Char(h, "Evil One"), "unsolicited data is dropped")
	T.clean(h)
end

function cases.throttle_keeps_sends_under_the_budget()
	local sent = {}
	local state = { setup = function(game)
		game.C_ChatInfo = {
			RegisterAddonMessagePrefix = function() return 0 end,
			SendAddonMessage = function(_, text) sent[#sent + 1] = text return 0 end,
		}
		game.IsInGuild = function() return false end
		game.IsInGroup = function() return false end
		game.IsInRaid = function() return false end
	end }
	local chars = {}
	for i = 1, 30 do chars["N:Alt" .. i .. "@?"] = rec("Alt Number" .. i, W.NOW, { zone = ("Z"):rep(40) }) end
	state.saved = { chars = chars }
	local _, h = W.New(state)
	h.Slash("RESTEDLEVELING", "link Lebankken")
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "Hbbbbbb;00000000;#3;1", "WHISPER", "Lebankken")   -- mutual: it linked us too
	local first = #sent
	T.ok(first <= 6, "no more than the burst at once (" .. first .. ")")
	h.Env().__now = h.Env().__now + 6   -- 6 s later: about 5 more
	state.ns.Sync.Pump()
	T.ok(#sent - first <= 5 and #sent > first, "refills at one per 1.2 s (" .. (#sent - first) .. ")")
	for _, text in ipairs(sent) do T.ok(#text <= 255, "message fits") end
	T.clean(h)
end

function cases.links_take_full_names_any_case_and_any_realm_suffix()
	local h, state, sent = lone()
	state.ns.Sync.Pump()
	local before = #sent
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "Hbbbbbb;00000000;Other;0", "GUILD", "Le Bankken")
	local hint = false
	for _, l in ipairs(h.Printed()) do if l:find("runs Rested Leveling", 1, true) then hint = true end end
	T.ok(not hint, "a guild hello prints no pairing hint")
	h.Slash("RESTEDLEVELING", "link   le  bankken ")   -- extra spaces, other case
	local s = W.DB(h).sync
	T.ok(s.links["le bankken"], "the whole name is linked, spaces collapsed")
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "Hbbbbbb;00000000;Other;1", "WHISPER", "Le Bankken-Forever")
	state.ns.Sync.Pump()
	T.eq(s.confirmed["le bankken"], "bbbbbb", "a Name-Realm sender matches the linked name, case ignored")
	local data = false
	for i = before + 1, #sent do if sent[i].text:sub(1, 1) == "D" then data = true end end
	T.ok(data, "and the mutual link sends our roster")
	T.ok(s.peers.bbbbbb, "the paired account takes a peer slot")
	h.Slash("RESTEDLEVELING", "unlink Le Bankken")
	T.ok(next(s.links) == nil and s.confirmed["le bankken"] == nil, "/rlvl unlink Le Bankken removes it")
	T.ok(s.peers.bbbbbb == nil, "and frees its peer slot, so a ninth account can pair later")
	T.clean(h)
end

function cases.a_later_login_syncs_both_ways_without_waiting_for_the_ticker()
	local a, b, deliver = pair(true)   -- no shared guild or group: whispers only
	a.h.Slash("RESTEDLEVELING", "link " .. b.name)
	b.h.Slash("RESTEDLEVELING", "link " .. a.name)
	deliver()
	T.ok(W.Char(b.h, "Le Jette"), "paired and synced once")
	-- Later: b stays online; a logs out, plays a new alt, and logs in again. Only a says hello (its login announce).
	for _, c in ipairs({ a, b }) do W.Advance(c.h, 3600) end
	W.DB(a.h).chars["N:Le Newbie@?"] = rec("Le Newbie", W.NOW + 3500, { account = "aaaaaa" })
	a.state.ns.Sync.Announce()
	deliver()
	T.ok(W.Char(b.h, "Le Newbie"), "b answers a's login hello, so a sends its new roster at once")
	T.clean(a.h); T.clean(b.h)
end

-- A mutually linked lone client, ready to receive chunks from "Le Bankken".
local function confirmed()
	local h, state, sent = lone()
	h.Slash("RESTEDLEVELING", "link Le Bankken")
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "Hbbbbbb;00000000;Other;1", "WHISPER", "Le Bankken")
	return h, state, sent
end

function cases.a_long_roster_reassembles_while_chunks_keep_coming()
	local h, state = confirmed()
	local C = state.ns.Codec
	local function chunks(full) return C.Chunk(C.EncodeRoster({ ["N:" .. full .. "@?"] = rec(full, W.NOW) }, "bbbbbb"), 40) end
	local function send(id, parts, i)
		h.Fire("CHAT_MSG_ADDON", "RLVL1", ("D%d;%d;%d;%s"):format(id, i, #parts, parts[i]), "WHISPER", "Le Bankken")
	end
	W.RunTimers(state)
	local far = chunks("Le Far")
	T.ok(#far >= 3, "several chunks (" .. #far .. ")")
	send(7, far, 1)
	local first = table.remove(state.timers)   -- the expiry started by chunk 1
	send(7, far, 2)
	first()   -- 60 s after chunk 1, but chunk 2 came since: the roster is still being received
	for i = 3, #far do send(7, far, i) end
	T.ok(W.Char(h, "Le Far"), "the roster completes")
	-- A roster that stops arriving still expires 60 s after its last chunk.
	local gone = chunks("Le Gone")
	send(8, gone, 1)
	W.RunTimers(state)
	for i = 2, #gone do send(8, gone, i) end
	T.ok(not W.Char(h, "Le Gone"), "a stalled roster is dropped")
	T.clean(h)
end

function cases.names_keep_a_realm_that_is_not_ours()
	local state = { setup = function(game) game.GetNormalizedRealmName = function() return "Forever" end end }
	local _, h = W.New(state)
	local S = state.ns.Sync
	T.eq(S.CleanName("Le Bankken-Forever"), "Le Bankken", "our own realm is dropped")
	T.eq(S.CleanName("Le Bankken"), "Le Bankken", "no realm: as is")
	T.eq(S.CleanName("Le Bankken-Other Realm"), "Le Bankken-OtherRealm", "another realm is kept")
	T.ok(S.NameKey("Le Bankken-OtherRealm") ~= S.NameKey("Le Bankken"), "so it never matches a link to ours")
	T.clean(h)
end

-- Review (ILL-1272): the peer said hello a minute ago, so it does not answer ours again (RESEND); our own announce
-- must still send a changed roster to a confirmed peer.
function cases.announce_sends_a_changed_roster_to_a_confirmed_peer_at_once()
	local a, b, deliver = pair(true)
	a.h.Slash("RESTEDLEVELING", "link " .. b.name)
	b.h.Slash("RESTEDLEVELING", "link " .. a.name)
	deliver()
	for _, c in ipairs({ a, b }) do W.Advance(c.h, 60) end   -- well inside the 5-minute resend window
	W.DB(a.h).chars["N:Le Fresh@?"] = rec("Le Fresh", W.NOW + 50, { account = "aaaaaa" })
	a.state.ns.Sync.Announce()
	deliver()
	T.ok(W.Char(b.h, "Le Fresh"), "the new alt arrives without waiting for the ticker")
	T.clean(a.h); T.clean(b.h)
end

-- Review (ILL-1272): a non-integer index never stores a part (the header takes digits only).
function cases.a_chunk_with_a_fractional_index_is_dropped()
	local h, state = confirmed()
	local C = state.ns.Codec
	local parts = C.Chunk(C.EncodeRoster({ ["N:Le Odd@?"] = rec("Le Odd", W.NOW) }, "bbbbbb"), 400)
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "D9;1.0;1;" .. parts[1], "WHISPER", "Le Bankken")
	T.ok(not W.Char(h, "Le Odd"), "not a chunk index")
	h.Fire("CHAT_MSG_ADDON", "RLVL1", "D9;1;1;" .. parts[1], "WHISPER", "Le Bankken")
	T.ok(W.Char(h, "Le Odd"), "the same chunk with a whole index is taken")
	T.clean(h)
end

return cases
