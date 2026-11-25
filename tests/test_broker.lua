-- The LibDataBroker feed: "N full | N resting | N outside", which ElvUI and other displays show as a datatext.

local W = dofile("tests/world.lua")
local H, D = 3600, 86400

local function alt(full, levels, ago, resting, extra)
	local c = { full = full, class = "MAGE", race = "Scourge", sex = 3, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = resting, restKind = resting and "inn" or "outside", t = W.NOW - ago }
	for k, v in pairs(extra or {}) do c[k] = v end
	return c
end

local function world(state)
	state = state or {}
	local sounds = {}
	state.setup = function(game)
		game.PlaySound = function(id) sounds[#sounds + 1] = id end
		game.SOUNDKIT = { RAID_WARNING = 8959 }
		game.GameMenuFrame = game.CreateFrame("Frame", "GameMenuFrame")
		game.GameMenuFrame:Hide()
	end
	local game, h = W.New(state)
	return game, h, state, sounds
end

local function banner(h) local b = h.Env().RestedLevelingBanner; return b and b:IsShown() end
local function printed(h, needle)
	for _, l in ipairs(h.Printed()) do if l:find(needle, 1, true) then return true end end
	return false
end

local cases = {}

function cases.datatext_counts()
	local saved = { chars = {
		["N:A@?"] = alt("Full One", 1.5, 2 * D, true),
		["N:B@?"] = alt("Resting One", 0.5, 0, true),
		["N:C@?"] = alt("Outside One", 0.5, 0, false),
	} }
	local _, h, state = world({ saved = saved })
	local feed = h.Env().LibStub("LibDataBroker-1.1"):GetDataObjectByName("RestedLeveling")
	local text = feed.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	T.eq(text, "1 full | 1 resting | 1 outside", "datatext")
	T.ok(state, "world")
	T.clean(h)
end

function cases.hover_shows_our_own_roster_tip()
	local saved = { chars = {
		["N:A@?"] = alt("Full One", 1.5, 2 * D, true),
		["N:C@?"] = alt("Outside One", 0.5, 0, false),
	} }
	local _, h = world({ saved = saved })
	local feed = h.Env().LibStub("LibDataBroker-1.1"):GetDataObjectByName("RestedLeveling")
	local owner = h.Env().CreateFrame("Frame", nil, h.Env().UIParent)
	feed.OnEnter(owner)
	local tip = h.Env().RestedLevelingTip
	T.ok(tip and tip:IsShown(), "tip shown")
	T.has(tip.rows[1].name:GetText(), "Full One", "best first")
	T.has(tip.rows[1].state:GetText(), "Full", "state word")
	T.ok(not tip.rows[3].name:IsShown(), "no empty rows")
	feed.OnLeave(owner)
	T.ok(not tip:IsShown(), "hidden on leave")
	T.clean(h)
end

return cases
