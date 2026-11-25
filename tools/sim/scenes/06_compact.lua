-- Scene 06: compact mode (dragged down above the toast area) with the datatext tooltip any LDB display shows; the last
-- kill uses up the rest, so a toast at the bottom says who to play next.
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.compactBtn)
RestedLevelingCompact:ClearAllPoints()
RestedLevelingCompact:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 250)
local feed = LibStub("LibDataBroker-1.1"):GetDataObjectByName("RestedLeveling")
feed.OnEnter(RestedLevelingCompact)   -- what a datatext or the minimap button does on hover
RLFIX.rested = 0
FireEvent("PLAYER_XP_UPDATE", "player")
C_Timer.After(1.5, function()
	local toast
	for _, f in ipairs({ UIParent:GetChildren() }) do if f.timer and f:IsShown() then toast = f end end
	RLCrop(RestedLevelingCompact, RestedLevelingTip, toast)
end)
