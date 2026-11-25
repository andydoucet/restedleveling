#!/usr/bin/env python3
"""Checks every WoW API name Rested Leveling uses against two copies of Blizzard's own UI source, and writes
docs/API.md (the verified/unverified list) and tests/client-api.lua (the names the fake client may define).

Sources (read-only, not committed):
  FOREVER  the installed Forever client's UI, as cached by wow-ui-sim   (~/.cache/wow-ui-sim/blizzard-ui/wowforever)
  CLASSIC  Gethe/wow-ui-source, branch classic_era                       (~/.cache/rested-leveling/wow-ui-source-classic_era)

A name counts as "doc" when Blizzard_APIDocumentationGenerated declares it (function, event or widget method),
"used" when Blizzard's own Lua/XML calls it, and "-" when neither. Names the addon only touches after checking they
exist are listed in FALLBACKS. Usage: python3 tools/apicheck.py [--check]  (--check: exit 1 if API.md is stale).
"""
import os, re, subprocess, sys

ROOT = os.environ.get("RL_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOREVER = os.environ.get("RL_FOREVER_UI", os.path.expanduser("~/.cache/wow-ui-sim/blizzard-ui/wowforever"))
CLASSIC = os.environ.get("RL_CLASSIC_UI", os.path.expanduser("~/.cache/rested-leveling/wow-ui-source-classic_era/Interface"))
LUACHECK = os.environ.get("LUACHECK", os.path.expanduser("~/.luarocks/bin/luacheck"))

# Blizzard windows "Save my look" refuses to close (UI/SaveLook.lua): frames, each checked before use.
SAVE_BLOCKERS = ["MerchantFrame", "BankFrame", "MailFrame", "GossipFrame", "QuestFrame", "LootFrame", "TradeFrame",
                 "ItemTextFrame", "TaxiFrame", "ClassTrainerFrame", "AuctionHouseFrame", "PetitionFrame",
                 "GuildRegistrarFrame", "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4"]
# Names used only after an existence check (`if X then`, `X and X.Fn`), so absence in a client is safe.
FALLBACKS = {
    "UnitNameUnmodified", "GetMaxLevelForPlayerExpansion", "C_Traits", "C_UnitAuras", "C_Spell",
    "ElvUI", "LibStub", "issecretvalue", "Settings", "BackdropTemplateMixin", "C_Texture",
    "C_ChatInfo.AreOutgoingAddonChatMessagesRestricted", "MenuUtil", "GetPhysicalScreenSize",
} | set(SAVE_BLOCKERS)
# Globals that are tables (frames, constants) rather than functions.
TABLES = {"SlashCmdList", "UIParent", "Minimap", "GameMenuFrame", "GameTooltip", "Settings", "SOUNDKIT",
          "RAID_CLASS_COLORS", "CLASS_ICON_TCOORDS", "ElvUI", "BackdropTemplateMixin", "ChatFrame1", "Enum",
          "DEFAULT_CHAT_FRAME", "UISpecialFrames", "MenuUtil"} | set(SAVE_BLOCKERS)
# Real client globals the fake client (tests/fakewow.lua) always defines.
HARNESS = {"CreateFrame", "UIParent", "WorldFrame", "Minimap", "SlashCmdList", "hooksecurefunc", "issecretvalue", "GetTime",
           "time", "date", "strsplit", "wipe", "tinsert", "tremove", "format", "strmatch", "strfind", "debugstack",
           "geterrorhandler", "seterrorhandler", "securecallfunction"}
# Globals the addon defines itself.
OWN = {"RestedLevelingDB", "SLASH_RESTEDLEVELING1", "SLASH_RESTEDLEVELING2", "RestedLevelingMain"}
LUA51 = set("""assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile loadstring module next pairs
pcall print rawequal rawget rawset require select setfenv setmetatable tonumber tostring type unpack xpcall
coroutine debug io math os package string table _G _VERSION newproxy gcinfo""".split())


# Research notes kept with the verification table (ILL-1274): why offline characters show a crest, not a face.
OFFLINE_APPEARANCE = """## Offline appearance

Andy saw Le Jette (red pigtails) drawn as a stock blue-haired gnome: v1 used `TemporaryPortrait-<sex>-<race>` art for
characters that are not logged in. ILL-1274 looked for any way to draw an offline character's real look on Forever.
Checked against the Forever UI source (Blizzard_APIDocumentationGenerated and Blizzard's own FrameXML callers):

| API | Forever | Can it show an offline character's real look? |
|---|---|---|
| `C_PlayerInfo.GetDisplayID`, `GetNativeDisplayID` | doc | No. The logged-in player's creature display ID (race/sex model). FrameXML uses it only for shapeshift forms, together with the active player's customizations. Hair, face and skin are not in it. |
| `ModelSceneActor:SetModelByCreatureDisplayID(id, useActivePlayerCustomizations)` | doc | No. Customizations can only come from the active player: it would put Le Nette's hair on Le Jette. |
| `PlayerModel:SetDisplayInfo(displayID)` | doc | No. Draws the display with default choices: another stock face. |
| `ModelSceneActor:SetPlayerModelFromGlues(characterIndex, ...)` | doc | No. FrameXML calls it only when `C_Glue.IsOnGlueScreen()` (character select, shop); addons never run there. |
| `ModelSceneActor:SetFrontEndLobbyModelFromDefaultCharacterDisplay` | doc | No. Glue lobby only (GluePartyPoseUI, AccountStore). |
| `C_BarberShop.GetAvailableCustomizations`, `GetCurrentCharacterData`, `SetCustomizationChoice` | doc | No. The logged-in character's barber-shop preview only; nothing applies saved choices to another model. |
| `C_PlayerInfo.GetPlayerCharacterData` | doc | No. Name, file name, sex, alternate form and an icon atlas; no customization choices. |
| `UnitCreatureDisplayID` | - | Not in the Forever client. |
| `PlayerModel:SetCustomRace` | - | Not in the Forever client (v1 guarded it; it would also keep the active player's look). Removed. |

Result: nothing on Forever reproduces another character's appearance while it is offline. So the logged-in character
keeps its real portrait (`SetPortraitTexture(tex, "player")`) and the 3D stage (`PlayerModel:SetUnit("player")`);
every other character shows its class crest (`classicon-<class>`) with its race emblem as a small badge
(`raceicon128-<race>-<sex>`, named as Blizzard's `GetRaceAtlas` in SharedUtils.lua names it, used only when
`C_Texture.GetAtlasInfo` finds it), and the card says "Last seen as a level 46 Gnome Warrior. Log in to see them."
Verified in game: not yet. The race atlas is verified only through the simulator, which reads the installed client's
atlas data.
"""

SAVED_LOOK = """## Saved looks (screenshot portraits)

ILL-1276 asked, with a hidden `/rlvl shotprobe` (now removed): can a screenshot the addon takes be drawn again later as
a texture? Andy ran it on Forever (`refs/ingame/andy_probe_take.png`, `andy_probe_show.png`): after a full client
restart, `Screenshots\\WoWScrnShot_112526_051821.tga` loaded as a texture at full resolution, named from the second of
`SCREENSHOT_SUCCEEDED`. The forms `..\\Screenshots\\<file>` and `Interface\\..\\Screenshots\\<file>` drew nothing.
So "Save my look" (ILL-1279) shoots the logged-in character as `.tga` and other characters' portraits draw that
file through `Screenshots\\<file>` (about 8 MB per save; old screenshots in `_forever_\\Screenshots` can be
deleted). Checked against the Forever UI source:

| API | Forever | Use and guard |
|---|---|---|
| `Screenshot()` | doc | ClientDocumentation.lua; no restriction flags. The SCREENSHOT binding calls it. |
| `SCREENSHOT_SUCCEEDED`, `SCREENSHOT_FAILED` | doc | VideoDocumentation.lua; no payload. Only counted after our own `Screenshot()` call. |
| `C_CVar.GetCVar("screenshotFormat")`, `C_CVar.SetCVar` | doc | Set to `tga` for the one shot, the player's format put back on every way out. |
| `UIParent:Hide()`, `UIParent:Show()` | used | MovieFrame.lua does the same. UIParent holds secure frames, so it is only hidden out of combat (`InCombatLockdown`, doc), and `PLAYER_REGEN_DISABLED` (fires before the lockdown starts) ends the capture and shows it again. If combat came first anyway, it is shown on `PLAYER_REGEN_ENABLED`. Alt-Z itself calls `SetUIVisibility`, which also hides nameplates; our opaque stage covers those. |
| `CreateFrame("Frame", name, WorldFrame)` | used | The stage is parented to WorldFrame, not UIParent, so it stays up while UIParent is hidden; `SetAllPoints(WorldFrame)`, strata FULLSCREEN_DIALOG, `EnableKeyboard` for Esc, `SetPropagateKeyboardInput` (doc, out of combat) so every other key still reaches the game. |
| `MerchantFrame`, `BankFrame`, `MailFrame`, `GossipFrame`, `QuestFrame`, `LootFrame`, `TradeFrame`, `ItemTextFrame`, `TaxiFrame`, `ClassTrainerFrame`, `AuctionHouseFrame`, `PetitionFrame`, `GuildRegistrarFrame`, `StaticPopup1`-`4` | used | Hiding UIParent runs their OnHide, which ends the NPC interaction (`CloseMerchant`, `C_Bank.CloseBankFrame`, `CloseMail`, `C_GossipInfo.CloseGossip`, `CloseQuest`, `CloseLoot`, `CloseTrade`, ...) or answers a popup (PARTY_INVITE's OnHide calls `DeclineGroup`). Save is refused while one is shown ("Close the merchant window first."). Each guarded: the trainer and auction house load on demand. |
| `GetPhysicalScreenSize()` | doc | ScreenDocumentation.lua; guarded. The model square is 512 physical px (at most 80% of the screen height). |
| `DressUpModel:SetUnit("player")`, `UndressSlot(16/17/18)` | doc | FrameAPICharacterModelBase / FrameAPIDressUpModel. INVSLOT_MAINHAND/OFFHAND/RANGED are 16/17/18 (Constants.lua). Each call guarded. |
| `SetPortraitZoom`, `SetRotation`, `SetAnimation`, `ClearModel` | doc | Portrait framing (QuestNPCModel uses zoom 0.6). Guarded. Framing verified in game: not yet. |
| `OnModelLoaded` script | used | Blizzard_Wardrobe.xml. Shoots 0.25 s after it, or after 1 s if it never fires; gives up after 6 s. |
| `Texture:SetTexture(path)`, `SetTexCoord` | doc | Returns `success`. Each candidate name is tried until one returns true (nil, false or an error moves on); the crop goes over the class crest, so a file that does not load leaves the crest. |
| `MenuUtil.CreateContextMenu` | used | Blizzard_Menu (AddonList uses it); guarded. Without it a right-click opens the card. |

Verified in game: the file name and the `Screenshots\\` path form (probe). Not yet: the capture itself, the model
framing, whether a new file loads in the same session (the card says it shows after a restart), and whether
`SetTexture` returns true for a loose screenshot that loads (only an explicit true draws the look; otherwise the crest
shows).
"""


def addon_files():
    toc = open(os.path.join(ROOT, "RestedLeveling.toc")).read().splitlines()
    out = []
    for line in toc:
        line = line.strip()
        if not line or line.startswith("#") or line.lower().startswith("libs"):
            continue
        path = os.path.join(ROOT, line.replace("\\", "/"))
        if path.endswith(".lua") and os.path.exists(path):
            out.append(path)
    return out


def used_names(files):
    """Globals (via luacheck) plus Namespace.Fn pairs, widget methods and event names (via regex)."""
    globs = set()
    res = subprocess.run([LUACHECK, "--no-config", "--std", "lua51", "--formatter", "plain", "--codes", *files],
                         capture_output=True, text=True)
    for line in res.stdout.splitlines():
        m = re.search(r"\((W11[123])\) (?:accessing|setting|mutating) (?:undefined|non-standard global) variable '?(\w+)'?", line)
        if m:
            globs.add(m.group(2))
    src = "\n".join(open(f).read() for f in files)
    fields = set(re.findall(r"\b((?:C_[A-Za-z]+|Settings|Enum))\.([A-Za-z_]+)", src))
    libsrc = "\n".join(open(os.path.join(dp, n)).read() for dp, _, ns_ in os.walk(os.path.join(ROOT, "Libs"))
                       for n in ns_ if n.endswith(".lua"))
    methods = (set(re.findall(r":([A-Z][A-Za-z]+)\(", src + libsrc)) | set(re.findall(r"pcall\(\w+\.([A-Z]\w+),", src))
               | set(re.findall(r"U\.Call\([\w.]+\.([A-Z]\w+), ", src)))   # guarded method calls: U.Call(obj.Method, obj, ...)
    strings = set(re.findall(r'"([A-Z][A-Z_]{5,})"', src))
    return globs - LUA51, fields, methods, strings


class Source:
    def __init__(self, root):
        self.root = root
        self.ok = os.path.isdir(root)
        self.funcs, self.events, self.methods, self.ns = set(), set(), set(), {}
        self.text = ""
        if not self.ok:
            return
        chunks = []
        for dirpath, _, names in os.walk(root):
            for n in names:
                if not n.endswith((".lua", ".xml")):
                    continue
                p = os.path.join(dirpath, n)
                try:
                    t = open(p, encoding="utf-8", errors="replace").read()
                except OSError:
                    continue
                if "APIDocumentationGenerated" in dirpath:
                    self.parse_doc(t)
                else:
                    chunks.append(t)
        self.text = "\n".join(chunks)

    def parse_doc(self, t):
        ns = re.search(r'^\tNamespace = "(\w+)"', t, re.M)
        is_obj = re.search(r'^\tType = "ScriptObject"', t, re.M)
        fnames = re.findall(r'Name = "(\w+)",\s*\n\s*Type = "Function"', t)
        for ev in re.findall(r'LiteralName = "(\w+)"', t):
            self.events.add(ev)
        if is_obj:
            self.methods.update(fnames)
        elif ns:
            self.ns.setdefault(ns.group(1), set()).update(fnames)
        else:
            self.funcs.update(fnames)

    def glob(self, name):
        if name in self.funcs or name in self.ns:
            return "doc"
        if re.search(r"(?<![\w.:])" + re.escape(name) + r"\b", self.text):
            return "used"
        return "-"

    def field(self, ns, fn):
        if fn in self.ns.get(ns, ()):
            return "doc"
        if re.search(re.escape(ns) + r"\." + re.escape(fn) + r"\b", self.text):
            return "used"
        return "-"

    def method(self, name):
        if name in self.methods:
            return "doc"
        return "used" if re.search(r":" + re.escape(name) + r"\(", self.text) else "-"

    def event(self, name):
        if name in self.events:
            return "doc"
        return "used" if ('"' + name + '"') in self.text else "-"


def main():
    check = "--check" in sys.argv
    files = addon_files()
    globs, fields, methods, strings = used_names(files)
    fv, cl = Source(FOREVER), Source(CLASSIC)
    if not fv.ok:
        sys.exit("Forever UI cache missing: " + FOREVER)
    rows, client_g, client_ns = [], {}, {}
    for g in sorted((globs | HARNESS) - OWN):
        a, b = fv.glob(g), cl.glob(g)
        rows.append(("global" if g in globs else "harness", g, a, b, g in FALLBACKS))
        if a != "-":
            client_g[g] = "t" if (g in fv.ns or g.startswith("C_") or g in TABLES or g.isupper()) else "f"
    for ns, fn in sorted(fields):
        if ns == "Enum":
            continue
        a, b = fv.field(ns, fn), cl.field(ns, fn)
        rows.append(("field", ns + "." + fn, a, b, (ns + "." + fn) in FALLBACKS or ns in FALLBACKS))
        if a != "-":
            client_ns.setdefault(ns, set()).add(fn)
            client_g[ns] = "t"
    widget = [m for m in sorted(methods) if fv.method(m) == "doc" or m in FALLBACKS]
    for m in widget:
        rows.append(("method", m, fv.method(m), cl.method(m), m in FALLBACKS))
    for e in sorted(strings):
        a, b = fv.event(e), cl.event(e)
        if a != "-" or b != "-":
            rows.append(("event", e, a, b, False))

    unverified = [r for r in rows if r[2] == "-" and not r[4]]
    lines = ["# API verification", "",
             "Generated by `tools/apicheck.py` from the addon source. Each game name the addon uses, checked against",
             "Blizzard's own UI code for the installed Forever client (wow-ui-sim cache) and Gethe/wow-ui-source",
             "`classic_era`. **doc** = declared in Blizzard_APIDocumentationGenerated; **used** = called by Blizzard's",
             "own Lua/XML; **-** = not found. *Guarded* names are only used after checking they exist.", "",
             "Verified in game: not yet (the desk runs the in-game matrix). Unverified here: %d." % len(unverified), "",
             "| kind | name | Forever | classic_era | guarded |", "|---|---|---|---|---|"]
    for kind, name, a, b, guarded in rows:
        lines.append("| %s | `%s` | %s | %s | %s |" % (kind, name, a, b, "yes" if guarded else ""))
    lines.append("")
    lines += OFFLINE_APPEARANCE.splitlines() + [""]
    lines += SAVED_LOOK.splitlines() + [""]
    md = "\n".join(lines)
    md_path = os.path.join(ROOT, "docs", "API.md")

    out = ["-- Generated by tools/apicheck.py from the Forever client's UI source. Do not edit.",
           "-- The game names this addon uses that the real client has; the fake client may define only these.",
           "return {", "\tglobals = {"]
    for g in sorted(client_g):
        out.append('\t\t["%s"] = "%s",' % (g, client_g[g]))
    out += ["\t},", "\tnamespaces = {"]
    for ns in sorted(client_ns):
        out.append('\t\t["%s"] = { %s },' % (ns, ", ".join('["%s"] = "f"' % f for f in sorted(client_ns[ns]))))
    out += ["\t},", "\tmethods = {"]
    out += ['\t\t["%s"] = true,' % m for m in widget if fv.method(m) != "-"]
    out += ["\t},", "}", ""]
    api = "\n".join(out)
    api_path = os.path.join(ROOT, "tests", "client-api.lua")

    rc = ["-- Generated by tools/apicheck.py: only names the real client has (or guarded fallbacks). Do not edit.",
          'std = "lua51"', "max_line_length = false",
          'exclude_files = { "Libs/", "tests/", "tools/", ".release/" }',
          'ignore = { "212" }   -- unused arguments (event handlers and hooks get fixed argument lists)',
          "globals = {"]
    rc += ['\t"%s",' % g for g in sorted(OWN | {"SlashCmdList"})]
    rc += ["}", "read_globals = {"]
    for g in sorted(set(client_g) | {r[1] for r in rows if r[0] == "global" and r[4]}):
        if g == "SlashCmdList":
            continue
        if g in client_ns:
            rc.append('\t%s = { fields = { %s } },' % (g, ", ".join('"%s"' % f for f in sorted(client_ns[g]))))
        else:
            rc.append('\t"%s",' % g)
    rc += ["}", ""]
    luacheckrc = "\n".join(rc)
    rc_path = os.path.join(ROOT, ".luacheckrc")

    if check:
        stale = [p for p, t in ((md_path, md), (api_path, api), (rc_path, luacheckrc)) if not os.path.exists(p) or open(p).read() != t]
        if stale:
            sys.exit("stale: " + ", ".join(stale) + " (run python3 tools/apicheck.py)")
    else:
        open(md_path, "w").write(md)
        open(api_path, "w").write(api)
        open(rc_path, "w").write(luacheckrc)
    for r in unverified:
        print("UNVERIFIED %s %s" % (r[0], r[1]))
    print("%d names checked, %d unverified" % (len(rows), len(unverified)))


if __name__ == "__main__":
    main()
