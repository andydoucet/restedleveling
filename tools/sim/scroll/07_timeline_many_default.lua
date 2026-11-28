-- render: --case many
-- Scroll 07 (1.3.1): the timeline with thirteen lanes: five shown, the same scrollbar, the same window height.
RestedLevelingDB.opts.view = "timeline"
SlashCmdList.RESTEDLEVELING("")
C_Timer.After(2, function() RLCrop(RestedLevelingMain) end)
