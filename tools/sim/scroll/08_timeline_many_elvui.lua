-- render: --case many
-- Scroll 08 (1.3.1): the timeline under ElvUI + WC3, scrolled two lanes down.
SlashCmdList.WC3THEME("wc3")
RestedLevelingDB.opts.view = "timeline"
SlashCmdList.RESTEDLEVELING("")
local t = RestedLevelingMain.timeline
t:GetScript("OnMouseWheel")(t, -2)
C_Timer.After(2, function() RLCrop(RestedLevelingMain) end)
