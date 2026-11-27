-- Rested Leveling: the mini-roster tip. Our own tooltip panel in the window's materials (iron edge, oak-brown
-- fill, cream and gold type), used by the datatext / minimap button (LibDataBroker OnEnter) and the compact bar.
-- Columns: rank, name in class colour, level, then state word and time in the state colour.

local _, ns = ...
local St, Wg, Wd = ns.Style, ns.Widgets, ns.Words
local Tip = {}
ns.Tip = Tip

local W, ROW, MAX = 520, 20, 12   -- wide enough for "93%  ·  Full in 9d 23h (Thu 4 Dec, 22:40)"

local function create()
	St.Ensure()
	local f = CreateFrame("Frame", "RestedLevelingTip", UIParent, "BackdropTemplate")
	f:SetFrameStrata("TOOLTIP")
	f:SetWidth(W)
	St.Panel(f, "tooltip")
	f.title = Wg.Text(f, "title", nil, 16)
	f.title:SetPoint("TOPLEFT", 16, -12)
	f.title:SetText("Rested Leveling")
	St.Color(f.title, St.GOLD)
	f.sub = Wg.Text(f, "small", nil, 12)
	f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)   -- what the order means, under the title
	f.sub:SetText("Play the top one first")
	St.Color(f.sub, St.MUTED)
	f.rule = f:CreateTexture(nil, "ARTWORK")
	St.Paint(f.rule, "sw_rule")
	f.rule:SetHeight(1)
	f.rule:SetPoint("TOPLEFT", 14, -52)
	f.rule:SetPoint("TOPRIGHT", -14, -52)
	f.rows = {}
	for i = 1, MAX do
		local r = {}
		r.rank = Wg.Text(f, "number", nil, 13)
		r.rank:SetPoint("TOPLEFT", 16, -58 - (i - 1) * ROW)
		r.rank:SetWidth(18)
		r.rank:SetJustifyH("RIGHT")
		r.rank:SetTextColor(0.91, 0.79, 0.50)
		r.name = Wg.Text(f, "body", nil, 13)
		r.name:SetPoint("LEFT", r.rank, "RIGHT", 10, 0)
		r.name:SetWidth(200)
		r.state = Wg.Text(f, "body", nil, 13)
		r.state:SetPoint("TOPRIGHT", -16, -58 - (i - 1) * ROW)
		r.state:SetJustifyH("RIGHT")
		f.rows[i] = r
	end
	f.empty = Wg.Text(f, "body", nil, 13)
	f.empty:SetPoint("TOPLEFT", 16, -60)
	f.empty:SetWidth(W - 32)
	f.empty:SetWordWrap(true)
	St.Color(f.empty, St.CREAM)
	f.empty:SetText("No other characters yet. Log each one in and out once.")
	f.hint = Wg.Text(f, "small", nil, 12)
	St.Color(f.hint, St.SECOND)
	f.hint:SetText("Click: open the window  ·  Right-click: options")
	f:Hide()
	return f
end

-- Show the tip by `owner`, below it (or above when the owner is low on the screen).
function Tip.Show(owner)
	Tip.frame = Tip.frame or create()
	local f = Tip.frame
	local rows, now = ns.Rows({ hideGrey = true }), time()
	local n = math.min(#rows, MAX)
	for i, line in ipairs(f.rows) do
		local r = rows[i]
		local shown = r ~= nil and i <= n
		line.rank:SetShown(shown)
		line.name:SetShown(shown)
		line.state:SetShown(shown)
		if shown then
			local s = St.STATE[r.state] or St.STATE.max
			line.rank:SetText(i)
			line.name:SetText(St.ClassText(r.c.class, r.c.full or "?", true) .. ("  |cffb9b0a0· Lv %d|r"):format(r.c.level or 0))
			-- one phrase per row, with the real-life time to full: "Full since 2d 4h ago", "93% · Full in 3h (today 07:00)"
			local p = r.p
			local word, detail
			if not p then word = s.word
			elseif p.left == 0 then word = Wd.FullLine(p, now)
			else word, detail = (r.state == "outside" and "Outside" or (math.floor(p.pct * 100) .. "%")), Wd.FullLine(p, now) end
			line.state:SetText(("|c%s%s|r|cffb8a88a%s|r"):format(St.Hex(s.r, s.g, s.b), word, detail and ("  ·  " .. detail) or ""))
		end
	end
	f.empty:SetShown(n == 0)
	local body = n > 0 and n * ROW or 40
	f.hint:ClearAllPoints()
	f.hint:SetPoint("TOPLEFT", 16, -64 - body)
	f:SetHeight(64 + body + 30)
	f:ClearAllPoints()
	local below = not owner.GetBottom or not owner:GetBottom() or owner:GetBottom() > f:GetHeight() + 40
	if below then f:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -8) else f:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 8) end
	f:Show()
end

function Tip.Hide() if Tip.frame then Tip.frame:Hide() end end
