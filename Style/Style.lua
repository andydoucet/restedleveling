-- Rested Leveling: the style layer. One interface, two backends (Style/Default.lua, Style/ElvUI.lua), picked by the
-- "style" option: auto (ElvUI when it is loaded), default or elvui. UI code only ever calls ns.Style.*.

local _, ns = ...
local St = {}
ns.Style = St

St.MEDIA = "Interface\\AddOns\\RestedLeveling\\media\\"
St.backends = {}

-- State colours, at least 40 degrees of hue apart and still distinct under ElvUI_WC3's wash, each with a non-colour
-- cue (icon and word) for colour-blind players. One word per state everywhere: chip, legend, card, tooltip.
St.STATE = {
	full    = { r = 0.24, g = 0.86, b = 0.42, word = "Full",        icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
	near    = { r = 0.95, g = 0.86, b = 0.23, word = "Nearly full", icon = "Interface\\Buttons\\UI-MicroStream-Yellow" },
	resting = { r = 0.91, g = 0.56, b = 0.18, word = "Resting",     icon = "Interface\\Icons\\Spell_Nature_Sleep" },
	outside = { r = 0.82, g = 0.23, b = 0.16, word = "Not resting", icon = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" },
	max     = { r = 0.47, g = 0.45, b = 0.42, word = "Max level",   icon = "Interface\\Icons\\Achievement_Level_60" },
	done    = { r = 0.47, g = 0.45, b = 0.42, word = "At target",   icon = "Interface\\Icons\\INV_Misc_Flag_01" },
	cur     = { r = 0.46, g = 0.73, b = 0.86, word = "Rested left", icon = "Interface\\Icons\\Spell_Nature_Sleep" },   -- the character you're on
}

-- Where a character was saved, as a badge.
St.PLACE = {
	inn     = { word = "Inn",          icon = "Interface\\Icons\\INV_Drink_05" },
	city    = { word = "City",         icon = "Interface\\Icons\\Ability_Townwatch" },
	bag     = { word = "Sleeping bag", icon = "Interface\\Icons\\INV_Misc_Bag_08" },
	outside = { word = "Outside",      icon = "Interface\\Icons\\Ability_Hunter_Pathfinding" },
}

-- Colours for fills are baked into small textures (media/sw_*, st_*, row_*, chip_*, bar_*) and drawn white, so they
-- look the same in any renderer (some treat vertex colours as linear and wash dark ones out). Vertex colours are left
-- for text, glows and highlights.
function St.Paint(t, name)
	t:SetTexture(St.MEDIA .. name)
	t:SetVertexColor(1, 1, 1, 1)
end

-- A flat panel: a swatch fill and a 1 px swatch edge (or none).
function St.Backdrop(frame, fill, edge, size)
	if not frame.SetBackdrop then return end
	frame:SetBackdrop({ bgFile = St.MEDIA .. fill, edgeFile = edge and (St.MEDIA .. edge) or nil, edgeSize = size or 1 })
	frame:SetBackdropColor(1, 1, 1, 1)
	if edge then frame:SetBackdropBorderColor(1, 1, 1, 1) end
end

-- Text: cream for reading, a softer cream for secondary lines, gold only for section labels and emphasis.
St.GOLD = { r = 0.84, g = 0.71, b = 0.42 }
St.CREAM = { r = 0.92, g = 0.87, b = 0.80 }
St.SECOND = { r = 0.90, g = 0.84, b = 0.76 }
St.ACTION = { r = 1.0, g = 0.83, b = 0.42 }   -- what to do next
St.MIN_TEXT = 12   -- no text smaller than this, in either style
St.MUTED = { r = 0.81, g = 0.76, b = 0.66 }   -- captions: still readable
St.BRONZE = { r = 0.40, g = 0.32, b = 0.22 }

function St.Color(fs, c) fs:SetTextColor(c.r, c.g, c.b) end

-- "Acct #3" for another account's character; nil for this account's (no point labelling your own).
function St.AccountTag(c)
	if not c.account or c.account == ns.DB().account then return nil end
	return "Acct " .. ns.AccountLabel(c.account)
end

function St.StateColor(state)
	local c = St.STATE[state] or St.STATE.max
	return c.r, c.g, c.b
end

function St.Hex(r, g, b)
	return ("ff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function St.ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.9, 0.9, 0.9
end

-- soft: mix the class colour 40% toward cream (roster rows and the tip), so a name never outshouts the state colours.
function St.ClassText(class, text, soft)
	local r, g, b = St.ClassColor(class)
	if soft then r, g, b = r * 0.6 + 0.94 * 0.4, g * 0.6 + 0.90 * 0.4, b * 0.6 + 0.82 * 0.4 end
	return "|c" .. St.Hex(r, g, b) .. tostring(text) .. "|r"
end

-- Which backend: the option, with "auto" meaning ElvUI when it is loaded.
function St.Pick(option)
	if option == "default" then return "default" end
	local elv = St.backends.elvui
	if elv and elv.Available() then return "elvui" end
	return "default"
end

function St.Use(name)
	St.name = St.backends[name] and name or "default"
	St.backend = St.backends[St.name]
	if St.backend.Init then St.backend.Init() end
	return St.name
end

local function call(method)
	return function(...)
		if not St.backend then St.Use(St.Pick(ns.DB().opts.style)) end
		local fn = St.backend[method] or St.backends.default[method]
		return fn(...)
	end
end

-- The interface. kind for Panel: "card", "inset", "row", "strip", "toast", "tooltip".
-- role for Font: "title", "hero", "name", "body", "small", "number", "label".
for _, m in ipairs({ "Window", "Panel", "Button", "Close", "Check", "Bar", "Tab", "ScrollBar", "Font", "BarTexture",
	"MakeButton", "MakeClose", "Slider" }) do
	St[m] = call(m)
end

-- An inner panel in the host's own colours under a host skin (ElvUI: E.media), else our inset. fade: the lighter fill.
function St.Well(frame, fade)
	St.Ensure()
	if St.HostFrame() and St.backend.Well then St.backend.Well(frame, fade) else St.Panel(frame, "inset") end
end
-- The host's panel fill { r, g, b, a } under a host skin, or nil.
function St.HostFill(fade)
	St.Ensure()
	local c = St.HostFrame() and St.backend.HostColors and St.backend.HostColors(fade)
	return c and c.bg or nil
end

-- The window scale option (a readable-size preset): 0.8 to 1.4, applied to our own windows only.
function St.Scale(frame)
	local sc = tonumber(ns.DB().opts.scale) or 1
	frame:SetScale(math.max(0.8, math.min(1.4, sc)))
end

-- True when the host UI's skin draws our window frame and title band (ElvUI unless the "own" opt-out is set):
-- then nothing of ours goes in that band, and window buttons sit in the footer as on the host's skinned windows.
function St.HostFrame()
	St.Ensure()
	return St.backend.HostFrame and St.backend.HostFrame() or false
end

-- The template our windows are built on: the client's portrait frame for our own chrome; a plain frame under a host
-- skin, so the skin draws the window but has no template title to put a plaque on (we draw a quiet title instead).
function St.WindowTemplate()
	return St.HostFrame() and "BackdropTemplate" or "PortraitFrameTemplate"
end

-- True when an ElvUI skin draws our surfaces, so rows and wells leave their fills to it.
function St.Skinned()
	St.Ensure()
	return St.backend.Skinned and St.backend.Skinned() or false
end

function St.Ensure()
	if not St.backend then St.Use(St.Pick(ns.DB().opts.style)) end
	return St.name
end
