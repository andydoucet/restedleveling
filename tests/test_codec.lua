-- The sync codec and merge rules, headless: round trips, malformed and foreign data, newest-wins merges, chunking,
-- skipping unknown fields, clock skew, safe truncation, and that a peer never overwrites our own characters.

local W = dofile("tests/world.lua")
local H = 3600

local function pure()
	return W.Pure({ "Core/Util.lua", "Core/Model.lua", "Core/Identity.lua", "Core/Look.lua", "Sync/Codec.lua" })
end

local function rec(full, t, extra)
	local c = { full = full, class = "MAGE", level = 20, xpMax = 9000, rested = 4500, resting = true, t = t, account = "bbbbbb" }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end

local cases = {}
function cases.codec_round_trips_a_roster()
	local ns = pure()
	local C = ns.Codec
	local chars = { ["N:Le Nette@?"] = rec("Le Nette", W.NOW, { zone = "Elwynn; Forest=|^~", ranks = 3, atMax = false }) }
	local account, recs = C.DecodeRoster(C.EncodeRoster(chars, "aaaaaa"), W.NOW)
	T.eq(account, "aaaaaa", "account")
	T.eq(#recs, 1, "one record")
	T.eq(recs[1].key, "N:Le Nette@?", "key")
	T.eq(recs[1].zone, "Elwynn; Forest=|^~", "escaped string survives")
	T.eq(recs[1].ranks, 3, "number")
	T.eq(recs[1].atMax, false, "boolean")
	T.eq(recs[1].resting, true, "boolean true")
end

function cases.malformed_and_foreign_data_is_ignored()
	local ns = pure()
	local C = ns.Codec
	T.eq(C.DecodeRoster("2^aaaaaa^k=N:x;f=x;t=1794600000;xm=1", W.NOW), nil, "wrong version")
	T.eq(C.DecodeRoster("1^bad account!^", W.NOW), nil, "bad header")
	local good = C.EncodeRecord(rec("Good", W.NOW, { key = "N:Good@?" }))
	local bad = {
		"k=N:x;f=x;t=1794600000;xm=1;zz9=1",                        -- unknown field
		"k=N:x;f=x;t=1794600000;xm=1;l=999",                        -- level out of range
		"k=N:x;f=x;t=1794600000;xm=abc",                            -- not a number
		"k=N:x;f=x;t=1794600000;xm=1;rs=yes",                       -- not a boolean
		"k=X:x;f=x;t=1794600000;xm=1",                              -- bad key
		"k=N:x;f=x;t=9999999999;xm=1",                              -- from the far future
		"k=N:x;f=x;t=1794600000;xm=1;c=loadstring('x')",            -- class must be A-Z
		"k=N:x;f=x;t=1794600000;xm=1;f=again",                      -- duplicate field
		"k=N:x;f=x~q;t=1794600000;xm=1",                            -- bad escape
	}
	local payload = "1^aaaaaa^" .. good .. "^" .. table.concat(bad, "^")
	local _, recs, dropped = C.DecodeRoster(payload, W.NOW)
	T.eq(#recs, 1, "only the good record")
	T.eq(dropped, #bad, "every bad one dropped")
end

function cases.merge_newest_wins_and_older_is_ignored()
	local ns = pure()
	local C = ns.Codec
	local chars = { ["N:Le Nette@?"] = rec("Le Nette", W.NOW - H, { rested = 100 }) }
	T.eq(C.Merge(chars, { rec("Le Nette", W.NOW - 2 * H, { key = "N:Le Nette@?", rested = 1 }) }, "bbbbbb", W.NOW, nil, "aaaaaa"), 0, "older ignored")
	T.eq(chars["N:Le Nette@?"].rested, 100, "kept")
	T.eq(C.Merge(chars, { rec("Le Nette", W.NOW, { key = "N:Le Nette@?", rested = 900 }) }, "bbbbbb", W.NOW, nil, "aaaaaa"), 1, "newer taken")
	T.eq(chars["N:Le Nette@?"].rested, 900, "updated")
	T.eq(chars["N:Le Nette@?"].src, "sync", "tagged as synced")
	T.eq(chars["N:Le Nette@?"].via, "bbbbbb", "from account b")
end

function cases.merge_resolves_hidden_realm_keys_without_duplicates()
	local ns = pure()
	local C = ns.Codec
	local chars = { ["G:Player-1"] = rec("Le Nette", W.NOW - H, { guid = "Player-1" }) }
	C.Merge(chars, { rec("Le Nette", W.NOW, { key = "N:Le Nette@?" }) }, "bbbbbb", W.NOW, nil, "aaaaaa")
	local n = 0
	for _ in pairs(chars) do n = n + 1 end
	T.eq(n, 1, "one record")
	T.eq(chars["G:Player-1"].t, W.NOW, "newest data under the guid key")
end

function cases.chunks_reassemble_in_any_order()
	local ns = pure()
	local parts = ns.Codec.Chunk(("x"):rep(500), 220)
	T.eq(#parts, 3, "three chunks")
	T.eq(table.concat(parts), ("x"):rep(500), "joined")
end

-- Two clients on two accounts, wired together: whatever one sends, the other receives.
function cases.a_peer_cannot_overwrite_our_own_characters()
	local C = pure().Codec
	local chars = { ["N:Le Nette@?"] = rec("Le Nette", W.NOW - H, { account = "aaaaaa", rested = 100 }) }
	local forged = rec("Le Nette", W.NOW, { key = "N:Le Nette@?", account = "aaaaaa", rested = 1 })
	T.eq(C.Merge(chars, { forged }, "bbbbbb", W.NOW, nil, "aaaaaa"), 0, "a newer remote copy of our own alt is ignored")
	T.eq(chars["N:Le Nette@?"].rested, 100, "ours stays")
end

function cases.codec_skips_unknown_fields_clamps_time_and_cuts_utf8_safely()
	local ns = pure()
	local C, U = ns.Codec, ns.Util
	local s = C.EncodeRecord(rec("Le Nette", W.NOW, { key = "N:Le Nette@?" })) .. ";zq=future;zr=2"
	local c = C.DecodeRecord(s, W.NOW)
	T.ok(c and c.full == "Le Nette", "unknown fields from a newer version are skipped, the record kept")
	local ahead = C.DecodeRecord(C.EncodeRecord(rec("Le Nette", W.NOW + 3600, { key = "N:Le Nette@?" })), W.NOW)
	T.eq(ahead.t, W.NOW, "a clock ahead of ours is clamped to now")
	T.eq(U.Truncate("Tailoring 145, Enchanting 120, Herbalism 70", 34), "Tailoring 145, Enchanting 120", "cut at a list item")
	local cut = U.Truncate(("é"):rep(10), 7)
	T.ok(#cut == 6 and cut == ("é"):rep(3), "never inside a UTF-8 character")
end

return cases
