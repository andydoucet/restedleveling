-- v1.1 options (ILL-1272): the account filter and the low-rest threshold, their migration from v1 saved data, and
-- where they apply (hero, roster, compact, datatext; the low-rest chat line).

local W = dofile("tests/world.lua")
local H, D = 3600, 86400

local function alt(full, levels, account, resting)
	return { full = full, class = "MAGE", race = "Scourge", sex = 3, level = 20, xpMax = 10000,
		rested = math.floor(levels * 10000), resting = resting ~= false, restKind = "inn", t = W.NOW - 2 * D, account = account }
end

local function world(opts)
	local saved = { account = "aaaaaa", accountLabels = { bbbbbb = "#3" }, opts = opts, chars = {
		["N:Le Nette@?"] = alt("Le Nette", 1.5, "aaaaaa"),
		["N:Le Dette@?"] = alt("Le Dette", 0.5, nil),           -- an old record without an account: ours
		["N:Le Bankken@?"] = alt("Le Bankken", 1.2, "bbbbbb"),   -- synced from the other account
	} }
	local state = { saved = saved, setup = function(game)
		game.UISpecialFrames = {}
		game.GameTooltip = game.CreateFrame("GameTooltip", "GameTooltip")
		game.GameTooltip.SetOwner, game.GameTooltip.AddLine = function() end, function() end
		game.RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
		game.SetPortraitTexture = function() end
	end }
	local _, h = W.New(state)
	return h, state
end

local function names(rows)
	local out = {}
	for _, r in ipairs(rows) do out[#out + 1] = r.c.full end
	table.sort(out)
	return table.concat(out, ",")
end

local cases = {}

function cases.v1_saved_data_migrates_with_defaults()
	local h = world({ style = "auto", lowPct = "abc", accounts = "not-an-id" })
	local d = W.DB(h)
	T.eq(d.version, 2, "saved data is version 2")
	T.eq(d.opts.lowPct, 10, "a damaged threshold falls back to 10%")
	T.eq(d.opts.accounts, nil, "a damaged filter shows all")
	local h2 = world({ lowPct = 80, accounts = "bbbbbb" })
	T.eq(W.DB(h2).opts.lowPct, 50, "a threshold out of range is clamped")
	T.eq(W.DB(h2).opts.accounts, "bbbbbb", "a valid filter is kept")
	local h3 = world(nil)   -- v1 file without opts at all
	T.eq(W.DB(h3).opts.lowPct, 10, "default 10%")
	T.clean(h); T.clean(h2); T.clean(h3)
end

function cases.the_filter_drops_hidden_accounts_everywhere()
	local h, state = world()
	local ns = state.ns
	T.eq(names(ns.Rows()), "Le Bankken,Le Dette,Le Nette", "all accounts by default")
	T.eq(#ns.Accounts(), 2, "two accounts in the roster")
	ns.Options.SetAccounts("mine")
	T.eq(names(ns.Rows()), "Le Dette,Le Nette", "this account: records without an account count as ours")
	T.has(ns.Broker.Text(ns.Rows({ hideGrey = true })), "1 full", "the datatext counts only the shown account")
	ns.Options.SetAccounts("bbbbbb")
	T.eq(names(ns.Rows()), "Le Bankken", "the other account only")
	T.eq(ns.AccountFilterLabel(), "#3", "labelled with the peer's label")
	W.DB(h).chars["N:Le Bankken@?"] = nil   -- that account's characters are gone (pruned)
	T.eq(names(ns.Rows()), "Le Dette,Le Nette", "a filter for an account with no characters shows all")
	T.clean(h)
end

function cases.footer_control_cycles_the_accounts()
	local h, state = world()
	local ns = state.ns
	h.Slash("RESTEDLEVELING", "")
	local f = ns.Main.frame
	T.ok(f and f:IsShown(), "main window open")
	T.ok(f.acctBtn:IsShown(), "shown when more than one account is in the roster")
	local seen = {}
	for i = 1, 3 do
		FakeWoW.RunScript(f.acctBtn, "OnClick")
		seen[i] = ns.AccountFilterLabel()
	end
	T.eq(table.concat(seen, "|"), "This account|#3|All accounts", "all -> this account -> #3 -> all")
	W.DB(h).chars["N:Le Bankken@?"] = nil
	ns.Main.Refresh()
	T.ok(not f.acctBtn:IsShown(), "hidden with one account")
	T.clean(h)
end

function cases.options_set_the_filter_and_the_threshold()
	local h, state = world()
	local panel = h.Env().RestedLevelingOptions
	FakeWoW.RunScript(panel, "OnShow")
	local mine
	for _, b in ipairs(panel.accButtons) do if b.value == "mine" then mine = b end end
	T.ok(mine, "a 'This account' choice")
	FakeWoW.RunScript(mine, "OnClick")
	T.eq(W.DB(h).opts.accounts, "mine", "saved")
	FakeWoW.RunScript(panel.low, "OnValueChanged", 3)
	T.eq(W.DB(h).opts.lowPct, 5, "the slider never goes under 5%")
	FakeWoW.RunScript(panel.low, "OnValueChanged", 24.6)
	T.eq(W.DB(h).opts.lowPct, 25, "whole percent")
	h.Slash("RESTEDLEVELING", "low 99")
	T.eq(W.DB(h).opts.lowPct, 50, "/rlvl low clamps to 50%")
	h.Slash("RESTEDLEVELING", "accounts all")
	T.eq(W.DB(h).opts.accounts, nil, "/rlvl accounts all")
	T.eq(#state.ns.Rows(), 3, "everyone back")
	T.clean(h)
end

function cases.low_rest_warning_uses_the_threshold()
	local state = { rested = 6000, xpMax = 10000, saved = { opts = { lowPct = 30 } } }
	local _, h = W.New(state)
	local A, Ru = state.ns.Alerts, state.ns.Rules
	T.eq(Ru.LowFraction(W.DB(h)), 0.3, "30% from the option")
	T.ok(Ru.WentLow(0.5, 0.4, 1.5, 0.3), "crossing 30% of a 1.5-level cap (0.45) warns")
	T.ok(not Ru.WentLow(0.5, 0.4, 1.5), "the default 10% would not")
	h.ClearPrinted()
	A.OnSessionChanged(5000)
	A.OnSessionChanged(4000)   -- 0.5 -> 0.4 levels, under 0.45
	local out = table.concat(h.Printed(), "\n")
	T.has(out, "running low", "the chat line fires")
	T.has(out, "under 30% of full", "and says the threshold")
	T.clean(h)
end

return cases
