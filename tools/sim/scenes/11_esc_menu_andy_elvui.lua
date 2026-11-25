-- render: --case andy
-- Scene 11 (ILL-1274): Andy's Esc menu under ElvUI, the FIRST time it opens: on Le Nette outside, with Le Jette in an
-- inn and nothing banked. The card is sized from the menu and hangs under it; Details sits on the card's right edge
-- in line with the close X; the next-character line is shortened rather than pushing the button.
SlashCmdList.WC3THEME("wc3")   -- Andy's skin; render.sh checks our window carries it, so the window is built (closed)
SlashCmdList.RESTEDLEVELING("")
RestedLevelingMain:Hide()
if GameMenuFrame then GameMenuFrame:Show() end
C_Timer.After(1, function() RLCrop(GameMenuFrame, RestedLevelingMenuStrip) end)
