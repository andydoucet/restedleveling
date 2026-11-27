-- Rested Leveling: the "#1 · PLAY NEXT" hero card at the top of the window. Left: who (portrait, name, identity).
-- Right: the number that matters and why it beats #2. Across the bottom: the one thing to do, with the card button.

local _, ns = ...
local St, Wg, Wd, U = ns.Style, ns.Widgets, ns.Words, ns.Util
local Hero = {}
ns.Hero = Hero

local BAR_SEGS, ACTION_H = 30, 42

local function text(f, role, size, color)
	local t = Wg.Text(f, role, nil, size)
	if color then St.Color(t, color) end
	return t
end

function Hero.Create(parent, w, h)
	local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
	f:SetSize(w, h)
	St.Panel(f, "card")
	f.art = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.art:SetTexture(St.MEDIA .. "hero_bg")
	f.art:SetPoint("TOPLEFT", 1, -1)
	f.art:SetPoint("BOTTOMRIGHT", -1, ACTION_H)
	f.art:SetTexCoord(0, 1, 0.22, 1)
	f.shadeArt = f:CreateTexture(nil, "BACKGROUND", nil, 1)   -- the painting stays atmosphere: 35% dark over it
	f.shadeArt:SetPoint("TOPLEFT", f.art)
	f.shadeArt:SetPoint("BOTTOMRIGHT", f.art)
	St.Paint(f.shadeArt, "sw_black")
	f.shadeArt:SetVertexColor(1, 1, 1, 0.22)   -- the inn reads as an inn; the fade keeps text clear
	f.fade = f:CreateTexture(nil, "BACKGROUND", nil, 2)   -- dark under the text, the inn shows on the right
	f.fade:SetTexture(St.MEDIA .. "fade_h")
	f.fade:SetPoint("TOPLEFT", 1, -1)
	f.fade:SetPoint("BOTTOMLEFT", 1, ACTION_H)
	f.fade:SetWidth(w * 0.42)   -- dark only under the text: the barrels and hearth show
	f.edge = f:CreateTexture(nil, "BORDER")
	f.edge:SetPoint("TOPLEFT", 1, -1)
	f.edge:SetPoint("BOTTOMLEFT", 1, 1)
	f.edge:SetWidth(4)
	f.pulse = f.edge:CreateAnimationGroup()   -- a slow breath on the accent while a full #1 wastes rest
	f.pulse:SetLooping("BOUNCE")
	local breath = f.pulse:CreateAnimation("Alpha")
	breath:SetFromAlpha(1)
	breath:SetToAlpha(0.5)
	breath:SetDuration(2)
	f.hover = f:CreateTexture(nil, "HIGHLIGHT")
	f.hover:SetPoint("TOPLEFT", 1, -1)
	f.hover:SetPoint("BOTTOMRIGHT", -1, ACTION_H)
	St.Paint(f.hover, "sw_btn_hi")
	f.hover:SetAlpha(0.2)

	f.portrait = Wg.Portrait(f, 112)
	f.portrait:SetPoint("TOPLEFT", 28, -22)
	f.badge = f.portrait:CreateTexture(nil, "OVERLAY", nil, 6)
	St.Paint(f.badge, "disc_gold")
	f.badge:SetSize(26, 26)
	f.badge:SetPoint("CENTER", f.portrait, "TOPLEFT", -6, 6)   -- clear of the ring, not clipping it
	f.badgeRing = f.portrait:CreateTexture(nil, "OVERLAY", nil, 5)   -- a dark ring so the badge sits on the frame
	St.Paint(f.badgeRing, "disc_dark")
	f.badgeRing:SetSize(28, 28)
	f.badgeRing:SetPoint("CENTER", f.badge)
	f.badgeText = Wg.Text(f.portrait, "number", nil, 15)
	f.badgeText:SetDrawLayer("OVERLAY", 7)
	f.badgeText:SetPoint("CENTER", f.badge, "CENTER", 0, 0)
	f.badgeText:SetText("1")
	f.badgeText:SetTextColor(0.10, 0.07, 0.02)
	f.badgeText:SetShadowOffset(0, 0)

	f.kicker = text(f, "label", 13, { r = 0.94, g = 0.82, b = 0.50 })   -- #1 · PLAY NEXT: a heading, not a caption
	f.kicker:SetPoint("TOPLEFT", f.portrait, "TOPRIGHT", 28, 0)   -- clear of the portrait's badge
	f.chip = Wg.Chip(f, 22, 86)
	f.chip:SetPoint("LEFT", f.kicker, "RIGHT", 10, 0)
	f.name = Wg.Text(f, "hero", nil, 30)
	f.name:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -6)
	-- The #1 speaks on its own row under its name, decision first ("Send me. 1.7 levels banked."), in a dark bubble
	-- whose tail points back at the portrait. One line; the row is reserved so the layout holds without it.
	f.say = Wg.Bubble(f, 14)
	f.say:SetHeight(24)
	f.say:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 24, -6)   -- the tail clear of the class badge; 6 px gaps
	f.sayText = f.say.text
	f.sayText:SetPoint("LEFT", 10, 0)
	Wg.PointTail(f.say, "left")
	f.sub = text(f, "body", 13, St.SECOND)
	f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 1, -34)   -- 6 px under the speech bubble

	-- The figure and its unit read as one ("1.5 LEVELS BANKED"), right-aligned on the bar's right end, under the name's
	-- size so the name leads.
	f.stat = Wg.Text(f, "hero", nil, 38)
	f.stat:SetPoint("TOPRIGHT", -20, -16)
	f.stat:SetJustifyH("RIGHT")
	f.statSub = text(f, "label", 12, St.CREAM)
	f.statSub:SetPoint("TOPRIGHT", f.stat, "BOTTOMRIGHT", 0, -2)   -- one right edge for the figure, unit and runner-up
	f.statSub:SetJustifyH("RIGHT")
	f.ahead = text(f, "small", 12, St.MUTED)   -- the runner-up, read last: fills the column under the figure
	f.ahead:SetPoint("TOPRIGHT", f.statSub, "BOTTOMRIGHT", 0, -8)
	f.ahead:SetJustifyH("RIGHT")
	f.acct = Wg.Text(f, "label", nil, 11)
	f.acct:SetPoint("TOPRIGHT", f.ahead, "BOTTOMRIGHT", 0, -4)
	f.acct:SetTextColor(0.62, 0.78, 0.95)

	Hero.BAR_W = w - 168 - 24   -- from the text column to the figure's right edge: no gutter between bar and number
	f.bar = Wg.BubbleBar(f, Hero.BAR_W, 18, BAR_SEGS)
	f.bar:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", -1, -10)
	f.sheen = f.bar.bar:CreateTexture(nil, "OVERLAY", nil, 6)   -- a gold sheen sweeps the bar when the window opens
	f.sheen:SetTexture(St.MEDIA .. "glow")
	f.sheen:SetBlendMode("ADD")
	f.sheen:SetSize(60, 40)
	f.sheen:SetVertexColor(1, 0.85, 0.45, 0.8)
	f.sheen:SetPoint("CENTER", f.bar.bar, "LEFT", 0, 0)
	f.sheen:SetAlpha(0)
	f.sweep = f.sheen:CreateAnimationGroup()
	local mv = f.sweep:CreateAnimation("Translation")
	mv:SetOffset(Hero.BAR_W, 0)
	mv:SetDuration(0.5)
	local fa = f.sweep:CreateAnimation("Alpha")
	fa:SetFromAlpha(1)
	fa:SetToAlpha(0)
	fa:SetDuration(0.5)
	f.why = text(f, "body", 14, St.CREAM)
	f.why:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 1, -8)
	f.why:SetWidth(Hero.BAR_W)

	-- The action bar: what to do next, and the card button.
	f.action = CreateFrame("Frame", nil, f, "BackdropTemplate")
	f.action:SetPoint("BOTTOMLEFT", 5, 1)
	f.action:SetPoint("BOTTOMRIGHT", -1, 1)
	f.action:SetHeight(ACTION_H - 1)
	St.Panel(f.action, "strip")
	f.actionRule = f.action:CreateTexture(nil, "ARTWORK")
	St.Paint(f.actionRule, "sw_rule")
	f.actionRule:SetPoint("TOPLEFT")
	f.actionRule:SetPoint("TOPRIGHT")
	f.actionRule:SetHeight(1)
	f.cta = text(f.action, "name", 16, { r = 0.95, g = 0.89, b = 0.69 })   -- cream: the names in it keep their class colours
	f.cta:SetPoint("LEFT", 22, 0)
	f.open = St.MakeButton(f.action, 120, "View card", true)
	f.open:SetPoint("RIGHT", -8, 0)
	f.ctaW = w - 6 - 22 - 120 - 8 - 12   -- from its inset to 12 px short of the button
	f.open:SetScript("OnClick", function() if f.row and ns.ShowDetail then ns.ShowDetail(f.row.key) end end)

	-- First run: a dimmed portrait and a line in the character's own voice.
	-- the same speech bubble as the character card, with its tail toward the portrait
	f.quote = Wg.Bubble(f, 15)
	f.quoteText = f.quote.text
	f.quoteText:SetPoint("LEFT", 12, 0)
	f.quoteText:SetText("I'll sit at the top once I'm full.")
	f.quote:SetSize(f.quoteText:GetStringWidth() + 26, 32)
	f.quote:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 6, -10)
	Wg.PointTail(f.quote, "left")   -- back at the portrait, like every speech tail
	f.empty = text(f, "body", 14, St.CREAM)
	f.empty:SetPoint("TOPLEFT", f.quote, "BOTTOMLEFT", -6, -14)
	f.empty:SetWidth(w - 180)
	f.empty:SetText("Log each alt in once. Park them in an inn. Your best-rested character rises to the top.")

	f:SetScript("OnClick", function(self) if self.row and ns.ShowDetail then ns.ShowDetail(self.row.key) end end)
	return f
