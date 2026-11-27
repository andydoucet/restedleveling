-- Rested Leveling: movable notifications. The logout warning, the toasts and the Esc-menu card each keep a position
-- of the player's choosing, saved per account in RestedLevelingDB.positions as { point, relPoint, x, y } against
-- UIParent, anchored to the nearest edge (so it survives a resolution or UI scale change) and clamped to the screen.
--
-- /rlvl move (Options > Move notifications, or a right-click on the cog) shows each one as a labelled placeholder in its real size and style,
-- to drag, with Reset per item, Reset all and Done; Esc leaves. The Esc-menu card hangs under the menu until it is
-- moved (detached); Reset attaches it again. With ElvUI the three are also ElvUI movers in their own "Rested Leveling"
-- group in /moveui; both ways of moving them save to the same place. Not in combat.

local _, ns = ...
local St, Wg, U = ns.Style, ns.Widgets, ns.Util
local A = ns.Alerts
local Mv = {}
ns.Move = Mv

Mv.KEYS = { "banner", "toasts", "menu" }
Mv.ITEMS = {
	banner = { label = "Logout warning", note = "When you log out outside a rest area.", state = "outside", w = 510, h = 112,
		default = { point = "TOP", relPoint = "TOP", x = 0, y = -8 } },
	toasts = { label = "Toasts", note = "Filled up, ran out, running low, sleeping bag.", state = "full", w = 360, h = 74,
		default = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 150 } },
	menu = { icon = "MENU_ICON", label = "Esc menu card", note = "Under the Esc menu when not resting.", state = "outside", w = 360, h = 112 },
}
Mv.TOAST_STEP = 78   -- one toast above (or below) the last

local POINTS = { TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, CENTER = true, TOPLEFT = true, TOPRIGHT = true,
	BOTTOMLEFT = true, BOTTOMRIGHT = true }

-- A saved position, or nil when it is not a usable one.
function Mv.Valid(pos)
	if type(pos) ~= "table" or not POINTS[pos.point] or not POINTS[pos.relPoint] then return nil end
	if type(pos.x) ~= "number" or type(pos.y) ~= "number" or pos.x ~= pos.x or pos.y ~= pos.y then return nil end
	return pos
end

-- Where a point sits inside a w x h box, from its bottom-left corner.
local function at(point, w, h)
	local x = point:find("LEFT") and 0 or (point:find("RIGHT") and w or w / 2)
	local y = point:find("TOP") and h or (point:find("BOTTOM") and 0 or h / 2)
	return x, y
end

-- A frame's rect (left, bottom, width, height) on a W x H screen -> a position anchored to the nearest edge, the way
-- ElvUI's movers do it: top or bottom half, left / middle / right third.
function Mv.FromRect(l, b, w, h, W, H)
	local cx, cy = l + w / 2, b + h / 2
	local v = cy >= H / 2 and "TOP" or "BOTTOM"
	local hz = cx >= W * 2 / 3 and "RIGHT" or (cx <= W / 3 and "LEFT" or "")
	local point = v .. hz
	local px, py = at(point, W, H)
	local ax, ay = at(point, w, h)
	return { point = point, relPoint = point, x = math.floor(l + ax - px + 0.5), y = math.floor(b + ay - py + 0.5) }
end

-- The rect's left and bottom for a position.
function Mv.ToRect(pos, w, h, W, H)
	local px, py = at(pos.relPoint, W, H)
	local ax, ay = at(pos.point, w, h)
	return px + pos.x - ax, py + pos.y - ay
end

-- The same position moved just enough to keep the whole w x h box on the screen.
function Mv.Clamp(pos, w, h, W, H)
	if not (W and H and W > 0 and H > 0) then return pos end
	local l, b = Mv.ToRect(pos, w, h, W, H)
	l = U.Clamp(l, 0, math.max(0, W - w))
	b = U.Clamp(b, 0, math.max(0, H - h))
	return Mv.FromRect(l, b, w, h, W, H)
end

local function store() local d = ns.DB(); d.positions = d.positions or {}; return d.positions end
function Mv.Get(key) return Mv.Valid(store()[key]) end

-- UIParent units per unit of `f` (a frame parented to the Game Menu may be scaled with it).
local function ratio(f)
	local fs, us = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
	return (fs and us and fs > 0) and (us / fs) or 1
end

