# Round 9 of v1.1 (ILL-1272): answers council r7 (opus 8.0, sol 7.7, grok 7.8)

The systemic steer worked: opus moved readability and layout to 8, and every opus category is now 8. What is left
is finish. This round keeps the r7 type scale and grid, and fixes what the judges named. Each change was asked for by
at least two judges unless one is named.

## Changed

- **The Esc card no longer overflows** (sol: "a shipping blocker"). Its lines wrap inside the card: from the moon's
  right edge to 12 px short of the close column, measured on every show. The card grows to fit. Test: both lines are
  held to the card's text column and wrap on words; the test fails on the old code.
- **The plan strip has one fewer box** (opus, sol). Step 2 has a 3 px gold tick and a faint wash instead of an
  outlined pill, and its verb ("play now") is 15 px. The next line is a future recommendation, not a second switch:
  "After Le Dette: Le Bankken, full in 19h 11m" (sol).
- **The full #1's second line says the consequence, not a scold** (grok, sol): "Bank is full: time logged out adds
  nothing now."
- **One chip recipe, truly** (opus, sol, grok). Every chip is a dark neutral fill with a 1 px edge, mark and word in its
  state colour. NEARLY FULL was the only one that still looked filled.
- **Darker wells under the skin** (opus, sol, grok). The recessed well is two steps darker (#18130E), closer to the
  reference Character pane, and still warm.
- **Hero art** (opus, sol). A darker overlay behind the text block (62%).
- **Badges** (all three) are 21 px minimum.
- **Toast** (opus, sol, grok). The advice ("Play Le Dette") is the headline; the cause is the muted line above it. Its
  rail is neutral, so red stays the logout warning's alone (sol).
- **Alert corner controls** (opus, sol). The gear sits 12 px from the close, outside its 32 px hit area.
- **Move mode** (sol): "Reset position" on each placeholder, "Reset all positions" on the panel.
- **Timeline** (opus, sol, grok). The FULL AFTER 48h column is 24 px wider, so the dates and "Not filling" have room.
  The night shading is a visible neutral shade (grok: invisible before). The axis labels are at full reading contrast.
- **NOW PLAYING** (opus). "No rested XP" sits on the rows' bar line.

## DECLINED

- **Moving "Account 3" into the meta line** (sol, grok): I tried it. With the class word and 13 px text there is no
  room, and it shortened "Goldshire inn" to "Go..." and ran into the bar column. It stays beside the name.
- **"Full for 1d 16h"** (opus): "Full since" was chosen in r2 by two judges.
- **Lighting step 1 instead of step 2** (grok): opus and sol read step 2 (who to play) as the point.
- **14 px reading text** (sol): the desk's type scale sets 13; opus and grok scored readability 8 with it.
- **Merging the three alerts into one card, and one width for all** (grok): they are three different alerts that never
  show together in play (the toast waits for the banner, and the Esc card hides under it). Scene 05 shows them together
  only for the shot.
- **Blizzard stone buttons and a gold title for the default theme** (grok): the settled default is oak and bronze.
- **WC3 rivets on the roster, the compact tip's header block** (grok, opus): WC3 art, out of scope.
- **Not done this round** (one judge each): grouped counts in compact mode, zzz on roster portraits, a hover pulse
  in the timeline, and a 76 px NOW PLAYING strip.

## Checks

- `lua5.1 tests/run.lua`: 181 pass. luacheck is clean. tools/apicheck.py: 0 unverified.
- All 8 renders come from the real addon in wow-ui-sim. 04 is the full-screen context shot; the others are 1:1 crops.
