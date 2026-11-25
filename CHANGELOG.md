# Changelog

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