-- Put `f` at `pos` (UIParent units), clamped to the screen, `dy` further up (toast stacking).
local function put(f, pos, dy)
	local r = ratio(f)
	local w, h = (f:GetWidth() or 0) / r, (f:GetHeight() or 0) / r
	local p = Mv.Clamp({ point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y + (dy or 0) }, w, h,
		UIParent:GetWidth(), UIParent:GetHeight())
	f:ClearAllPoints()
	f:SetPoint(p.point, UIParent, p.relPoint, p.x * r, p.y * r)
end

-- Place a real alert frame: its saved position, else its default. Returns false for the Esc card when it is attached
-- (no saved position): the caller hangs it under the menu.
function Mv.Apply(f, key)
	local pos = Mv.Get(key) or Mv.ITEMS[key].default
	if not pos then return false end
	put(f, pos)
	return true
end

-- Toast `slot` (1..4): the first at the toasts' position, the rest stacked away from the nearer screen edge.
function Mv.PlaceToast(f, slot)
	local pos = Mv.Get("toasts") or Mv.ITEMS.toasts.default
	local _, b = Mv.ToRect(pos, A.WIDTH, 74, UIParent:GetWidth() or 0, UIParent:GetHeight() or 0)
	local up = (UIParent:GetHeight() or 0) == 0 or b + 37 < (UIParent:GetHeight() or 0) / 2
	put(f, pos, (slot - 1) * Mv.TOAST_STEP * (up and 1 or -1))
end

-- Re-place every alert that is showing (after a move, a reset or a UI scale change).
function Mv.ApplyAll()
	if A.banner then Mv.Apply(A.banner, "banner") end
	for i, t in ipairs(A.toasts or {}) do if t:IsShown() then Mv.PlaceToast(t, i) end end
	if A.strip and A.strip:IsShown() and A.LayoutStrip then A.LayoutStrip(A.strip) end
	if Mv.frames then for _, key in ipairs(Mv.KEYS) do Mv.PlacePlaceholder(key) end end
end

-- ElvUI movers --------------------------------------------------------------------------------------------------------

local E
local function elv()
	if E ~= nil then return E or nil end
	E = (type(ElvUI) == "table" and type(ElvUI[1]) == "table" and type(ElvUI[1].CreateMover) == "function") and ElvUI[1] or false
	return E or nil
end
local function moverName(key) return "RestedLeveling" .. key:sub(1, 1):upper() .. key:sub(2) .. "Mover" end
Mv.holders = {}

