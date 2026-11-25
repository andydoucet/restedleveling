-- Scene 13 (ILL-1279): click the now-playing strip: your own card, the live model, and "Save my look" top right.
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.current)
C_Timer.After(2, function() RLCrop(RestedLevelingMain, RestedLevelingCard) end)
