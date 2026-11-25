-- Rested Leveling: the character card. Click a roster row or the hero: the character steps onto a stage that reacts
-- to its state (a lantern-lit inn with drifting z's when it is resting, a cold blue road with fog when it is not),
-- says a line made from its own data in a speech bubble, and shows its tidbits.
--
-- Only the logged-in character can be drawn as a live 3D model (PlayerModel:SetUnit("player")), framed from the waist
-- up and playing the talk animation when the client has it. The game has no way to draw another character's real look
-- (hair, face, skin) while it is offline (see docs/API.md, "Offline appearance"), so everyone else shows their saved
-- look ("Save my look") or, without one, their class crest with a race emblem, rather than a stock face.
--
-- The stage is two columns: the speech bubble on the left, the figure (live model or portrait disc) on the right.
-- The bubble, tail included, always ends Card.GAP px left of the figure column (Andy, ILL-1279: the bubble ran into
-- her head).

local _, ns = ...
local St, Wg, Wd, U, M = ns.Style, ns.Widgets, ns.Words, ns.Util, ns.Model
local Card = {}
ns.Card = Card

local W, STAGE_H, PAD = 460, 300, 22   -- PAD: the band plus a 12 px inset, the same for every section
local IW = W - PAD * 2
-- The figure column, in stage pixels from the stage's left edge (the stage is IW = 416 wide, STAGE_H = 300 tall).
-- FIG_X: the portrait disc's centre right of the stage centre, so its ring starts at Card.FIG_LEFT.
local FIG_X, DISC = 112, 150
local MODEL_BOTTOM = 66   -- the live model stops above the name plate and the chip
Card.FIG_LEFT = math.floor(IW / 2 + FIG_X - DISC * 1.1 / 2)   -- the ring's left edge: 237
Card.GAP, Card.BUBBLE_LEFT, Card.TAIL = 12, 14, 12   -- clearance; the bubble's left edge; how far the tail sticks out
Card.MODEL_ZOOM = 0.35   -- PlayerModel:SetPortraitZoom: 0 is the full body, 0.6 Blizzard's head-and-shoulders portrait
-- The bubble's text width: what is left of the bubble's column after its 12 px insets, the tail and the gap.
Card.BUBBLE_W = Card.FIG_LEFT - Card.GAP - Card.TAIL - Card.BUBBLE_LEFT - 24
Card.BUBBLE_TOP = 22
Card.CONTROLS_BOTTOM = 68   -- "Save my look" sits on the left, above the name plate
local TALK, TALK_EXCLAIM = 60, 64   -- AnimationData ids (EmoteTalk, EmoteExclamation): checked with HasAnimation
local ICONS = {
	["/played"] = "Interface\\Icons\\INV_Misc_PocketWatch_01", Hearth = "Interface\\Icons\\INV_Misc_Rune_01",
	Gold = "Interface\\Icons\\INV_Misc_Coin_01", Professions = "Interface\\Icons\\Trade_Engineering",
	Guild = "Interface\\Icons\\INV_Shirt_GuildTabard_01", Title = "Interface\\Icons\\INV_Scroll_11",
	Gear = "Interface\\Icons\\INV_Chest_Chain", ["Logged out in"] = "Interface\\Icons\\INV_Misc_Map_01",
	["Rest bonus"] = "Interface\\Icons\\Spell_Nature_Sleep", ["Time at full"] = "Interface\\Icons\\INV_Misc_PocketWatch_02",
}

local function drift(parent, text, x, delay)
	local z = parent:CreateFontString(nil, "OVERLAY")
	St.Font(z, "hero", 12)
	z:SetText(text)
	z:SetTextColor(0.77, 0.72, 0.60)
	z:SetPoint("BOTTOM", parent, "BOTTOM", x, 236)
	local g = z:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local mv = g:CreateAnimation("Translation")
	mv:SetOffset(14, 46)
	mv:SetDuration(3.2)
	mv:SetStartDelay(delay)
	local fade = g:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.9)
	fade:SetToAlpha(0)
	fade:SetDuration(3.2)
	fade:SetStartDelay(delay)
	z.anim = g
	return z
end

