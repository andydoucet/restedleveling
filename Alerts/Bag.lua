-- Rested Leveling: the Cozy Sleeping Bag reminder (from Rested Watch 1.4.8 by doc_biddle, GPL-3.0): once each time
-- the bag comes off cooldown, when using it would actually help.

local _, ns = ...
local U, S, M = ns.Util, ns.Snap, ns.Model
local B = {}
ns.Bag = B

-- The bag item, found in your bags by name.
function B.Find()
	local d = ns.DB()
	if C_Container and C_Container.GetContainerNumSlots then
		for bag = 0, 4 do
			for slot = 1, U.Call(C_Container.GetContainerNumSlots, bag) or 0 do
				local id = U.Call(C_Container.GetContainerItemID, bag, slot)
				local name = id and U.Str(U.Call(C_Item.GetItemNameByID, id))
				if name and name:lower():find("sleeping bag", 1, true) then d.bagItem = id return id end
			end
		end
	end
	if d.bagItem and U.Call(PlayerHasToy, d.bagItem) then return d.bagItem end
	return nil
end

-- "ready", "active" or "cooldown" (and seconds left), or nil without a bag.
function B.State()
	local id = B.Find()
	if not id then return nil end
	local buff = S.BagBuff()
	local cd = 0
	local start, dur = U.Call(C_Container.GetItemCooldown, id)
	if start and start > 0 and dur and dur > 1.5 then cd = math.max(0, start + dur - GetTime()) end
	if buff and buff > 0 then return "active", buff end
	if cd > 0 then return "cooldown", cd end
	return "ready"
end

function B.Check()
	local d = ns.DB()
	local state = B.State()
	if state ~= "ready" then d.bagReminded = nil return end
	if d.bagReminded or not ns.Rules.Enabled(d, "bag") then return end
	local ctx = ns.Alerts.Context()
	if ctx.atMax or (ctx.target and ctx.level and ctx.level >= ctx.target) then return end
	if U.Call(UnitAffectingCombat, "player") or U.Call(IsInInstance) then return end
	if U.Call(IsResting) == true then return end   -- already resting: the bag adds nothing
	if ctx.restedLevels and ctx.restedLevels >= M.Cap(ns.Me() or {}, d.calib) - 0.005 then return end
	d.bagReminded = true
	ns.Alerts.Toast({ kind = "bag", kicker = "SLEEPING BAG READY", text = "Cozy Sleeping Bag", sub = "Lie down out here for faster rest.",
		state = "resting", icon = "Interface\\Icons\\INV_Misc_Bag_08" })
end

ns.RegisterCallback(B, "LOGIN_DONE", function() ns.DB().bagReminded = nil; B.Check() end)
ns.RegisterCallback(B, "TICK", function() if ns.Ready() then B.Check() end end)
