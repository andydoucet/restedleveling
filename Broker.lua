-- Rested Leveling: LibDataBroker feed ("3 full | 2 resting | 1 outside", tooltip = mini roster) and the minimap
-- button. ElvUI turns any LDB feed into a datatext by itself. The minimap button hides when ElvUI is loaded
-- (option to show it anyway).

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
	OnEnter = function(owner) ns.Tip.Show(owner) end,
	OnLeave = function() ns.Tip.Hide() end,
})

function Br.Update()
	if ns.Ready() then Br.feed.text = Br.Text(ns.Rows({ hideGrey = true })) end
end

function Br.UpdateMinimap()
	if not ICON then return end
	local o = ns.DB().opts
	local hide = o.minimap.hide or (ns.Style.Pick("auto") == "elvui" and not o.showMinimapWithElvUI)
	if hide then ICON:Hide("RestedLeveling") else ICON:Show("RestedLeveling") end
end

ns.RegisterCallback(Br, "LOGIN_DONE", function()
	if ICON and not ICON:IsRegistered("RestedLeveling") then ICON:Register("RestedLeveling", Br.feed, ns.DB().opts.minimap) end
	Br.UpdateMinimap()
	Br.Update()
end)
ns.RegisterCallback(Br, "ROSTER_CHANGED", Br.Update)
ns.RegisterCallback(Br, "TICK", Br.Update)
