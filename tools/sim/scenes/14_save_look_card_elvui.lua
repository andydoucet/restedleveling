-- Scene 14 (ILL-1279): the same under ElvUI + WC3: your own card with "Save my look".
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.current)
RLModelPlaceholder(RestedLevelingCard.stage)   -- the sim cannot draw the model: its frame, labelled
C_Timer.After(1, function() RLCheckWC3(RestedLevelingCard, "RestedLevelingCard") end)
C_Timer.After(2, function() RLCrop(RestedLevelingCard) end)
