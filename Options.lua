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
	y = y - 34
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
	p:SetScript("OnShow", function()
		local d = ns.DB()
		for _, cb in ipairs(p.checks) do cb:SetChecked(cb.sw.get(d) and true or false) end
		for _, b in ipairs(p.styleButtons) do b:SetChecked(b.value == (d.opts.style or "auto")) end
	end)
	O.panel = p
	if Settings and Settings.RegisterCanvasLayoutCategory then
		O.category = Settings.RegisterCanvasLayoutCategory(p, "Rested Leveling")
		Settings.RegisterAddOnCategory(O.category)
	end
	return p
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
ns.slash.scale = function(arg)
	local n = tonumber(arg)
	if not n then U.Print("usage: /rlvl scale <0.8 to 1.4>  (now " .. (ns.DB().opts.scale or 1) .. ")") return end
	ns.DB().opts.scale = math.max(0.8, math.min(1.4, n))
	for _, f in ipairs({ ns.Main and ns.Main.frame, ns.Card and ns.Card.frame }) do if f then St.Scale(f) end end
	U.Print("window scale " .. ns.DB().opts.scale .. ".")
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl scale <0.8-1.4> - window size"
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl options - the settings page"
