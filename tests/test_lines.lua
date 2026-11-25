-- The character card's line bank: deterministic per character and state, filled from that character's own data.

local W = dofile("tests/world.lua")
local H, D = 3600, 86400
local NOW = W.NOW

local function load()
	return W.Pure({ "Core/Util.lua", "Core/Model.lua", "Core/Identity.lua", "UI/Words.lua", "Detail/Lines.lua" })
end

local function row(state, p, c)
	c = c or {}
	c.full = c.full or "Le Nette"
	return { key = "N:" .. c.full .. "@?", c = c, p = p, state = state }
end

local cases = {}

function cases.card_line_is_deterministic_and_uses_the_characters_data()
	local ns = load()
	local L = ns.Lines
	local r = row("full", { pct = 1, levels = 1.5, left = 0, fullSince = NOW - 2 * D }, { class = "MAGE", restKind = "inn", subzone = "Brill" })
	local a, b = L.For(r, NOW), L.For(r, NOW)
	T.eq(a, b, "same line every time")
	T.ok(not a:find("{", 1, true), "every token filled: " .. a)
	local hits = 0
	for _, needle in ipairs({ "2d", "1.5 levels", "Brill" }) do if a:find(needle, 1, true) then hits = hits + 1 end end
	T.ok(hits >= 1, "mentions this character's own numbers: " .. a)
end

function cases.every_line_in_the_bank_fills_for_every_state()
	local ns = load()
	local L = ns.Lines
	for state, bank in pairs(L.BANK) do
		for i = 1, #bank do
			local c = { full = "Alt" .. i, class = "WARRIOR", zone = "Durotar", level = 20, restKind = "outside" }
			local p = state ~= "max" and { pct = 0.5, levels = 0.75, left = 3 * H, fullSince = NOW - H } or nil
			local line = L.For(row(state, p, c), NOW, state == "me")
			T.ok(#line > 10 and not line:find("{", 1, true), state .. ": " .. line)
		end
	end
end

function cases.hero_line_leads_with_the_decision()
	local L = load().Lines
	local full = L.Decision(row("full", { pct = 1, levels = 1.7, left = 0, fullSince = NOW - D }, { class = "MAGE" }), NOW)
	T.ok(full:find("^Send me%.") ~= nil, "decision first: " .. full)
	T.ok(not full:find("1.7", 1, true), "no numbers: the figure says how much, once")
	T.ok(#full > #"Send me.  ", "then the character's own line")
	T.ok(L.Decision(row("max", nil, {}), NOW) == nil, "nothing to decide at max level")
end

return cases
