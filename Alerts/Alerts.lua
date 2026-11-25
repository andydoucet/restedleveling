-- Rested Leveling: alerts. Banner, toasts and a strip under the Esc menu, plus chat lines; never a popup.
-- Every alert: the close button or a left-click dismisses this one; right-click opens a small menu (not a popup),
-- flush under the alert: "Dismiss" or "Disable <kind> warnings...", which then offers Undo and the options inline.
-- Logging out can't be cancelled by an addon (CancelLogout is restricted), so the banner says "move to cancel":
-- moving cancels the camp timer.

local _, ns = ...
local St, Wg, U, M, Ru, S = ns.Style, ns.Widgets, ns.Util, ns.Model, ns.Rules, ns.Snap
local A = ns.Alerts or {}   -- Alerts/Menu.lua loads first
ns.Alerts = A
local dismissable, closeButton, optionsButton = A.Dismissable, A.CloseButton, A.OptionsButton

local function enabled(kind) return Ru.Enabled(ns.DB(), kind) end


-- The next character, secondary to the warning: her portrait, "Next: Le Nette · Full · 1.7 levels banked", and a
-- small Details button that opens her card. The warning itself is about the character logging out.
local function altLine(f, anchor)
	f.alt = Wg.Portrait(f, 22)
	f.alt:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 2, -8)
	f.altText = Wg.Text(f, "small", nil, 13)
	f.altText:SetPoint("LEFT", f.alt, "RIGHT", 12, 0)
	St.Color(f.altText, St.SECOND)
	f.altBtn = St.MakeButton(f, 72, "Details", false, 22)
	f.altBtn:SetPoint("LEFT", f.altText, "RIGHT", 12, 0)
	f.altBtn:SetScript("OnClick", function(self) if self.key and ns.ShowDetail then ns.ShowDetail(self.key) end end)
	f.altBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Open " .. (self.name or "their") .. "'s card")
		GameTooltip:Show()
	end)
	f.altBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
local function setAlt(f, alt)
	f.alt:SetShown(alt ~= nil)
	f.altBtn:SetShown(alt ~= nil)
	f.altText:SetShown(alt ~= nil)
	if not alt then return end
	Wg.SetPortrait(f.alt, alt.c, false, alt.state)
	f.altBtn.key, f.altBtn.name = alt.key, alt.c.full
	local st = St.STATE[alt.state] or St.STATE.max
	f.altText:SetText(("Next: %s  ·  %s%s"):format(alt.c.full or "?", st.word,
		alt.p and ("  ·  " .. ns.Words.Levels(alt.p.levels) .. " banked") or ""))
end
local function nextUp()
	local rows = ns.Rows({ hideGrey = true })
	return rows[1] and rows[1].group ~= 5 and rows[1] or nil
end

-- The shared alert surface: the iron-edged panel plus a 4 px enamel stripe down the left in the state colour.
local function surface(f, kind, state)
	St.Panel(f, kind)
	f.stripe = f.stripe or f:CreateTexture(nil, "ARTWORK")
	f.stripe:SetPoint("TOPLEFT", 4, -4)
	f.stripe:SetPoint("BOTTOMLEFT", 4, 4)
	f.stripe:SetWidth(4)
	St.Paint(f.stripe, "st_" .. (St.STATE[state] and state or "outside"))
end

-- One alert surface at a time: while the logout banner is up, the Esc-menu strip stays hidden; while either is up,
-- toasts wait.
A.waiting = {}
local function bannerUp() return A.banner and A.banner:IsShown() end
local function busy() return bannerUp() or (A.strip and A.strip:IsShown()) end
A.WIDTH = 360   -- toasts and the Esc strip share one width, centred

