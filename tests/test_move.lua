-- Movable notifications (ILL-1272): positions are saved per account, applied to the real alerts, clamped to the
-- screen, reset per item or all; move mode opens and closes (Esc, Done, combat) and never starts in combat; the
-- Esc-menu card is attached under the menu until moved; ElvUI movers share the same saved positions.

local W = dofile("tests/world.lua")

local SW, SH = 1920, 1080

local function world(state)
	state = state or {}
	local outer = state.setup
	state.setup = function(game, h, st)
		game.UISpecialFrames = {}
		game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
		game.UIParent.GetWidth, game.UIParent.GetHeight = function() return SW end, function() return SH end
		game.GameMenuFrame = game.CreateFrame("Frame", "GameMenuFrame")
		game.GameMenuFrame:Hide()
		game.InCombatLockdown = function() return st.combat or false end
		game.SOUNDKIT = { RAID_WARNING = 8959 }
		game.PlaySound = function() end
		if outer then outer(game, h, st) end
	end
	local _, h = W.New(state)
	return h, state
end

-- The last anchor set on a frame: point, relPoint, x, y.
local function anchor(f)
	local p = f.__points and f.__points[#f.__points]
	if not p then return nil end
	return p[1], p[3], p[4], p[5]
end

local cases = {}

function cases.positions_round_trip_and_clamp_to_the_screen()
	local _, state = world()
	local Mv = state.ns.Move
	local pos = Mv.FromRect(1700, 900, 200, 100, SW, SH)
	T.eq(pos.point, "TOPRIGHT", "top-right third")
	local l, b = Mv.ToRect(pos, 200, 100, SW, SH)
	T.eq(l, 1700, "left round trip"); T.eq(b, 900, "bottom round trip")
	local c = Mv.FromRect(860, 100, 200, 74, SW, SH)
	T.eq(c.point, "BOTTOM", "bottom middle"); T.eq(c.x, 0, "centred"); T.eq(c.y, 100, "100 up")
	local off = Mv.Clamp({ point = "TOPLEFT", relPoint = "TOPLEFT", x = -300, y = 50 }, 200, 100, SW, SH)
	l, b = Mv.ToRect(off, 200, 100, SW, SH)
	T.eq(l, 0, "clamped to the left edge"); T.eq(b, SH - 100, "and to the top")
	local big = Mv.Clamp({ point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = 500, y = -40 }, 470, 112, 1024, 768)
	l, b = Mv.ToRect(big, 470, 112, 1024, 768)
	T.eq(l, 1024 - 470, "a smaller screen keeps it whole"); T.eq(b, 0, "on the bottom edge")
end

function cases.saved_positions_apply_to_the_real_alerts()
	local h, state = world({ saved = { positions = {
		banner = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -60 },
		toasts = { point = "TOP", relPoint = "TOP", x = 0, y = -200 },
		bogus = { point = "TOP" },
	} } })
	local A = state.ns.Alerts
	T.ok(W.DB(h).positions.bogus == nil, "unknown or broken entries are dropped on load")
	A.ShowBanner("Cancel the logout first", "Le Jette is outside a rest area.", "outside", "Hearth.")
	local p, rp, x, y = anchor(A.banner)
	T.eq(p .. rp .. x .. "," .. y, "TOPLEFTTOPLEFT40,-60", "the banner at its saved place")
	A.banner:Hide()   -- toasts wait while the banner is up
	A.Toast({ kind = "filled", kicker = "FULLY RESTED", text = "Le Nette", state = "full" })
	A.Toast({ kind = "filled", kicker = "FULLY RESTED", text = "Le Dette", state = "full" })
	local _, _, _, y1 = anchor(A.toasts[1])
	local _, _, _, y2 = anchor(A.toasts[2])
	T.eq(y1, -200, "first toast at the saved place")
	T.eq(y2, -200 - 78, "toasts near the top stack downwards")
	T.clean(h)
end

