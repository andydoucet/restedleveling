-- render: --case v112
-- Council 08: compact mode with the datatext tooltip any LDB display (an ElvUI datatext, the minimap button) shows.
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.compactBtn)
RestedLevelingCompact:ClearAllPoints()
RestedLevelingCompact:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
local feed = LibStub("LibDataBroker-1.1"):GetDataObjectByName("RestedLeveling")
feed.OnEnter(RestedLevelingCompact)
C_Timer.After(1.5, function() RLCrop(RestedLevelingCompact, RestedLevelingTip) end)
