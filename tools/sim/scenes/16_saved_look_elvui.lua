-- render: --case look
-- Scene 16 (ILL-1279): the same saved looks under ElvUI + WC3 (no bronze ring: the thin state line only).
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.hero)
C_Timer.After(1, function() RLCheckWC3(RestedLevelingCard, "RestedLevelingCard") end)
C_Timer.After(2, function() RLCrop(RestedLevelingMain, RestedLevelingCard) end)
