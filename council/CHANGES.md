# Round 4 of v1.1 (ILL-1272): answers council r3 (opus 7.7, sol 7.9, grok 8.1)

Every category has been under 9 for three rounds, so this round changes layouts and components rather than numbers.
Each change was asked for by at least two judges, unless a single judge is named.

## New layouts and components

- **The hero's plan is a numbered two-step strip** (opus, sol, grok: play-next, layout). The one cream sentence is
  gone. Gold disc **1**: "Le Jette: hearth to an inn"; gold disc **2**: "Le Dette: play next". Each step starts with
  the character it is about, so its class colour leads the line. The runner-up moved out of the figure column into the
  strip, as the plan's next step ("Then Le Bankken, full in 19h"), before View details (sol, opus). With nobody to
  switch to, the strip falls back to the one-line advice.
- **The hero's figure column is one centred group: 1.5 / LEVELS BANKED / a state tag ("✓ FULL")** (opus, grok). It
  sits level with the portrait. "Full since 1d 16h ago" stays in the state colour, and "· more rest is wasted." is a
  separate amber line, so the reason to switch is no longer painted as success (grok).
- **The character card is a new composition** (all three). The name block (name, "Level 11 Tauren Druid / Seen 23
  hours ago", state chip) moves into the left column under the speech, beside the portrait. The stage is 50 px shorter
  and the empty well is gone. The level medallion and the "Last seen as..." note are gone; the meta line carries both
  (all three). The rest bar is 14 px, inside the same box, and the rest text is two deliberate lines: where and how
  much, then the time to full (opus). This also fixed a real layout bug: the box was anchored to its own child, which
  could leave the tidbit tiles above the card.
- **The Esc card has its own shape** (opus, grok). An ESC MENU tag, a moon icon, one instruction line, and the next
  character without a button (the menu is already open). It no longer reads as a second banner. Its move-mode
  placeholder shows the same moon (opus, sol).
- **Rows name the class** (sol, grok): "Lv 6 Mage · Thunderbrew · 2d ago". The bar column starts 20 px later to make
  room. A place shortens to its first word only when that word has 6 or more letters ("Thunderbrew", never "Dun").

## Changed

- **Banner** (opus, sol). The instruction comes first under the title (13 px cream); "Le Jette is outside a rest area."
  follows at 12 px, softer. Its button reads "View details", as in the main window (sol).
- **Toast** (opus, sol, grok). The trigger line is a darker amber; the advice is cream at 15 px, 6 px below it.
- **NOW PLAYING** (opus). The empty 13 px track is back, on the rows' columns, with "No rested XP: kills give normal
  XP" under it, so the strip has no hole.
- **Timeline** (all three). Night bands are neutral grey, with no fifth hue. The AFTER 48H column gives the date and,
  on a second line, the time ("Full Wed 2 Dec / 01:36"), so lanes full the same day differ (opus, sol). 6 px between
  the percent and the plot (opus). "Full now" is a tick. The hover tooltip hangs under its lane, inside the window
  (grok).
- **Default theme** (opus, grok). The main action is a lighter bronze than the frame (new `btn_bronze` art); the rest
  stay dark bronze. The close button is a drawn cross, not a letter X. The title has a crisp gold moon, not the
  shrunken logo. Alternate rows differ more (opus, grok).

## DECLINED

- **ElvUI-specific checks:** host-yellow option labels (opus), host-style tabs (opus), 26 px buttons (sol). One judge
  each, and opus's "cap at 22 px" conflicts with sol's 26 px.
- **A saved-look crop editor** (sol): a new feature, out of this ticket's scope.
- **A 2 px class ring on every row portrait** (grok): the state ring is the portrait rule; class reads from the name
  and now the class word.
- **"Fully rested · reached cap 1d 16h ago"** (sol): two judges asked for the single "Full since" wording last round.
- **The dark block in the logout placeholder's wood**: WC3 skin art (see r3).
- **Not done this round** (one judge each):
  - sol: two-line calendar ETAs in rows, 14 px text everywhere, and a dashed Esc-menu anchor.
  - grok: the bar enamel hairlines.
  - opus: a shimmer when a row fills, and row-hover quips.

## Checks

- `lua5.1 tests/run.lua`: 177 pass. luacheck is clean. tools/apicheck.py: 0 unverified, at every layer.
- New tests: the plan's two steps (Words.Steps); the Esc card's own shape (tag, no button, one instruction); the card's
  name block and two-line rest text; the hero's amber waste line.
- All 8 renders come from the real addon in wow-ui-sim. 04 is the full-screen context shot; the others are 1:1 crops.
