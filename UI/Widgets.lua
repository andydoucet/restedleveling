-- Rested Leveling: shared widgets: round class-ringed portraits, the segmented 30-bubble rested bar, state chips,
-- place badges and Well Rested pips. All drawing goes through ns.Style so ElvUI skins apply.

local _, ns = ...
local St, U = ns.Style, ns.Util
local Wg = {}
ns.Widgets = Wg

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- The race emblem (the client's own race icon atlas, as Blizzard's GetRaceAtlas names it): "raceicon128-gnome-female".
-- Only when the client has that atlas (C_Texture.GetAtlasInfo), else nil and no emblem.
local RACE_ATLAS = { scourge = "undead", undead = "undead", highmountaintauren = "highmountain",
	lightforgeddraenei = "lightforged", zandalaritroll = "zandalari" }
function Wg.RaceAtlas(c)
	local race = c and type(c.race) == "string" and c.race:lower()
	if not race or race == "" then return nil end
	local atlas = ("raceicon128-%s-%s"):format(RACE_ATLAS[race] or race, c.sex == 3 and "female" or "male")
	if not (C_Texture and C_Texture.GetAtlasInfo and U.Call(C_Texture.GetAtlasInfo, atlas)) then return nil end
	return atlas
end

-- The roster's column grid (x offsets inside a row), shared with the current-character strip so bars line up.
-- rank | portrait | name + sub | bar + caption | state chip | Well Rested moons
Wg.COL = { rank = 4, portrait = 32, text = 94, bar = 330, chip = 596 }   -- the Well Rested moons sit on the bar's caption line

