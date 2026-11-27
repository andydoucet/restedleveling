# Round 1 of v1.1 (ILL-1272): baseline is Andy's 1.1.2 screenshot (refs/ingame/andy_v112_main.png)

New scene set (tools/render_council.sh, 8 scenes). The fixture is Andy's own roster from that screenshot: Le Dette
full, Le Nette, Jacques Hammer outside, Le Jedde, Amdo Rhen, Le Beouf (a saved look, stand-in face), and Le Bankken
on his linked account #3. He is on Le Jette, level 48, not resting.

## New

- **Movable notifications** (04, 05). /rlvl move or the options button shows the logout warning, the toasts and the
  Esc menu card as labelled placeholders in their real size and surface, over a dimmed screen, with Reset per item,
  Reset all and Done (Esc also leaves). Positions are saved per account, kept on screen, and anchored to the nearest
  edge. The Esc card stays under the menu until moved; Reset attaches it again. With ElvUI they are also movers in a
  "Rested Leveling" group in /moveui. Scene 05 shows all three at once for the shot; in play only one shows at a time.
- **48-hour fill timeline** (03): the band's TIMELINE tab. Now to +48 h, nights shaded, a NOW line, one lane per
  character, soonest full first; a bar in the state colour up to the fill moment with the clock time; full ones sit on
  NOW; later ones run to the edge and fade, with the date. Hover gives "Full in ... (clock)".
- **Account filter** (01, 07): All accounts / This account / #3, in the footer (shown when there are two accounts)
  and on the options page. **Low rest warning** slider, 5 to 50% (07).

## Look changes from the baseline notes

- One red only: the main action button is gold enamel in both themes, so red means "not resting" and nothing else.
  Chips are quiet for every state except NOT RESTING, which keeps its bright edge.
- Hero: the figure is smaller than the name (38 px vs 28 px name, was 48) and reads with its unit ("1.5 / LEVELS
  BANKED", cream caps, right-aligned). The bar now runs from the text column to the figure's right edge: no gutter.
- No "..." on meaningful text: a row's place shortens by words ("Thunderbrew Distillery inn" -> "Thunderbrew inn")
  before any ellipsis; NOW PLAYING says "~1 double-XP kill · none used yet" instead of "0.0 of a level...".
- Roster bars are thicker (13 px) with readable bubble seams. The band's legend uses colour dots, not a second set of
  icons; the band's right end holds the ROSTER | TIMELINE tabs.

## Checks

- lua5.1 tests/run.lua: all pass. luacheck clean. tools/apicheck.py: 0 unverified.
- All 8 renders are the real addon in wow-ui-sim; 01-03 and 05-08 are 1:1 crops, 04 is the full-screen context shot.
