-- render: --case v112
-- Chrome 09 (ILL-1299 review): a small screen (UI scale 1.4: 771 units tall) with bigger windows: the Settings page
-- scrolls inside its well (mouse wheel), with a gold thumb; here scrolled down two notches.
UIParent:SetScale(1.4)
RestedLevelingDB.opts.scale = 1.15
SlashCmdList.RESTEDLEVELING("options")
local s = RestedLevelingSettings.scroll
s:GetScript("OnMouseWheel")(s, -1)
s:GetScript("OnMouseWheel")(s, -1)
C_Timer.After(2, function() RLCrop(RestedLevelingSettings) end)
