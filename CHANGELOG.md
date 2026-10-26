# Changelog

All notable changes to Indic Keyboard for iOS. Versions follow [Semantic Versioning](https://semver.org); each release is tagged in git (`v0.1.0`, `v0.1.1`, …).

## [0.4.2] — 2026-10-26
### Added
- **Speed check** in the keyboard's ⚙ panel: average and worst times for the keyboard's own work per key, the app's reply, and the suggestion bar. Only timings are kept, never text.
### Fixed
- Taps no longer wait for the suggestion bar. Measured on an iPhone 15, the keyboard's own work was under 1 ms per key, but refreshing the bar took 8 ms on average and up to 36 ms. At normal typing speed that refresh landed between keys, so the next tap had to wait. Now:
  - English spell-checking runs on a background queue, and an out-of-date answer is dropped.
  - The bar keeps its buttons and only changes their text instead of rebuilding them.
  - The bar refreshes after 40 ms instead of 70 ms, since it no longer holds up typing.
- Light/dark mode is only reapplied when it actually changes, instead of after every edit (which could redraw every key).

## [0.4.1] — 2026-10-26
### Fixed
- Quick repeated taps ("aa", "ll") and keys at the screen edges (a, q, z, the bottom row) responded late. iOS held back the *end* of touches near the edges while it checked for its own swipe gestures, and keys type when the finger lifts. The keyboard now stops that delay too, not only the delay at the start of a touch, and asks iOS to let keys win over edge swipes.
- The suggestion bar now updates after a short pause in typing (70 ms) instead of after every key, so the spell checker no longer runs between two quick taps.

## [0.4.0] — 2026-10-26
### Added
- **English (India), Manglish-friendly.** The English keyboard now uses Apple's Indian English dictionary when the phone has it, and it no longer autocorrects Malayalam typed in English letters. It knows about 660 common Manglish words and their spellings (enthu, alle, machane, evide, kollaam, pwoli…), including stretched ones like enthaaa. It also skips words with spellings English rarely uses (aa, ii, uu, zh, and endings like -nnu, -ille, -aano, -yude).
- Manglish completions in the suggestion bar: type *mach* and it offers *machane*.
- New setting **Leave Manglish alone** (on by default) in the keyboard's ⚙ panel.
### Changed
- If you undo a correction with backspace, the keyboard now remembers that word permanently, not just until the keyboard restarts.

## [0.3.6] — 2026-10-26
### Fixed
- Switching from Swanalekha to English no longer turns on Shift in the middle of a sentence. The keyboard now counts the Malayalam word it has just written instead of trusting the text field's context, which is still empty for a moment after the switch.
### Changed
- Capital letters on the keys are drawn smaller (21 pt instead of 25) so they sit inside the key like on Apple's keyboard, in English and Swanalekha.

## [0.3.5] — 2026-10-26
### Fixed
- No more separate rounded strip above the suggestion bar on iOS 26. iOS 26 draws its own glass panel around every keyboard, with a little padding above the keys that apps can't draw into. Our grey background didn't match that panel, so the padding showed as a stripe. On iOS 26 the keyboard background is now transparent and blends into the system panel; older iOS versions keep the grey background.
- The emoji and settings panels now hide the keys and the bar behind them, so nothing shows through the transparent background.

## [0.3.4] — 2026-10-26

### Changed
- Thinner bar above the keys (32 pt, was 38; 26 pt in landscape) when iOS grants less than the requested height, so keys get about 41 pt on an iPhone 15. Suggestion buttons fill more of the bar so they stay easy to tap.

## [0.3.3] — 2026-10-26

### Fixed
- **Keys were smaller than the iPhone keyboard's.** iOS 26 decides a third-party keyboard's height itself and ignores the height the keyboard asks for (tested: constraints at every priority, set at load / before / after appearing, self-sizing input view, intrinsic size, `preferredContentSize` — iOS keeps its own `UIView-Encapsulated-Layout-Height`, 216 pt in the simulator and about 231 pt on an iPhone 15, against about 258 pt for Apple's keyboard). Previously everything was scaled down evenly to fit, so keys shrank to about 37 pt. Now the bar above the keys gets slimmer and the gaps tighter first, keeping the keys as tall as possible: **about 40 pt on an iPhone 15** (Apple's are 42 pt).
- Removed the self-sizing / intrinsic-size code added in 0.3.2: it did not help and is not needed. The keyboard still asks for its full height (at a lower priority, as early as possible) in case a future iOS honours it.

### Notes
- The text box staying above the keyboard (0.3.2) works: the keyboard's height no longer changes while it is on screen, so apps place the text box correctly.

## [0.3.2] — 2026-10-26

### Fixed
- **Keyboard could cover the text box** in some apps. The keyboard now tells iOS its full height before it appears (self-sizing input view plus a height constraint set when it loads), so apps can place the text box above it from the start instead of after it has grown.
- **The keyboard no longer changes height** when switching layouts or opening emoji or settings. The height is now fixed per orientation, and 5-row layouts (InScript and others) fit their keys into the same height.

### Changed
- Asked iOS for slightly taller keys (45 pt). iOS 26 turned out not to grant the extra height; see 0.3.3.
- **The bar above the keys shows just ⚙ when idle.** The layout name is no longer printed next to it; the space bar already shows which layout is on.

## [0.3.1] — 2026-10-26

### Added
- **App icon**: a ര keycap above a row of keys, on blue. Drawn by `tools/make_icon.swift`.
- **[docs/INSTALL.md](docs/INSTALL.md)**: a step-by-step install guide for people new to Xcode, covering Xcode, Apple ID signing, Developer Mode, trusting the developer, enabling the keyboard, the 7-day limit, updating, the simulator and troubleshooting.

### Fixed
- **Emoji panel's top row looked faded.** iOS 26 adds a soft fade ("scroll edge effect") to the edges of scrolling views. It is now turned off for the emoji grid, the suggestion bar and the settings list, so they stay crisp.
- **Keys felt slower than the Apple keyboard.**
  - iOS was holding touches near the screen edges (bottom row, `q`, `p`, shift, delete) while it checked for system gestures. The keyboard now tells iOS not to delay its touches.
  - Suggestions (spell checker, transliteration alternatives) are now worked out right after each keystroke has gone to the app, instead of before, so typing never waits for them.
  - Key and pop-up shadows use precomputed outlines, so drawing a key press is cheaper.

## [0.3.0] — 2026-10-26

### Added
- **Emoji keyboard** (😊 key in the bottom row): iOS-style horizontally scrolling grid, 8 categories plus *Frequently Used* (remembered on device), category bar with ABC and delete (hold to repeat). Data: 1,906 emoji from Unicode emoji data via `unicode-emoji-json` 0.8.0.
- **English word suggestions** in the bar above the keys while typing in the English layout: three iOS-style slots — “typed word” | **correction** | suggestion. Uses Apple's on-device `UITextChecker`; no Full Access, nothing leaves the phone.
- **English auto-correction** on space, return and punctuation, with distance limits so only near misses are changed (`teh` → `the`, `dont` → `don't`, `i` → `I`). **Backspace right after a correction restores what you typed** and stops correcting that word.
- Your iOS **Text Replacements** (Settings → General → Keyboard) work as shortcuts.
- **"." shortcut**: double-tap space for a full stop and space.
- Settings panel switches for *Auto-Correction*, *Predictive* and *"." Shortcut*.
- Blue return key for *send / search / go / done* fields, like the system keyboard.
- Extra symbols on long press in the 123 page (`₹` → `$ € £ ¥ ₩`, `.` → `…`, `'` → `’ ‘ ` `` ` ``).

### Changed
- **Key geometry matches the iOS keyboard**: 3 pt side margins, 6 pt between keys, ~42 pt keys and 12 pt row gaps in portrait, second row indented, shift and delete pinned to the edges with the letters centred, continuous rounded corners (8.5 pt on iOS 26+).
- Shift, delete, globe and emoji keys use SF Symbols (`shift`, `shift.fill`, `capslock.fill`, `delete.left`, `globe`, `face.smiling`).
- Key views are reused when only labels change (shift, page switch), so the keyboard no longer rebuilds on every keystroke.
- Space bar reads “space” in English and the layout name otherwise.

### Fixed
- Bottom row (123 / emoji / space / return) could be cut off when iOS granted less height than requested: the height constraint is now installed once the keyboard is on screen, and keys scale to fit whatever height is granted.

## [0.2.0] — 2026-10-26

### Added
- **`~` key on the main letter page** for Swanalekha and Mozhi (next to `m`), so chillu letters can be typed without switching pages (`njaan~` → ഞാൻ, `avaL~` → അവൾ). Long press gives `_` and `^`, which Swanalekha also uses.

## [0.1.1] — 2026-10-26

### Fixed
- **Mozhi (ലിപ്യന്തരണം) produced garbled output** such as `മല$1ാ$1ം` for *malayaaLam*. Converting jquery.ime replacement templates iterated over Swift `Character`s, and a group reference followed by a combining vowel sign (`$1ാ`) formed a single grapheme cluster, so `$1` was never recognised. Templates are now processed per Unicode scalar. Found by the new command-line engine check (`tools/enginecheck`): all 125 golden checks pass.

### Added
- `tools/enginecheck` — builds the shared engines with `swiftc` and compares them with the Python reference on 40 test words.
- `tools/build_data.sh` — regenerates every data file from the upstream repositories.

## [0.1.0] — 2026-10-26

First version: a port of the Android [Indic Keyboard](https://gitlab.com/indicproject/Indic-Keyboard) (SMC / Indic Project) to an iOS custom keyboard.

### Added
- Container app (SwiftUI): setup steps, “Try it” field, Swanalekha quick guide, layout list and credits.
- Keyboard extension (UIKit) with its own touch handling: key previews, long-press alternatives, touch roll-over, backspace repeat, shift / caps lock, 123 and #+= pages, globe key when iOS needs it.
- **Swanalekha** transliteration (default) from SMC's official rule table (2,162 rules), with the Tab alternatives shown in the bar above the keys (`ka` → ക / ഗ / ഖ / ഘ).
- **Mozhi-style ലിപ്യന്തരണം** via a jquery.ime rule engine (316 rules).
- **Direct Malayalam layouts** converted from the Android XML: Lalitha, Compact, Mobile InScript, InScript, Poorna InScript.
- English QWERTY with sentence auto-capitalisation.
- Layout key to cycle enabled layouts; ⚙ panel (or hold the layout key / space) to enable layouts and change settings.
- Word shown underlined while composing, with a setting to write directly for apps that mishandle marked text.
- Everything layout-related is data (`Shared/Resources`), produced by converters in `tools/`.
- Unit tests against `Tests/golden.json`, generated by the Python reference engine.
