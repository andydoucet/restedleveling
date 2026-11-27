-- Rested Leveling: options. A page in the Blizzard Settings panel, the same switches on an ElvUI /ec page when ElvUI
-- is loaded (LibElvUIPlugin), and the About credits.

local addonName, ns = ...
local St, Wg, U, Ru = ns.Style, ns.Widgets, ns.Util, ns.Rules
local O = {}
ns.Options = O

O.CREDITS = "Builds on Rested Watch by doc_biddle (GPL-3.0): the rested-XP projection, self-calibration, the "
	.. "Well Rested rank reader and the sleeping-bag logic. Thank you."

-- Every switch, used by both pages. get/set read and write the saved options.
O.SWITCHES = {
	{ key = "compact", label = "Compact mode (one line of state pips)", get = function(d) return d.opts.compact end,
		set = function(_, v) if ns.Compact then ns.Compact.Toggle(v) end end },
	{ key = "showGrey", label = "Show max level and hidden characters (dimmed, at the bottom)",
		get = function(d) return d.opts.showGrey ~= false end, set = function(d, v) d.opts.showGrey = v end },
	{ key = "minimap", label = "Minimap button", get = function(d) return not d.opts.minimap.hide end,
		set = function(d, v) d.opts.minimap.hide = not v end },
	{ key = "minimapElv", label = "Minimap button even with ElvUI", get = function(d) return d.opts.showMinimapWithElvUI end,
		set = function(d, v) d.opts.showMinimapWithElvUI = v end },
}
O.SWITCHES[#O.SWITCHES + 1] = { key = "bigger", label = "Bigger windows (115%, for high resolutions; after /reload)",
	get = function(d) return (tonumber(d.opts.scale) or 1) > 1 end, set = function(d, v) d.opts.scale = v and 1.15 or nil end }
O.SWITCHES[#O.SWITCHES + 1] = { key = "reduceMotion", label = "Reduce motion (no sweep when a new character takes #1)",
	get = function(d) return d.opts.reduceMotion end, set = function(d, v) d.opts.reduceMotion = v or nil end }
O.SWITCHES[#O.SWITCHES + 1] = { key = "elvuiWindow", label = "With ElvUI: use Rested Leveling's own frame, not the ElvUI skin (after /reload)",
	get = function(d) return d.opts.elvuiWindow == "own" end, set = function(d, v) d.opts.elvuiWindow = v and "own" or nil end }
for _, kind in ipairs({ "logout", "menu", "outrest", "lowrest", "filled", "digest", "bag" }) do
	O.SWITCHES[#O.SWITCHES + 1] = { key = "alert_" .. kind, label = Ru.KINDS[kind].label,
		get = function(d) return not d.alertsOff[kind] end, set = function(d, v) d.alertsOff[kind] = (not v) or nil end }
end

-- Account filter: nil = all, "mine" = this account, or a peer account id. Applies to hero, roster, compact, datatext.
function O.SetAccounts(value)
	local d = ns.DB()
	if value == d.account then value = "mine" end
	d.opts.accounts = value
	ns.Fire("ROSTER_CHANGED")
	if ns.Broker and ns.Broker.Update then ns.Broker.Update() end
end

