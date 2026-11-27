-- render: --case v112
-- Chrome 03 (ILL-1299): the Settings window (the cog) in the default theme: General, Accounts, Alerts, Positions,
-- About.
SlashCmdList.RESTEDLEVELING("")
RestedLevelingMain:Hide()
SlashCmdList.RESTEDLEVELING("options")
C_Timer.After(2, function() RLCrop(RestedLevelingSettings) end)