-- Banner: the logout warning, under the game's own logout countdown, until dismissed or the logout is cancelled.
function A.Banner()
	if A.banner then return A.banner end
	St.Ensure()
	local f = CreateFrame("Frame", "RestedLevelingBanner", UIParent, "BackdropTemplate")
	f:SetSize(470, 112)   -- wide enough to name the character on one line
	f:SetPoint("TOP", 0, -8)   -- top-centre, above the game's own logout countdown
	f:SetFrameStrata("DIALOG")
	surface(f, "warn", "outside")
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(28, 28)
	f.icon:SetPoint("TOPLEFT", 18, -10)
	-- Two steps, then the alternative: "Move to cancel the logout." / "Then hearth or reach an inn..." / Or play next.
	f.title = Wg.Text(f, "name", nil, 15)
	f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 12, 0)
	f.title:SetWidth(330)
	f.text = Wg.Text(f, "name", nil, 14)
	f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
	f.text:SetWidth(320)
	St.Color(f.text, St.CREAM)
	f.action = Wg.Text(f, "body", nil, 13)   -- the second step
	f.action:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -3)
	f.action:SetWidth(380)   -- the inn guidance on one line where it can be
	f.action:SetWordWrap(true)
	St.Color(f.action, St.CREAM)   -- only "4x slower" is coloured
	altLine(f, f.action)
	f.close = closeButton(f)   -- a 32 px column on the right holds close and options
	f.options = optionsButton(f, "logout")
	f.fade = f:CreateAnimationGroup()
	local a = f.fade:CreateAnimation("Alpha")
	a:SetFromAlpha(0)
	a:SetToAlpha(1)
	a:SetDuration(0.25)
	dismissable(f, "logout")
	f:SetScript("OnShow", function() if A.strip then A.strip:Hide() end end)
	f:SetScript("OnHide", function() A.Flush() end)
	A.banner = f
	f:Hide()
	return f
end

-- alt: an optional roster row offered as the alternative ("Or play next: Le Nette · Full").
function A.ShowBanner(title, text, state, action, alt)
	local f = A.Banner()
	local s = St.STATE[state] or St.STATE.outside
	surface(f, "warn", state)
	f.icon:SetTexture(s.icon)
	f.title:SetText(title)
	f.title:SetTextColor(0.94, 0.84, 0.55)
	f.text:SetText(text)
	f.text:SetWordWrap(true)
	Wg.Balance(f.text, 380)   -- a long hearth name wraps evenly; the banner grows to fit
	f.action:SetText(action or "")
	Wg.Balance(f.action, 380)
	local hasAction = action ~= nil and action ~= ""
	f.action:SetShown(hasAction)
	f.alt:ClearAllPoints()
	f.alt:SetPoint("TOPLEFT", hasAction and f.action or f.text, "BOTTOMLEFT", 2, -8)
	f.title:SetTextColor(0.98, 0.55, 0.15)   -- warning orange: the instruction reads before the explanation
	setAlt(f, alt)
	local h = 10 + f.title:GetStringHeight() + 3 + f.text:GetStringHeight() + (hasAction and (3 + f.action:GetStringHeight()) or 0) + 8 + 22 + 10
	f:SetHeight(math.max(84, h))   -- grows when a long name or line wraps
	f:Show()
	f.fade:Play()
end

-- Toasts: at the bottom, where the game's own alerts appear; a portrait, a title line, the news, an 8 s timer bar.
A.toasts = {}
local LIFE = 8
local function toastFrame(i)
	local f = A.toasts[i]
	if f then return f end
	f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	f:SetSize(A.WIDTH, 74)
	f:SetFrameStrata("DIALOG")
	surface(f, "toast", "full")
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(40, 40)
	f.icon:SetPoint("LEFT", 18, 0)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.portrait = Wg.Portrait(f, 32)   -- with its state ring
	f.portrait:SetPoint("LEFT", 22, 0)
	f.flash = f.portrait:CreateTexture(nil, "OVERLAY", nil, 4)   -- a one-time gold ring when a character fills
	St.Paint(f.flash, "ring_full")
	f.flash:SetPoint("CENTER")
	f.flash:SetSize(42, 42)
	f.flash:SetAlpha(0)
	f.flashAnim = f.flash:CreateAnimationGroup()
	local fl = f.flashAnim:CreateAnimation("Alpha")
	fl:SetFromAlpha(1)
	fl:SetToAlpha(0)
	fl:SetDuration(0.4)
	f.kicker = Wg.Text(f, "small", nil, 11)   -- what happened, small; the line under it says what to do
	f.kicker:SetPoint("TOPLEFT", 76, -11)
	f.kicker:SetWidth(A.WIDTH - 118)   -- clear of the close button
	St.Color(f.kicker, St.MUTED)
	f.text = Wg.Text(f, "name", nil, 15)
	f.text:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -3)
	f.text:SetWidth(A.WIDTH - 104)
	f.sub = Wg.Text(f, "body", nil, 12)
	f.sub:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -3)
	f.sub:SetWidth(A.WIDTH - 104)
	f.timer = f:CreateTexture(nil, "OVERLAY")
	St.Paint(f.timer, "sw_bubble_edge")   -- a quiet 2 px timer along the bottom inner edge
	f.timer:SetPoint("BOTTOMLEFT", 2, 2)
	f.timer:SetHeight(2)
	f.close = closeButton(f)
	f:SetScript("OnUpdate", function(self, elapsed)
		self.age = (self.age or 0) + elapsed
		self.timer:SetWidth(math.max(1, (self:GetWidth() - 4) * (1 - self.age / LIFE)))
		if self.age > LIFE then self:Hide()
		elseif self.age > LIFE - 1 then self:SetAlpha(LIFE - self.age)
		elseif self.age < 0.25 then self:SetAlpha(self.age / 0.25) else self:SetAlpha(1) end
	end)
	A.toasts[i] = f
	return f