end

local function setShown(f, on)
	f.chip:Hide()   -- the bar and the one line already say the state
	for _, k in ipairs({ "bar", "why", "ahead", "sub", "acct", "stat", "statSub", "action", "badge", "badgeRing", "badgeText", "say" }) do
		f[k]:SetShown(on)
	end
	f.quote:SetShown(not on)
	f.empty:SetShown(not on)
	-- the inn art reaches the bottom when there is no action bar
	f.art:SetPoint("BOTTOMRIGHT", -1, on and ACTION_H or 1)
	f.fade:SetPoint("BOTTOMLEFT", 1, on and ACTION_H or 1)
	-- Under a host skin the hero is a flat well like its own windows: no painting, no bright rule.
	f.art:SetShown(not St.HostFrame())
	f.fade:SetShown(not St.HostFrame())
	f.edge:SetShown(true)   -- the #1's state accent in both themes: it belongs to the ranked list below
	-- no gold medallion or bronze ring under a host skin: the kicker already says #1, the ring is the state line
	for _, k in ipairs({ "badge", "badgeRing", "badgeText" }) do f[k]:SetShown(false) end   -- the kicker says #1
	f.portrait.ring:SetShown(not St.HostFrame())
	f.shadeArt:SetShown(not St.HostFrame())
end