function cases.esc_card_hangs_under_the_menu_until_moved()
	local h, state = world({ resting = false })
	local A, Mv = state.ns.Alerts, state.ns.Move
	FakeWoW.RunScript(h.Env().GameMenuFrame, "OnShow")
	h.Env().GameMenuFrame:Show()
	A.OnMenuShown()
	local strip = A.strip
	T.ok(strip and strip:IsShown(), "the card shows while not resting")
	local p, rp = anchor(strip)
	T.eq(p .. "/" .. rp, "TOP/BOTTOM", "attached: under the menu")
	T.eq(strip.__points[#strip.__points][2], h.Env().GameMenuFrame, "to the menu itself")
	Mv.Save("menu", 100, 100, 440, 112)
	A.LayoutStrip(strip)
	T.eq(strip.__points[#strip.__points][2], h.Env().UIParent, "moved: detached, on the screen")
	Mv.Reset("menu")
	A.LayoutStrip(strip)
	T.eq(strip.__points[#strip.__points][2], h.Env().GameMenuFrame, "reset: attached again")
	T.clean(h)
end

function cases.move_mode_opens_saves_resets_and_closes()
	local h, state = world()
	local Mv, env = state.ns.Move, h.Env()
	h.Slash("RESTEDLEVELING", "move")
	T.ok(Mv.Active(), "/rlvl move opens move mode")
	for _, key in ipairs(Mv.KEYS) do T.ok(Mv.frames[key]:IsShown(), key .. " placeholder shown") end
	T.ok(env.UISpecialFrames[#env.UISpecialFrames] == "RestedLevelingMoveBar", "Esc closes it")
	local ph = Mv.frames.banner
	ph.__left, ph.__bottom = 1500, 50   -- dropped near the bottom right
	FakeWoW.RunScript(ph, "OnDragStart")
	FakeWoW.RunScript(ph, "OnDragStop")
	local saved = W.DB(h).positions.banner
	T.eq(saved.point, "BOTTOMRIGHT", "saved against the nearest edge")
	T.eq(saved.y, 50, "where it was dropped")
	FakeWoW.RunScript(ph.reset, "OnClick")
	T.ok(W.DB(h).positions.banner == nil, "Reset puts it back to the default")
	Mv.Save("toasts", 10, 10, 360, 74)
	Mv.Save("menu", 10, 400, 440, 112)
	FakeWoW.RunScript(Mv.bar.resetAll, "OnClick")
	T.ok(next(W.DB(h).positions) == nil, "Reset all")
	Mv.bar:Hide()   -- what Esc does
	T.ok(not Mv.Active() and not Mv.frames.banner:IsShown(), "Esc leaves move mode")
	h.Slash("RESTEDLEVELING", "move")
	FakeWoW.RunScript(Mv.bar.done, "OnClick")
	T.ok(not Mv.Active(), "Done leaves move mode")
	T.clean(h)
end

function cases.never_in_combat()
	local h, state = world()
	local Mv = state.ns.Move
	state.combat = true
	h.Slash("RESTEDLEVELING", "move")
	T.ok(not Mv.Active(), "refused in combat")
	state.combat = false
	h.Slash("RESTEDLEVELING", "move")
	T.ok(Mv.Active(), "fine after")
	h.Fire("PLAYER_REGEN_DISABLED")
	T.ok(not Mv.Active(), "combat closes it")
	T.clean(h)
end

function cases.elvui_movers_share_the_saved_positions()
	local created, saved = {}, {}
	local E = { db = { movers = {} } }
	function E:CreateMover(holder, name, text, _, _, postdrag, types)
		local mover = { name = name, points = {} }
		function mover:ClearAllPoints() self.points = {} end
		function mover:SetPoint(...) self.points = { ... } end
		function mover:GetLeft() return 600 end
		function mover:GetBottom() return 20 end
		function mover:GetWidth() return 360 end
		function mover:GetHeight() return 74 end
		holder.mover = mover
		created[name] = { holder = holder, text = text, postdrag = postdrag, types = types, mover = mover }
	end
	function E:SaveMoverPosition(name) saved[name] = true; self.db.movers[name] = "saved" end
	function E:ResetMovers(name) created.reset = name; self.db.movers[name] = nil end
	function E:ConfigMode_AddGroup(key, label) created.group = key .. "=" .. label end
	local h, state = world({ saved = { positions = { banner = { point = "TOP", relPoint = "TOP", x = 0, y = -300 } } },
		setup = function(_, hh) rawset(hh.Env(), "ElvUI", { E }) end })   -- an addon global, not a client name
	local Mv = state.ns.Move
	local toasts = created.RestedLevelingToastsMover
	T.ok(toasts and created.RestedLevelingBannerMover and created.RestedLevelingMenuMover, "three movers")
	T.eq(created.group, "RESTEDLEVELING=Rested Leveling", "in their own group")
	T.eq(toasts.types, "ALL,RESTEDLEVELING", "shown with /moveui and in that group")
	T.eq(toasts.text, "Toasts", "labelled")
	T.ok(saved.RestedLevelingBannerMover, "a position moved before ElvUI is handed to its mover")
	-- Dragged in /moveui: ElvUI saved it and calls postdrag.
	E.db.movers.RestedLevelingToastsMover = "moved"
	toasts.postdrag(toasts.mover)
	T.eq(W.DB(h).positions.toasts.point, "BOTTOM", "our copy follows the ElvUI mover")
	-- Reset in /moveui: ElvUI forgets it and calls postdrag.
	E.db.movers.RestedLevelingToastsMover = nil
	toasts.postdrag(toasts.mover)
	T.ok(W.DB(h).positions.toasts == nil, "and its reset resets ours")
	-- Moved in our own mode: the mover follows and ElvUI saves it.
	Mv.Save("menu", 100, 400, 440, 112)
	T.ok(saved.RestedLevelingMenuMover, "our move updates the ElvUI mover")
	Mv.Reset("menu")
	T.ok(E.db.movers.RestedLevelingMenuMover == nil, "our reset clears ElvUI's copy")
	T.eq(created.reset, "RestedLevelingMenuMover", "through ElvUI's own E:ResetMovers")
	T.clean(h)
end

-- Review (ILL-1272): our DB is the source of truth. Another ElvUI profile's mover entry is overwritten at load.
function cases.our_saved_position_wins_over_another_elvui_profile()
	local saved = {}
	local E = { db = { movers = { RestedLevelingBannerMover = "TOP,UIParent,TOP,0,-500" } } }
	function E:CreateMover(holder) holder.mover = { SetPoint = function(self, ...) self.points = { ... } end,
		ClearAllPoints = function() end } end
	function E:SaveMoverPosition(name) saved[name] = true end
	local h = world({ saved = { positions = { banner = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -60 } } },
		setup = function(_, hh) rawset(hh.Env(), "ElvUI", { E }) end })
	local holder = h.Env().RestedLevelingbannerHolder
	T.ok(saved.RestedLevelingBannerMover, "our position is saved into ElvUI's profile")
	T.eq(table.concat({ holder.mover.points[1], holder.mover.points[4], holder.mover.points[5] }, ","), "TOPLEFT,40,-60",
		"and the mover sits there, not at the other profile's spot")
	T.clean(h)
end

-- Review (ILL-1272): placeholders are not left user-placed for the client's layout cache; every one says where it is.
function cases.placeholders_are_not_user_placed_and_all_say_where()
	local h, state = world()
	local Mv = state.ns.Move
	h.Slash("RESTEDLEVELING", "move")
	local ph = Mv.frames.toasts
	local placed = {}
	ph.SetUserPlaced = function(_, v) placed[#placed + 1] = v end
	ph.__left, ph.__bottom = 600, 300
	FakeWoW.RunScript(ph, "OnDragStop")
	T.eq(placed[#placed], false, "SetUserPlaced(false) after a drag")
	T.ok(ph.where:IsShown() and ph.where:GetText():find("Custom position", 1, true), "the toasts placeholder says where too")
	T.clean(h)
end

return cases
