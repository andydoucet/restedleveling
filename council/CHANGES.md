# Round 5 of v1.1 (ILL-1272): answers council r4 (opus 7.6, sol 7.8, grok 7.1) and the desk's steer

## Desk steer

- **ElvUI mode inherits; it does not invent.** Under ElvUI our inner panels take ElvUI's own colours and texture at
  runtime: E.media.backdropcolor / backdropfadecolor / bordercolor on E.media.blankTex, guarded, with our baked well
  as the fallback. That covers the hero, NOW PLAYING, the roster well, the card stage and the options page. Fonts were
  already E.media.normFont and bars E.media.normTex. Windows, alerts, toasts and the Esc card go through ElvUI's own
  S:Handle* calls, so the active skin (WC3 here) dresses them all alike. With stock ElvUI the panels come out
  near-black, as in the in-game references.
- **The renders now show those colours as the game does.** wow-ui-sim treats vertex and backdrop colours as linear and
  re-encodes them, so ElvUI's 0.1 backdrop drew as a 0.35 grey slab. That was also the "taupe" Settings panel and the
  grey square judges saw. A render-sandbox shim (tools/sim/fixture/Gamma.lua, never installed) linearises those colours
  first, so every addon's colours (ElvUI's and ours) render as in the game. No addon code depends on it.
- **Red rows promise no fill time** (desk; grok, sol). Rows, tooltips, the compact tip, the card and the hero say "Not
  filling: rest at an inn". The timeline lane says "Not filling: find an inn" in its date column. (`Words.RowFull`,
  `Words.NOT_FILLING`.)

**Desk note: r4 scored below r3.** I compared r3 (8924e8e) with r4 (dfdd343). The drop came almost entirely from grok
(7.9 to 7.1). Three things r4 introduced read worse in the render, and this round fixes each at its cause:

- **Whole plan lines in a class colour.** Each step started with an inline colour code. The simulator applies such a
  code to the whole string, so "Le Dette: play next" rendered entirely purple (opus). The name and the verb are now
  separate text: the name in its class colour, the verb in cream.
- **The waste reason on the same line.** "Full since 1d 16h ago · more rest is wasted." still sat on one line, despite
  r4's notes (opus, sol). It is now its own amber line, under the state line.
- **An empty black track in NOW PLAYING** (grok, opus): it read as a hole or an empty input. Every bar track now has
  a warm bronze edge, and the line under it is full cream.

I kept the r4 layout changes that judges credited: the numbered plan, the class word in rows, the two-line AFTER 48H
dates, the grey night bands, and the card's name block beside the portrait.

## Changed (each asked for by at least two judges unless one is named)

- **Plan strip** (all three). The runner-up moves out of the step row onto its own line under the steps ("Then Le
  Bankken, full in 19h"), clear of View details. Step 2 reads "Le Dette: play now", not a repeat of PLAY NEXT (grok).
  The strip is taller, so nothing is squeezed.
- **Hero.** The figure group (1.5 / LEVELS BANKED / FULL) is centred on the portrait's midline (opus, sol). The speech
  bubble starts at the name's edge (opus). The art behind the text is darker: a 45% overlay and a wider fade (opus,
  sol).
- **Filled state chips** (opus, grok). Each chip has its state's own dark fill, its edge and a light tint of its colour
  for the word; outlines read as form fields. Icons only where they add meaning: the warning on NOT RESTING, the
  arrow on NEARLY FULL, the tick on FULL. RESTING has no smudgy icon (opus).
- **Esc card** (all three). It is about 70% of the banner's width (340-380 px), with no red rail and a crisp gold
  crescent (the title's moon, not a spell icon). The ESC MENU tag sits inside the frame. Its move-mode placeholder
  has the same moon, the same width and no rail.
- **Banner** (opus, sol). Line 2 no longer repeats the title: "Hearth to Feathermoon Stronghold, or find an inn."
- **Timeline** (opus, grok, sol):
  - Midnight reads "Wed 25 Nov". There is a label every 12 hours (6-hour lines stay), so day labels fit.
  - "+48h" is lowercase, like "19h".
  - The gutter is "FULL AFTER 48h", with "Wed 2 Dec / 01:36"; the repeated "Full" prefix is gone.
  - The lanes say their order: "BY TIME TO FULL" (opus, sol: the order differs from the roster's).
  - The tooltip opens right of a short lane's end. There is more room between a marker and its time.
- **Default theme** (sol, grok). Secondary buttons are a darker bronze, so only the main action is light. The close
  cross is bright, not grey (opus).
- **Compact tip** (grok): "Play the top one first".

## DECLINED

- **Mirroring the character card** (opus): the three judges disagree (opus mirror, grok r3-style, sol keep r4); sol
  scored the r4 card highest. It stays.
- **A muted red Unlink button** (opus): red means "not resting" only.
- **"Full for 1d 16h" again** (sol): two judges asked for "Full since" in r2.
- **More options spacing and helper lines under each checkbox** (opus, sol): the Settings canvas is a fixed height, and
  the page already uses it to the bottom; more spacing would push About off the canvas.
- **The compact tip's lighter header block, the Settings Close sliver, the stray grey square and bar in move mode**:
  WC3 or ElvUI frames, not ours.
- **Not done this round** (one judge each):
  - sol: a calendar line in every row (taller rows), "Account 3", and a toast after dismissing.
  - grok: the toast's own skin, and solid chip colours.
  - opus: a hatch on red bars, and a pulse on the #1 disc.

## Checks

- `lua5.1 tests/run.lua`: 179 pass. luacheck is clean. tools/apicheck.py: 0 unverified, at every layer.
- New or changed tests: ElvUI's E.media colours on our panels (fails without the inheritance); the plan's name and verb
  are separate; red rows, the hero and the card say "Not filling: rest at an inn" with no fill time; chips are filled with
  meaningful icons only; the Esc card width; timeline ticks (day, date, month; a label every 12 hours).
- All 8 renders come from the real addon in wow-ui-sim. 04 is the full-screen context shot; the others are 1:1 crops.