end

-- t: { kind, kicker, text, sub, state, row (portrait), icon }. Waits while the logout banner is up.
function A.Toast(t)
	if not enabled(t.kind) then return end
	if busy() then A.waiting[#A.waiting + 1] = t return end
	St.Ensure()
	local slot = 1
	while A.toasts[slot] and A.toasts[slot]:IsShown() and slot < 4 do slot = slot + 1 end
	local f = toastFrame(slot)
	f:ClearAllPoints()
	f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 150 + (slot - 1) * 78)
	local s = St.STATE[t.accent or t.state] or St.STATE.full
	surface(f, "toast", t.accent or t.state)
	f.icon:SetTexture(t.icon or s.icon)
	f.icon:SetShown(t.row == nil)
	f.portrait:SetShown(t.row ~= nil)
	if t.row then Wg.SetPortrait(f.portrait, t.row.c, false, t.row.state) end
	if t.kind == "filled" and t.row and not ns.DB().opts.reduceMotion then f.flashAnim:Play() end
	f.kicker:SetText(t.kicker or "")

	f.text:SetText(t.text or "")
	f.sub:SetText(t.sub or "")
	local ss = St.STATE[t.state] or s
	f.sub:SetTextColor(ss.r, ss.g, ss.b)
	dismissable(f, t.kind)
	f.age = 0
	f:SetAlpha(0)
	f:Show()
	if Ru.KINDS[t.kind].sound then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
end

function A.Flush()
	local q = A.waiting
	A.waiting = {}
	for _, t in ipairs(q) do A.Toast(t) end
end

-- The travel advice, named for this character's own hearth when it is known.
function A.HearthLine(me)
	return me and me.bind and ("Hearth to %s or find an inn, then log out."):format(me.bind)
		or "Hearth or find an inn, then log out."
end

local function chat(kind, text) if enabled(kind) then U.Print(text) end end

-- The Esc-menu strip: informational only, under the Game Menu while not resting and no banner is up.
function A.MenuStrip()
	if A.strip or not GameMenuFrame then return A.strip end
	local f = CreateFrame("Frame", "RestedLevelingMenuStrip", GameMenuFrame, "BackdropTemplate")
	f:SetSize(460, 112)   -- the next-character line and its Details button fit inside
	f:SetPoint("TOP", GameMenuFrame, "BOTTOM", 0, -12)
	surface(f, "toast", "outside")   -- a neutral panel: it must not read as another red menu button
	local s = St.STATE.outside
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(24, 24)
	f.icon:SetPoint("TOPLEFT", 18, -14)
	f.icon:SetTexture(s.icon)
	f.text = Wg.Text(f, "name", nil, 15)   -- the same pattern as the banner: what to do, then who and how
	f.text:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, 0)
	f.text:SetTextColor(0.98, 0.55, 0.15)
	f.text:SetText("Find an inn before you log out")
	f.who = Wg.Text(f, "name", nil, 13)
	f.who:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -4)
	St.Color(f.who, St.CREAM)
	f.action = Wg.Text(f, "name", nil, 13)
	f.action:SetPoint("TOPLEFT", f.who, "BOTTOMLEFT", 0, -3)
	St.Color(f.action, St.CREAM)
	altLine(f, f.action)
	f.close = closeButton(f)
	f:SetScript("OnHide", function() A.Flush() end)
	dismissable(f, "menu")
	A.strip = f
	return f
end

-- The logged-in character's state, for the rules.
local function context()
	local me, d = ns.Me(), ns.DB()
	local xpMax = U.Num(U.Call(UnitXPMax, "player"))
	local level = U.Num(U.Call(UnitLevel, "player"))
	return {
		resting = S.RestingNow(), atMax = S.AtMaxLevel(level), level = level, target = d.opts.target,
		restedLevels = xpMax and xpMax > 0 and (U.Num(U.Call(GetXPExhaustion)) or 0) / xpMax or nil,
		cap = M.Cap(me or {}, d.calib),
	}
end
A.Context = context

