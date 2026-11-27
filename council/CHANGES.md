# Round 2 of v1.1 (ILL-1272): answers council r1 (opus 7.0, sol 7.5, grok 7.2)

I grouped the requests by root cause. Everything below was asked for by at least two judges, unless a single judge is
named. The renders are the same 8 scenes.

## Changed

- **Move mode** (all three). Every placeholder has Reset in the same place, top right. The beige glow behind the text
  is gone: each placeholder is the real alert surface with a 2 px gold outline. The copy states the attachment: "Attached
  to the Esc menu. Drag to detach it." / "Custom position. Reset attaches it to the Esc menu again." The dimmed screen
  now sits above everything else, under the placeholders.
- **One alert surface** (opus, sol). The Esc menu card is now a top-level window like the banner and the toasts. It
  shows and hides with the menu and still hangs under it. The skin therefore dresses all three alike (scene 05). It was
  a flat grey panel before.
- **Banner copy** (all three). The title is "Cancel logout, then rest in an inn". The banner is wider, so "Hearth to
  Feathermoon Stronghold or find an inn, then log out." fits on one line with no empty line.
- **NOW PLAYING** (all three). The empty track and "0.0 of a level left" are gone. Under a twentieth of a level the bar
  hides and one line says "No rested XP: kills give normal XP". Under the name it says "Not banking: log out in an
  inn" (or "Banking rest here"). With rest left, the 13 px bar matches the roster's, with "0.4 levels left · ~12
  double-XP kills".
- **Hero** (all three). "#1 · PLAY NEXT" is a 13 px heading. The action reads as two ordered clauses: "First: hearth
  Le Jette to an inn. Then: play Le Dette." It is set in cream so the class-coloured names stand out. "Full since 1d
  16h ago: rest is going to waste." replaces the ambiguous "Full for". The state accent now shows under ElvUI too
  (opus). The figure is the same cream-gold in both themes (opus). The speech bubble is 14 px with more padding and
  sits clear of the badge.
- **Race/class badges** (all three). They are 17-24 px (was 14), on a dark disc with a bronze rim.
- **One chip family** (opus, sol, grok). Every chip has a near-black fill, a 1 px edge and the word in its state colour.
  NEARLY FULL is no longer olive, and RESTING no longer blends into a brown row.
- **Legend dots** (grok, opus). They are 10 px with a dark ring.
- **Rows** (opus, sol). The default rows are darker (#251D14 / #2B2218) with a lighter outside tint. Names have a dark
  shadow, so shaman blue reads on the red-tinted row. There are 7 px between each bar and its time.
- **Footer** (all three). One row. The status fits on one line ("Paired: Le Bankken · synced 3h ago"), next to the
  Unlink button. The account button is narrower.
- **Timeline** (all three). Dates for lanes that fill after 48 h sit in a 112 px right gutter, never on the bar. Those
  bars stay solid to the edge and end in an arrow cap (sol). Night bands are quieter. Hour labels are lighter, and
  midnight shows the date ("Wed 25"). The hover tooltip opens left of the window so it never covers the dates.
- **Options page** (all three). It has its own near-black panel. Gold headings (APPEARANCE, ACCOUNTS, LOW REST
  WARNING · 10%, NOTIFICATIONS, WINDOW AND DISPLAY, ALERTS) separate cream settings and softer helper lines; no yellow
  paragraphs. The style choices are evenly spaced. The slider has a visible thumb. The About line is short and fits.
- **Character card** (opus, sol, grok). With a saved look, the "Last seen as ..." note is gone: the meta line already
  says who it is. The sleep "z z Z" is 14 px and sits over the portrait's top right.

## DECLINED

- **The stray bar and grey square in move mode** (opus, grok) are ElvUI's own frames in the simulator. The brief
  forbids touching ElvUI frames. The dimmed screen now covers everything it is allowed to.
- **Gatewood dialog art on the roster, the options page and the compact tip's header, and the "seam" in the window
  frame** (grok, opus, sol) come from the WC3 skin's own art. WC3-specific code is out of scope. Our frames go
  through ElvUI's skin calls, and all three alerts now get the same treatment.
- **UIPanelButtonTemplate stone buttons and a classic gold dialog for the default theme** (grok) would change the
  settled default chrome (oak and bronze). The other two judges did not ask for it.
- **A "Play Le Dette" button** (grok): an addon cannot switch characters. The action line names who to play.
- **Opus: "Le Beouf's roster row shows the class icon"**: row 7 already shows his saved face with the class crest as
  its badge (scenes 01 and 02). **Opus: NOW PLAYING shows a class icon**: the simulator draws no live portrait; in game
  it is `SetPortraitTexture("player")`.
- **Not done this round (one judge each):** the compressed 48 h to 10 d tail (opus), the "Ding" sound (opus), the
  hover shimmer (opus), the account pill (opus), the toast's rail colour (sol), and the card's bar inside the stage box
  (opus).

## Checks

- `lua5.1 tests/run.lua`: all pass. luacheck is clean. tools/apicheck.py: 0 unverified, at every layer.
- All 8 renders come from the real addon in wow-ui-sim. 04 is the full-screen context shot; the others are 1:1 crops.
