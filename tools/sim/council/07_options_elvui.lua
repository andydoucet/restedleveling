-- render: --case v112
-- Council 07: the options page in the game's Settings panel: style, Show accounts, the low rest warning slider,
-- Move notifications and the switches.
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")   -- render.sh checks the skin on our main window, so it is built (then closed)
RestedLevelingMain:Hide()
SlashCmdList.RESTEDLEVELING("options")
C_Timer.After(2, function()
	if SettingsPanel and SettingsPanel:IsShown() then RLCrop(SettingsPanel) else RLCrop(RestedLevelingOptions) end
end)
