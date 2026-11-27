-- render: --case v112
-- Chrome 07 (ILL-1299): the minimap button (the app icon) and its tip with the click hints, default UI.
local b = LibDBIcon10_RestedLeveling
local fn = b and b:GetScript("OnEnter")
if fn then fn(b) end
RLCROP_MARGIN = 30
C_Timer.After(1.5, function() RLCrop(Minimap, b, RestedLevelingTip) end)
