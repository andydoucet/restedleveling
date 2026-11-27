# Rested Leveling: spec v1.0 (approved scope, Andy 2026-11-24, autoloop)

Tracking: ILL-1244. Repo: github.com/andydoucet/restedleveling (public). Licence GPL-3.0, credit doc_biddle / Rested Watch.

Goal: never play a character that isn't rested. One glance tells you who to log in next, and the addon
nags (without popups) whenever you're about to waste rest.

Base: Rested Watch 1.4.8 (doc_biddle, GPL-3.0, 836-line single file). We reuse its projection, calibration,
Well Rested rank reader and sleeping-bag logic with credit, so this addon ships GPL-3.0.

## 1. Research findings that shape the design

- Rested maths (from RW, verify in game): 5% of a level per 8h resting, x0.25 outside, cap 150% of a level,
  Well Rested Legacy rank +4% per rank to rate and cap. Self-calibration at login corrects rate/cap.
- Only the logged-in character can be read. Every other row is a projection from its last snapshot.
- XP is already cleared at PLAYER_LOGOUT: snapshot on PLAYER_CAMPING / PLAYER_QUITING and every XP/rest event.
- Forever hides the realm (RW 1.4.7/1.4.8 shipped duplicate characters because of it). Key on a stable id
  (GUID when readable, else name + surname + saved realm), guard everything with issecretvalue.
- Forever names have surnames: use UnitNameUnmodified for the full name.
- CancelLogout is a restricted API, and Andy vetoed popups anyway. No cancel button: the warning says
  "move to cancel" (moving cancels the camp timer natively).
