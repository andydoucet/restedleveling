# Round 8 of v1.1 (ILL-1272): the desk's systemic steer for readability and layout

No new council input this round; this is the desk's steer (Marcus). Every category is at 8 except readability and
layout_polish, which have been at 7 or below in every round. Nudging sizes one surface at a time did not move them, so
this round changes the system and leaves the categories already at 8 alone.

## 1. One type scale, applied everywhere through St

- `St.TYPE` / `St.Size`: body and meta 13, names 14, window titles 16, caps labels and chips 12. Both styles (Default
  and ElvUI) size every font through it, so no surface can ask for an ad-hoc smaller size. Body and meta are fixed at
  13 whatever a caller passes; names and titles may only be larger (headlines). Hero names, figures and numbers keep
  their display sizes.
- Chips and caps labels are 12, not 11: the project's own test forbids text under 12 px (an earlier council rule).
- Secondary text keeps its cream tier (St.SECOND, St.MUTED); both sit at over 7:1 on the warm wells (the existing
  contrast test).
- Rows grow to 62 px (from 58) rather than squeeze the 13 px second line.
- Test: every reading-tier font string in the main window and card is 13 px or more.

## 2. One column grid

- `Wg.COL`: rank | portrait | name + meta | bar | value | chip, used by the rows and by NOW PLAYING. The % has its own
  right-aligned value column on the bar's line; the line under the bar says when ("Full in 19h 11m (today 23:12)",
  "Not filling: rest at an inn"). Chips are one fixed width on one column, so one right edge. NOW PLAYING's chip sits
  on the same column.
- One left edge: hero, NOW PLAYING, the roster and now the footer (it sat 8 px in).
- Test: the rows' chips share the width and column, the value column ends before them, and NOW PLAYING's chip is on
  the rows' column.

## 3. Timeline

- No tooltip at all. A fixed detail line under the chart shows the hovered lane ("Le Bankken · Full in 19h 11m (today
  23:12) · 1.4 levels banked · Goldshire inn"), and the lane lights. Nothing ever covers another lane. Idle, it says
  how to use it.
- The axis is relative: Now / +12h / +24h / +36h / +48h, with a line every 6 hours. The nights stay shaded by the local
  clock; calendar dates live only in the FULL AFTER 48h column.
- Tests: the relative ticks, and that the detail line fills on hover and resets on leave.

## Checks

- `lua5.1 tests/run.lua`: 180 pass. luacheck is clean. tools/apicheck.py: 0 unverified.
- All 8 renders come from the real addon in wow-ui-sim. 04 is the full-screen context shot; the others are 1:1 crops.
