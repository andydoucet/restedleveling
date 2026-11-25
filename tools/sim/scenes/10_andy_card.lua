-- render: --case andy
-- Scene 10 (ILL-1274): Andy links his other account from the field (waiting for the other side), then opens Le
-- Jette's card: her class crest and race emblem instead of a stock face, the real-life time to full, professions once.
SlashCmdList.RESTEDLEVELING("")
local link = RestedLevelingMain.roster.guide.link
RLClick(link.open)
link.edit:SetText("Le Bankken")
local enter = link.edit:GetScript("OnEnterPressed")
enter(link.edit)
RLClick(RestedLevelingMain.hero)
C_Timer.After(2, function() RLCrop(RestedLevelingMain, RestedLevelingCard) end)