-- One line, shortened with "..." to stay left of the figure column.
local function say(f, line)
	f.say:SetShown(line ~= nil and line ~= "")
	if not line then return end
	Wg.Fit(f.sayText, line, f:GetWidth() - 340)
	f.say:SetWidth(f.sayText:GetStringWidth() + 22)
end

-- The next step, whole: one line at the normal size, else a smaller one, else two balanced lines (word breaks only),
-- never "..." and never under the button. A wider font (ElvUI's) clipped it in game: "Then pl" at the button.
Hero.ACTION_SIZES = { 16, 14, 13 }
function Hero.FitAction(f, line)
	local cta, maxW = f.cta, f.ctaW
	cta:SetHeight(0)
	for i, size in ipairs(Hero.ACTION_SIZES) do
		St.Font(cta, "name", size)
		cta:SetWordWrap(false)
		cta:SetWidth(maxW)
		cta:SetText(line)
		if cta:GetUnboundedStringWidth() <= maxW then return size, 1 end
		if i == #Hero.ACTION_SIZES then break end
	end
	cta:SetWordWrap(true)
	Wg.Balance(cta, maxW)   -- two lines at the smallest size; the bar is ACTION_H high
	return Hero.ACTION_SIZES[#Hero.ACTION_SIZES], 2
end

-- row: the top roster row (nil when there is nobody to suggest); rows: the full order (for "ahead of");
-- me: the logged-in character record. empty: nobody has rest worth switching to, so `row` is the one that fills
-- first and the card says so instead of "play next".
function Hero.Update(f, row, now, me, rows, empty)
	local fresh = f.row == nil or (row and f.row.key ~= row.key)
	f.row = row
	if not row or row.group == 5 then
		setShown(f, false)
		f.kicker:SetText("WELCOME")
		f.name:SetText(me and St.ClassText(me.class, me.full) or "Rested Leveling")
		St.Paint(f.edge, "sw_gold")
		if me then Wg.SetPortrait(f.portrait, me, true, "resting") end
		f.portrait:SetAlpha(0.7)
		return
	end
	setShown(f, true)
	f.portrait:SetAlpha(1)
	f.kicker:SetText(empty and "NOBODY RESTED YET" or "#1  ·  PLAY NEXT")
	local c, p = row.c, row.p
	local r, g, b = St.StateColor(row.state)
	St.Paint(f.edge, "st_" .. row.state)
	if row.state == "full" and not ns.DB().opts.reduceMotion then f.pulse:Play() else f.pulse:Stop() end
	Wg.SetPortrait(f.portrait, c, false, row.state)
	Wg.SetChip(f.chip, row.state, Wd.Chip(row))
	f.name:SetText(St.ClassText(c.class, c.full or "?"))
	local raceName = c.race == "Scourge" and "Undead" or (c.race and c.race:gsub("(%l)(%u)", "%1 %2")) or ""
	local className = c.class and (c.class:sub(1, 1) .. c.class:sub(2):lower()) or ""
	f.sub:SetText(("Level %d %s %s  ·  %s  ·  seen %s"):format(c.level or 0, raceName, className, Wd.Place(c),
		U.Ago(now - (c.t or now))))
	local calibrated = ns.DB().calib.n ~= nil
	Wg.SetBubbleBar(f.bar, p.pct, row.state, not calibrated)
	if empty then   -- nothing banked anywhere: the figure is the real-life wait, not a 0.0
		f.stat:SetText(U.Duration(p.left))
		f.statSub:SetText("UNTIL FULL")
		f.why:SetText(("Nobody is rested yet. %s fills first: Full in %s."):format(c.full or "?", U.Duration(p.left)))
		f.ahead:SetText("full " .. Wd.When(now + p.left, now))   -- the clock time under the wait
	else
		f.stat:SetText(("%.1f"):format(math.floor(p.levels * 10 + 0.5) / 10))
		f.statSub:SetText(p.levels >= 0.95 and p.levels < 1.05 and "LEVEL BANKED" or "LEVELS BANKED")
		f.why:SetText(Wd.HeroWhy(row, now))   -- the state, then the real-life time to full
		f.ahead:SetText(rows and Wd.Ahead(rows, now) or "")
	end
	f.stat:SetTextColor(0.96, 0.86, 0.58)   -- one warm cream-gold figure in both themes; the accent and bar carry state
	f.why:SetTextColor(0.5 + r * 0.5, 0.5 + g * 0.5, 0.5 + b * 0.5)   -- it belongs to the bar: a light state colour
	-- The next step. Any "first, ..." is about the character you are on, never the one to play next.
	local name = St.ClassText(c.class, c.full or "them")
	local meName = me and St.ClassText(me.class, me.full or "this character") or nil
	Hero.FitAction(f, Wd.Action(name, meName, ns.Snap.RestingNow(), empty))
	f.open:SetLabel("View details")   -- the name is right above it
	local tag = St.AccountTag(c)
	f.acct:SetText(tag and (c.src == "sync" and (tag .. " · synced") or tag) or "")
	say(f, ns.Lines and ns.Lines.Short(row, now))   -- the joke; the action bar carries the decision
	if fresh and not ns.DB().opts.reduceMotion then f.sweep:Play() end
end
