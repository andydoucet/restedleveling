-- render: --case v112
-- Council 03: the 48-hour fill timeline (the band's TIMELINE tab), under ElvUI + WC3, the mouse on Le Bankken's lane.
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
for _, b in ipairs(RestedLevelingMain.tabs) do if b.view == "timeline" then RLClick(b) end end
C_Timer.After(1, function()
	local lane = RestedLevelingMain.timeline.lanes[2]
	lane:GetScript("OnEnter")(lane)
end)
C_Timer.After(2, function() RLCrop(RestedLevelingMain, GameTooltip) end)
