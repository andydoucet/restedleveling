-- Rested Leveling: options. One page of settings, built by O.Build into any frame: our own Settings window (the cog,
-- UI/Settings.lua) and a page in the Blizzard Settings panel show the same content; the same switches are on an
-- ElvUI /ec page when ElvUI is loaded (LibElvUIPlugin).

local addonName, ns = ...
local St, Wg, U, Ru = ns.Style, ns.Widgets, ns.Util, ns.Rules
local O = {}
ns.Options = O

O.CREDITS = "Builds on Rested Watch by doc_biddle (GPL-3.0): the rested-XP projection, self-calibration, the "
	.. "Well Rested rank reader and the sleeping-bag logic. Thank you."
O.W = 600   -- the page's width: two columns of switches
O.pages = {}   -- every page built, so one change refreshes them all

-- Every switch, used by every page. get/set read and write the saved options; tip: a longer line on hover.
O.SWITCHES = {
	{ key = "minimap", label = "Minimap button", get = function(d) return not d.opts.minimap.hide end,
		set = function(d, v) d.opts.minimap.hide = not v end, tip = "Also: /rlvl minimap" },
	{ key = "compact", label = "Compact mode (one line of pips)", get = function(d) return d.opts.compact end,
		set = function(_, v) if ns.Compact then ns.Compact.Toggle(v) end end },
	{ key = "showGrey", label = "Show max level and hidden", get = function(d) return d.opts.showGrey ~= false end,
		set = function(d, v) d.opts.showGrey = v end, tip = "Max level and hidden characters, dimmed, at the bottom" },
	{ key = "bigger", label = "Bigger windows (after /reload)", get = function(d) return (tonumber(d.opts.scale) or 1) > 1 end,
		set = function(d, v) d.opts.scale = v and 1.15 or nil end, tip = "115%, for high resolutions" },
	{ key = "reduceMotion", label = "Reduce motion", get = function(d) return d.opts.reduceMotion end,
		set = function(d, v) d.opts.reduceMotion = v or nil end, tip = "No sweep when a new character takes #1" },
	{ key = "elvuiWindow", label = "Own frame under ElvUI (after /reload)", elvui = true,
		get = function(d) return d.opts.elvuiWindow == "own" end, set = function(d, v) d.opts.elvuiWindow = v and "own" or nil end,
		tip = "With ElvUI: Rested Leveling's own oak frame instead of the ElvUI skin" },
}
for _, kind in ipairs({ "logout", "menu", "outrest", "lowrest", "filled", "digest", "bag" }) do
	O.SWITCHES[#O.SWITCHES + 1] = { key = "alert_" .. kind, label = Ru.KINDS[kind].label, alert = true,
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
		out[#out + 1] = { a.mine and "mine" or a.id, a.mine and "This account" or ns.AccountName(a.id) }
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
end
function O.LowText(pct) return ("Warn when under %d%% of a full bar is left"):format(pct) end

function O.RefreshAll() for _, p in ipairs(O.pages) do if p:IsShown() then O.Refresh(p) end end end

local function apply(sw, v)
	sw.set(ns.DB(), v and true or false)
	if ns.Broker then ns.Broker.UpdateMinimap() end
	ns.Fire("ROSTER_CHANGED")
	O.RefreshAll()
end

local STYLES = { { "auto", "Auto (ElvUI when loaded)" }, { "default", "Default" }, { "elvui", "ElvUI" } }

-- The page's text roles: gold section headings, cream settings, softer helper lines; nothing under 13 px.
local function words(parent, text, color)
	local t = Wg.Text(parent, "body", nil, 13)
	t:SetText(text)
	St.Color(t, color or St.CREAM)
	return t
end

-- A section: a frame under the last one (so a taller section moves the rest down), with its gold heading.
local function section(p, title, h)
	local s = CreateFrame("Frame", nil, p)
	s:SetSize(O.W, h)
	local prev = p.sections[#p.sections]
	if prev then s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14) else s:SetPoint("TOPLEFT", p, "TOPLEFT", p.x0, p.y0) end
	s.head = words(s, title:upper(), St.GOLD)   -- caps headings (written in title case for tools/apicheck.py)
	s.head:SetPoint("TOPLEFT", 0, 0)
	s.rule = s:CreateTexture(nil, "ARTWORK")
	St.Paint(s.rule, "sw_rule")
	s.rule:SetHeight(1)
	s.rule:SetPoint("LEFT", s.head, "RIGHT", 10, 0)
	s.rule:SetPoint("RIGHT", s, "RIGHT", 0, 0)
	p.sections[#p.sections + 1] = s
	return s
end

local function tipOn(frame, title, line)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(title)
		if line then GameTooltip:AddLine(line, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function check(p, s, sw, x, y)
	local cb = CreateFrame("CheckButton", nil, s, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", x, y)
	St.Check(cb)
	cb.text = words(cb, sw.label)
	cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	cb:SetScript("OnClick", function(self) apply(sw, self:GetChecked()) end)
	if sw.tip then tipOn(cb, sw.label, sw.tip) end
	cb.sw = sw
	p.checks[#p.checks + 1] = cb
	return cb
end

-- Two columns of switches from `list`, from y; returns the y under them.
local function switches(p, s, list, y)
	for i, sw in ipairs(list) do check(p, s, sw, (i - 1) % 2 * 300, y - math.floor((i - 1) / 2) * 26) end
	return y - math.ceil(#list / 2) * 26
end

local function general(p)
	local list = {}
	local elv = St.backends.elvui and St.backends.elvui.Available()
	for _, sw in ipairs(O.SWITCHES) do if not sw.alert and (elv or not sw.elvui) then list[#list + 1] = sw end end
	local s = section(p, "General", 0)
	local y = switches(p, s, list, -22)
	local label = words(s, "Style (after /reload):", St.SECOND)
	label:SetPoint("TOPLEFT", 4, y - 6)
	local x = 4 + label:GetStringWidth() + 12
	p.styleButtons = {}
	for i, st in ipairs(STYLES) do   -- one 20 px gap between choices
		local b = CreateFrame("CheckButton", nil, s, "UIRadioButtonTemplate")
		b:SetPoint("TOPLEFT", x, y - 4)
		local t = words(b, st[2])
		t:SetPoint("LEFT", b, "RIGHT", 4, 0)
		x = x + 20 + t:GetStringWidth() + 20
		b:SetScript("OnClick", function()
			ns.DB().opts.style = st[1]
			for _, o in ipairs(p.styleButtons) do o:SetChecked(o == b) end
		end)
		b.value = st[1]
		p.styleButtons[i] = b
	end
	s:SetHeight(-y + 26)
end

-- Accounts: whose characters show (radio buttons, rebuilt on refresh: accounts come and go with links), and the
-- link field (the same one as the main window's footer).
local function accounts(p)
	local s = section(p, "Accounts", 0)
	p.accSection, p.accButtons = s, {}
	s.show = words(s, "Show:", St.SECOND)
	s.show:SetPoint("TOPLEFT", 4, -26)
	p.link = ns.Link.Create(s, O.W - 8)
end

local function alerts(p)
	local list = {}
	for _, sw in ipairs(O.SWITCHES) do if sw.alert then list[#list + 1] = sw end end
	local s = section(p, "Alerts", 0)
	local y = switches(p, s, list, -22)
	p.lowLabel = words(s, "Low rest warning", St.SECOND)
	p.lowLabel:SetPoint("TOPLEFT", 4, y - 10)
	-- the threshold: a slider, 5 to 50%, after its label, with its ends and the value in words beside it
	local sl = CreateFrame("Slider", nil, s, "BackdropTemplate")
	sl:SetOrientation("HORIZONTAL")
	sl:SetSize(180, 14)
	sl:SetPoint("LEFT", p.lowLabel, "RIGHT", 46, 0)
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
		local e = words(s, v .. "%", St.MUTED)
		e:SetPoint(i == 1 and "RIGHT" or "LEFT", sl, i == 1 and "LEFT" or "RIGHT", i == 1 and -6 or 6, 0)
	end
	sl.value = words(s, "", St.SECOND)
	sl.value:SetPoint("TOPLEFT", p.lowLabel, "BOTTOMLEFT", 0, -8)
	sl:SetScript("OnValueChanged", function(self, v)
		O.SetLow(v)
		O.ShowLow(self)
	end)
	p.low = sl
	s:SetHeight(-y + 54)
end

-- Positions: unlock the notifications to drag them (move mode), lock them again, or put them back.
local function positions(p)
	local s = section(p, "Positions", 72)
	p.lock = s:CreateTexture(nil, "ARTWORK")
	p.lock:SetSize(18, 18)
	p.lock:SetPoint("TOPLEFT", 4, -25)
	p.lock:SetVertexColor(St.GOLD.r, St.GOLD.g, St.GOLD.b, 1)
	p.move = St.MakeButton(s, 170, "Unlock notifications", false, 24)
	p.move:SetPoint("LEFT", p.lock, "RIGHT", 8, 0)
	p.move:SetScript("OnClick", function()
		-- the Blizzard Settings panel covers the screen: it steps aside; our own window stays beside the placeholders
		if ns.Move.Toggle() and p.blizzard and SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
			HideUIPanel(SettingsPanel)
		end
		O.RefreshAll()
	end)
	p.reset = St.MakeButton(s, 130, "Reset positions", false, 24)
	p.reset:SetPoint("LEFT", p.move, "RIGHT", 8, 0)
	p.reset:SetScript("OnClick", function() ns.Move.ResetAll() end)
	p.moveNote = words(s, "", St.SECOND)
	p.moveNote:SetPoint("TOPLEFT", p.lock, "BOTTOMLEFT", 0, -12)
end

local function version()
	local v = U.Call(C_AddOns and C_AddOns.GetAddOnMetadata, addonName, "Version")
	return (type(v) == "string" and not v:find("^@")) and v or "dev"
end

local function about(p)
	local s = section(p, "About", 0)
	s.logo = s:CreateTexture(nil, "ARTWORK")   -- the app icon (media/logo, 128 px), at 56
	s.logo:SetTexture(St.MEDIA .. "logo")
	s.logo:SetSize(56, 56)
	s.logo:SetPoint("TOPLEFT", 4, -26)
	local t = words(s, "", St.SECOND)
	t:SetPoint("TOPLEFT", s.logo, "TOPRIGHT", 14, 0)
	t:SetWidth(O.W - 78)
	t:SetWordWrap(true)
	t:SetText(("Rested Leveling %s  ·  /rlvl help lists every command.\n%s\nApp icon generated for this addon.")
		:format(version(), O.CREDITS))
	p.about = t
	s:SetHeight(26 + math.max(56, t:GetStringHeight()))
end

-- Build the settings into `p` at (x0, y0): its switches (p.checks), style and account choices, the low-rest slider,
-- the Positions controls and About. blizzard: p is the Blizzard Settings canvas, which is shorter than our window:
-- its header carries the About line instead.
function O.Build(p, x0, y0, blizzard)
	St.Ensure()
	p.x0, p.y0, p.blizzard, p.sections, p.checks = x0, y0, blizzard, {}, {}
	general(p)
	accounts(p)
	alerts(p)
	positions(p)
	if not blizzard then about(p) end
	O.pages[#O.pages + 1] = p
	return p
end

-- How tall the built content is, from its top.
function O.Height(p)
	local h = -p.y0
	for i, s in ipairs(p.sections) do h = h + s:GetHeight() + (i > 1 and 14 or 0) end
	return h
end

-- Fill a page from the saved options: switches, style, the account choices, the threshold, move mode.
function O.Refresh(p)
	local d = ns.DB()
	for _, cb in ipairs(p.checks) do cb:SetChecked(cb.sw.get(d) and true or false) end
	for _, b in ipairs(p.styleButtons) do b:SetChecked(b.value == (d.opts.style or "auto")) end
	local current = d.opts.accounts
	if current and not ns.AccountFilter() then current = nil end   -- a filter for a gone account shows all
	local s, choices = p.accSection, O.AccountChoices()
	local x, row = 4 + s.show:GetStringWidth() + 12, 0
	for i, choice in ipairs(choices) do
		local b = p.accButtons[i]
		if not b then
			b = CreateFrame("CheckButton", nil, s, "UIRadioButtonTemplate")
			b.text = words(b, "")
			b.text:SetPoint("LEFT", b, "RIGHT", 4, 0)
			b:SetScript("OnClick", function(self) O.SetAccounts(self.value); O.RefreshAll() end)
			p.accButtons[i] = b
		end
		b.value = choice[1]
		b.text:SetText(choice[2])
		local w = 20 + b.text:GetStringWidth() + 20
		if x + w > O.W and x > 80 then x, row = 4 + s.show:GetStringWidth() + 12, row + 1 end   -- wrap to a new row
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", x, -24 - row * 24)
		x = x + w
		b:SetChecked(choice[1] == current)
		b:Show()
	end
	for i = #choices + 1, #p.accButtons do p.accButtons[i]:Hide() end
	p.link:ClearAllPoints()
	p.link:SetPoint("TOPLEFT", 4, -56 - row * 24)
	ns.Link.Refresh(p.link)
	s:SetHeight(86 + row * 24)
	p.low:SetValue(d.opts.lowPct)
	O.ShowLow(p.low)
	local on = ns.Move.Active()
	p.lock:SetTexture(St.MEDIA .. (on and "unlock" or "lock"))
	p.move:SetLabel(on and "Lock notifications" or "Unlock notifications")
	p.moveNote:SetText(on and "Unlocked: drag the logout warning, the toasts and the Esc menu card, then lock them."
		or "Locked. Unlock to drag the logout warning, the toasts and the Esc menu card.")
end

-- Under plain ElvUI: ElvUI's own backdrop colour; inside a skin's window (checked on show): its warm well.
function O.PaintPanel(p)
	-- skinned: the Settings window itself, or a skin seen on our own windows this session (the page sits beside them)
	local skinned = St.SkinnedWindow(p) or (St.backend and St.backend.skinSeen)
	local fill = not skinned and St.HostFill()
	if fill then p.bg:SetColorTexture(unpack(fill)) else St.Paint(p.bg, "sw_host_well") end
end

-- The page in the Blizzard Settings panel (Esc > Options > AddOns): the same content as our window.
function O.Panel()
	if O.panel then return O.panel end
	St.Ensure()
	local p = CreateFrame("Frame", "RestedLevelingOptions")
	p.name = "Rested Leveling"
	p.bg = p:CreateTexture(nil, "BACKGROUND")   -- our own near-black panel, like the roster's wells, in both themes
	St.Paint(p.bg, "sw_host_well")
	p.bg:SetAllPoints()
	local logo = p:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(St.MEDIA .. "logo")
	logo:SetSize(28, 28)
	logo:SetPoint("TOPLEFT", 16, -12)
	local title = Wg.Text(p, "title", nil, 20)
	title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
	title:SetText("Rested Leveling")
	title:SetTextColor(St.GOLD.r, St.GOLD.g, St.GOLD.b)
	local credit = words(p, ("Version %s  ·  Builds on Rested Watch by doc_biddle (GPL-3.0). Thank you."):format(version()), St.SECOND)
	credit:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -6)
	O.Build(p, 16, -72, true)
	p:SetScript("OnShow", function() O.PaintPanel(p) O.Refresh(p) end)
	O.panel = p
	if Settings and Settings.RegisterCanvasLayoutCategory then
		O.category = Settings.RegisterCanvasLayoutCategory(p, "Rested Leveling")
		Settings.RegisterAddOnCategory(O.category)
		p.category = O.category   -- the renders open the panel at this page (tools/sim/council/07)
	end
	return p
end

-- The cog, the minimap button's right-click and /rlvl options: our own Settings window.
function ns.OpenOptions()
	if ns.Settings then ns.Settings.Show() end
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
		move = { order = 5, type = "execute", name = "Unlock notifications", func = function()
			if ns.Move.Start() then
				local e = ElvUI and ElvUI[1]
				if e and e.Config_CloseWindow then pcall(e.Config_CloseWindow, e) end
			end
		end },
		lowPct = { order = 4, type = "range", name = "Low rest warning (% of a full bar left)", min = ns.LOW_MIN,
			max = ns.LOW_MAX, step = 1, get = function() return ns.DB().opts.lowPct end, set = function(_, v) O.SetLow(v) end },
	}
	for i, sw in ipairs(O.SWITCHES) do
		args[sw.key] = { order = 10 + i, type = "toggle", name = sw.label, desc = sw.tip, width = "full",
			get = function() return sw.get(ns.DB()) and true or false end, set = function(_, v) apply(sw, v) end }
	end
	E.Options.args.RestedLeveling = { order = 100, type = "group", name = "Rested Leveling", args = args }
end

local plugin = LibStub("LibElvUIPlugin-1.0", true)
if plugin and ElvUI then pcall(plugin.RegisterPlugin, plugin, addonName, elvOptions) end

ns.RegisterCallback(O, "LOGIN_DONE", function() O.Panel() end)
ns.RegisterCallback(O, "MOVE_MODE", function() O.RefreshAll() end)
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
	for _, f in ipairs({ ns.Main and ns.Main.frame, ns.Card and ns.Card.frame, ns.Settings and ns.Settings.frame }) do
		if f then St.Scale(f) end
	end
	U.Print("window scale " .. ns.DB().opts.scale .. ".")
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl scale <0.8-1.4> - window size"
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl options - the settings window"
