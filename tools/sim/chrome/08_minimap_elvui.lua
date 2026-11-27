-- render: --case v112
-- Chrome 08 (ILL-1299): the minimap button (the app icon) and its tip with the click hints, ElvUI + WC3 (1.2 hid
-- it under ElvUI).
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
RestedLevelingMain:Hide()
local b = LibDBIcon10_RestedLeveling
local fn = b and b:GetScript("OnEnter")
if fn then fn(b) end
RLCROP_MARGIN = 30
C_Timer.After(1.5, function() RLCrop(Minimap, b, RestedLevelingTip) end)
