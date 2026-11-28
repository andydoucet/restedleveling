-- Rested Leveling: the Settings window (the cog in a title bar, the minimap button's right-click, /rlvl options). Our
-- own movable window in the main window's chrome around the settings page (Options.lua builds the same page into the
-- Blizzard Settings panel). Esc closes it; where it was dragged is saved (RestedLevelingDB.positions.settings).
-- While the notifications are unlocked it docks at the left edge, above the dimmed screen, beside the placeholders.
-- Taller than the screen (a small screen with bigger windows): the page scrolls, with the main window's scrollbar.

local _, ns = ...
local St, Wg = ns.Style, ns.Widgets
local Se = {}
ns.Settings = Se

local PAD, INSET = 20, 14

-- The window's rect in UIParent units: what positions are saved in.
local function ratio(f) return f:GetEffectiveScale() / UIParent:GetEffectiveScale() end

-- Where and on which layer, from the current move-mode state (also for a window first opened while unlocked).
local function place(f)
	local on = ns.Move.Active()
	f:SetFrameStrata(on and "FULLSCREEN_DIALOG" or "HIGH")
	if on then f:SetFrameLevel(30) end   -- over the shade (1), the placeholders (10) and the move bar (20)
	f:ClearAllPoints()
	local r = ratio(f)
	if ns.Move.Active() then   -- beside the placeholders (they start in the middle of the screen)
		f:SetPoint("LEFT", UIParent, "LEFT", 24 / r, 0)
		return
	end
	local pos = ns.Move.Valid((ns.DB().positions or {}).settings)
	if pos then f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x / r, pos.y / r) else f:SetPoint("CENTER", 0, 20) end
end

local function save(f)
	local r = ratio(f)
	local l, b = f:GetLeft(), f:GetBottom()
	if not (l and b) then return end
	local d = ns.DB()
	d.positions = d.positions or {}
	d.positions.settings = ns.Move.FromRect(l * r, b * r, f:GetWidth() * r, f:GetHeight() * r, UIParent:GetWidth(), UIParent:GetHeight())
end

function Se.Create()
	if Se.frame then return Se.frame end
	St.Ensure()
	local ok, f = pcall(CreateFrame, "Frame", "RestedLevelingSettings", UIParent, St.WindowTemplate())
	if not ok or not f then
		f = CreateFrame("Frame", "RestedLevelingSettings", UIParent, "BackdropTemplate")
		St.Panel(f, "card")
	end
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)   -- our DB holds the position, not the client's layout cache
		save(self)
	end)
	St.Window(f, "Rested Leveling Settings")
	St.Scale(f)
	tinsert(UISpecialFrames, "RestedLevelingSettings")
	f.top = St.HostFrame() and 40 or (St.RAIL + 12)   -- under the host skin's title band, or our rail
	local w = ns.Options.W + INSET * 2
	f.well = CreateFrame("Frame", nil, f, "BackdropTemplate")   -- the page's well, behind the scrolling area
	f.well:SetPoint("TOPLEFT", PAD, -f.top)
	f.well:SetWidth(w)
	St.Well(f.well)
	f.scroll = CreateFrame("ScrollFrame", nil, f)
	f.scroll:SetPoint("TOPLEFT", f.well, "TOPLEFT", 0, 0)
	f.scroll:SetPoint("BOTTOMRIGHT", f.well, "BOTTOMRIGHT", 0, 0)
	f.page = CreateFrame("Frame", nil, f.scroll)
	f.page:SetWidth(w)
	f.scroll:SetScrollChild(f.page)
	f.scroll:EnableMouseWheel(true)
	f.scroll:SetScript("OnMouseWheel", function(_, delta) Se.ScrollTo((f.scrollAt or 0) - delta * 40) end)
	f.bar = Wg.ScrollBar(f.well, function(at) Se.ScrollTo(at) end, 40)   -- drag, page, wheel; only when it scrolls
	f.bar:SetPoint("TOPRIGHT", -3, -3)
	f.bar:SetFrameLevel(f.scroll:GetFrameLevel() + 2)
	ns.Options.Build(f.page, INSET, -INSET)
	f:SetWidth(w + PAD * 2)
	f:SetScript("OnShow", function() place(f) Se.Refresh() end)
	Se.frame = f
	f:Hide()
	place(f)
	return f
end

-- Fill the page and fit the window to it (the account choices can take a second row).
function Se.Refresh()
	local f = Se.frame
	if not f or not f:IsShown() then return end
	ns.Options.Refresh(f.page)
	local h = ns.Options.Height(f.page) + INSET   -- Height counts the top inset
	f.page:SetHeight(h)
	local room = (UIParent:GetHeight() - 40) / ratio(f)   -- the screen, in the window's own units
	local winH = math.min(f.top + h + PAD, room)
	f:SetHeight(winH)
	f.well:SetHeight(winH - f.top - PAD)
	f.scrollMax = math.max(0, h - (winH - f.top - PAD))
	Se.ScrollTo(f.scrollAt or 0)
end

-- Scroll the page to `y` (clamped), and set the scrollbar to match.
function Se.ScrollTo(y)
	local f = Se.frame
	local max = f.scrollMax or 0
	f.scrollAt = math.max(0, math.min(max, y))
	f.scroll:SetVerticalScroll(f.scrollAt)
	local view = f.well:GetHeight()
	f.bar:SetHeight(math.max(1, view - 6))
	f.bar:SetRange(view + max, view, f.scrollAt)
end

function Se.Show()
	local f = Se.Create()
	f:Show()
	if f.Raise then f:Raise() end
end

function Se.Toggle()
	local f = Se.Create()
	if f:IsShown() then f:Hide() else Se.Show() end
end

-- Unlocked: above the dimmed screen at the left edge; locked again: back where it was.
ns.RegisterCallback(Se, "MOVE_MODE", function()
	local f = Se.frame
	if not f then return end
	place(f)
end)
ns.RegisterCallback(Se, "ROSTER_CHANGED", function() Se.Refresh() end)
