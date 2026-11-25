-- Options: the settings page builds at login and its switches write the saved options.

local W = dofile("tests/world.lua")
local H, D = 3600, 86400

local function alt(full, class, levels, ago, resting)
	return { full = full, class = class, race = "Orc", sex = 2, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = resting, restKind = resting and "inn" or "outside",
		zone = "Durotar", subzone = "Razor Hill", t = W.NOW - ago, history = { { W.NOW - 2 * H, 0.4 }, { W.NOW - H, 0.5 } } }
end

local function world()
	local saved = { chars = {
		["N:Le Nette@?"] = alt("Le Nette", "MAGE", 1.5, 2 * D, true),
		["N:Le Dette@?"] = alt("Le Dette", "WARLOCK", 0.5, H, true),
		["N:Amdo Moto@?"] = alt("Amdo Moto", "ROGUE", 0.3, H, false),
	} }
	local state = { saved = saved, setup = function(game)
		game.UISpecialFrames = {}
		game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
		game.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
			ROGUE = { r = 1, g = 0.96, b = 0.41 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
		game.SetPortraitTexture = function() end
	end }
	local _, h = W.New(state)
	return h, state
end

local cases = {}

function cases.options_page_builds_and_switches_save()
	local h = world()
	local panel = h.Env().RestedLevelingOptions
	T.ok(panel, "options page built at login")
	FakeWoW.RunScript(panel, "OnShow")
	local grey
	for _, cb in ipairs(panel.checks) do if cb.sw.key == "showGrey" then grey = cb end end
	T.ok(grey:GetChecked(), "shown checked by default")
	grey:SetChecked(false)
	FakeWoW.RunScript(grey, "OnClick")
	T.eq(W.DB(h).opts.showGrey, false, "switch saved")
	T.clean(h)
end

return cases
