-- Scene 04: the character card under ElvUI + WC3, for a character parked outside (cold-road stage).
SlashCmdList.WC3THEME("wc3")   -- what the player types to turn the WC3 Gatewood skin on
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.roster.rows[5])
C_Timer.After(1, function() RLCheckWC3(RestedLevelingCard, "RestedLevelingCard") end)
C_Timer.After(2, function() RLCrop(RestedLevelingCard) end)
