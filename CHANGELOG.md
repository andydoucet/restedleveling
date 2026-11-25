# Changelog

## Unreleased

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