- SavedVariables are per WoW account (WTF/Account/591606#2 and #3 on Andy's box). An in-game-only roster
  cannot see the other account. See section 5.
- Addons cannot draw on the character-select screen. The roster is read in game, before you log out.
- ElvUI: its Skins module exposes S:HandleFrame / HandleButton / HandleStatusBar / HandleCloseButton /
  HandleTrimScrollBar. ElvUI_WC3 (r34, installed) hooks exactly those with hooksecurefunc and paints oak,
  iron and rivets on whatever they touch. So if our frames go through S:Handle*, the WC3 look applies with
  zero WC3-specific code. Caveat: WC3 bars add a 15% desaturation + gloss over the fill, so our
  green/yellow/orange/red read slightly muted under WC3 (fill colour itself is never changed).
- ElvUI auto-turns any LibDataBroker object into a datatext ("LDB_<name>"), and LibElvUIPlugin lets us put
  our options inside /ec. Both are free once ElvUI is present.
- Publishing: the BigWigs packager maps Interface 16xxx to the Forever game type and uploads one tag to
  CurseForge (CF_API_TOKEN + X-Curse-Project-ID) and Wago (WAGO_API_TOKEN + X-Wago-ID), plus a GitHub
  release with release.json for WowUp. RW does exactly this.

## 2. State colours

- Green: full (at cap).
- Yellow: 90% or more of cap.
- Orange: resting, under 90%.
- Red: logged out NOT resting, under 90%.
- Grey: max level / ignored.
- Precedence (decided): fullness first (green, yellow), then resting state (orange/red) below 90%.
- Projected values carry a "~" and a faint hatch until calibrated.

## 3. Sort: "play the top one first"

Priority (decided):
1. Green, longest time sitting full first (that rest is being wasted right now).
2. Yellow, highest % first.
3. Orange and red by rested amount in absolute levels of double XP, highest first.
4. Empty (0 rested) and grey at the bottom.
Red rows get a "park me" tag: log in, hearth, log out, it fills 4x faster.
Current character pinned in its own strip at the top with live burn, not in the queue.

## 4. GUI (Andy: "genuinely cool and engaging, be creative")

Andy's asks: character portraits, cool tidbits per character, animated portraits that "talk" when you
click a character for detail. Council-scored in wow-ui-sim until every judge >= 9 in every category.

Character capture (only possible while logged in on that character, saved to SavedVariables):
- race, sex, class, level, guild, zone/subzone at logout, bind location (GetBindLocation), gold,
  /played (RequestTimePlayed, suppressing the chat echo), professions + skill, ilvl-ish/equipped item
  quality summary, title, Well Rested rank, deaths if cheaply available, last-seen time, account tag.
- Portrait: SetPortraitTexture works only for live units, so the logged-in character gets its real
  portrait; others use a race/sex portrait atlas + class crest fallback, plus a live 3D model in detail
  via PlayerModel/DressUpModel with SetUnit (current) or a race/sex display + saved appearance where the
  API allows (verify; fall back gracefully).
- Detail panel ("character sheet card"): large 3D model with idle animation; on open it plays a talk/
  emote animation (SetAnimation talk/wave/bow; verify ids on Forever) and a speech bubble with a line
  generated from that character's data ("I've been snoozing in the Pig and Whistle for 2 days. 1.5
  levels of double XP, let's go."). Line bank per state x class flavour, deterministic per character.
- Tidbits strip: "/played 3d 4h", "Hearth: Goldshire", "Gold 42g", "Mining 175", "Last seen 2d ago".

Main window (/rlvl, minimap button, datatext click):
- "Play next" hero card: class icon, name, big bar, why ("full for 9h, 1.5 levels of double XP").
- Roster rows: class icon, name in class colour, level, 30-bubble segmented bar in state colour,
  % and "full in 6h 20m / 18:40", location badge (inn / city / campfire / outside), account tag (#2/#3),
  Well Rested pips, last seen.
- Current-character strip: rested left, ~kills at double XP, rested used this session.
- Filters: hide character, target level, show max level. (v1.1: an account filter, all / this account / one
  linked account; rows from another account also carry an account tag.)
- Compact mode: one line of coloured dots, hover for the row.
- Optional v1.1: 48h fill timeline (each alt as a lane, marker where it hits full).

Datatext / LDB text: "3 full | 2 resting | 1 outside", tooltip is the mini roster.

Styling:
- Style layer with two backends behind one interface: Default (our own art) and ElvUI (S:Handle*, ElvUI
  media, fonts, LSM statusbar). Auto-detect, override in options: auto / default / elvui.
- One addon, ElvUI optional (OptionalDeps: ElvUI). No separate ElvUI_ addon.
- Never touch ElvUI frames or profiles. Textures and colours only on our own frames.

## 5. Cross-account roster

- Andy decision: addon only. No desktop script, no companion. If the addon can't do it, that's the limit.
- Live in-game sync: when clients from two paired accounts are online at once, each sends its own account's
  characters with hidden addon messages (C_ChatInfo.SendAddonMessage, WHISPER); the newest snapshot per character
  wins, and the data then persists in each account's SavedVariables. A remote record never overwrites one of ours.
- Pairing is explicit and mutual: /rlvl link <Name> on each account (up to 8 links). A hello seen on GUILD / PARTY /
  RAID, or from an unlinked whisper, only prints how to pair; it never links and never sends data. Data from a name
  that has not linked us back is dropped.
- Hard limits (documented in README and shown in the UI): both characters must be on the same realm and
  same faction (Classic blocks cross-faction addon whispers); accounts must have been online together at
  least once; a remote account's rows are projections from the last sync and are tagged as such.
- Battle.net (BNSendGameData) is out: it needs a Battle.net friend, and you can't friend yourself.

## 6. Alerts (all dismissable, none are popups)

Delivery: centre banner (fades, click to dismiss, right-click "don't show this kind again"),
optional sound, chat line. No StaticPopup.
- Camping or quitting outside a rested area: banner + sound + chat with nearest inn/city if cheap,
  "move to cancel".
- Game Menu guard: when Esc menu opens while not resting, a slim red strip under the menu:
  "Not resting: this character will fill 4x slower". Informational only.
- Rested ran out on the current character: "Out of rested. Next up: Le Nette (full)."
- Rested low (threshold 5..50% of a full bar, default 10%, v1.1): heads-up in chat.
- An alt filled up while you play: toast, digested if several.
- Login digest in chat: who's full, who fills soon, last logout was outside.
- Cozy Sleeping Bag ready (from RW).
- Optional resting pill near the XP bar: Resting / Not resting.
- v1.1: the logout banner, toasts and Esc-menu card can be moved (/rlvl move; ElvUI movers too).

## 7. Architecture

RestedLeveling/
  RestedLeveling.toc  (Interface 16001, SavedVariables RestedLevelingDB, OptionalDeps ElvUI, LibDataBroker)
  Libs/  LibStub, CallbackHandler, LibDataBroker-1.1, LibDBIcon-1.0
  Core.lua      events, snapshots, identity, migration
  Model.lua     projection, calibration, cap, state, sort (pure, headless-tested)
  Sync.lua      cross-account (addon messages), merge rules
  Alerts.lua    banner, chat, sound, game-menu strip
  Style/Default.lua, Style/ElvUI.lua
  UI/Roster.lua, UI/Hero.lua, UI/Compact.lua
  Broker.lua    LDB + minimap
  Options.lua   Settings panel, ElvUI plugin page when present, slash commands
Slash: /rlvl and /restedleveling (avoid /rested and /rl).

## 8. Done check

- Model unit tests (lua5.1): inn, outside, cap, ranks, calibration, colour precedence, sort order,
  merge (newest wins, no duplicates under hidden realm).
- luacheck clean; mocks reject unknown WoW APIs; every newly called API listed verified/unverified
  against wow-ui-source classic_era.
- Visual: offline renders of Default and ElvUI+WC3 roster, hero, compact, banner. Andy approves renders
  before anything is installed.
- In-game matrix on Andy's characters (inn, open world, capital /camp, max level, already full,
  level up + /reload, both accounts online, hidden realm duplicates).
- CI on GitHub Actions (public repo). Release by tag through the BigWigs packager. Publishing waits for Andy's go.

## 9. Non-goals

No auto-logout, no input automation, no popups, no network beyond in-game addon messages, no Titan
dependency (RW's Titan plugin is not ported unless asked).
