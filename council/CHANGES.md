# Round 3 of v1.1 (ILL-1272): answers council r2 (opus 7.5, sol 7.9, grok 7.9)

I grouped the requests by root cause. Each change below was asked for by at least two judges, unless a single judge is
named. The renders are the same 8 scenes.

## Changed

- **One button family per theme** (grok, opus, sol). Under ElvUI every button is the host's blue: Compact, View
  details, Unlink, All accounts, Done, Reset all, Move notifications. In the default theme every button is bronze. The
  main action (View details, Done) is the same button with a 1 px gold rim; there is no second colour. The gold enamel
  is gone. The default close button is a cream X on bronze with a gold rim instead of a red square (opus, grok).
- **One wording for "full"** (opus, grok). Everywhere a character is full, it says "Full since 1d 16h ago": rows, the
  compact tip, the card and tooltips. "Full for" read like time remaining. The hero says "Full since 1d 16h ago · more
  rest is wasted.", which is shorter, as sol asked.
- **Race and class badges in colour** (all three). They were washed out, and the simulator draws any desaturation as
  full grey, so every row showed the same grey head. Badges are now in full colour, 19-28 px on a dark disc with a
  bronze rim. Discs under 36 px (alert "Next:" rows, timeline lanes) show the picture alone, with no double blob
  (opus). The portrait rule itself is unchanged: no look = class icon + race badge; a face = class badge.
- **Chips** (grok, sol, opus). The word is now exactly the state colour, the same as its edge, the legend dot and the
  bar. Every chip uses one 12 px icon size with a 6 px inset. Legend text is in the exact state colour (opus).
- **Hero** (opus, grok):
  - The portrait is 112 px (was 104) and the name 30 px.
  - The empty column under "1.5 LEVELS BANKED" now names the runner-up ("Then Le Bankken, full in 19h").
  - The text column clears the larger badge.
  - When #1 is full, the state accent breathes slowly. Reduce motion turns this off.
- **NOW PLAYING** (opus, grok). A red state rail, like the rows. The line under the name gives the place ("Outside ·
  Feralas"). It no longer repeats the NOT RESTING chip.
- **Character card** (all three):
  - The rest bar and its line are inside one box with the stage, 12 px in, under the name and meta line. They no
    longer float between two panels.
  - Hearth and logout place merge into one tile when they are the same town (opus).
- **Timeline** (sol, opus, grok):
  - Each lane shows how full it is now (21%, 14%), so the long lanes differ (sol).
  - The right column has an "AFTER 48H" heading over a quiet separator.
  - Dates are 13 px with more room after the arrow.
  - Night bands are darker and nearly neutral, no longer slate blue.
  - The band heading names who fills next: "NEXT 48 HOURS · Le Bankken full in 19h 11m" (sol).
- **Move mode** (grok, opus). The coachmark panel uses the alerts' surface and gold outline, so it matches the
  placeholders. Buttons follow the one-family rule. The toast placeholder sits clear of the chat panel in scene 04.
- **Alerts** (opus, sol, grok):
  - **Banner.** The situation line is secondary (13 px, softer); the instruction leads (13 px cream).
  - **Esc card.** Its icon is an inn, not the banner's warning sign, so the two read apart.
  - **Toast.** Its trigger line ("Le Jette: rested XP used up") is 12 px amber. Its rail is in the colour of the
    character who ran out (sol, second round asking). Green stays on the advice line.
  - **Close buttons.** Every close button has a 32 px hit target (sol).
- **Options** (opus, sol, grok). The Move notifications helper sits under its 22 px button, never to the panel edge.
  The spacing above headings is more even.
- **Footer** (opus). The account button sits 12 px from the checkbox, grouped with it on the right.

## DECLINED

- **Class-coloured names and a gold "First:"/"Then:" in the action line** (opus, grok): they are already inline colour
  codes. The simulator draws an inline colour only at the start of a string (a known wow-ui-sim limit), so the names
  look cream in the render. In game they are class-coloured.
- **The Settings panel's outer frame and its grey search bar, and the blue sliver by Close** (opus, grok): these
  belong to Blizzard's Settings panel, skinned by ElvUI, not to our canvas. Our canvas paints only its own near-black
  panel.
- **The stray bar and grey square in move mode** (from r1): these are ElvUI frames, and touching them is ruled out.
- **The dark block on the right of the logout placeholder's wood** (opus): it is the WC3 skin's own art. I tried
  resizing the frame once shown, so the skin lays it out again; it did not change, and I reverted it. The real banner
  at the same width draws full wood (scene 05).
- **The compact tip's brown header block and the window frame "seam"**: these are WC3 skin art. WC3-specific code is
  ruled out.
- **A Cancel logout button** (sol): CancelLogout is restricted for addons. The banner says to cancel the countdown
  first.
- **Faction-tinted badge discs** (opus): the coloured badges now separate the rows.
- **Not done this round** (one judge each):
  - sol: a two-line ETA with the calendar date in every row and taller rows, a portrait-left card layout, the level
    badge moved into the meta line, account aliases, and a dashed "Esc menu" anchor.
  - grok: the class word in row meta, and a percent coloured by state.
  - opus: a mood glyph on row hover, and a sparkle on "Full now".

## Checks

- `lua5.1 tests/run.lua`: 175 pass. luacheck is clean. tools/apicheck.py: 0 unverified, at every layer.
- New tests: badges drawn in colour (the old desaturated badge fails it); hearth and logout place merge; the runner-up
  line for every group; the timeline heading names who fills next.
- All 8 renders come from the real addon in wow-ui-sim. 04 is the full-screen context shot; the others are 1:1 crops.
