-- render: --case v112
-- Council 06: Le Beouf's character card under ElvUI + WC3: a saved look (a stand-in face: the sim has no screenshots)
-- with the class crest as its badge. Opened the way a player does: a click on its roster row.
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
for _, row in ipairs(RestedLevelingMain.roster.rows) do
	if row:IsShown() and row.data and row.data.c.full == "Le Beouf" then RLClick(row) end
end
RestedLevelingMain:Hide()
C_Timer.After(1, function() RLCheckWC3(RestedLevelingCard, "RestedLevelingCard") end)
C_Timer.After(2.5, function() RLCrop(RestedLevelingCard) end)
