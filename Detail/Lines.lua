-- Rested Leveling: what a character says. Each line is a short hook in the character's voice ("Two days waiting.")
-- plus one short follow-up from its own data ("Brill inn suits me."); XP numbers stay in the status area. The card
-- shows the hook large and the follow-up small; roster tooltips quote the hook. The pick is deterministic per character and state, so the
-- same character in the same state always says the same thing. Pure, tested headless.

local _, ns = ...
local U, Wd = ns.Util, ns.Words
local L = {}
ns.Lines = L

-- { hook, facts } per state. Tokens: {time} {levels} {pct} {left} {clock} {place} {zone} {level}.
L.BANK = {
	full = {
		{ "{time} waiting.", "Let's go." },
		{ "Ready when you are.", "{place} has been home long enough." },
		{ "Bags packed.", "{place} can spare me now." },
	},
	near = {
		{ "Almost there.", "Give me {left} more, or take me now." },
		{ "Good time to play me.", "I'm nearly topped off." },
		{ "Nearly topped off.", "{place} is treating me well." },
	},
	resting = {
		{ "Still snoozing.", "Full {clock}. Let me sleep." },
		{ "Comfy here.", "{place} suits me." },
		{ "Give me {left}.", "Then I'm full at {place}." },
	},
	outside = {
		{ "Get me to an inn.", "Out here in {zone} I fill 4x slower." },
		{ "Cold out here in {zone}.", "Hearth me home to fill up." },
		{ "No bed in {zone}.", "Park me somewhere warm." },
	},
	max = {
		{ "Max level. I keep the bench warm.", "Level {level}. Go wake up one of the little ones." },
	},
	done = {
		{ "Target reached.", "Go play someone who needs it." },
	},
	me = {
		{ "That's me.", "Let's burn the rest we've got." },
		{ "We're out here.", "Make the double XP count." },
	},
}

-- A class aside, sometimes used as the hook when the character is (nearly) full.
L.CLASS = {
	WARRIOR = { "Rage bar's empty. Rest bar isn't.", "Shield's polished.", "I've charged nothing all week." },
	MAGE = { "Water's conjured.", "Portal's warm.", "Polymorphed the innkeeper's cat. Twice." },
	WARLOCK = { "My imp is bored.", "Soul shards sorted.", "The voidwalker ate the stew." },
	DRUID = { "Travel form's ready.", "Slept as a bear. Twice.", "The inn's plants are thriving." },
	ROGUE = { "Daggers are sharp.", "Picked every lock in the inn.", "Nobody saw me rest." },
	SHAMAN = { "The spirits say it's my turn.", "Totems packed.", "The wind's at my back." },
	HUNTER = { "My pet's restless.", "Arrows fletched.", "The boar out back is nervous." },
	PRIEST = { "Prayed long enough.", "Shields up, spirits high.", "Even the innkeeper feels blessed." },
	PALADIN = { "The Light and the rested bonus are with me.", "Hammer's blessed.", "Auras recharged." },
}

local function fill(tpl, v)
	return (tpl:gsub("{(%w+)}", function(k) return v[k] ~= nil and tostring(v[k]) or "" end))
end

local function cap(s) return (s:gsub("^%l", string.upper)) end

-- r: a roster row ({ c, p, state }) or, with isMe, the logged-in character. Returns hook, facts.
-- turn: 0 for the card, 1 for the hero, so the two never say the same line side by side.
function L.Parts(r, now, isMe, turn)
	local c, p = r.c, r.p
	local state = isMe and "me" or r.state
	local bank = L.BANK[state] or L.BANK.resting
	local h = U.Hash((c.key or c.full or "?") .. "|" .. state)
	local pick = bank[((h + (turn or 0)) % #bank) + 1]
	local v = {
		place = Wd.Place(c), zone = c.zone or "the wild", level = c.level or "?",
		levels = p and Wd.Levels(p.levels) or "no rest",
		pct = p and (math.floor(p.pct * 100) .. "%") or "",
		time = p and p.fullSince and U.Long(now - p.fullSince) or "",
		left = p and p.left and U.Long(p.left) or "",
		clock = p and p.left and p.left > 0 and U.Clock(now + p.left, now) or "soon",
	}
	local hook, facts = cap(fill(pick[1], v)), cap(fill(pick[2], v))
	local pool = c.class and L.CLASS[c.class]
	local flavour = pool and pool[((math.floor(h / 3) + (turn or 0)) % #pool) + 1]
	if flavour and (state == "full" or state == "near") and (math.floor(h / 7) % 2 == 0) then hook = flavour end
	return hook, facts
end

function L.For(r, now, isMe)
	local hook, facts = L.Parts(r, now, isMe)
	return hook .. " " .. facts
end

-- (Kept for the roster tooltip and tests.) One decision word, then the character's own joke ("Send me. Water's conjured."). No numbers:
-- the big figure says how much is banked, once.
L.DECIDE = { full = "Send me.", near = "Send me soon.", resting = "Not yet.", outside = "Inn first." }
function L.Decision(r, now)
	local word = L.DECIDE[r.state]
	if not word then return nil end
	return word .. "  " .. (L.Parts(r, now or time()))
end

-- The hook alone, for tooltips.
function L.Short(r, now)
	return (L.Parts(r, now or time(), nil, 1))
end

return L
