-- render: --case andy
-- Scene 09 (ILL-1274): Andy's roster. Nobody is rested yet, so the hero says who fills first and when, not "play
-- next". Buttons are held in their hover state (Compact, View details, Link account...) so each label can be
-- checked over the hover face.
SlashCmdList.RESTEDLEVELING("")
RestedLevelingMain.compactBtn:LockHighlight()
RestedLevelingMain.hero.open:LockHighlight()
RestedLevelingMain.roster.guide.link:LockHighlight()
C_Timer.After(2, function() RLCrop(RestedLevelingMain) end)
