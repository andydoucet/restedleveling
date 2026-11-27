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
Wg.COL = { rank = 4, portrait = 32, text = 94, bar = 350, chip = 596 }   -- the Well Rested moons sit on the bar's caption line

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
	local cs = math.max(19, math.min(28, math.floor(size * 0.25)))   -- legible: the race or class reads at a glance
	f.noBadge = size < 36   -- a small disc (alert rows, timeline lanes) shows the picture alone: no double blob
	f.crestEdge = f:CreateTexture(nil, "OVERLAY", nil, 1)   -- a 1 px bronze rim parts the badge from the portrait
	St.Paint(f.crestEdge, "ring_bronze")
	f.crestRing = f:CreateTexture(nil, "OVERLAY", nil, 2)
	St.Paint(f.crestRing, "disc_dark")
	f.crestRing:SetSize(cs + 4, cs + 4)
	f.crestRing:SetPoint("CENTER", f, "CENTER", size * 0.5 + cs * 0.15, -size * 0.36)
	f.crest = f:CreateTexture(nil, "OVERLAY", nil, 3)
	f.crest:SetSize(cs, cs)
	f.crest:SetPoint("CENTER", f.crestRing)
	f.crestEdge:SetSize(cs + 8, cs + 8)
	f.crestEdge:SetPoint("CENTER", f.crestRing)
	f.crestMask = f:CreateMaskTexture()
	f.crestMask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	f.crestMask:SetAllPoints(f.crest)
	f.crest:AddMaskTexture(f.crestMask)
	return f
end

-- Two looks, one rule (Andy, ILL-1279): a face in the disc gets the class crest as its badge; no face, the class crest
-- is the picture and the badge is the race emblem.
--   isMe: the logged-in character's live portrait (SetPortraitTexture), class crest badge.
--   a saved look ("Save my look"): that face, cropped from its screenshot, class crest badge, like the live one.
--   neither: the game cannot draw their real look offline, so the disc shows their class crest and the badge their
--   race emblem. Honest, and clearly not a face that might be wrong (no stock race portrait).
-- Returns "live", "look" or "crest".
function Wg.SetPortrait(f, c, isMe, state)
	f.ring:SetShown(not St.HostFrame())   -- under a host skin: no bronze ring, the thin state line only
	St.Paint(f.stateRing, "ring_" .. (St.STATE[state or ""] and state or "max"))
	local crest = c.class and ("classicon-" .. c.class:lower()) or nil
	local dim = state == "max" or state == "done"
	f.live = isMe and true or false
	if isMe then
		SetPortraitTexture(f.tex, "player")
	elseif crest then
		f.tex:SetAtlas(crest)   -- under a saved look too: where its file does not load, the crest shows through
	else
		St.Paint(f.tex, "disc_dark")
	end
	f.tex:SetDesaturated(dim)
	local saved = ns.Look.Show(f, not isMe and c or nil, dim)
	local face = isMe or saved
	local badge = face and crest or Wg.RaceAtlas(c)
	if badge then f.crest:SetAtlas(badge) end
	-- The badge in colour (council r2: washed-out race emblems read as identical grey heads): a stock race icon at
	-- badge size names the race; it does not claim this character's own look.
	f.crest:SetDesaturation(0)
	if f.noBadge then badge = nil end
	f.crest:SetShown(badge ~= nil)
	f.crestRing:SetShown(badge ~= nil)
	f.crestEdge:SetShown(badge ~= nil)
	f.kind = isMe and "live" or (saved and "look" or "crest")
	return f.kind
end

-- The segmented rested bar: a real StatusBar (so ElvUI skins frame it: S:HandleStatusBar) cut into `segs` bubbles.
-- Each bubble is 1/segs of the cap (30 bubbles: each is 5% of a level, 8 hours in an inn). The coloured fill is our
-- own texture on top, sized from the value, so the state colour reads exactly under any skin (ElvUI_WC3 washes
-- native fills 15% grey); the StatusBar's native fill is kept transparent.
function Wg.BubbleBar(parent, w, h, segs)
	local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	holder:SetSize(w + 4, h + 4)
	St.Backdrop(holder, "sw_well", "sw_edge", 1)   -- a warm bronze edge: an empty bar still reads as a bar
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
		d:SetAlpha(0.2)   -- bubble seams (8 hours in an inn each): there, but the bar reads as a fill, not a ruler
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
	f.icon:SetSize(12, 12)   -- one icon size in every chip
	f.icon:SetPoint("LEFT", 4, 0)
	f.text = Wg.Text(f, "label", nil, 13)
	f.text:SetPoint("LEFT", f.icon, "RIGHT", 5, 0)
	return f
end


function Wg.SetChip(f, state, text)
	local s = St.STATE[state] or St.STATE.max
	local key = St.STATE[state] and state or "max"
	-- Every state has its mark: tick, arrow, warning, and for resting a small moon in its own orange.
	if key == "resting" then
		f.icon:SetTexture(St.MEDIA .. "moon_gold")
		f.icon:SetVertexColor(St.StateColor("resting"))
	else
		f.icon:SetTexture(s.icon)
		f.icon:SetVertexColor(1, 1, 1)
	end
	f.text:SetText(text or s.word:upper())
	local r, g, b = St.StateColor(key)
	f.text:SetTextColor(r * 0.55 + 0.45, g * 0.55 + 0.45, b * 0.55 + 0.45)   -- a light tint of the state, clear of its fill
	-- A filled tag, not a hollow box: the state's own dark fill and its edge (council r4: outlines read as form fields).
	St.Backdrop(f, "chipfill_" .. key, "st_" .. key, 1)
	if St.HostFrame() and f.SetBackdropColor then f:SetBackdropColor(1, 1, 1, 0.85) end
	local icon = key == "outside" or key == "near" or key == "full" or key == "resting"
	f.icon:SetShown(icon)
	local group = f.text:GetStringWidth() + (icon and (f.icon:GetWidth() + 5) or 0)
	if not f.fixed then f:SetWidth(group + 14) end
	f.icon:ClearAllPoints()   -- icon and word centred as one group: no dead space on the right
	f.icon:SetPoint("LEFT", math.max(6, math.floor((f:GetWidth() - group) / 2)), 0)
	f.text:ClearAllPoints()
	if icon then f.text:SetPoint("LEFT", f.icon, "RIGHT", 5, 0) else f.text:SetPoint("CENTER", 0, 0) end
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
