-- Scene 08: the Esc menu while not resting: the informational strip under the Game Menu, the only alert on screen.
if GameMenuFrame then GameMenuFrame:Show() end
C_Timer.After(1, function() RLCrop(GameMenuFrame, RestedLevelingMenuStrip) end)
