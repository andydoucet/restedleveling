-- With ElvUI loaded, Rested Leveling inherits it: windows go through ElvUI's skin calls (so a skin such as
-- ElvUI_WC3 can paint them), action buttons stay our own enamel, and check boxes keep a visible tick even after the
-- skin strips their textures.

local W = dofile("tests/world.lua")
local D = 86400

-- A minimal ElvUI: E:GetModule("Skins") records every S:Handle* call; HandleCheckBox strips the check like the real
-- one replaces it.
local function elvui(calls, skinArt)
	local S = setmetatable({}, { __index = function(_, method)
		return function(_, frame)
			calls[#calls + 1] = { method = method, frame = frame }
			if method == "HandleCheckBox" then frame.__stripped = true end
			if method == "HandlePortraitFrame" or method == "HandleFrame" then
				frame.Center = frame:CreateTexture(nil, "BACKGROUND")   -- ElvUI's template fill
				if skinArt then   -- a skin hooked in and drew its own window art
					frame:CreateTexture(nil, "BACKGROUND", nil, -6):SetTexture("Interface\\AddOns\\SomeSkin\\Media\\wood.tga")
				end
			end
		end
	end })
	local E = { media = { normFont = "Fonts\\FRIZQT__.TTF", normTex = "Interface\\Buttons\\WHITE8X8",
		blankTex = "Interface\\Buttons\\WHITE8X8", backdropcolor = { r = 0.1, g = 0.1, b = 0.1 },
		backdropfadecolor = { r = 0.06, g = 0.06, b = 0.06, a = 0.8 }, bordercolor = { r = 0, g = 0, b = 0 } } }
	function E:GetModule(name) if name == "Skins" then return S end end
	return { E }
end

local function world(opts, skinArt)
	local calls = {}
	local saved = { opts = opts or {}, chars = {
		["N:Le Nette@?"] = { full = "Le Nette", class = "MAGE", race = "Scourge", sex = 3, level = 22, xpMax = 10000,
			rested = 15000, resting = true, restKind = "inn", t = W.NOW - 2 * D },
		["N:Le Dette@?"] = { full = "Le Dette", class = "WARLOCK", race = "Scourge", sex = 2, level = 21, xpMax = 10000,
			rested = 5000, resting = true, restKind = "inn", t = W.NOW - D },
	} }
	local state = { saved = saved, setup = function(game, h)
		rawset(h.Env(), "ElvUI", elvui(calls, skinArt))   -- an addon global, not a client name
		game.UISpecialFrames = {}
		game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
		game.SetPortraitTexture = function() end
	end }
	local _, h = W.New(state)
	return h, calls
end

local function handled(calls, method, frame)
	for _, c in ipairs(calls) do if c.method == method and (frame == nil or c.frame == frame) then return true end end
	return false
end

local cases = {}

function cases.windows_go_through_the_elvui_skin_by_default()
	local h, calls = world()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	T.ok(handled(calls, "HandleFrame", main), "main window handed to the skin")
	T.ok(main.TitleContainer == nil and main.TitleText == nil, "no template title for a skin to put a plaque on")
	T.eq(main.rlHostTitle:GetText(), "Rested Leveling", "our own quiet title instead")
	T.ok(main.rlChrome == nil, "none of our own frame art on it")
	T.ok(not handled(calls, "HandleButton", main.hero.open), "action buttons are our own enamel")
	T.ok(not main.roster.rows[1].base:IsShown(), "no tinted rows: like the host's own lists")
	T.ok(main.roster.rows[1].stripe:IsShown(), "the state rail stays")
	T.ok(handled(calls, "HandleCheckBox", main.greyCheck), "check boxes still go through the skin")
	T.clean(h)
end

function cases.compact_sits_in_the_title_bar_in_both_styles()
	local h = world()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	local point = main.compactBtn:GetPoint(1)
	T.eq(point, "TOPRIGHT", "Compact sits in the title bar, as on the default frame")
	T.eq(main.compactBtn:GetHeight(), 22, "22 px, like the host's buttons")
	T.clean(h)
	h = world({ elvuiWindow = "own" })
	h.Slash("RESTEDLEVELING", "")
	T.eq((h.Env().RestedLevelingMain.compactBtn:GetPoint(1)), "TOPRIGHT", "on our own frame it stays on the rail")
	T.clean(h)
end

function cases.own_frame_is_the_opt_out()
	local h, calls = world({ elvuiWindow = "own" })
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	T.ok(not handled(calls, "HandlePortraitFrame", main), "not handed to the skin")
	T.ok(main.rlChrome ~= nil, "our own frame")
	T.clean(h)
end

function cases.check_box_keeps_its_tick_after_the_skin()
	local h, calls = world()
	h.Slash("RESTEDLEVELING", "")
	local cb = h.Env().RestedLevelingMain.greyCheck
	T.ok(handled(calls, "HandleCheckBox", cb) and cb.__stripped, "skinned (and stripped)")
	T.ok(cb.rlTick and cb.rlTick:IsShown(), "checked: tick shown")
	cb:SetChecked(false)
	T.ok(not cb.rlTick:IsShown(), "unchecked: tick hidden")
	cb:SetChecked(true)
	T.ok(cb.rlTick:IsShown(), "checked again: tick shown")
	T.clean(h)
end

function cases.a_skins_window_art_shows_through_our_window()
	local h = world(nil, true)
	h.Slash("RESTEDLEVELING", "")
	T.eq(h.Env().RestedLevelingMain.Center:GetAlpha(), 0, "template fill cleared over the skin's art")
	local h2 = world(nil, false)
	h2.Slash("RESTEDLEVELING", "")
	T.eq(h2.Env().RestedLevelingMain.Center:GetAlpha(), 1, "plain ElvUI keeps its fill")
end

-- Desk steer (r5): ElvUI mode inherits ElvUI's own panel colours (E.media), it does not invent them.
function cases.inner_panels_take_elvui_media_colours()
	local h = world()
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	local bg = main.list.__bg
	T.ok(bg and bg[1] == 0.1 and bg[2] == 0.1 and bg[3] == 0.1, "the roster well is E.media.backdropcolor")
	T.eq(main.list.__backdrop.bgFile, "Interface\\Buttons\\WHITE8X8", "on ElvUI's blank texture")
	T.clean(h)
end

-- Council r5: inside a skin's own window art (a skin on top of ElvUI), the wells take the skin's warm well, so panels
-- and window read as one family; with plain ElvUI they keep ElvUI's colours (the test above).
function cases.inside_a_skinned_window_wells_take_the_skins_warm_tone()
	local h = world(nil, true)   -- a skin drew its own window art
	h.Slash("RESTEDLEVELING", "")
	local main = h.Env().RestedLevelingMain
	T.has(main.list.__backdrop.bgFile, "sw_host_well", "the roster well takes the skin's warm well")
	T.clean(h)
end

return cases
