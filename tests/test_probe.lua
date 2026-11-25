-- /rlvl shotprobe (ILL-1276): a hidden in-game experiment. Takes a screenshot, records its expected file name, and
-- later tries to draw that file through three path forms. Nothing runs unless the command is typed.

local W = dofile("tests/world.lua")

local function world(format)
	local state = { cvars = { screenshotFormat = format }, shots = 0 }
	state.setup = function(game)
		game.Screenshot = function() state.shots = state.shots + 1 end
		game.C_CVar = {
			GetCVar = function(name) return state.cvars[name] end,
			SetCVar = function(name, value) state.cvars[name] = value end,
		}
	end
	local _, h = W.New(state)
	return h, state
end

local function printed(h, needle)
	for _, l in ipairs(h.Printed()) do if l:find(needle, 1, true) then return l end end
end

local cases = {}

function cases.nothing_runs_unless_typed_and_it_is_not_in_help()
	local h, state = world("jpeg")
	h.Slash("RESTEDLEVELING", "help")
	T.ok(not printed(h, "shotprobe"), "not listed in /rlvl help")
	T.eq(state.shots, 0, "no screenshot on load")
	T.ok(W.DB(h).probe == nil, "nothing recorded")
	T.ok(h.Env().RestedLevelingShotProbe == nil, "no frame")
	T.clean(h)
end

function cases.take_records_the_expected_file_name()
	local h, state = world("jpeg")
	h.Slash("RESTEDLEVELING", "shotprobe take")
	T.eq(state.shots, 1, "Screenshot() called once")
	h.Fire("SCREENSHOT_SUCCEEDED")
	local p = W.DB(h).probe
	T.eq(p.result, "ok", "recorded")
	T.eq(p.file, "WoWScrnShot_" .. os.date("%m%d%y_%H%M%S", p.done) .. ".jpg", "the client's pattern, jpeg as .jpg")
	T.ok(#p.names >= 1 and p.names[1] == p.file, "the success second first, then the ones around it")
	T.ok(printed(h, p.file), "printed")
	h.Fire("SCREENSHOT_SUCCEEDED")
	T.eq(p.done, W.DB(h).probe.done, "only its own screenshot: listens once")
	T.clean(h)
end

function cases.take_tga_switches_the_format_and_puts_it_back()
	local h, state = world("jpeg")
	h.Slash("RESTEDLEVELING", "shotprobe take tga")
	T.eq(state.cvars.screenshotFormat, "tga", "tga for this one shot")
	h.Fire("SCREENSHOT_SUCCEEDED")
	T.eq(state.cvars.screenshotFormat, "jpeg", "the player's format restored")
	T.has(W.DB(h).probe.file, ".tga", "a .tga name")
	T.clean(h)
end

function cases.a_failed_screenshot_is_reported_and_restores_the_format()
	local h, state = world("png")
	h.Slash("RESTEDLEVELING", "shotprobe take tga")
	h.Fire("SCREENSHOT_FAILED")
	T.eq(W.DB(h).probe.result, "failed", "failed")
	T.eq(state.cvars.screenshotFormat, "png", "restored")
	T.ok(printed(h, "failed"), "said so")
	T.clean(h)
end

function cases.show_tries_three_path_forms_in_a_test_frame()
	local h, state = world("tga")
	h.Slash("RESTEDLEVELING", "shotprobe show")
	T.ok(printed(h, "nothing recorded yet"), "show before take says what to do")
	h.Slash("RESTEDLEVELING", "shotprobe take")
	h.Fire("SCREENSHOT_SUCCEEDED")
	local file = W.DB(h).probe.file
	h.Slash("RESTEDLEVELING", "shotprobe show")
	local f = h.Env().RestedLevelingShotProbe
	T.ok(f and f:IsShown(), "the test frame")
	T.eq(f.panes[1]:GetWidth(), 256, "256 wide")
	T.eq(f.panes[1]:GetHeight(), 144, "144 high")
	T.eq(f.panes[1].tex:GetTexture(), "Screenshots\\" .. file, "form 1")
	T.eq(f.panes[2].tex:GetTexture(), "..\\Screenshots\\" .. file, "form 2")
	T.eq(f.panes[3].tex:GetTexture(), "Interface\\..\\Screenshots\\" .. file, "form 3")
	W.RunTimers(state)
	T.ok(printed(h, "1. Screenshots\\" .. file), "a line per form, after it had time to load")
	T.ok(printed(h, "loaded="), "with what the client says")
	h.Slash("RESTEDLEVELING", "shotprobe hide")
	T.ok(not f:IsShown(), "hide closes it")
	T.clean(h)
end

return cases
