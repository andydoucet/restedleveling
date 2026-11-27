-- render: --case v112
-- Chrome 04 (ILL-1299): the Settings window (the cog) in the ElvUI + WC3 theme: General, Accounts, Alerts,
-- Positions, About.
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
RestedLevelingMain:Hide()
SlashCmdList.RESTEDLEVELING("options")
C_Timer.After(2, function() RLCrop(RestedLevelingSettings) end)
