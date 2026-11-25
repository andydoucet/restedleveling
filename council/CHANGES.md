# Round 19 (answers council r16: opus 7.9, sol 8.2, grok 8.1)

This round makes only the changes at least two judges asked for.

## Changed

- **One finished button family** (opus, sol, grok). Every button now has the restrained bevel (lit top edge, dark
  bottom edge): the default theme's red "View details" and the bronze secondaries, and the ElvUI enamel buttons.
  They are one family at 24 px (22 px under ElvUI).
- **Hero rhythm** (opus, sol). The gaps from name to speech bubble to meta line are an even 6 px, with 10 px before
  the rest bar.
- **The max-level row recedes** (opus, sol, grok). Max-level and hidden rows draw at 70%, and the bench line is
  muted.
- **The compact tip shows the numbers** (sol, opus). It reads "93% · full in 14h 25m" and "Full for 2d" instead of
  repeating the state word. The state colour still marks each line.
- **First run** (opus, sol). "Link account…" sits on the step text's left edge, 8 px under it.

## DECLINED

- **A "Cancel logout" button that calls CancelLogout()** (opus, sol). The brief rules it out: CancelLogout is
  restricted for addons. The banner says "Cancel the logout first" because the game's own countdown has the Cancel
  button. The banner stays non-modal and never claims that dismissing it cancels anything.
- **The now-playing bar in the state colour** (grok). Earlier rounds (opus, sol) kept its own blue.
- **Scene art behind the ElvUI card stage** (opus). Sol asked for the near-black panel; the r8 steer keeps ElvUI
  interiors flat.

## Checks

- 81 tests pass. luacheck is clean. The API check reports 242 verified and 0 unverified.
- All 8 renders come from the real addon in wow-ui-sim. 02 to 08 are 1:1 crops, and the WC3 region check passes.
- CI has not run on GitHub: Actions still has no workflow registered on the repo.
