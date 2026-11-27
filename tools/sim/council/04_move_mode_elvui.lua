-- render: --case v112
-- Council 04: move mode (/rlvl move), full screen for context: the three placeholders in their real size and style,
-- the controls (Reset per item, Reset all, Done) and the dimmed game behind. The toasts were moved before (Reset lit).
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
RestedLevelingMain:Hide()
RestedLevelingDB.positions = { toasts = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -60, y = 220 } }
SlashCmdList.RESTEDLEVELING("move")
