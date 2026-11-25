-- Scene 12 (ILL-1276): the card under ElvUI + WC3 saying Andy's line, which v1 cut to "Give me 9 days 2..." /
-- "Then I'm full at Thunder...". The line goes through the card's own typer, which fits the bubble when it finishes.
SlashCmdList.WC3THEME("wc3")
SlashCmdList.RESTEDLEVELING("")
for _, row in ipairs(RestedLevelingMain.roster.rows) do
	if row:IsShown() and (row.name:GetText() or ""):find("Le Beouf", 1, true) then RLClick(row) end
end
local f = RestedLevelingCard
local hook, text = "Give me 9 days 23 hours.", "Then I'm full at Thunder Bluff."
f.stage.bubble.line = { hook, text }
f.typer.hook, f.typer.text, f.typer.t = hook, text, 0
f.typer:Show()
C_Timer.After(1, function() RLCheckWC3(RestedLevelingCard, "RestedLevelingCard") end)
C_Timer.After(2.5, function() RLCrop(RestedLevelingCard) end)