local function makeStage(f)
	local s = CreateFrame("Frame", nil, f, "BackdropTemplate")
	s:SetSize(IW, STAGE_H)
	s:SetPoint("TOP", 0, -(St.RAIL + 10))
	St.Panel(s, "inset")
	s.bg = s:CreateTexture(nil, "BACKGROUND")
	s.bg:SetPoint("TOPLEFT", 3, -3)
	s.bg:SetPoint("BOTTOMRIGHT", -3, 3)
	-- State lighting: a warm lantern pool (resting, full) or a cold blue cast (not resting).
	s.warm = s:CreateTexture(nil, "BACKGROUND", nil, 2)
	s.warm:SetTexture(St.MEDIA .. "glow")
	s.warm:SetBlendMode("ADD")
	s.warm:SetSize(300, 260)
	s.warm:SetPoint("CENTER", s, "TOPRIGHT", -90, -110)
	s.warm:SetVertexColor(1, 0.62, 0.25, 0.32)
	s.cold = s:CreateTexture(nil, "BACKGROUND", nil, 2)   -- a cold blue cast falling from the top
	St.Paint(s.cold, "shade_cold")
	s.cold:SetPoint("TOPLEFT", 3, -3)
	s.cold:SetPoint("TOPRIGHT", -3, -3)
	s.cold:SetHeight(STAGE_H * 0.7)
	s.cold:SetTexCoord(0, 1, 1, 0)
	s.fog = s:CreateTexture(nil, "BORDER", nil, 1)
	St.Paint(s.fog, "shade_fog")
	s.fog:SetPoint("BOTTOMLEFT", 3, 3)
	s.fog:SetPoint("BOTTOMRIGHT", -3, 3)
	s.fog:SetHeight(120)
	s.shade = s:CreateTexture(nil, "BORDER")
	s.shade:SetTexture(St.MEDIA .. "shade")
	s.shade:SetPoint("BOTTOMLEFT", 3, 3)
	s.shade:SetPoint("BOTTOMRIGHT", -3, 3)
	s.shade:SetHeight(110)
	s.zs = { drift(s, "z", 150, 0), drift(s, "z", 162, 1.1), drift(s, "Z", 174, 2.2) }   -- just above the head
	-- The live model: the logged-in character only, in the figure column from the top of the stage down to just
	-- above the name plate (the frame clips the model: waist up, head in the upper middle).
	s.model = CreateFrame("PlayerModel", nil, s)
	s.model:SetPoint("TOPRIGHT", -3, -3)
	s.model:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", Card.FIG_LEFT, MODEL_BOTTOM)
	s.model:SetScript("OnModelLoaded", function(m) Card.FrameModel(m) end)   -- loading resets the camera
	-- The figure for everyone else: portrait art standing on a shadow, breathing.
	s.floor = s:CreateTexture(nil, "ARTWORK", nil, 1)
	s.floor:SetTexture(St.MEDIA .. "glow")   -- a soft shadow under the figure
	s.floor:SetSize(190, 26)
	s.floor:SetPoint("BOTTOM", FIG_X, 62)
	s.floor:SetVertexColor(0, 0, 0, 1)
	s.pedestal = s:CreateTexture(nil, "ARTWORK", nil, 2)   -- a thin bronze line the figure stands on
	St.Paint(s.pedestal, "sw_lip")
	s.pedestal:SetSize(150, 2)
	s.pedestal:SetPoint("BOTTOM", FIG_X, 76)
	s.figure = Wg.Portrait(s, DISC)
	s.figure:SetPoint("BOTTOM", FIG_X, 78)
	s.note = Wg.Text(s, "small", "OVERLAY", 12)   -- beside the crest, under the bubble: why there is no face
	s.note:SetPoint("BOTTOMRIGHT", s.figure, "BOTTOMLEFT", -20, 8)
	s.note:SetWidth(160)
	s.note:SetJustifyH("RIGHT")
	s.note:SetWordWrap(true)
	St.Color(s.note, St.CREAM)   -- on the stage art: the full-contrast cream
	s.settle = s.figure:CreateAnimationGroup()   -- one small settling motion as the card opens
	local st = s.settle:CreateAnimation("Scale")
	st:SetScaleFrom(0.96, 0.96)
	st:SetScaleTo(1, 1)
	st:SetDuration(0.25)
	st:SetSmoothing("OUT")
	s.breathe = s.figure:CreateAnimationGroup()
	s.breathe:SetLooping("BOUNCE")
	local sc = s.breathe:CreateAnimation("Scale")
	sc:SetScaleFrom(1, 1)
	sc:SetScaleTo(1.035, 1.035)
	sc:SetDuration(1.8)
	sc:SetSmoothing("IN_OUT")
	-- Speech bubble: the dark bubble, its tail pointing at the speaker. Click the stage to finish the line at once.
	local b = Wg.Bubble(s, 13)
	b.shadow = b:CreateTexture(nil, "BACKGROUND", nil, -8)   -- a soft drop shadow
	b.shadow:SetTexture(St.MEDIA .. "glow")
	b.shadow:SetVertexColor(0, 0, 0, 1)
	b.shadow:SetPoint("TOPLEFT", -6, 2)
	b.shadow:SetPoint("BOTTOMRIGHT", 10, -10)
	b.hook = b:CreateFontString(nil, "OVERLAY")   -- the line in the character's voice, large
	St.Font(b.hook, "name", 17)
	b.hook:SetShadowOffset(0, 0)
	b.hook:SetTextColor(0.95, 0.90, 0.78)
	b.hook:SetWidth(Card.BUBBLE_W)
	b.hook:SetWordWrap(true)
	b.hook:SetJustifyH("LEFT")
	b.hook:SetPoint("TOPLEFT", s, "TOPLEFT", Card.BUBBLE_LEFT + 12, -Card.BUBBLE_TOP)
	b.text = b:CreateFontString(nil, "OVERLAY")   -- the facts, small
	St.Font(b.text, "body", 13)
	b.text:SetShadowOffset(0, 0)
	b.text:SetTextColor(0.77, 0.72, 0.60)
	b.text:SetWidth(Card.BUBBLE_W)
	b.text:SetWordWrap(true)
	b.text:SetJustifyH("LEFT")
	b.text:SetPoint("TOPLEFT", b.hook, "BOTTOMLEFT", 0, -4)
	b:SetPoint("TOPLEFT", b.hook, "TOPLEFT", -12, 10)   -- Card.FitBubble sizes it around both blocks
	Wg.PointTail(b, "right")   -- on the right edge, pointing at the figure
	b.tail:ClearAllPoints()
	b.tail:SetPoint("LEFT", b, "BOTTOMRIGHT", -1, 20)
	b.pop = b:CreateAnimationGroup()   -- a 200 ms reveal
	local a1 = b.pop:CreateAnimation("Alpha")
	a1:SetFromAlpha(0)
	a1:SetToAlpha(1)
	a1:SetDuration(0.2)
	s.bubble = b
	s:EnableMouse(true)
	s:SetScript("OnMouseUp", function() if f.typer:IsShown() then f.typer.t = 99 end end)
	-- Name plate: a level badge, the name in class colour, then who and where.
	-- The figure on the stage is the face; its gold level disc sits on the ring at 4 o'clock.
	s.lvl = s.figure:CreateTexture(nil, "OVERLAY", nil, 6)
	St.Paint(s.lvl, "disc_gold")
	s.lvl:SetSize(24, 24)
	s.lvl:SetPoint("CENTER", s.figure, "CENTER", -54, -54)   -- 7 o'clock, overlapping the ring a little: attached
	s.lvlText = Wg.Text(s.figure, "number", "OVERLAY", 14)
	s.lvlText:SetDrawLayer("OVERLAY", 7)
	s.lvlText:SetPoint("CENTER", s.lvl)
	s.lvlText:SetTextColor(0.14, 0.09, 0.03)
	s.lvlText:SetShadowOffset(0, 0)
	s.plate = Wg.Text(s, "hero", "OVERLAY", 22)
	s.plate:SetPoint("BOTTOMLEFT", 14, 36)
	s.sub = Wg.Text(s, "body", "OVERLAY", 13)
	s.sub:SetPoint("TOPLEFT", s.plate, "BOTTOMLEFT", 1, -2)
	St.Color(s.sub, St.CREAM)
	s.chip = Wg.Chip(s, 20)
	s.chip:SetPoint("BOTTOMRIGHT", -14, 40)   -- on the name line, clear of "Seen ..."
	s.lookBox = ns.Look.CardControls(s)   -- "Save my look", under the bubble: the character you are on only
	s.lookBox:SetPoint("BOTTOMLEFT", Card.BUBBLE_LEFT, Card.CONTROLS_BOTTOM)
	return s