-- Drop a trailing partial UTF-8 character (a lead byte without all its continuation bytes) left by a byte cut.
local function dropPartial(t)
	local i = #t
	while i > 0 and t:byte(i) >= 0x80 and t:byte(i) < 0xC0 do i = i - 1 end   -- continuation bytes
	local b = t:byte(i)
	if not b or b < 0xC0 then return t end
	local need = b >= 0xF0 and 4 or (b >= 0xE0 and 3 or 2)
	return (#t - i + 1 < need) and t:sub(1, i - 1) or t
end
Wg.DropPartial = dropPartial

-- Shorten `text` with an ellipsis until it fits `width` (font strings can't be trusted to clip cleanly), cutting
-- whole UTF-8 characters only ("·", accented names).
function Wg.Fit(fs, text, width)
	fs:SetText(text)
	if fs:GetStringWidth() <= width then return text end
	local t = text
	while #t > 1 and fs:GetStringWidth() > width do
		t = dropPartial(t:sub(1, #t - 1)):gsub("%s+$", "")
		fs:SetText(t .. "...")
	end
	return fs:GetText()
end

function Wg.Text(parent, role, layer, size)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	St.Font(fs, role, size)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

function Wg.Portrait(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.back = f:CreateTexture(nil, "BORDER")
	St.Paint(f.back, "disc_dark")
	f.back:SetAllPoints()
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetPoint("TOPLEFT", 2, -2)
	f.tex:SetPoint("BOTTOMRIGHT", -2, 2)
	f.mask = f:CreateMaskTexture()
	f.mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	f.mask:SetAllPoints(f.tex)
	f.tex:AddMaskTexture(f.mask)
	-- A saved look (UI/SaveLook.lua): the screenshot crop over the crest, in the same disc and mask. Where the file
	-- does not load it draws nothing and the crest shows through.
	f.look = f:CreateTexture(nil, "ARTWORK", nil, 1)
	f.look:SetAllPoints(f.tex)
	f.look:AddMaskTexture(f.mask)
	f.look:Hide()
	-- A bronze ring with a thin inner line in the state colour; class colour stays on the name.
	f.ring = f:CreateTexture(nil, "OVERLAY")
	St.Paint(f.ring, "ring_bronze")
	f.ring:SetPoint("CENTER")
	f.ring:SetSize(size * 1.1, size * 1.1)
	f.stateRing = f:CreateTexture(nil, "OVERLAY", nil, 1)
	f.stateRing:SetPoint("CENTER")
	f.stateRing:SetSize(size * 1.0, size * 1.0)
	-- The class crest sits outside the ring at 4 o'clock, in its own dark circle.
	local cs = math.max(14, math.min(22, math.floor(size * 0.24)))
	f.crestRing = f:CreateTexture(nil, "OVERLAY", nil, 2)
	St.Paint(f.crestRing, "disc_dark")
	f.crestRing:SetSize(cs + 4, cs + 4)
	f.crestRing:SetPoint("CENTER", f, "CENTER", size * 0.5 + cs * 0.15, -size * 0.36)
	f.crest = f:CreateTexture(nil, "OVERLAY", nil, 3)
	f.crest:SetSize(cs, cs)
	f.crest:SetPoint("CENTER", f.crestRing)
	f.crestMask = f:CreateMaskTexture()
	f.crestMask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	f.crestMask:SetAllPoints(f.crest)
	f.crest:AddMaskTexture(f.crestMask)
	-- An additive copy of the race emblem over it: lifts the dark parts so the race reads on the dark disc.
	f.crestLift = f:CreateTexture(nil, "OVERLAY", nil, 4)
	f.crestLift:SetAllPoints(f.crest)
	f.crestLift:SetBlendMode("ADD")
	f.crestLift:SetAlpha(0.8)
	f.crestLift:AddMaskTexture(f.crestMask)
	return f
end

-- isMe: the logged-in character, whose real portrait the game can draw (face in the disc, class crest at 4 o'clock).
-- Anyone else: the game cannot draw their real look offline, so the disc shows their class crest and the small
-- badge their race emblem. Honest, and clearly not a face that might be wrong (no stock race portrait). If they
-- saved their look ("Save my look"), that face covers the crest; the race emblem stays as the badge.
function Wg.SetPortrait(f, c, isMe, state)
	f.ring:SetShown(not St.HostFrame())   -- under a host skin: no bronze ring, the thin state line only
	St.Paint(f.stateRing, "ring_" .. (St.STATE[state or ""] and state or "max"))
	local crest = c.class and ("classicon-" .. c.class:lower()) or nil
	local badge
	f.live = isMe and true or false
	if isMe then
		SetPortraitTexture(f.tex, "player")
		badge = crest
	else
		if crest then f.tex:SetAtlas(crest) else St.Paint(f.tex, "disc_dark") end
		badge = Wg.RaceAtlas(c)
	end
	if badge then f.crest:SetAtlas(badge) end
	-- The race emblem partly washed out, so it names the race without claiming a skin or hair colour, and lifted by
	-- its additive copy so it reads as a face on the dark disc, not a grey blob. The class crest (isMe) as drawn.
	local lift = badge ~= nil and not isMe
	f.crest:SetDesaturation(isMe and 0 or 0.5)
	if lift then f.crestLift:SetAtlas(badge) f.crestLift:SetDesaturation(0.5) end
	f.crestLift:SetShown(lift)
	f.crest:SetShown(badge ~= nil)
	f.crestRing:SetShown(badge ~= nil)
	f.tex:SetDesaturated(state == "max" or state == "done")
	ns.Look.Show(f, not isMe and c or nil, state == "max" or state == "done")
end

-- The segmented rested bar: a real StatusBar (so ElvUI skins frame it: S:HandleStatusBar) cut into `segs` bubbles.
-- Each bubble is 1/segs of the cap (30 bubbles: each is 5% of a level, 8 hours in an inn). The coloured fill is our
-- own texture on top, sized from the value, so the state colour reads exactly under any skin (ElvUI_WC3 washes
-- native fills 15% grey); the StatusBar's native fill is kept transparent.
function Wg.BubbleBar(parent, w, h, segs)
	local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	holder:SetSize(w + 4, h + 4)
	St.Backdrop(holder, "sw_well", "sw_black", 1)
	local bar = CreateFrame("StatusBar", nil, holder)
	bar:SetPoint("TOPLEFT", 2, -2)
	bar:SetPoint("BOTTOMRIGHT", -2, 2)
	bar:SetMinMaxValues(0, 1)
	St.Bar(bar)
	holder.bar = bar
	local native = bar:GetStatusBarTexture()
	if native then native:SetAlpha(0) end
	holder.fill = bar:CreateTexture(nil, "OVERLAY", nil, 0)
	St.Paint(holder.fill, "bar_full")
	holder.fill:SetPoint("TOPLEFT", bar, "TOPLEFT")
	holder.fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
	-- The empty part of the track is ours too, above anything a skin draws on the bar, so it stays a clean dark well.
	holder.track = bar:CreateTexture(nil, "OVERLAY", nil, -1)
	St.Paint(holder.track, "sw_well")
	holder.track:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
	holder.track:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
	holder.shine = bar:CreateTexture(nil, "OVERLAY", nil, 3)   -- a 1 px highlight along the top of the fill
	St.Paint(holder.shine, "sw_parch")
	holder.shine:SetAlpha(0.28)
	holder.shine:SetPoint("TOPLEFT", bar, "TOPLEFT")
	holder.shine:SetHeight(1)
	holder.hatch = bar:CreateTexture(nil, "OVERLAY", nil, 1)
	holder.hatch:SetTexture(St.MEDIA .. "hatch", "REPEAT", "REPEAT")
	holder.hatch:SetHorizTile(true)
	holder.hatch:SetVertTile(true)
	holder.hatch:SetAllPoints(bar)
	holder.hatch:SetVertexColor(0.1, 0.1, 0.1, 1)
	holder.dividers = {}
	segs = segs or 30
	for i = 1, segs - 1 do
		local d = bar:CreateTexture(nil, "OVERLAY", nil, 2)
		St.Paint(d, "sw_well")
		d:SetAlpha(0.15)   -- quiet bubble seams: they read on the fill without adding noise
		d:SetWidth(1)
		d:SetPoint("TOP", bar, "TOPLEFT", w * i / segs, 0)
		d:SetPoint("BOTTOM", bar, "BOTTOMLEFT", w * i / segs, 0)
		holder.dividers[i] = d
	end
	holder.width = w
	return holder
end

-- projected: an estimate not yet confirmed by a login (shows a faint hatch).
function Wg.SetBubbleBar(holder, pct, state, projected)
	local r, g, b = St.StateColor(state)
	pct = math.max(0, math.min(1, pct or 0))
	holder.bar:SetValue(pct)
	holder.bar:SetStatusBarColor(r, g, b)
	holder.fill:SetWidth(math.max(0.01, holder.width * pct))
	holder.fill:SetTexCoord(0, math.max(0.01, pct), 0, 1)
	St.Paint(holder.fill, "bar_" .. (St.STATE[state] and state or "max"))
	holder.fill:SetShown(pct > 0)
	holder.hatch:SetShown(projected and pct > 0 and pct < 1)
	local x = holder.width * pct
	holder.track:SetWidth(math.max(0.01, holder.width - x))
	holder.track:SetShown(pct < 1)
	holder.shine:SetWidth(math.max(0.01, x))
	holder.shine:SetShown(pct > 0)
end

-- A chip: state icon + word, the non-colour cue. Fixed width so the columns after it never move.
Wg.CHIP_W = 116
function Wg.Chip(parent, h, w)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetSize(w or Wg.CHIP_W, h or 20)
	f.fixed = w ~= false
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize((h or 20) - 6, (h or 20) - 6)
	f.icon:SetPoint("LEFT", 4, 0)
	f.text = Wg.Text(f, "label", nil, 13)
	f.text:SetPoint("LEFT", f.icon, "RIGHT", 5, 0)
	return f
end

-- Chip colours: a dark state-tinted fill with light state-coloured text, so the word clears the fill.
local CHIP_TEXT = { full = { 0.90, 1, 0.91 }, near = { 0.89, 0.94, 0.42 }, resting = { 0.94, 0.77, 0.54 },   -- not UI gold
	outside = { 1, 0.83, 0.83 }, max = { 0.75, 0.72, 0.67 }, done = { 0.75, 0.72, 0.67 } }

function Wg.SetChip(f, state, text)
	local s = St.STATE[state] or St.STATE.max
	f.icon:SetTexture(s.icon)
	f.text:SetText(text or s.word:upper())
	local key = St.STATE[state] and state or "max"
	f.text:SetTextColor(unpack(CHIP_TEXT[key]))
	St.Backdrop(f, "chipfill_" .. key, "st_" .. key, 1)
	if St.HostFrame() and f.SetBackdropColor then f:SetBackdropColor(1, 1, 1, 0.35) end   -- quiet fills, like his flat cells
	local group = f.text:GetStringWidth() + f.icon:GetWidth() + 5
	if not f.fixed then f:SetWidth(group + 14) end
	f.icon:ClearAllPoints()   -- icon and word centred as one group: no dead space on the right
	f.icon:SetPoint("LEFT", math.max(4, math.floor((f:GetWidth() - group) / 2)), 0)
end

-- Place badge: icon (+ optional text).
function Wg.SetPlace(tex, c)
	local kind = c.restKind or (c.resting and "inn" or "outside")
	local p = St.PLACE[kind] or St.PLACE.outside
	tex:SetTexture(p.icon)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	return kind
end

-- Well Rested rank as five small moons (filled gold per rank, dim otherwise; faint when the rank is unknown).
-- A speech bubble: a dark panel with a bronze edge and cream text, and a tail (colours baked in) that points at the
-- speaker. side: "left", "right" or "down"; offset moves the tail along that edge.
function Wg.Bubble(parent, size)
	local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	St.Backdrop(b, "sw_bubble", "sw_bubble_edge", 1)
	b.tail = b:CreateTexture(nil, "ARTWORK")
	b.text = b:CreateFontString(nil, "OVERLAY")
	St.Font(b.text, "body", size or 13)
	b.text:SetTextColor(0.95, 0.90, 0.78)
	b.text:SetJustifyH("LEFT")
	return b
end

function Wg.PointTail(b, side, offset)
	b.tail:ClearAllPoints()
	if side == "left" or side == "right" then
		St.Paint(b.tail, side == "left" and "btail_l" or "btail_r")
		b.tail:SetSize(13, 20)   -- long enough to read as the speaker's tail at 1:1
		if side == "left" then b.tail:SetPoint("RIGHT", b, "LEFT", 1, offset or 0)
		else b.tail:SetPoint("LEFT", b, "RIGHT", -1, offset or 0) end
	else
		St.Paint(b.tail, "btail_d")
		b.tail:SetSize(20, 13)
		b.tail:SetPoint("TOP", b, "BOTTOMLEFT", offset or 22, 1)
	end
end

-- Wrap without orphans: when the text needs more than one line at maxW, narrow the field so the lines come out
-- even ("Hearth me home and I'll fill" / "up." becomes two balanced lines). Returns the width used.
function Wg.Balance(fs, maxW)
	fs:SetWidth(maxW)
	local w = fs:GetUnboundedStringWidth()
	-- +28: word breaks never push a last word onto a line of its own
	if w > maxW then fs:SetWidth(math.min(maxW, math.ceil(w / math.ceil(w / maxW)) + 28)) end
	return fs:GetWidth()
end
