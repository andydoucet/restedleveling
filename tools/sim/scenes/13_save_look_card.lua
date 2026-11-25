-- Scene 13 (ILL-1279): click the now-playing strip: your own card, the live model (waist up, in the figure column on
-- the right; a labelled box here) and "Save my look" under the bubble.
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.current)
RLModelPlaceholder(RestedLevelingCard.stage)   -- the sim cannot draw the model: its frame, labelled
C_Timer.After(2, function() RLCrop(RestedLevelingMain, RestedLevelingCard) end)
