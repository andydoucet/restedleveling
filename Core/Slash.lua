-- Rested Leveling: /rlvl and /restedleveling. Other modules add subcommands to ns.slash.

local _, ns = ...
local U, M = ns.Util, ns.Model

ns.slash = ns.slash or {}
ns.slashHelp = ns.slashHelp or {}

local function findChars(name)
	local d, out = ns.DB(), {}
	name = (name or ""):lower()
	for key, c in pairs(d.chars) do
		if (c.full and c.full:lower() == name) or (c.first and c.first:lower() == name) then out[#out + 1] = key end
	end
	return out
end

-- The roster as chat lines (also the fallback when the window can't open).
function ns.PrintRoster()
	local now = time()
	local rows = ns.Rows({ hideGrey = true })
	if #rows == 0 then
		U.Print("no other characters yet. Log each one in and out once (or link your other account: /rlvl link <Name>).")
		return
	end
	U.Print("play next, top first:")
	for i, r in ipairs(rows) do
		local p = r.p
		local status = r.state == M.FULL and ("full for " .. U.Duration(now - p.fullSince))
			or ("%d%%, full in %s"):format(math.floor(p.pct * 100), U.Duration(p.left))
		print(("  %d. %s %d: %s (%.1f lvl)%s"):format(i, r.c.full or "?", r.c.level or 0, status, p.levels,
			r.c.resting and "" or " |cffff6040outside|r"))
	end
end

ns.slash.list = ns.PrintRoster
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl list - roster in chat"

ns.slash.target = function(arg)
	local d = ns.DB()
	local n = tonumber(arg)
	d.opts.target = (n and n > 1) and math.floor(n) or nil
	U.Print(d.opts.target and ("characters at level " .. d.opts.target .. "+ drop to the bottom.") or "no target level.")
	ns.Fire("ROSTER_CHANGED")
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl target <level|off> - characters at or above it drop to the bottom"

local function setHidden(arg, on)
	local d = ns.DB()
	local keys = findChars(arg)
	if #keys == 0 then U.Print("no character called " .. tostring(arg) .. ".") return end
	for _, k in ipairs(keys) do d.hidden[k] = on or nil end
	U.Print((arg or "?") .. (on and " hidden." or " shown."))
	ns.Fire("ROSTER_CHANGED")
end
ns.slash.hide = function(arg) setHidden(arg, true) end
ns.slash.show = function(arg) setHidden(arg, false) end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl hide|show <name> - hide a character (it stays, dimmed, at the bottom)"

ns.slash.ranks = function(arg)
	local c, n = ns.Me(), tonumber(arg)
	if not c or not n then return end
	c.ranks, c.rankRead = U.Clamp(math.floor(n), 0, M.MAX_RANK), false
	U.Print(("Well Rested on %s set to rank %d."):format(c.full or "?", c.ranks))
	ns.Fire("ROSTER_CHANGED")
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl ranks <0-5> - Well Rested rank, only if it can't be read"

ns.slash.account = function(arg)
	local d = ns.DB()
	arg = (arg or ""):match("^%s*(.-)%s*$")
	if arg == "" then U.Print("this account is " .. ns.AccountLabel(d.account) .. ".") return end
	d.accountLabels = d.accountLabels or {}
	d.accountLabels[d.account] = arg:sub(1, 12)
	U.Print("this account is now labelled " .. d.accountLabels[d.account] .. ".")
	ns.Fire("ROSTER_CHANGED")
end
ns.slashHelp[#ns.slashHelp + 1] = "/rlvl account <label> - name this WoW account (e.g. #2)"

local function run(msg)
	local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "help" or cmd == "?" then
		U.Print("commands:")
		print("  /rlvl - open the roster")
		for _, line in ipairs(ns.slashHelp) do print("  " .. line) end
		return
	end
	local fn = ns.slash[cmd]
	if fn then fn(arg) return end
	if cmd == "" and ns.ToggleMain then ns.ToggleMain() return end
	ns.PrintRoster()
end

SLASH_RESTEDLEVELING1 = "/rlvl"
SLASH_RESTEDLEVELING2 = "/restedleveling"
SlashCmdList.RESTEDLEVELING = run
ns.RunSlash = run
