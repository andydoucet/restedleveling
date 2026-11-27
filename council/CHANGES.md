# Round 7 of v1.1 (ILL-1272): answers council r6 (opus 7.9, sol 7.9, grok 7.8)

r6 recovered to r3's level. This round keeps r6's structure and fixes what all three judges named: copy drift, the
timeline tooltip covering lanes, two chip styles, a plan step that looked disabled, and options as a cold slab beside
the warm window. Each change below was asked for by at least two judges unless one is named.

## Changed

- **One wording everywhere** (opus, grok). The other account reads "Account 3" in rows, the hero and options, not
  "Acct #3" in one place and "Account 3" in another. A not-filling character reads "Not filling: rest at an inn" in
  rows, tips, the card and the timeline; the timeline said "find an inn".
- **Class colours read as class colours** (opus). Roster and tip names were mixed 40% toward cream, which turned a
  warrior's tan (Le Bankken) near-white. The mix is now 15%. Class-coloured names are unchanged as a rule.
- **Warm panels everywhere under the skin** (grok, opus). The warm recessed well is one step warmer (#1E1812). The
  options page takes it too whenever a skin dresses our windows: it was a cold near-black slab beside the warm window
  (grok). Under plain ElvUI, panels and options still take ElvUI's own E.media colours.
- **The plan's lit step reads lit** (opus, grok, sol):
  - Step 2 ("Le Dette: play now") is a gold-rimmed pill on a dark warm fill; the flat khaki read as disabled (opus).
  - Step 1's disc recedes: grey, 70%.
  - The next line is a step of its own, "Then play Le Bankken, full in 19h 11m", set under step 2, not under step 1
    (sol, grok).
- **One chip recipe, every state marked** (grok, sol, opus). All four fills are 25% of the state colour on #1a140e.
  RESTING has its own mark now, a small moon in its orange, next to the tick, the arrow and the warning (sol). None of
  them reads as a button.
- **Timeline** (opus, sol, grok):
  - The hover tooltip opens level with its lane, outside the chart, so it covers no lane, marker or date (all three).
  - Noon names its day ("Tue 12:00", "Wed 12:00"), so the two noons no longer read alike (grok); midnight keeps "Wed 25
    Nov".
  - The right column is 14 px wider, so "Not filling: rest at an inn" wraps there whole.
- **Roster** (opus). A not-filling character's bar is drawn at half strength: banked, but not moving.
- **Hero bar** (opus, sol). 14 px (was 18) with quieter seams, so it no longer outweighs the name. The same quieter
  seams on every bar.
- **Logout banner** (sol, opus). The headline is the goal, "Rest at an inn before logging out". Under it come the
  manual steps, "Cancel the logout, then hearth to Feathermoon Stronghold.", then the reason at 13 px (was 12).
- **Move mode** (opus, grok, sol). The drag hint sits right under each placeholder's note, in readable cream, with no
  dead gap: "Drag anywhere on this panel."
- **ROSTER / TIMELINE** (sol) are real 64 x 24 targets.

## DECLINED

- **The waste line back on the state line** (opus): r4's judges asked for it on its own line, and grok asks for more
  weight on it.
- **"Full for 1d 16h"** (sol): two judges chose "Full since" in r2.
- **Lighting step 1 instead of step 2** (grok): opus and sol read step 2 (who to play) as the point of the plan.
- **The Blizzard dialog backdrop and beveled buttons for the default theme** (grok): the settled default chrome is oak
  and bronze.
- **The WC3 wood stopping short on the banner, the Esc card and the placeholders; WC3's red button bevel; the compact
  tip's header block** (opus, grok): that is the WC3 skin's own art and button treatment. WC3-specific code is ruled
  out.
- **"Le jette" vs "Le Jette"** (grok): one string (the saved name) feeds every surface. The difference is the font's
  J at small sizes in the simulator.
- **NOW PLAYING's live face** (opus): it is `SetPortraitTexture("player")` in game; the simulator cannot draw it.
- **Not done this round** (one judge each):
  - sol: calendar dates on every row, a smaller hero portrait, and an explicit two-line toast.
  - opus: coin icons in the card, and a FULL-chip pulse.
  - grok: dropping the Settings sidebar (Blizzard's).

## Checks

- `lua5.1 tests/run.lua`: 180 pass. luacheck is clean. tools/apicheck.py: 0 unverified, at every layer.
- Changed tests: the RESTING chip's moon (and none on MAX LEVEL), the banner headline, the runner-up wording.
- All 8 renders come from the real addon in wow-ui-sim. 04 is the full-screen context shot; the others are 1:1 crops.
  Scene 03 is wider because its tooltip now opens outside the window.
