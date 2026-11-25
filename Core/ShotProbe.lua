-- Rested Leveling: /rlvl shotprobe, a hidden experiment for one question (Andy, ILL-1276): can a screenshot the addon
-- takes be drawn again later as a texture, say as a portrait? Nothing here runs unless the command is typed, and it
-- is not listed in /rlvl help. See docs/API.md, "Screenshot probe".
--   /rlvl shotprobe take [tga|png|jpeg]  take a screenshot (optionally in that format, restored after) and record its
--                                        expected file name in RestedLevelingDB.probe
--   /rlvl shotprobe show                 after a full client restart: try to draw that file through three path forms
--                                        in a test frame and print what the client says about each
--   /rlvl shotprobe hide                 close the test frame (or click it)

local _, ns = ...
local U = ns.Util
local P = {}
ns.ShotProbe = P

-- The client writes <install>\_forever_\Screenshots\WoWScrnShot_MMDDYY_HHMMSS.<ext> (local time). The pattern is the
-- client's own (not in the UI source); the probe records every second from the command to the success event.
P.EXT = { jpeg = "jpg", jpg = "jpg", png = "png", tga = "tga" }
P.FORMS = { "Screenshots\\%s", "..\\Screenshots\\%s", "Interface\\..\\Screenshots\\%s" }
P.W, P.H = 256, 144

function P.FileName(ts, format)
	return ("WoWScrnShot_%s.%s"):format(date("%m%d%y_%H%M%S", ts), P.EXT[(format or ""):lower()] or "jpg")
end

local function getFormat() return C_CVar and U.Call(C_CVar.GetCVar, "screenshotFormat") end

-- Every name the screenshot could have: the second of the success event first, then the seconds around it.
function P.Candidates(p)
	local out, seen = {}, {}
	local function add(ts)
		local n = P.FileName(ts, p.format)
		if not seen[n] then seen[n], out[#out + 1] = true, n end
	end
	add(p.done or p.asked)
	for ts = (p.asked or p.done) - 1, (p.done or p.asked) + 1 do add(ts) end
	return out
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(self, event)
	self:UnregisterAllEvents()
	local p = ns.DB().probe
	if not p then return end
	if p.restore then U.Call(C_CVar.SetCVar, "screenshotFormat", p.restore); p.restore = nil end
	if event == "SCREENSHOT_FAILED" then
		p.result = "failed"
		U.Print("shotprobe: the client says the screenshot failed.")
		return
	end
	p.done, p.result = time(), "ok"
	p.file, p.names = P.FileName(p.done, p.format), P.Candidates(p)
	U.Print(("shotprobe: saved, expected as _forever_\\Screenshots\\%s (format %s). Check the folder, then quit the game "
		.. "fully, start it again and type /rlvl shotprobe show."):format(p.file, p.format))
end)

function P.Take(arg)
	local want = P.EXT[(arg or ""):lower()] and (arg:lower() == "jpg" and "jpeg" or arg:lower()) or nil
	local format = getFormat() or "jpeg"
	local p = { asked = time(), format = format }
	if want and want ~= format and C_CVar and C_CVar.SetCVar then   -- the client may only load .tga back: try it
		p.restore, p.format = format, want
		U.Call(C_CVar.SetCVar, "screenshotFormat", want)
	end
	ns.DB().probe = p
	events:RegisterEvent("SCREENSHOT_SUCCEEDED")
	events:RegisterEvent("SCREENSHOT_FAILED")
	U.Print(("shotprobe: taking a screenshot (%s)..."):format(p.format))
	Screenshot()
end

local function pane(parent, i)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(P.W, P.H)
	f:SetPoint("TOPLEFT", (i - 1) * (P.W + 8), 0)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints()
	f.label = ns.Widgets.Text(f, "small", nil, 11)
	f.label:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
	return f
end

local function testFrame()
	if P.frame then return P.frame end
	local f = CreateFrame("Frame", "RestedLevelingShotProbe", UIParent)
	f:SetSize(#P.FORMS * (P.W + 8) - 8, P.H + 18)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	f:SetScript("OnMouseUp", function(self) self:Hide() end)
	f.panes = {}
	for i = 1, #P.FORMS do f.panes[i] = pane(f, i) end
	P.frame = f
	return f
end

-- What the client says about one texture path: SetTexture's result, the file ID and path it took, and (a moment
-- later, when it has had time to load) IsObjectLoaded.
local function try(tex, path)
	local ok = U.Call(tex.SetTexture, tex, path)
	return { path = path, ok = ok, id = U.Call(tex.GetTextureFileID, tex), file = U.Call(tex.GetTextureFilePath, tex) }
end

function P.Show()
	local p = ns.DB().probe
	if not (p and p.file) then U.Print("shotprobe: nothing recorded yet. Type /rlvl shotprobe take first.") return end
	local f = testFrame()
	f:Show()
	local results = {}
	for i, form in ipairs(P.FORMS) do
		local r = try(f.panes[i].tex, form:format(p.file))
		f.panes[i].label:SetText(i .. ": " .. r.path)
		results[i] = r
	end
	p.shown = results
	U.Print(("shotprobe: %s (format %s). Three panes, one per path form; an image means it loaded."):format(p.file, p.format))
	C_Timer.After(1, function()
		for i, r in ipairs(results) do
			r.loaded = U.Call(f.panes[i].tex.IsObjectLoaded, f.panes[i].tex)
			print(("  %d. %s  SetTexture=%s  fileID=%s  path=%s  loaded=%s"):format(i, r.path, tostring(r.ok),
				tostring(r.id), tostring(r.file), tostring(r.loaded)))
		end
		print("  Other names it could have, if the folder shows a different second: " .. table.concat(p.names or {}, ", "))
	end)
end

ns.slash.shotprobe = function(arg)
	local cmd, rest = (arg or ""):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "take" then P.Take(rest)
	elseif cmd == "show" then P.Show()
	elseif cmd == "hide" then if P.frame then P.frame:Hide() end
	else U.Print("shotprobe: /rlvl shotprobe take [tga], then after a restart /rlvl shotprobe show") end
end