-- The choices, in order: { value, label } (value nil = all).
function O.AccountChoices()
	local out = { { nil, "All accounts" } }
	for _, a in ipairs(ns.Accounts()) do
		local label = a.label:match("^#(%d+)$") and ("Account " .. a.label:sub(2)) or a.label   -- not a bare "#3"
		out[#out + 1] = { a.mine and "mine" or a.id, a.mine and "This account" or label }
	end
	return out
end

-- The low-rest warning threshold, whole % of a full bar left (5..50).
function O.SetLow(v)
	local n = tonumber(v)
	if not n then return end
	ns.DB().opts.lowPct = U.Clamp(math.floor(n + 0.5), ns.LOW_MIN, ns.LOW_MAX)
end
function O.ShowLow(sl)
	local pct = ns.DB().opts.lowPct
	sl.value:SetText(O.LowText(pct))
	local w = math.max(1, (sl:GetWidth() - 2) * (pct - ns.LOW_MIN) / (ns.LOW_MAX - ns.LOW_MIN))
	sl.fill:SetWidth(w)
	sl.knob:ClearAllPoints()
	sl.knob:SetPoint("CENTER", sl, "LEFT", 1 + w, 0)
	if O.panel and O.panel.lowLabel then O.panel.lowLabel:SetText(("LOW REST WARNING  ·  %d%%"):format(pct)) end
end
function O.LowText(pct) return ("Warn when under %d%% of a full bar is left"):format(pct) end

local function apply(sw, v)
	local d = ns.DB()
	sw.set(d, v and true or false)
	if ns.Broker then ns.Broker.UpdateMinimap() end
	ns.Fire("ROSTER_CHANGED")
end

local STYLES = { { "auto", "Auto (ElvUI when loaded)" }, { "default", "Default" }, { "elvui", "ElvUI" } }

-- The page's text roles: gold section headings, cream settings, softer helper lines (no yellow paragraphs).
local function heading(p, text, x, y)
	local h = Wg.Text(p, "label", nil, 12)
	h:SetPoint("TOPLEFT", x, y)
	h:SetText(text)
	St.Color(h, St.GOLD)
	return h
end
local function words(parent, text, size, color)
	local t = Wg.Text(parent, size and size < 12 and "small" or "body", nil, size or 12)
	t:SetText(text)
	St.Color(t, color or St.CREAM)
	return t
end

	-- Under plain ElvUI: ElvUI's own backdrop colour; inside a skin's window (checked on show): its warm well.
function O.PaintPanel(p)
	-- skinned: the Settings window itself, or a skin seen on our own windows this session (the page sits beside them)
	local skinned = St.SkinnedWindow(p) or (St.backend and St.backend.skinSeen)
	local fill = not skinned and St.HostFill()
	if fill then p.bg:SetColorTexture(unpack(fill)) else St.Paint(p.bg, "sw_host_well") end
end

function O.Panel()
	if O.panel then return O.panel end
	St.Ensure()
	local p = CreateFrame("Frame", "RestedLevelingOptions")
	p.name = "Rested Leveling"
	p.bg = p:CreateTexture(nil, "BACKGROUND")   -- our own near-black panel, like the roster's wells, in both themes
	St.Paint(p.bg, "sw_host_well")
	p.bg:SetAllPoints()
	local title = Wg.Text(p, "title", nil, 20)
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Rested Leveling")
	title:SetTextColor(St.GOLD.r, St.GOLD.g, St.GOLD.b)
	local sub = words(p, "Never level unrested. /rlvl opens the roster, /rlvl help lists commands.", 12, St.SECOND)
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	local y = -64
	heading(p, "APPEARANCE  (style applies after /reload)", 16, y)
	y = y - 20
	p.styleButtons = {}
	local x = 16
	for i, s in ipairs(STYLES) do   -- one 24 px gap between choices
		local b = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
		b:SetPoint("TOPLEFT", x, y)
		local t = words(b, s[2])
		t:SetPoint("LEFT", b, "RIGHT", 4, 0)
		x = x + 20 + t:GetStringWidth() + 24
		b:SetScript("OnClick", function()
			ns.DB().opts.style = s[1]
			for _, o in ipairs(p.styleButtons) do o:SetChecked(o == b) end
		end)
		b.value = s[1]
		p.styleButtons[i] = b
	end
	y = y - 38
	-- Show accounts: radio buttons, rebuilt on show (accounts come and go with links).
	heading(p, "ACCOUNTS", 16, y)
	p.accButtons = {}
	p.accY = y - 20
	-- Low-rest warning threshold: a slider, 5 to 50%.
	p.lowLabel = heading(p, "LOW REST WARNING", 380, y)
	local sl = CreateFrame("Slider", nil, p, "BackdropTemplate")
	sl:SetOrientation("HORIZONTAL")
	sl:SetSize(200, 14)
	sl:SetPoint("TOPLEFT", 412, y - 26)
	sl:SetMinMaxValues(ns.LOW_MIN, ns.LOW_MAX)
	sl:SetValueStep(1)
	sl:SetObeyStepOnDrag(true)
	St.Slider(sl)
	sl.over = CreateFrame("Frame", nil, sl)   -- above any backdrop a skin adds to the slider
	sl.over:SetAllPoints()
	sl.over:SetFrameLevel(sl:GetFrameLevel() + 3)
	sl.fill = sl.over:CreateTexture(nil, "OVERLAY")   -- the value as a gold fill from the left, whatever the skin's thumb
	sl.fill:SetColorTexture(0.84, 0.66, 0.30, 0.85)
	sl.fill:SetPoint("TOPLEFT", 1, -1)
	sl.fill:SetPoint("BOTTOMLEFT", 1, 1)
	sl.knob = sl.over:CreateTexture(nil, "OVERLAY", nil, 1)   -- a visible thumb at the value, on any skin
	sl.knob:SetColorTexture(0.98, 0.88, 0.60, 1)
	sl.knob:SetSize(6, 20)
	for i, v in ipairs({ ns.LOW_MIN, ns.LOW_MAX }) do
		local e = Wg.Text(p, "small", nil, 12)
		e:SetPoint(i == 1 and "RIGHT" or "LEFT", sl, i == 1 and "LEFT" or "RIGHT", i == 1 and -6 or 6, 0)
		e:SetText(v .. "%")
		St.Color(e, St.MUTED)
	end
	sl.value = Wg.Text(p, "small", nil, 12)
	sl.value:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", -32, -8)
	St.Color(sl.value, St.SECOND)
	sl:SetScript("OnValueChanged", function(self, v)
		O.SetLow(v)
		O.ShowLow(self)
	end)
	p.low = sl
	y = y - 70
	-- Where the notifications show: a button into move mode (the same as /rlvl move).
	heading(p, "NOTIFICATIONS", 16, y)
	p.move = St.MakeButton(p, 170, "Move notifications", false, 22)
	p.move:SetPoint("TOPLEFT", 16, y - 22)
	p.move:SetScript("OnClick", function()
		if ns.Move.Start() and SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
	end)
	local mvText = words(p, "Drag the logout warning, the toasts and the Esc menu card where you want them.", 12, St.SECOND)
	mvText:SetPoint("TOPLEFT", p.move, "BOTTOMLEFT", 2, -6)   -- under its button, never to the panel's edge
	y = y - 78
	heading(p, "WINDOW AND DISPLAY", 16, y)
	y = y - 20
	p.checks = {}
	local col, alerts = 0, false
	for _, sw in ipairs(O.SWITCHES) do
		if sw.key:find("^alert_") and not alerts then   -- the alert kinds: their own heading, two columns
			alerts = true
			heading(p, "ALERTS", 16, y - 8)
			y = y - 26
		end
		local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
		cb:SetSize(24, 24)
		cb:SetPoint("TOPLEFT", 16 + col * 300, y)
		St.Check(cb)
		local t = words(cb, sw.label)
		t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
		cb:SetScript("OnClick", function(self) apply(sw, self:GetChecked()) end)
		cb.sw = sw
		p.checks[#p.checks + 1] = cb
		if alerts then col = 1 - col end
		if col == 0 then y = y - 22 end
	end
	if col == 1 then y = y - 22 end
	local about = words(p, "", 11, St.MUTED)
	about:SetPoint("TOPLEFT", 16, y - 12)
	about:SetWidth(600)   -- the canvas has no width of its own when this runs: wrap at a fixed measure
	about:SetWordWrap(true)
	about:SetText("|cffd6b56bAbout|r  Builds on Rested Watch by doc_biddle (GPL-3.0). Thank you.")   -- one line: the rest is in /ec
	p:SetScript("OnShow", function() O.PaintPanel(p) O.RefreshPanel(p) end)
	O.panel = p
	if Settings and Settings.RegisterCanvasLayoutCategory then
		O.category = Settings.RegisterCanvasLayoutCategory(p, "Rested Leveling")
		Settings.RegisterAddOnCategory(O.category)
	end
	return p
end

-- Fill the panel from the saved options: switches, style, the account choices and the threshold.
function O.RefreshPanel(p)
	local d = ns.DB()
	for _, cb in ipairs(p.checks) do cb:SetChecked(cb.sw.get(d) and true or false) end
	for _, b in ipairs(p.styleButtons) do b:SetChecked(b.value == (d.opts.style or "auto")) end
	local current = d.opts.accounts
	if current and not ns.AccountFilter() then current = nil end   -- a filter for a gone account shows all
	for i, choice in ipairs(O.AccountChoices()) do
		local b = p.accButtons[i]
		if not b then
			b = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
			b.text = words(b, "")
			b.text:SetPoint("LEFT", b, "RIGHT", 4, 0)
			b:SetScript("OnClick", function(self) O.SetAccounts(self.value); O.RefreshPanel(p) end)
			p.accButtons[i] = b
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 16 + ((i - 1) % 3) * 120, p.accY - math.floor((i - 1) / 3) * 22)
		b.value = choice[1]
		b.text:SetText(choice[2])
		b:SetChecked(choice[1] == current)
		b:Show()
	end
	for i = #O.AccountChoices() + 1, #p.accButtons do p.accButtons[i]:Hide() end
	p.low:SetValue(d.opts.lowPct)
	O.ShowLow(p.low)
end

function ns.OpenOptions()
	O.Panel()
	if Settings and Settings.OpenToCategory and O.category then
		Settings.OpenToCategory(O.category:GetID())
	else
		U.Print("options: /rlvl help lists every switch as a command.")
	end
end

-- ElvUI: the same switches on an /ec page.
local function elvOptions()
	local E = ElvUI and ElvUI[1]
	if not (E and E.Options and E.Options.args) then return end
	local args = {
		about = { order = 1, type = "description", name = O.CREDITS },
		style = { order = 2, type = "select", name = "Style (after /reload)", values = { auto = "Auto", default = "Default", elvui = "ElvUI" },
			get = function() return ns.DB().opts.style or "auto" end, set = function(_, v) ns.DB().opts.style = v end },
		accounts = { order = 3, type = "select", name = "Show accounts",
			values = function()
				local v = {}
				for _, c in ipairs(O.AccountChoices()) do v[c[1] or "all"] = c[2] end
				return v
			end,
			get = function() return ns.AccountFilter() and (ns.DB().opts.accounts or "all") or "all" end,
			set = function(_, v) O.SetAccounts(v ~= "all" and v or nil) end },
		move = { order = 5, type = "execute", name = "Move notifications", func = function()
			if ns.Move.Start() then
				local e = ElvUI and ElvUI[1]
				if e and e.Config_CloseWindow then pcall(e.Config_CloseWindow, e) end
			end
		end },
		lowPct = { order = 4, type = "range", name = "Low rest warning (% of a full bar left)", min = ns.LOW_MIN,
			max = ns.LOW_MAX, step = 1, get = function() return ns.DB().opts.lowPct end, set = function(_, v) O.SetLow(v) end },
	}
	for i, sw in ipairs(O.SWITCHES) do
		args[sw.key] = { order = 10 + i, type = "toggle", name = sw.label, width = "full",
			get = function() return sw.get(ns.DB()) and true or false end, set = function(_, v) apply(sw, v) end }
	end
	E.Options.args.RestedLeveling = { order = 100, type = "group", name = "Rested Leveling", args = args }
end

local plugin = LibStub("LibElvUIPlugin-1.0", true)
if plugin and ElvUI then pcall(plugin.RegisterPlugin, plugin, addonName, elvOptions) end

ns.RegisterCallback(O, "LOGIN_DONE", function() O.Panel() end)
ns.slash.options = ns.OpenOptions
ns.slash.accounts = function(arg)
	arg = (arg or ""):lower():match("^%s*(.-)%s*$")
	for _, c in ipairs(O.AccountChoices()) do
		local v = c[1] or "all"
		if arg == v or arg == c[2]:lower() or (arg == "this" and v == "mine") then
			O.SetAccounts(c[1])
			U.Print("showing " .. c[2]:lower() .. ".")
			return
		end
	end
	local names = {}
	for _, c in ipairs(O.AccountChoices()) do names[#names + 1] = c[1] == nil and "all" or (c[1] == "mine" and "this" or c[2]) end
	U.Print("usage: /rlvl accounts " .. table.concat(names, " | ") .. "  (now: " .. ns.AccountFilterLabel() .. ")")
end
ns.slash.low = function(arg)
	if not tonumber(arg) then U.Print(("usage: /rlvl low <%d-%d>  (now %d%%)"):format(ns.LOW_MIN, ns.LOW_MAX, ns.DB().opts.lowPct)) return end
	O.SetLow(arg)
	U.Print(O.LowText(ns.DB().opts.lowPct) .. ".")
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl accounts all|this|<label> - whose characters the roster shows"
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl low <5-50> - low rest warning threshold, % of a full bar"
ns.slash.scale = function(arg)
	local n = tonumber(arg)
	if not n then U.Print("usage: /rlvl scale <0.8 to 1.4>  (now " .. (ns.DB().opts.scale or 1) .. ")") return end
	ns.DB().opts.scale = math.max(0.8, math.min(1.4, n))
	for _, f in ipairs({ ns.Main and ns.Main.frame, ns.Card and ns.Card.frame }) do if f then St.Scale(f) end end
	U.Print("window scale " .. ns.DB().opts.scale .. ".")
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl scale <0.8-1.4> - window size"
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl options - the settings page"
