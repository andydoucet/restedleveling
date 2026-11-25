-- Rested Leveling: a character's saved look (ILL-1279), the data half. "Save my look" (UI/SaveLook.lua) takes a
-- screenshot of the logged-in character's model on a plain backdrop; this file names that screenshot, works out
-- where the model sat in it, and checks a look before anything draws it or sends it to the other account.
--
-- A look: { file = "WoWScrnShot_MMDDYY_HHMMSS.tga", l, r, t, b = the model's square as texcoords of the whole
-- screenshot, at = when the screenshot was written, asked = when it was asked for }. Pure functions, tested headless.

local _, ns = ...
local L = {}
ns.LookData = L

-- The client writes <install>\_forever_\Screenshots\WoWScrnShot_MMDDYY_HHMMSS.tga (local time). In game (ILL-1276
-- probe) the second of SCREENSHOT_SUCCEEDED named the file, and only the "Screenshots\" form loaded it.
L.DIR = "Screenshots\\"
L.PATTERN = "^WoWScrnShot_%d%d%d%d%d%d_%d%d%d%d%d%d%.tga$"   -- nothing else may reach SetTexture (no "..\")
L.PX = 512   -- the model's square on screen, in physical pixels (at most 80% of the screen height)

function L.FileName(ts) return ("WoWScrnShot_%s.tga"):format(date("%m%d%y_%H%M%S", ts)) end

-- Every name the screenshot could have, best first: the saved name, then each second from just before it was asked
-- for to just after it was written (the clock may tick between the two). Worked out from the two saved times, so
-- the list travels with the look without sending every name.
function L.Names(look)
	local out, seen = {}, {}
	local function add(n) if n and not seen[n] then seen[n], out[#out + 1] = true, n end end
	add(look.file)
	local from, to = look.asked or look.at, look.at or look.asked
	if from and to and to >= from and to - from <= 10 then
		for ts = from - 1, to + 1 do add(L.FileName(ts)) end
	end
	return out
end

local function frac(v) return type(v) == "number" and v == v and v >= 0 and v <= 1 end

-- The look if it is safe to draw, else nil: a screenshot name and nothing else, and a real square inside the image.
function L.Valid(look)
	if type(look) ~= "table" or type(look.file) ~= "string" or not look.file:match(L.PATTERN) then return nil end
	if not (frac(look.l) and frac(look.r) and frac(look.t) and frac(look.b)) then return nil end
	if look.l >= look.r or look.t >= look.b then return nil end
	if look.at ~= nil and type(look.at) ~= "number" then return nil end
	if look.asked ~= nil and type(look.asked) ~= "number" then return nil end
	return look
end

local function round(v) return math.floor(v * 10000 + 0.5) / 10000 end

-- The model's rect as texcoords of the full screenshot. Both rects in the same units (the capture stage covers the
-- screen); y grows upwards on screen and downwards in the image.
function L.TexCoords(screen, model)
	local w, h = screen.right - screen.left, screen.top - screen.bottom
	return round((model.left - screen.left) / w), round((model.right - screen.left) / w),
		round((screen.top - model.top) / h), round((screen.top - model.bottom) / h)
end

-- The model's side in the stage's units: L.PX physical pixels (or 80% of a smaller screen), so the crop has the same
-- resolution whatever the UI scale. physH: GetPhysicalScreenSize's height; unitsH: the stage's own height.
function L.ModelSize(physH, unitsH)
	if not physH or physH <= 0 then return unitsH * 0.6 end
	local px = math.min(L.PX, math.floor(physH * 0.8))
	return px * unitsH / physH
end

-- For the sync wire: four short fields instead of a table (Sync/Codec.lua).
function L.Pack(c)
	local look = L.Valid(c.look)
	c.look = nil
	if not look then return c end
	c.lookFile, c.lookAt, c.lookAsked = look.file, look.at, look.asked
	c.lookBox = ("%.4f,%.4f,%.4f,%.4f"):format(look.l, look.r, look.t, look.b)
	return c
end

function L.Unpack(c)
	local file, box, at, asked = c.lookFile, c.lookBox, c.lookAt, c.lookAsked
	c.lookFile, c.lookBox, c.lookAt, c.lookAsked = nil, nil, nil, nil
	if not file or type(box) ~= "string" then return c end
	local l, r, t, b = box:match("^([%d.]+),([%d.]+),([%d.]+),([%d.]+)$")
	c.look = L.Valid({ file = file, l = tonumber(l), r = tonumber(r), t = tonumber(t), b = tonumber(b), at = at, asked = asked })
	return c
end

return L
