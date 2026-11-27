-- render: --case v112
-- Chrome 05 (ILL-1299): "Unlock notifications" in the Settings window: move mode with the window docked at the left,
-- above the dimmed screen, the toggle now reading "Lock notifications". Full screen for context.
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
RestedLevelingMain:Hide()
SlashCmdList.RESTEDLEVELING("options")
RLClick(RestedLevelingSettings.page.move)