end

-- Tidbits: one stats panel with two columns of borderless tiles (an odd last one spans both columns).
local TILE_H = 42
local function makeTiles(f)
	f.stats = CreateFrame("Frame", nil, f, "BackdropTemplate")
	f.stats:SetWidth(IW)
	St.Panel(f.stats, "inset")
	f.tiles = {}
	for i = 1, 10 do
		local t = CreateFrame("Frame", nil, f.stats)
		t:SetHeight(TILE_H)
		t.icon = t:CreateTexture(nil, "ARTWORK")
		t.icon:SetSize(22, 22)
		t.icon:SetPoint("TOPLEFT", 8, -10)
		t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		t.label = Wg.Text(t, "small", nil, 11)
		t.label:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 12, 2)
		St.Color(t.label, St.GOLD)
		t.value = Wg.Text(t, "body", nil, 13)
		t.value:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -2)
		St.Color(t.value, St.CREAM)
		f.tiles[i] = t
	end
end

function Card.Create()
	if Card.frame then return Card.frame end
	St.Ensure()
	local ok, f = pcall(CreateFrame, "Frame", "RestedLevelingCard", UIParent, St.WindowTemplate())
	if not ok or not f then
		f = CreateFrame("Frame", "RestedLevelingCard", UIParent, "BackdropTemplate")
		St.Panel(f, "card")
	end
	f:SetSize(W, 700)
	St.Scale(f)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	St.Window(f, "")
	tinsert(UISpecialFrames, "RestedLevelingCard")
	f.typer = CreateFrame("Frame", nil, f)
	f.stage = makeStage(f)
	f.bar = Wg.BubbleBar(f, IW - 4, 16, 30)   -- inside the panels' edges, like the stage and the facts
	f.bar:SetPoint("TOPLEFT", f.stage, "BOTTOMLEFT", 0, -10)
	f.why = Wg.Text(f, "body", nil, 13)
	f.why:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 10, -8)
	f.why:SetWidth(IW - 20)
	f.why:SetHeight(36)
	f.why:SetJustifyV("TOP")
	f.why:SetWordWrap(true)
	St.Color(f.why, St.CREAM)
	f.whyHit = CreateFrame("Frame", nil, f)   -- the rest line explains its own maths on hover
	f.whyHit:SetAllPoints(f.why)
	f.whyHit:EnableMouse(true)
	f.whyHit:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		for i, line in ipairs(Card.REST_HELP) do
			if i == 1 then GameTooltip:AddLine(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
		end
		GameTooltip:Show()
	end)
	f.whyHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
	makeTiles(f)
	f.typer:SetScript("OnUpdate", function(self, elapsed)
		self.t = (self.t or 0) + elapsed
		local n = math.floor(self.t * 38)
		local hook, text = self.hook or "", self.text or ""
		local b = f.stage.bubble
		b.hook:SetText(hook:sub(1, n))
		b.text:SetText(n > #hook and text:sub(1, n - #hook) or "")
		local talking = n < #hook + #text
		f.stage.figure:SetPoint("BOTTOM", FIG_X, 78 + (talking and math.abs(math.sin(self.t * 14)) * 3 or 0))
		if not talking then b.hook:SetText(hook); b.text:SetText(text); Card.FitBubble(f.stage); self:Hide() end
	end)
	f:HookScript("OnHide", function() ns.selectedKey = nil; if ns.Main then ns.Main.Refresh() end end)
	Card.frame = f
	f:Hide()
	return f
end

-- The bubble wraps to as many lines as the line needs and grows down the stage; only if it would then reach the note
-- (or the card's buttons, or the name plate) does it drop one font step. Never "...". Sized for the full line while it
-- types out.
Card.BUBBLE_SIZES = { { 17, 13 }, { 15, 12 } }   -- hook and facts: the normal size, then one step down
function Card.BubbleRoom(s)   -- px the bubble may take from its top (inside the 10 px top inset) to what is below it
	local floor = 84   -- the name plate's top
	if s.note:IsShown() then floor = 86 + s.note:GetStringHeight() + 8 end   -- the note's top
	if s.lookBox:IsShown() then floor = Card.CONTROLS_BOTTOM + s.lookBox:GetHeight() + 8 end   -- the buttons' top
	return STAGE_H - Card.BUBBLE_TOP - floor
end
-- The bubble's right edge, tail included, in stage pixels: never closer than Card.GAP to the figure column.
function Card.BubbleRight(s) return Card.BUBBLE_LEFT + s.bubble:GetWidth() + Card.TAIL end
-- A block's own width: one line as wide as it is, or balanced lines (no orphan word) when it wraps, widened until it
-- takes no more lines than it would at the full width (long words: "Feathermoon Stronghold inn suits me.").
local function natural(fs)
	local maxW = Card.BUBBLE_W
	local one = fs:GetUnboundedStringWidth()
	if one <= maxW then
		local w = math.min(maxW, math.ceil(one) + 4)
		fs:SetWidth(w)
		return w
	end
	fs:SetWidth(maxW)
	local fewest = fs:GetStringHeight()
	local w = Wg.Balance(fs, maxW)
	while w < maxW and fs:GetStringHeight() > fewest do
		w = math.min(maxW, w + 8)
		fs:SetWidth(w)
	end
	return w
end
function Card.FitBubble(s, hook, text)
	local b = s.bubble
	b.line = hook and { hook, text } or b.line
	if not b.line then return end
	local shownHook, shownText = b.hook:GetText(), b.text:GetText()   -- mid-typing: measured on the full line
	local room = Card.BubbleRoom(s)
	for i, size in ipairs(Card.BUBBLE_SIZES) do
		St.Font(b.hook, "name", size[1])
		St.Font(b.text, "body", size[2])
		-- no height left from the last fit: a string held to it measures (and draws) only the lines that fit, so a
		-- font that settles wider a frame later would keep "Feathermoon Stronghold..." cut (Andy's v1.1.1 card)
		b.hook:SetHeight(0)
		b.text:SetHeight(0)
		b.hook:SetText(b.line[1])
		b.text:SetText(b.line[2])
		local w = math.max(natural(b.hook), natural(b.text))
		local hh, th = b.hook:GetStringHeight(), b.text:GetStringHeight()
		b.size = i
		if 10 + hh + 4 + th + 10 <= room or i == #Card.BUBBLE_SIZES then
			b.hook:SetHeight(hh + 2)   -- a little slack: the last line is never cut
			b.text:SetHeight(th + 2)
			b:SetSize(w + 24, 10 + hh + 2 + 4 + th + 2 + 10)
			break
		end
	end
	b.hook:SetText(shownHook or "")
	b.text:SetText(shownText or "")
end

local function talk(f, hook, text)
	local b = f.stage.bubble
	b.hook:SetText("")
	b.text:SetText("")
	Card.FitBubble(f.stage, hook, text)
	-- Fonts (ElvUI's especially) settle a frame after show; measure again then, as the Esc card does.
	C_Timer.After(0, function() if f:IsShown() then Card.FitBubble(f.stage) end end)
	f.typer.hook, f.typer.text, f.typer.t = hook, text, 0
	f.typer:Show()
	b.pop:Play()
	f.stage.settle:Play()
end

-- How rest fills, for the rest line's tooltip (Andy asked whether ~10 days from empty is right: it is).
Card.REST_HELP = {
	"How rest fills",
	"Rest fills 5% of a level every 8h in an inn or city; full is 1.5 levels.",
	"So empty to full takes 10 days in an inn, 40 days outside (4x slower).",
	"Each Well Rested rank raises the rate and the cap by 4%, so the time stays the same.",
}

-- Waist up, turned a little toward the bubble. Again whenever the model (re)loads: loading resets the camera.
function Card.FrameModel(model)
	U.Call(model.SetCamDistanceScale, model, 1)
	U.Call(model.SetPortraitZoom, model, Card.MODEL_ZOOM)
	U.Call(model.SetRotation, model, -0.35)
end

-- The 3D figure is the logged-in character only: no other character's look can be drawn offline.
local function dressModel(model, isMe)
	if not isMe then
		model:ClearModel()
		return false
	end
	model:SetUnit("player")
	Card.FrameModel(model)
	local anim = (model:HasAnimation(TALK) and TALK) or (model:HasAnimation(TALK_EXCLAIM) and TALK_EXCLAIM) or 0
	model:SetAnimation(anim)
	return true
end

-- Flow layout: two columns; a value too long for half the panel takes the whole row on up to two lines.
local function fillTiles(f, c, now)
	local list = ns.Tidbits.List(c, now)
	local full = IW - 16
	local half = (full - 8) / 2
	f.stats:ClearAllPoints()
	f.stats:SetPoint("TOPLEFT", f.why, "BOTTOMLEFT", -10, -6)
	local y, col, n = -4, 0, 0
	for i, t in ipairs(f.tiles) do
		local item = list[i]
		t:ClearAllPoints()
		if item then
			n = n + 1
			t.value:SetWidth(half - 40)
			t.value:SetText(item[2])
			local wide = t.value:GetStringWidth() > half - 44 or (i == #list and col == 0 and #list % 2 == 1)
			if wide and col == 1 then y, col = y - TILE_H, 0 end   -- finish the half row first
			local w = wide and full or half
			t:SetWidth(w)
			t.value:SetWidth(w - 40)
			t.value:SetWordWrap(wide)
			t.value:SetText(item[2])
			local h = math.max(TILE_H, (t.value:GetStringHeight() or 14) + 26)
			t:SetHeight(h)
			t:SetPoint("TOPLEFT", f.stats, "TOPLEFT", 8 + col * (half + 8), y)
			t.icon:SetTexture(ICONS[item[1]] or "Interface\\Icons\\INV_Misc_QuestionMark")
			t.label:SetText(item[1]:upper())
			if not wide then Wg.Fit(t.value, item[2], half - 44) end
			t:Show()
			if wide or col == 1 then y, col = y - h, 0 else col = 1 end
		else
			t:Hide()
		end
	end
	if col == 1 then y = y - TILE_H end
	f.stats:SetHeight(-y + 6)
	f.stats:SetShown(n > 0)
	return n
end

-- Fill the card for a roster row, or the logged-in character.
function Card.Show(key)
	local f = Card.Create()   -- first, so creating (and hiding) the card cannot clear the selection
	ns.selectedKey = key
	if ns.Main and ns.Main.Refresh then ns.Main.Refresh() end   -- the roster marks the row at once
	local d, now = ns.DB(), time()
	local c = d.chars[key]
	if not c then return end
	local isMe = key == ns.MyKey()
	local p = M.Project(c, now, d.calib)
	local state = M.State(c, p, { maxLevel = ns.Snap.MaxLevel(), target = d.opts.target })
	local row = { key = key, c = c, p = p, state = state }
	if isMe then
		local s = ns.Session()
		if s then p = { levels = s.levels, pct = math.min(1, s.levels / M.Cap(c, d.calib)), left = 1 } end
		row.p = p
	end
	St.Window(f, c.full or "Character card")   -- the title names who this is
	local s = f.stage
	local outside = c.restKind == "outside"
	s.bg:SetTexture(St.MEDIA .. (outside and "stage_wild" or "stage_inn"))
	s.bg:SetTexCoord(0, 1, 0.12, 0.85)
	local host = St.HostFrame()   -- under a host skin the stage is a flat well, like its own windows
	s.bg:SetShown(not host)
	s.shade:SetShown(not host)
	if host then St.Backdrop(s, "sw_host_stage", "sw_host_line", 1) end   -- his panel colour, not a black void
	s.warm:SetShown(not outside and not host)
	s.cold:SetShown(outside and not host)
	s.fog:SetShown(outside and not host)
	for _, z in ipairs(s.zs) do
		z:SetShown(not outside and state ~= "max")
		if z:IsShown() then z.anim:Play() else z.anim:Stop() end
	end
	local modelShown = dressModel(s.model, isMe)
	s.model:SetShown(modelShown)
	s.figure:SetShown(not modelShown)
	s.floor:SetShown(not modelShown and not host)   -- under a host skin: no floor shadow or bronze rule
	s.note:SetShown(not modelShown)
	s.pedestal:SetShown(false)   -- no rule under the portrait
	if not modelShown then
		Wg.SetPortrait(s.figure, c, false, state)   -- the saved look, or the class crest with the race emblem
		s.note:SetText(Card.OfflineNote(c))
		Wg.Balance(s.note, 160)   -- no "them." alone on the last line
		St.Paint(s.lvl, host and "disc_dark" or "disc_gold")   -- under ElvUI a restrained dark disc, not a gold medallion
		s.lvlRing = s.lvlRing or s.figure:CreateTexture(nil, "OVERLAY", nil, 7)
		St.Paint(s.lvlRing, "ring_bronze")
		s.lvlRing:SetAllPoints(s.lvl)
		s.lvlRing:SetShown(host)   -- a thin bronze ring so it reads on the dark stage
		s.lvlText:SetTextColor(unpack(host and { 0.95, 0.90, 0.77 } or { 0.14, 0.09, 0.03 }))
		s.breathe:Play()
	end
	ns.Look.UpdateCardControls(s.lookBox, key, isMe)
	s.plate:SetText(St.ClassText(c.class, c.full or "?"))
	s.lvlText:SetText(c.level or "?")
	local raceName = c.race == "Scourge" and "Undead" or (c.race and c.race:gsub("(%l)(%u)", "%1 %2")) or ""
	local className = c.class and (c.class:sub(1, 1) .. c.class:sub(2):lower()) or ""
	local tag = St.AccountTag(c)
	local crest = c.class and ("|A:classicon-" .. c.class:lower() .. ":14:14|a ") or ""
	local ago = now - (c.t or now)
	local days = math.floor(ago / 86400)
	s.sub:SetText(("%sLevel %s %s %s  ·  Seen %s ago%s"):format(crest, c.level or "?", raceName, className,
		days >= 1 and (days .. (days == 1 and " day" or " days")) or U.Long(ago), tag and ("  ·  " .. tag) or ""))
	Wg.SetChip(s.chip, isMe and "resting" or state, isMe and "NOW PLAYING" or Wd.Chip(row))
	Wg.SetBubbleBar(f.bar, p and p.pct or 0, state, false)
	f.why:SetText(isMe and "This is the character you're on." or Wd.Why(row, now))   -- ends with the real-life time to full
	Wg.Balance(f.why, IW - 20)
	local n = fillTiles(f, c, now)
	-- Sit next to the main window, top edges level.
	f:ClearAllPoints()
	local main = ns.Main and ns.Main.frame
	local docked = main and main:IsShown()
	if docked then f:SetPoint("TOPLEFT", main, "TOPRIGHT", 10, 0) else f:SetPoint("CENTER", 220, 10) end
	f:Show()
	local top, bottom = f:GetTop(), (n > 0 and f.stats or f.why):GetBottom()   -- the card ends at its tidbits
	if top and bottom then f:SetHeight(top - bottom + PAD) end
	-- a different line on each open, never the one the hero is saying (the hero uses turn 1)
	Card.opens = Card.opens or {}
	Card.opens[key] = (Card.opens[key] or 0) + 1
	talk(f, ns.Lines.Parts(row, now, isMe, Card.opens[key] % 2 == 1 and 0 or 2))
end

-- Under the crest of a character that is not logged in: "Last seen as a level 46 Gnome Warrior. Log in to see them."
-- With a saved look the face is theirs, so only the first sentence.
function Card.OfflineNote(c)
	local race = c.race == "Scourge" and "Undead" or (c.race and c.race:gsub("(%l)(%u)", "%1 %2")) or ""
	local class = c.class and (c.class:sub(1, 1) .. c.class:sub(2):lower()) or ""
	local who = (race .. " " .. class):gsub("^%s+", ""):gsub("%s+$", "")
	local line = ("Last seen as a level %s %s."):format(c.level or "?", who ~= "" and who or "character")
	return c.look and line or (line .. " Log in to see them.")
end

ns.ShowDetail = Card.Show
