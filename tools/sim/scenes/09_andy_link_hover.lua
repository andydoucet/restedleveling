-- render: --case andy
-- Scene 09 (ILL-1274): Andy's roster. Nobody is rested yet, so the hero says who fills first and when, not "play
-- next". "Link account..." opens the inline name field in the guide. Two buttons are held in their hover state
-- (Compact, View details) so the label can be checked over the hover face.
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.roster.guide.link.open)
RestedLevelingMain.compactBtn:LockHighlight()
RestedLevelingMain.hero.open:LockHighlight()
RestedLevelingMain.roster.guide.link.cancel:LockHighlight()
C_Timer.After(2, function() RLCrop(RestedLevelingMain) end)
