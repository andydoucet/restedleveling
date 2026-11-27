# Changelog

## Unreleased

v1.1 (ILL-1272), sync:

- Once two accounts are paired, logging in on one while the other is online syncs both ways at once: the online
  client answers the login hello, so the newcomer sends its roster too (before, it waited for the 15-minute ticker
  unless the two shared a guild or group).
- A long roster no longer fails to arrive: the half-received buffer expires 60 s after its last chunk, not its first.
- /rlvl unlink frees that account's peer slot (at most 8), so a new account can pair later.
- A sender's "-Realm" is kept when it is not our realm, so a same-named character on another realm never matches a
  link (Forever reports no realm, so nothing changes there).

v1.1 (ILL-1272), options:

- Show accounts: all, this account, or one linked account (options page, the ElvUI /ec page, /rlvl accounts, and a
  button in the main window's footer when more than one account is in the roster). Hidden accounts leave the hero,
  the roster, compact mode and the datatext; alerts still cover every account.
- Low rest warning threshold: 5 to 50% of a full bar (default 10%), on the options page, /ec and /rlvl low. The chat
  line says it: "running low here: 0.1 levels left, under 10% of full".
- Saved data moves to version 2; v1 files load with the defaults, and damaged values are reset.

v1.1 (ILL-1272), movable notifications:

- /rlvl move (or "Move notifications" on the options page or /ec) shows the logout warning, the toasts and the Esc
  menu card as labelled placeholders in their real size and style. Drag them; Reset puts one back, Reset all puts all
  back, Done or Esc finishes. Not in combat (combat closes it).
- Positions are saved per account, anchored to the nearest screen edge, kept on screen, and applied again when the
  UI scale or the window size changes. Toasts stack away from the nearer edge.
- The Esc menu card stays attached under the menu until you move it; Reset attaches it again.
- With ElvUI, the three are also ElvUI movers in their own "Rested Leveling" group in /moveui. Moving or resetting
  them either way saves to the same place.

Fixes from the first in-game run (ILL-1274):

- Button labels stay readable on hover (every button and the close cross): the label draws above the hover face.
- Real-life time to full everywhere a character's rest shows (hero, rows, card, mini-roster, tooltips):
  "Full in 9d 23h (Thu 4 Dec, 22:40)", "Full in 6h 20m (today 18:40)", "Full for 2d 4h". The card's rest line
  explains the maths on hover (5% of a level per 8h in an inn or city, full at 1.5 levels: 10 days from empty).
- When nobody has rest banked, the hero no longer says "play next" a 0.0: it says who fills first and when. "First,
  take ... to an inn" is always about the character you are on.
- Professions are listed once each (Forever reported some twice); saved duplicates are cleaned on login.
- "Link account..." links in place: it opens a name field in the guide (or the footer), Enter links the same way as
  /rlvl link, Esc cancels. The field then says "Linked to ... Waiting for them to link you back" or "Paired with ...,
  synced 5m ago", with Unlink.
- Offline characters show their class crest with a grey race emblem instead of a stock face that was not theirs (the
  game cannot draw another character's look while it is offline; see docs/API.md). Only the character you are on is
  drawn live, on the card's 3D stage too.
- The Esc-menu card and the logout banner lay out the same on the first open as on later ones: the card is sized from
  the menu and hangs under it, Details sits on the right edge in line with the close X, and the next-character line
  is shortened instead of pushing the button out. Nobody is offered as "next" when nobody has rest banked.

Review follow-ups (ILL-1274):

- With nothing banked anywhere, the Esc-menu card and the logout banner now name the same character as the hero: the
  one that fills first (least time to full), not the one with a little more banked outside.
- When the hero is the one that fills first, the roster below it is numbered from 1 in sort order.
- The inline link field closes (and lets go of the keyboard) when its window hides mid-edit. A link that does not take
  (at most 8 links) keeps the field open with the name and says why under it.
- Shortened lines never cut a character in half ("·", accented names).
- Roster rows drop the clock time when full is more than two days away ("~30% · Full in 27d 22h"), so the line never
  clips; the tooltip and the card keep it.
- The race emblem on offline portraits is only partly washed out and slightly lifted, so the race reads at a glance.
- Riding is no longer listed as a profession.
- Not changed: Unlink still acts at once, without a confirmation step (it is one click to link again).

Speech bubble (ILL-1276):

- The card's speech bubble never cuts a line short ("Give me 9 days 2..."): it wraps to as many lines as the line
  needs, in balanced lines without an orphan word, and grows down the stage. Only if it would reach the note under it
  does it drop one font step. It measures again a frame after the card opens, when ElvUI's wider font has settled.

Save my look (ILL-1279):

- On your own card (click the NOW PLAYING strip, or right-click it for a menu): "Save my look". Out of combat, the
  UI hides for about a second, your character stands alone on a dark backdrop, the game takes one .tga screenshot and
  everything comes back (Esc or a click cancels; combat, a failed shot or a loading screen also put everything back).
  It is refused while a merchant, bank, mailbox, quest, trade or similar window or a popup is open ("Close the merchant
  window first."), since hiding the UI would close it. Each save is about 8 MB; old screenshots in
  `_forever_\Screenshots` can be deleted.
- After a game restart, that character's portrait everywhere else (hero, rows, card, alerts, and on your linked
  account) is its own face, cropped from the screenshot into the usual ring. If the file is gone it quietly shows the
  class crest again. "Clear look" removes it. The character you are on always shows its live portrait.
- The hidden `/rlvl shotprobe` experiment is gone; what it found is in docs/API.md.

Save my look, round 2 (ILL-1279, from Andy's 1.1.1 run):

- Your own card frames the live model from the waist up in the right half of the stage, and the speech bubble stays in
  the left half: it ends, tail included, at least 12 px short of the figure (it ran into her head). Lines that need
  the room wrap instead. Same on everyone else's card, against their portrait. "Save my look" moved under the bubble.
- The shot is a still stand: the stand animation is frozen on its first frame with weapons sheathed and hidden, so it
  no longer catches an idle fidget (a shrug, eyes shut).
- Badges follow what is in the disc: a face (your live portrait or a saved look) gets the class crest as its badge; no
  face, the class crest is the picture and the race emblem the badge.
- A card line is no longer cut ("Feathermoon Stronghold...") when ElvUI's wider font settles after the card opens.
- The next-step line above NOW PLAYING fits whole: a smaller size or two lines, never under the button.

## 1.0.0 (unreleased)

First release.

- Roster of every character, sorted so the top one is the one to play next: full first (longest full on top), then
  nearly full, then most double XP banked, then empty, then max level / hidden (dimmed).
- State colours with a word and icon for each: green full, yellow 90%+, orange resting, red logged out outside.
- PLAY NEXT hero card, current-character strip (rested left, double-XP kills left, rested used this session).
- Character card: the character on a stage (an inn at night, or a cold road if parked outside), a speech line made
  from its own data, and tidbits (/played, hearth, gold, professions, guild, gear, ...).
- Cross-account sync between paired accounts: /rlvl link <Name> on both sides; nothing is sent to or accepted from
  an unpaired name.
- Scope for 1.0: no account filter (other accounts' rows carry an account tag) and the low-rest warning is fixed at
  10% of the cap.
- Cross-account roster through hidden addon messages between your own clients (same realm and faction).
- Alerts without popups: logging out outside a rested area (banner, sound, chat: move to cancel), a strip under the
  Esc menu, rested ran out (who's next), alts filling up, login digest, sleeping bag ready. Each can be turned off.
- Compact mode, LibDataBroker feed (ElvUI datatext), minimap button, Settings page, ElvUI options page.
- Default style, and an ElvUI style that goes through ElvUI's own skin functions (ElvUI_WC3 applies on top).
- Builds on Rested Watch by doc_biddle (GPL-3.0): projection, calibration, Well Rested rank reader, sleeping bag.
