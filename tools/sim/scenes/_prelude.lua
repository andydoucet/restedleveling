-- Shared by every scene: hide the simulator's own PTR feedback overlay (not part of the game UI we render).
for _, f in ipairs({ PTR_IssueReporter, PTRIssueReporterAlertFrame }) do if f and f.Hide then f:Hide() end end
-- Click a button the way the game does: run its OnClick handler.
function RLClick(b, button) local fn = b and b:GetScript("OnClick") if fn then fn(b, button or "LeftButton") end end
-- ElvUI scenes: the window itself must carry the ElvUI skin's window art (not just skinned buttons). Counts textures
-- from ElvUI_WC3 among the frame's own regions; raises an error (failing tools/render.sh) when there are none.
function RLCheckWC3(frame, label)
	local n = 0
	local function count(f)
		for _, r in ipairs({ f:GetRegions() }) do
			if r.IsObjectType and r:IsObjectType("Texture") then
				local t = r:GetTexture()
				if t and tostring(t):lower():find("elvui_wc3", 1, true) then n = n + 1 end
			end
		end
	end
	count(frame)
	if n == 0 then error("RLSIM_CHECK: no ElvUI_WC3 textures on " .. (label or "frame")) end
	return n
end
-- Crop the shot to our frames: prints their union as fractions of the screen (left, bottom, right, top), which
-- tools/render.sh turns into a 1:1 pixel crop with a 40 px margin. Call once, after the frames are shown.
-- RLCROP_MARGIN (optional, px) overrides the 40 px margin for scenes whose neighbours are not ours.
function RLCrop(...)
	local uw, uh = UIParent:GetWidth() * UIParent:GetEffectiveScale(), UIParent:GetHeight() * UIParent:GetEffectiveScale()
	local l, b, r, t = math.huge, math.huge, -math.huge, -math.huge
	for _, f in ipairs({ ... }) do
		if f and f:IsShown() and f:GetLeft() then
			local s = f:GetEffectiveScale()
			l, b = math.min(l, f:GetLeft() * s), math.min(b, f:GetBottom() * s)
			r, t = math.max(r, f:GetRight() * s), math.max(t, f:GetTop() * s)
		end
	end
	-- the simulator logs only errors, so the crop is reported as one (render.sh reads it and does not count it)
	if l < r then error(("RLSIM_CROP %.5f %.5f %.5f %.5f %d"):format(l / uw, b / uh, r / uw, t / uh, RLCROP_MARGIN or 40), 0) end
end
