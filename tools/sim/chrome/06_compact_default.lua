-- render: --case v112
-- Chrome 06 (ILL-1299): the compact bar with the same controls (chevron down to expand, cog, X), default theme.
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.compactBtn)
RestedLevelingCompact:ClearAllPoints()
RestedLevelingCompact:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
RLCROP_MARGIN = 30
C_Timer.After(1.5, function() RLCrop(RestedLevelingCompact) end)
