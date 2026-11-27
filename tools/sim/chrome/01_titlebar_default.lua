-- render: --case v112
-- Chrome 01 (ILL-1299): the title bar's controls close up in the default theme, right to left X, cog, chevron; the
-- cog hovered (its highlight and tooltip).
SlashCmdList.RESTEDLEVELING("")
local m = RestedLevelingMain
m.cogBtn:LockHighlight()
m.cogBtn:ShowTip()
RLCROP_MARGIN = 60
C_Timer.After(2, function() RLCrop(m.compactBtn, m.cogBtn, m.rlClose, GameTooltip) end)