-- Push our position to the ElvUI mover (and ElvUI's saved layout), or forget it there on a reset.
local function syncMover(key, pos)
	local e, holder = elv(), Mv.holders[key]
	if not (e and holder and holder.mover) then return end
	local p = pos or Mv.ITEMS[key].default or Mv.MenuDefault()
	holder.mover:ClearAllPoints()
	holder.mover:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
	if pos then pcall(e.SaveMoverPosition, e, moverName(key))
	elseif type(e.ResetMovers) == "function" then pcall(e.ResetMovers, e, moverName(key))   -- ElvUI's own reset
	elseif type(e.db) == "table" and type(e.db.movers) == "table" then e.db.movers[moverName(key)] = nil end
end

-- One mover per alert, on an invisible holder of the alert's size; ElvUI keeps its own copy of the position, and a
-- drag in /moveui (or ElvUI's reset) comes back here through postdrag. Our saved position is the source of truth: at
-- load it is pushed to the mover even when ElvUI's profile holds another (several ElvUI profiles, one of ours).
function Mv.RegisterElvUI()
	local e = elv()
	if not e or Mv.elvDone then return end
	Mv.elvDone = true
	if e.ConfigMode_AddGroup then pcall(e.ConfigMode_AddGroup, e, "RESTEDLEVELING", "Rested Leveling") end
	for _, key in ipairs(Mv.KEYS) do
		local it = Mv.ITEMS[key]
		local holder = CreateFrame("Frame", "RestedLeveling" .. key .. "Holder", UIParent)
		holder:SetSize(it.w, it.h)
		local mine = Mv.Get(key)
		local p = it.default or Mv.MenuDefault()   -- the mover's origin is the default, so ElvUI's reset returns there
		holder:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
		Mv.holders[key] = holder
		local name = moverName(key)
		local ok = pcall(e.CreateMover, e, holder, name, it.label, nil, nil, function(mover)
			local moved = type(e.db) == "table" and type(e.db.movers) == "table" and e.db.movers[name]
			if moved then
				Mv.Save(key, mover:GetLeft(), mover:GetBottom(), mover:GetWidth(), mover:GetHeight(), true)
			elseif Mv.Get(key) then
				Mv.Reset(key, true)
			end
		end, "ALL,RESTEDLEVELING")
		if ok and mine then syncMover(key, mine) end
	end
end

-- Saving and resetting ------------------------------------------------------------------------------------------------

-- Save `key` from a rect in UIParent units. fromElvUI: the mover already holds it.
function Mv.Save(key, l, b, w, h, fromElvUI)
	if not (l and b and w and h) then return end
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	local pos = Mv.Clamp(Mv.FromRect(l, b, w, h, W, H), w, h, W, H)
	store()[key] = pos
	if not fromElvUI then syncMover(key, pos) end
	Mv.ApplyAll()
	return pos
end

-- Back to the default; the Esc card attaches under the menu again.
function Mv.Reset(key, fromElvUI)
	store()[key] = nil
	if not fromElvUI then syncMover(key, nil) end
	Mv.ApplyAll()
end

function Mv.ResetAll() for _, key in ipairs(Mv.KEYS) do Mv.Reset(key) end end

-- Where the attached Esc card shows: under the Game Menu, else a little below the screen centre.
function Mv.MenuDefault()
	local menu, it = GameMenuFrame, Mv.ITEMS.menu
	local b = menu and menu.GetBottom and menu:GetBottom()
	local l, w = menu and menu.GetLeft and menu:GetLeft(), menu and menu:GetWidth()
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	if b and l and w and W and H then
		local r = 1 / ratio(menu)
		local left = (l + w / 2) * r - it.w / 2
		local bottom = b * r - (A.STRIP_GAP or 12) - it.h
		return Mv.FromRect(left, bottom, it.w, it.h, W, H)
	end
	return { point = "TOP", relPoint = "CENTER", x = 0, y = -170 }
end

-- Move mode -----------------------------------------------------------------------------------------------------------

local function placeholder(key)
	local it = Mv.ITEMS[key]
	local f = CreateFrame("Frame", "RestedLevelingMove_" .. key, UIParent, "BackdropTemplate")
	f:SetSize(it.w, it.h)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(10)   -- over the dimmed screen
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	St.Panel(f, key == "banner" and "warn" or "toast")   -- the alert's own surface
	f.stripe = f:CreateTexture(nil, "ARTWORK")
	f.stripe:SetPoint("TOPLEFT", 4, -4)
	f.stripe:SetPoint("BOTTOMLEFT", 4, 4)
	f.stripe:SetWidth(4)
	St.Paint(f.stripe, "st_" .. it.state)
	f.stripe:SetShown(key ~= "menu")   -- like the real card: the Esc card has no red rail
	f.edge = CreateFrame("Frame", nil, f, "BackdropTemplate")   -- a gold outline: this one can be picked up
	f.edge:SetPoint("TOPLEFT", -3, 3)
	f.edge:SetPoint("BOTTOMRIGHT", 3, -3)
	f.edge:SetBackdrop({ edgeFile = St.MEDIA .. "sw_gold", edgeSize = 2 })
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(26, 26)
	f.icon:SetPoint("TOPLEFT", 18, -14)
	f.icon:SetTexture(it.icon and A[it.icon] or St.STATE[it.state].icon)
	if it.icon then f.icon:SetTexCoord(0, 1, 0, 1) end   -- each placeholder wears its alert's icon
	f.title = Wg.Text(f, "name", nil, 16)
	f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, 1)
	f.title:SetText(it.label)
	f.title:SetTextColor(0.98, 0.84, 0.5)
	f.note = Wg.Text(f, "body", nil, 13)
	f.note:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
	f.note:SetText(it.note)
	St.Color(f.note, St.CREAM)
	f.where = Wg.Text(f, "body", nil, 12)   -- the drag hint, right under the note: readable, no dead gap
	f.where:SetPoint("TOPLEFT", f.note, "BOTTOMLEFT", 0, -6)
	St.Color(f.where, St.CREAM)
	f.reset = St.MakeButton(f, 112, "Reset position", false, 22)   -- the same place on every placeholder
	f.reset:SetPoint("TOPRIGHT", -10, -12)
	if it.h < 100 then f.icon:SetPoint("TOPLEFT", 18, -12) end
	f.reset:SetScript("OnClick", function() Mv.Reset(key) end)
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)   -- our DB holds the position, not the client's layout cache
		Mv.Save(key, self:GetLeft(), self:GetBottom(), self:GetWidth(), self:GetHeight())
	end)
	return f
