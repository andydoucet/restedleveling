# Round 6 of v1.1 (ILL-1272): answers council r5 (opus 7.6, sol 7.9, grok 7.7)

**Desk note: r5 scored below r3.** I compared r3 (8924e8e) with r5 (2d7d4bb). Per judge, r5 matches r3 everywhere
except `elvui_wc3_fit` (opus and grok 8 → 7) and grok's `alerts_ux` / `layout_polish` (8 → 7). All three name the same
cause: the window turned into flat black slabs next to the WC3 wood (opus "three identical pure-black slabs", grok
"a flat black dashboard while alerts wear WC3 wood"). In r5 our inner panels took ElvUI's stock grey backdrop (0.1),
and the corrected render showed it as near-black. r3 drew them as a warm, recessed near-brown. This round reverts
that, without dropping the desk's "inherit" rule:

- **Inherit, by layer.** Under plain ElvUI, our panels still take ElvUI's own E.media colours (near-black, like stock
  ElvUI). When a skin on top of ElvUI paints its own art on our window (WC3 here, detected from the window's textures),
  that skin sets the look. Our panels then take a warm recessed well inside it (the r3 tone the council matched to the
  in-game references), so window, panels and alerts read as one family. Code: `X.SkinnedWindow`, `St.SkinnedWindow`.
  Test: the roster well takes the warm well inside a skinned window and keeps E.media colours under plain ElvUI.
- **NOW PLAYING with nothing banked shows no empty track** (as in r3). All three judges said the track read as an empty
  input field.

Kept from r4 and r5 (credited by judges): the numbered plan, the name/verb split, the amber waste line, the class word
in rows, filled chips, "Not filling: rest at an inn", the two-line date column, and the narrower Esc card.

## Changed (each asked for by at least two judges unless one is named)

- **Plan strip** (opus, grok). Step 2 is the only lit step: a warm pill behind "Le Dette: play now". Step 1 is quieter
  (13 px, muted verb). "Then Le Bankken, full in 19h 11m" is 13 px, aligned to the steps' text and exact to the minute
  (sol). The waste line has its own clearance above the strip (opus, sol).
- **One chip recipe** (opus, sol, grok). Every state fill is now a dark 25% tint on near-black. NEARLY FULL no longer
  shouts louder than FULL, and RESTING no longer reads as a bronze button.
- **Not-filling timeline lane** (sol). No bar or arrow promising progress: a thin red line with a stop marker at NOW,
  and "Not filling: find an inn" in the date column. A full lane draws no empty track behind "Full now" (opus). The
  hover tooltip sits on its own lane, right of the marker, clear of the dates (opus, sol, grok).
- **Esc card** (opus, grok). The ESC MENU tag is gone; the gold moon and the title say what it is. It uses the banner's
  exact hearth sentence (opus: the copies differed). Its next row shows who and their state only; the banked amount is
  the banner's (grok).
- **Character card** (opus, sol). The meta lines are flush with the name (the inline class icon indented them). The
  bubble sits lower, level with the face its tail points at.
- **Options** (opus, sol). "Account 3" instead of "#3". More space before WINDOW AND DISPLAY; About is one line.

## DECLINED

- **A "Cancel logout" or "Hearth" button on the banner** (grok, sol): CancelLogout and the hearthstone are protected
  actions an addon cannot take. The banner states what to do.
- **A class-colour ring on every portrait, and cropping the class icon** (grok): the ring is the state colour under the
  settled portrait rule.
- **Gold checkbox labels and host-style nav highlights** (opus, grok): those belong to the host's Settings frame, which
  we do not touch. Our labels follow ElvUI's own font.
- **Repainting our ElvUI window with the WC3 wood header** (grok): WC3-specific code is ruled out. Instead, our panels now
  take the skin's tone whenever a skin paints the window.
- **Not done this round** (one judge each):
  - sol: calendar dates on every roster row (taller rows), a smaller hero portrait, and 13 px metadata everywhere.
  - grok: midnight as "Wed 25 / 00:00", and slider end labels.
  - opus: a hero-bar shimmer, and red-state speech in timeline tooltips.

## Checks

- `lua5.1 tests/run.lua`: 180 pass. luacheck is clean. tools/apicheck.py: 0 unverified, at every layer.
- All 8 renders come from the real addon in wow-ui-sim (colours as the game shows them; tools/sim/fixture/Gamma.lua).
  04 is the full-screen context shot; the others are 1:1 crops.
