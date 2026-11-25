-- Scene 02: the main window under ElvUI with the WC3 "Gatewood" skin active.
SlashCmdList.WC3THEME("wc3")   -- what the player types to turn the WC3 Gatewood skin on
SlashCmdList.RESTEDLEVELING("")
C_Timer.After(2, function() RLCrop(RestedLevelingMain) end)   -- 1:1, our window only