function A.OnCamping()
	if not enabled("logout") or not Ru.LogoutWarning(context()) then return end
	local top = nextUp()
	local me = ns.Me()
	A.ShowBanner("Cancel the logout first", ((me and me.full) or "This character") .. " is outside a rest area.", "outside",
		A.HearthLine(me), top)
	pcall(PlaySound, SOUNDKIT.RAID_WARNING)
	chat("logout", "|cffff5a45logging out outside a rested area.|r Move to cancel, then find an inn or a city.")
end

function A.OnMenuShown()
	local f = A.MenuStrip()
	if f then
		f:SetShown(enabled("menu") and not bannerUp() and Ru.MenuStrip(context()))
		if f:IsShown() then
			local me = ns.Me()   -- name who, like the banner
			f.who:SetText(((me and me.full) or "This character") .. " is outside a rest area.")
			f.action:SetText(me and me.bind and ("Hearth to %s or find an inn."):format(me.bind) or "Hearth or find an inn.")
			setAlt(f, nextUp())
		end
	end
end

local lastRested
function A.OnSessionChanged(rested)
	local xpMax = U.Num(U.Call(UnitXPMax, "player"))
	if not xpMax or xpMax <= 0 then return end
	local before = lastRested
	lastRested = rested
	if not before then return end
	local cap = M.Cap(ns.Me() or {}, ns.DB().calib)
	if Ru.RanOut(before, rested) then
		local rows = ns.Rows({ hideGrey = true })
		local top = rows[1] and rows[1].group ~= 5 and rows[1] or nil
		local text, sub = Ru.NextUp(rows, St.ClassText)
		local me = ns.Me()
		A.Toast({ kind = "outrest", kicker = (me and me.full or "This character") .. ": rested XP used up", text = text,
			sub = sub, state = top and top.state or "outside", accent = top and top.state or "outside", row = top })   -- a recommendation: its rail in the target's state
	elseif Ru.WentLow(before / xpMax, rested / xpMax, cap) then
		chat("lowrest", ("rested XP is running low here: %s left."):format(ns.Words.Levels(rested / xpMax)))
	end
end

function A.CheckFills(quiet)
	local newly = Ru.NewlyFull(ns.Rows({ hideGrey = true }))
	if quiet or #newly == 0 then return end
	local names = {}
	for i = 1, math.min(#newly, 3) do names[i] = St.ClassText(newly[i].c.class, newly[i].c.full) end
	local one = #newly == 1
	A.Toast({ kind = "filled", kicker = one and "FULLY RESTED" or (#newly .. " CHARACTERS FULLY RESTED"),
		text = table.concat(names, ", ") .. (#newly > 3 and " and more" or ""),
		sub = one and (ns.Words.Levels(newly[1].p.levels) .. " of double XP waiting") or "Each has a full bar of double XP",
		state = "full", row = one and newly[1] or nil })
end

function A.Digest()
	if not enabled("digest") then return end
	for _, line in ipairs(Ru.Digest(ns.Rows({ hideGrey = true }), time(), ns.Me())) do U.Print(line) end
end

local frame = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_CAMPING", "PLAYER_QUITING", "LOGOUT_CANCEL" }) do pcall(frame.RegisterEvent, frame, e) end
frame:SetScript("OnEvent", function(_, event)
	if event == "LOGOUT_CANCEL" then
		if A.banner then A.banner:Hide() end
	elseif ns.Ready() then
		A.OnCamping()
	end
end)

if GameMenuFrame then GameMenuFrame:HookScript("OnShow", A.OnMenuShown) end

ns.RegisterCallback(A, "LOGIN_DONE", function(_, isLogin)
	lastRested = U.Num(U.Call(GetXPExhaustion))
	A.CheckFills(true)   -- the digest covers what filled while away; only new fills get a toast
	if isLogin then C_Timer.After(4, A.Digest) end
end)
ns.RegisterCallback(A, "SESSION_CHANGED", function(_, rested) A.OnSessionChanged(rested) end)
ns.RegisterCallback(A, "TICK", function() if ns.Ready() then A.CheckFills(false) end end)

ns.slash.alerts = function(arg)
	local d = ns.DB()
	local kind = (arg or ""):lower()
	if Ru.KINDS[kind] then
		d.alertsOff[kind] = (not d.alertsOff[kind]) or nil
		U.Print(Ru.KINDS[kind].label .. ": " .. (d.alertsOff[kind] and "off" or "on"))
		return
	end
	U.Print("alerts (/rlvl alerts <kind> to switch):")
	for k, info in pairs(Ru.KINDS) do print(("  %s - %s: %s"):format(k, info.label, d.alertsOff[k] and "|cffff6040off|r" or "|cff40ff40on|r")) end
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl alerts [kind] - list alert kinds, or switch one on/off"
