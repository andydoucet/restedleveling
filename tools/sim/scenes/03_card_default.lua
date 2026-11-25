-- Scene 03: click the PLAY NEXT hero: Le Nette's character card opens next to the window and talks.
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.hero)
C_Timer.After(2, function() RLCrop(RestedLevelingCard) end)
