-- render: --case many
-- Scroll 04 (1.3.1): ElvUI + WC3, scrolled to the middle (rows 6 to 10 of 13), the thumb hovered.
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
local r = RestedLevelingMain.roster
r:GetScript("OnMouseWheel")(r, -4)
r.bar.grab:GetScript("OnEnter")(r.bar.grab)
C_Timer.After(2, function() RLCrop(RestedLevelingMain) end)
