-- Rested Leveling: LibDataBroker feed ("3 full | 2 resting | 1 outside", tooltip = mini roster) and the minimap
-- button (the app icon, shown by default with or without ElvUI; one switch, or /rlvl minimap, hides it). ElvUI
-- turns any LDB feed into a datatext by itself. Left-click: the window, right-click: our settings.

local _, ns = ...
local St, M = ns.Style, ns.Model
local Br = {}
ns.Broker = Br

local LDB = LibStub("LibDataBroker-1.1")
local ICON = LibStub("LibDBIcon-1.0", true)

local function color(state, text) return "|c" .. St.Hex(St.StateColor(state)) .. text .. "|r" end

function Br.Text(rows)
	local full, resting, outside = M.Counts(rows)
	return ("%s | %s | %s"):format(color("full", full .. " full"), color("resting", resting .. " resting"),
		color("outside", outside .. " outside"))
end

Br.feed = LDB:NewDataObject("RestedLeveling", {
	type = "data source", label = "Rested", text = "Rested Leveling", icon = St.MEDIA .. "icon",
	OnClick = function(_, button)
		if button == "RightButton" and ns.OpenOptions then ns.OpenOptions() else ns.ToggleMain() end
	end,
	-- Our own themed tip rather than the host's generic tooltip (LDB displays call OnEnter / OnLeave).
	OnEnter = function(owner)   -- LibDBIcon's button can also be dragged around the minimap
		local minimap = owner and owner.GetName and tostring(owner:GetName() or ""):find("^LibDBIcon10_")
		ns.Tip.Show(owner, minimap and (ns.Tip.HINT .. "  ·  Drag: move") or nil)
	end,
	OnLeave = function() ns.Tip.Hide() end,
})

function Br.Update()
	if ns.Ready() then Br.feed.text = Br.Text(ns.Rows({ hideGrey = true })) end
end

function Br.UpdateMinimap()
	if not ICON then return end
	local o = ns.DB().opts
	if o.minimap.hide then ICON:Hide("RestedLeveling") else ICON:Show("RestedLeveling") end
end

-- /rlvl minimap: show or hide the button (for whoever hid it and lost the switch).
ns.slash.minimap = function()
	local o = ns.DB().opts
	o.minimap.hide = not o.minimap.hide
	Br.UpdateMinimap()
	if ns.Options then ns.Options.RefreshAll() end
	ns.Util.Print(o.minimap.hide and "minimap button hidden (/rlvl minimap brings it back)." or "minimap button shown.")
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl minimap - show or hide the minimap button"

ns.RegisterCallback(Br, "LOGIN_DONE", function()
	if ICON and not ICON:IsRegistered("RestedLeveling") then ICON:Register("RestedLeveling", Br.feed, ns.DB().opts.minimap) end
	Br.UpdateMinimap()
	Br.Update()
end)
ns.RegisterCallback(Br, "ROSTER_CHANGED", Br.Update)
ns.RegisterCallback(Br, "TICK", Br.Update)
