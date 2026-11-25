-- Who a character is: Forever surnames, hidden realms, GUID keys, and never a duplicate row.

local W = dofile("tests/world.lua")
local ns = W.Pure()
local I = ns.Identity

local cases = {}

function cases.full_name_from_name_and_surname()
	local full, first, sur = I.FullName("Le", "Jette", nil)
	T.eq(full, "Le Jette", "full")
	T.eq(first, "Le", "first")
	T.eq(sur, "Jette", "surname")
end

function cases.full_name_already_joined()
	T.eq((I.FullName("Le-Jette", nil, nil)), "Le Jette", "separator")
	T.eq((I.FullName("Le Jette", "Forever", "Forever")), "Le Jette", "second value is the realm, not a surname")
	T.eq((I.FullName("Shaan", "Forever", "Forever")), "Shaan", "no surname")
	T.eq((I.FullName(nil)), nil, "no name")
end

function cases.keys_prefer_the_guid()
	T.eq(I.Key("Player-1-ABC", "Le Jette", "R"), "G:Player-1-ABC", "guid key")
	T.eq(I.Key(nil, "Le Jette", nil), "N:Le Jette@?", "name key with hidden realm")
end

function cases.hidden_realm_then_known_realm_is_one_character()
	local chars = { ["N:Le Jette@?"] = { full = "Le Jette", class = "WARRIOR", t = 200, rested = 5 } }
	local hidden = { ["N:Le Jette@?"] = true }
	local key = I.Resolve(chars, { full = "Le Jette", realm = "Forever", class = "WARRIOR" }, hidden)
	T.eq(key, "N:Le Jette@Forever", "realm key")
	local n = 0
	for _ in pairs(chars) do n = n + 1 end
	T.eq(n, 1, "one record")
	T.eq(chars[key].rested, 5, "data kept")
	T.ok(hidden[key] and not hidden["N:Le Jette@?"], "hidden flag moved")
end

function cases.guid_appearing_later_folds_the_name_record()
	local chars = {
		["N:Le Jette@?"] = { full = "Le Jette", class = "WARRIOR", t = 300, rested = 7 },
		["N:Le Jette@Forever"] = { full = "Le Jette", class = "WARRIOR", realm = "Forever", t = 100, rested = 1 },
	}
	local key = I.Resolve(chars, { guid = "Player-1-A", full = "Le Jette", class = "WARRIOR" })
	T.eq(key, "G:Player-1-A", "guid key")
	T.eq(chars[key].rested, 7, "newest snapshot wins")
	T.eq(chars[key].realm, "Forever", "realm kept from the older record")
	T.eq(chars["N:Le Jette@?"], nil, "old key gone")
	T.eq(chars["N:Le Jette@Forever"], nil, "old key gone")
end

function cases.guid_unreadable_later_keeps_the_guid_key()
	local chars = { ["G:Player-1-A"] = { guid = "Player-1-A", full = "Le Jette", class = "WARRIOR", t = 1 } }
	local key = I.Resolve(chars, { full = "Le Jette", class = "WARRIOR" })
	T.eq(key, "G:Player-1-A", "same key")
end

function cases.same_name_different_class_is_a_different_character()
	local chars = { ["N:Le Jette@?"] = { full = "Le Jette", class = "MAGE", t = 1 } }
	I.Resolve(chars, { full = "Le Jette", class = "WARRIOR" })
	local n = 0
	for _ in pairs(chars) do n = n + 1 end
	T.eq(n, 1, "the mage stays; the warrior has no record until captured")
	T.ok(chars["N:Le Jette@?"].class == "MAGE", "mage untouched")
end

function cases.dedupe_folds_rested_watch_style_duplicates()
	local chars = {
		["N:Le Nette@?"] = { full = "Le Nette", class = "MAGE", t = 50 },
		["N:Le Nette@Forever"] = { full = "Le Nette", class = "MAGE", realm = "Forever", t = 90 },
		["G:Player-9"] = { guid = "Player-9", full = "Le Nette", class = "MAGE", t = 10 },
		["N:Le Dette@?"] = { full = "Le Dette", class = "WARLOCK", t = 5 },
	}
	T.eq(I.Dedupe(chars), 2, "two folded")
	T.ok(chars["G:Player-9"], "guid record kept as canonical")
	T.eq(chars["G:Player-9"].t, 90, "newest data")
	T.ok(chars["N:Le Dette@?"], "other character untouched")
end

return cases
