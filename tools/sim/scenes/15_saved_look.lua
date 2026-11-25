-- render: --case look
-- Scene 15 (ILL-1279): Le Nette (the PLAY NEXT hero) and Le Beouf (row 2) saved their looks: each portrait shows the
-- face cropped from the screenshot, inside the usual ring with its state line and class crest badge (round 2: like the
-- live portrait); every other row keeps its class crest with the race badge. Then Le Nette's card.
-- The faces are fixture stand-ins (tools/sim/fixture/look_*.tga); in game it is the character's own screenshot.
SlashCmdList.RESTEDLEVELING("")
RLClick(RestedLevelingMain.hero)
C_Timer.After(2, function() RLCrop(RestedLevelingMain, RestedLevelingCard) end)
