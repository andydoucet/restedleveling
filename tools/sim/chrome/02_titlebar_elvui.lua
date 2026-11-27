-- render: --case v112
-- Chrome 02 (ILL-1299): the title bar's controls close up in the ElvUI + WC3 theme, right to left X, cog, chevron; the
-- cog hovered (its highlight and tooltip).
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
local m = RestedLevelingMain
m.cogBtn:LockHighlight()
m.cogBtn:ShowTip()
RLCROP_MARGIN = 60
C_Timer.After(2, function() RLCrop(m.compactBtn, m.cogBtn, m.rlClose, GameTooltip) end)
