-- render: --case v112
-- Council 05: the alerts at rest where the player moved them, down the left of the screen: the logout warning on
-- top, the Esc menu card (detached from the menu) under it, then a toast. For the shot all three show at once; in play
-- only one shows at a time (toasts wait for the banner; the card hides under the banner).
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
RestedLevelingMain:Hide()
RestedLevelingDB.positions = {
	banner = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -64 },
	menu = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -200 },
	toasts = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -336 },
}
if GameMenuFrame then GameMenuFrame:Show() end   -- the card shows (not resting), at its own place
local strip = RestedLevelingMenuStrip
if strip then strip:Hide() end   -- out of the way while the toast comes in (toasts wait while it shows)
RLFIX.rested = 0
FireEvent("PLAYER_XP_UPDATE", "player")   -- the last kill uses up the rest: the "who next" toast
C_Timer.After(0.5, function()
	local toast
	for _, f in ipairs({ UIParent:GetChildren() }) do if f.timer and f:IsShown() then toast = f end end
	if toast then toast:SetScript("OnUpdate", nil) toast:SetAlpha(1) end   -- held for the shot
	FireEvent("PLAYER_CAMPING")
	if StaticPopup1 then StaticPopup1:Hide() end   -- the game's own countdown, not ours
	C_Timer.After(0.3, function()
		if strip then strip:Show() end
		C_Timer.After(0.5, function() RLCrop(RestedLevelingBanner, strip, toast) end)
	end)
end)
