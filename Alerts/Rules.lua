-- Rested Leveling: when to warn. Pure decisions (the game state is passed in), tested headless.
-- Alert kinds and their defaults: every kind on, sound only for the logout-outside warning.

local _, ns = ...
local Wd = ns.Words
local Ru = {}
ns.Rules = Ru

Ru.KINDS = {
	logout  = { label = "Logging out outside a rested area", sound = true },
	menu    = { label = "Not-resting strip under the Esc menu" },
	outrest = { label = "Rested ran out: who to play next" },
	lowrest = { label = "Rested running low (chat)" },
	filled  = { label = "An alt filled up while you play" },
	digest  = { label = "Login digest in chat" },
	bag     = { label = "Cozy Sleeping Bag ready" },
}
Ru.LOW = 0.10   -- "low" = 10% of the cap left

function Ru.Enabled(d, kind) return not (d.alertsOff and d.alertsOff[kind]) end

-- ctx: resting, atMax, level, target, restedLevels, cap.
-- Warn on /camp or quit only when it costs something: not resting, not max level, below target, not already full.
function Ru.LogoutWarning(ctx)
	if ctx.resting or ctx.atMax then return false end
	if ctx.target and ctx.level and ctx.level >= ctx.target then return false end
	if ctx.cap and ctx.restedLevels and ctx.restedLevels >= ctx.cap - 0.005 then return false end
	return true
end

-- The Esc-menu strip: same test as logging out.
Ru.MenuStrip = Ru.LogoutWarning

-- Rested went from something to nothing on this kill.
function Ru.RanOut(before, after) return (before or 0) > 0 and (after or 0) <= 0 end

-- Crossed below the low mark (fires once per crossing).
function Ru.WentLow(before, after, cap)
	local mark = Ru.LOW * cap
	return (before or 0) > mark and (after or 0) <= mark and (after or 0) > 0
end

-- Rows that became full since they were last announced. Marks them so each fill is announced once.
function Ru.NewlyFull(rows)
	local out = {}
	for _, r in ipairs(rows) do
		if r.group ~= 5 and r.p and r.p.left == 0 and r.p.fullSince then
			local mark = math.floor(r.p.fullSince)
			if r.c.alertedFor ~= mark then
				r.c.alertedFor = mark
				out[#out + 1] = r
			end
		end
	end
	return out
end

-- The login digest: a few short chat lines.
function Ru.Digest(rows, now, me)
	local full, soon = {}, nil
	for _, r in ipairs(rows) do
		if r.group ~= 5 and r.p then
			if r.p.left == 0 then full[#full + 1] = r.c.full
			elseif not soon or r.p.left < soon.p.left then soon = r end
		end
	end
	local out = {}
	if #full > 0 then
		out[#out + 1] = ("%d full: %s."):format(#full, table.concat(full, ", ", 1, math.min(#full, 5)) .. (#full > 5 and ", ..." or ""))
	end
	if soon then
		out[#out + 1] = ("Next to fill: %s. %s."):format(soon.c.full or "?", Wd.FullLine(soon.p, now))
	end
	if me and me.lastLogoutOutside then
		out[#out + 1] = "Last time you logged out here it was outside: this one filled 4x slower."
	end
	if #out == 0 then out[1] = "Nobody else recorded yet. Log your alts in and out once." end
	return out
end

-- The toast after the last of the rest is used: ("Play next: Le Nette", "Full · 1.7 levels of double XP").
-- `colorName` optionally colours the name (class colour in the UI).
function Ru.NextUp(rows, colorName)
	local r = rows[1]
	if not r or r.group == 5 or not r.p then return "No one else is rested yet.", "Park this one in an inn tonight." end
	local name = colorName and colorName(r.c.class, r.c.full or "?") or (r.c.full or "?")
	local word = (r.state == "full") and "Full" or (math.floor(r.p.pct * 100) .. "% full")
	return ("Play %s  ·  %s banked"):format(name, Wd.Levels(r.p.levels)), ("%s  ·  double XP waiting"):format(word)
end

return Ru