end

-- A placeholder at its item's saved (or default) place, saying which.
function Mv.PlacePlaceholder(key)
	local f = Mv.frames and Mv.frames[key]
	if not f then return end
	local saved = Mv.Get(key)
	local pos = saved or Mv.ITEMS[key].default or Mv.MenuDefault()
	put(f, pos)
	if key == "menu" then
		f.where:SetText(saved and "Custom position. Reset attaches it to the Esc menu again." or "Attached to the Esc menu. Drag to detach it.")
	else
		f.where:SetText(saved and "Custom position. Drag anywhere on this panel." or "Default position. Drag anywhere on this panel.")
	end
end

local function bar()
	local f = CreateFrame("Frame", "RestedLevelingMoveBar", UIParent, "BackdropTemplate")
	f:SetSize(430, 96)
	f:SetPoint("TOP", 0, -150)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(20)
	f:EnableMouse(true)
	St.Panel(f, "toast")   -- the alerts' own surface and gold outline: one family with the placeholders
	f.edge = CreateFrame("Frame", nil, f, "BackdropTemplate")
	f.edge:SetPoint("TOPLEFT", -3, 3)
	f.edge:SetPoint("BOTTOMRIGHT", 3, -3)
	f.edge:SetBackdrop({ edgeFile = St.MEDIA .. "sw_gold", edgeSize = 2 })
	f.title = Wg.Text(f, "name", nil, 16)
	f.title:SetPoint("TOP", 0, -14)
	f.title:SetText("Move notifications")
	St.Color(f.title, St.GOLD)
	f.text = Wg.Text(f, "body", nil, 13)
	f.text:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
	f.text:SetText("Drag each one where you want it. Esc or Done to finish.")
	St.Color(f.text, St.CREAM)
	f.done = St.MakeButton(f, 96, "Done", true, 24)
	f.done:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 12)
	f.done:SetScript("OnClick", function() Mv.Stop() end)
	f.resetAll = St.MakeButton(f, 150, "Reset all positions", false, 24)
	f.resetAll:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 12)
	f.resetAll:SetScript("OnClick", function() Mv.ResetAll() end)
	f:SetScript("OnHide", function() Mv.Stop() end)   -- Esc (UISpecialFrames) hides it
	tinsert(UISpecialFrames, "RestedLevelingMoveBar")
	f.shade = CreateFrame("Frame", nil, UIParent)   -- dims the game behind, so the placeholders read as editable
	f.shade:SetAllPoints(UIParent)
	f.shade:SetFrameStrata("FULLSCREEN_DIALOG")   -- over everything else on screen, under the placeholders
	f.shade:SetFrameLevel(1)
	local t = f.shade:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints()
	t:SetColorTexture(0, 0, 0, 0.45)
	return f
end

function Mv.Active() return Mv.bar ~= nil and Mv.bar:IsShown() end

function Mv.Start()
	if U.Call(InCombatLockdown) then U.Print("you can move notifications after combat.") return false end
	St.Ensure()
	Mv.frames = Mv.frames or {}
	for _, key in ipairs(Mv.KEYS) do
		Mv.frames[key] = Mv.frames[key] or placeholder(key)
		Mv.frames[key]:Show()
		Mv.PlacePlaceholder(key)
	end
	Mv.bar = Mv.bar or bar()
	Mv.bar.shade:Show()
	Mv.bar:Show()
	return true
end

function Mv.Stop()
	if Mv.stopping then return end
	Mv.stopping = true
	for _, f in pairs(Mv.frames or {}) do f:StopMovingOrSizing(); f:Hide() end
	if Mv.bar then Mv.bar.shade:Hide(); Mv.bar:Hide() end
	Mv.stopping = nil
end

-- Unlocked <-> locked: the cog's right-click. True when it is now unlocked.
function Mv.Toggle()
	if Mv.Active() then Mv.Stop() return false end
	return Mv.Start()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		if Mv.Active() then Mv.Stop(); U.Print("move mode closed: combat started.") end
	else
		Mv.ApplyAll()
	end
end)

ns.RegisterCallback(Mv, "LOGIN_DONE", function() Mv.RegisterElvUI() end)
ns.slash.move = function() Mv.Start() end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl move - move the logout warning, toasts and Esc-menu card"
