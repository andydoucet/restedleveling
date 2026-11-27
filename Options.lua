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
		out[#out + 1] = { a.mine and "mine" or a.id, a.mine and "This account" or a.label }
	end
	return out
end

-- The low-rest warning threshold, whole % of a full bar left (5..50).
function O.SetLow(v)
	local n = tonumber(v)
	if not n then return end
	ns.DB().opts.lowPct = U.Clamp(math.floor(n + 0.5), ns.LOW_MIN, ns.LOW_MAX)
end
function O.LowText(pct) return ("Warn when under %d%% of a full bar is left"):format(pct) end

local function apply(sw, v)
	local d = ns.DB()
	sw.set(d, v and true or false)
	if ns.Broker then ns.Broker.UpdateMinimap() end
	ns.Fire("ROSTER_CHANGED")
end

local STYLES = { { "auto", "Auto (ElvUI when loaded)" }, { "default", "Default" }, { "elvui", "ElvUI" } }

function O.Panel()
	if O.panel then return O.panel end
	St.Ensure()
	local p = CreateFrame("Frame", "RestedLevelingOptions")
	p.name = "Rested Leveling"
	local title = Wg.Text(p, "title", nil, 20)
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Rested Leveling")
	title:SetTextColor(St.GOLD.r, St.GOLD.g, St.GOLD.b)
	local sub = Wg.Text(p, "small", nil, 11)
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetText("Never level unrested. /rlvl opens the roster, /rlvl help lists commands.")
	local y = -64
	local styleLabel = Wg.Text(p, "label", nil, 11)
	styleLabel:SetPoint("TOPLEFT", 16, y)
	styleLabel:SetText("STYLE (takes effect after /reload)")
	y = y - 20
	p.styleButtons = {}
	for i, s in ipairs(STYLES) do
		local b = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
		b:SetPoint("TOPLEFT", 16 + (i - 1) * 190, y)
		local t = Wg.Text(b, "body", nil, 12)
		t:SetPoint("LEFT", b, "RIGHT", 4, 0)
		t:SetText(s[2])
		b:SetScript("OnClick", function()
			ns.DB().opts.style = s[1]
			for _, o in ipairs(p.styleButtons) do o:SetChecked(o == b) end
		end)
		b.value = s[1]
		p.styleButtons[i] = b
	end
	y = y - 38
	-- Show accounts: radio buttons, rebuilt on show (accounts come and go with links).
	local accLabel = Wg.Text(p, "label", nil, 11)
	accLabel:SetPoint("TOPLEFT", 16, y)
	accLabel:SetText("SHOW ACCOUNTS")
	p.accButtons = {}
	p.accY = y - 20
	-- Low-rest warning threshold: a slider, 5 to 50%.
	local lowLabel = Wg.Text(p, "label", nil, 11)
	lowLabel:SetPoint("TOPLEFT", 400, y)
	lowLabel:SetText("LOW REST WARNING")
	local sl = CreateFrame("Slider", nil, p, "BackdropTemplate")
	sl:SetOrientation("HORIZONTAL")
	sl:SetSize(200, 14)
	sl:SetPoint("TOPLEFT", 404, y - 26)
	sl:SetMinMaxValues(ns.LOW_MIN, ns.LOW_MAX)
	sl:SetValueStep(1)
	sl:SetObeyStepOnDrag(true)
	St.Slider(sl)
	sl.value = Wg.Text(p, "small", nil, 12)
	sl.value:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", -4, -6)
	St.Color(sl.value, St.SECOND)
	sl:SetScript("OnValueChanged", function(self, v)
		O.SetLow(v)
		self.value:SetText(O.LowText(ns.DB().opts.lowPct))
	end)
	p.low = sl
	y = y - 72
	p.checks = {}
	for _, sw in ipairs(O.SWITCHES) do
		local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
		cb:SetPoint("TOPLEFT", 16, y)
		St.Check(cb)
		local t = Wg.Text(cb, "body", nil, 12)
		t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
		t:SetText(sw.label)
		cb:SetScript("OnClick", function(self) apply(sw, self:GetChecked()) end)
		cb.sw = sw
		p.checks[#p.checks + 1] = cb
		y = y - 28
	end
	local about = Wg.Text(p, "small", nil, 11)
	about:SetPoint("TOPLEFT", 16, y - 16)
	about:SetPoint("RIGHT", -16, 0)
	about:SetWordWrap(true)
	about:SetText("|cffffd100About|r  " .. O.CREDITS .. "\nGPL-3.0. Cross-account sync uses hidden addon messages only, between your "
		.. "own clients on the same realm and faction.")
	p:SetScript("OnShow", function() O.RefreshPanel(p) end)
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
			b.text = Wg.Text(b, "body", nil, 12)
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
	p.low.value:SetText(O.LowText(d.opts.lowPct))
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
