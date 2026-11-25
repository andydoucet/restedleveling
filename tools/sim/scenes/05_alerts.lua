-- Scene 05: /camp outside a rested area. One warning only: the banner at rest, top-centre, above the game's own
-- logout countdown. The crop shows only our banner, so the game's countdown dialog is hidden for the shot (it is
-- the game's, not ours, and the simulator draws its text as "4Second:Seconds").
FireEvent("PLAYER_CAMPING")
C_Timer.After(1, function()
	if StaticPopup1 then StaticPopup1:Hide() end
	RLCrop(RestedLevelingBanner)
end)
