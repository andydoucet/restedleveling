-- Alert rules: when a logout costs rest (inn, world, capital /camp, max level, already full, at target), when rest
-- ran out or went low. Pure decisions, no frames.

local W = dofile("tests/world.lua")

local cases = {}

function cases.rules_matrix()
	local ns = W.Pure({ "Core/Util.lua", "Core/Model.lua", "Core/Identity.lua", "UI/Words.lua", "Alerts/Rules.lua" })
	local R = ns.Rules
	T.eq(R.LogoutWarning({ resting = false, level = 20, restedLevels = 0.2, cap = 1.5 }), true, "world: warn")
	T.eq(R.LogoutWarning({ resting = true, level = 20, restedLevels = 0.2, cap = 1.5 }), false, "inn or capital: no")
	T.eq(R.LogoutWarning({ resting = false, atMax = true, level = 60 }), false, "max level: no")
	T.eq(R.LogoutWarning({ resting = false, level = 20, restedLevels = 1.5, cap = 1.5 }), false, "already full: no")
	T.eq(R.LogoutWarning({ resting = false, level = 30, target = 30, restedLevels = 0.1, cap = 1.5 }), false, "at target: no")
	T.eq(R.RanOut(100, 0), true, "ran out")
	T.eq(R.RanOut(0, 0), false, "was already empty")
	T.eq(R.WentLow(0.2, 0.14, 1.5), true, "crossed 10% of cap")
	T.eq(R.WentLow(0.14, 0.12, 1.5), false, "already low")
end

return cases
