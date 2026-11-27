-- Render sandbox only (never installed): wow-ui-sim treats vertex and backdrop colours as linear light and encodes
-- them to sRGB, so a dark colour washes out (ElvUI's backdrop 0.1 renders as 0.35 grey, where the game draws it near
-- black, as in the supplied in-game references). The game uses these values as sRGB directly. This shim linearises
-- them before the simulator re-encodes them, so every addon's colours (ElvUI's and ours) render as in the game.
-- It changes no addon code: it wraps the simulator's own widget methods, loaded before every addon (!RLSimFixture).
local function lin(c) return type(c) == "number" and c > 0 and c < 1 and c ^ 2.2 or c end
local function wrap(tbl, name)
	local orig = tbl and tbl[name]
	if type(orig) ~= "function" then return end
	tbl[name] = function(self, r, g, b, ...)
		if type(r) == "table" then return orig(self, r, g, b, ...) end   -- colour objects pass through
		return orig(self, lin(r), lin(g), lin(b), ...)
	end
end
local tex = getmetatable(UIParent:CreateTexture()).__index
wrap(tex, "SetVertexColor")
wrap(tex, "SetColorTexture")
local bar = getmetatable(CreateFrame("StatusBar")).__index
wrap(bar, "SetStatusBarColor")
if BackdropTemplateMixin then
	wrap(BackdropTemplateMixin, "SetBackdropColor")
	wrap(BackdropTemplateMixin, "SetBackdropBorderColor")
end
