# Architecture

## Targets

| Target | What it is |
|---|---|
| `IndicKeyboard` | Container app (SwiftUI). Setup guide, test field, credits. Embeds the keyboard. |
| `Keyboard` | The keyboard extension (`com.apple.keyboard-service`), UIKit. Does not request Full Access. |
| `IndicKeyboardTests` | XCTest bundle for the engines. |

`Shared/` is compiled into all three (Xcode 16 synchronised folders, so new files are picked up automatically).

## Source map

```
App/                       container app
Keyboard/
  KeyboardViewController   entry point: layouts, typing, shift, pages, candidates, panels
  KeysView                 key grid: iOS geometry (KeyMetrics), drawing, touch tracking, popups
  KeyModel                 which keys exist on each page (KeySpec, KeyboardRows)
  Composer                 the word being composed → document (marked text or direct edits)
  CandidateBar             bar above the keys (English slots / Swanalekha alternatives / idle ⚙)
  EnglishSuggester         UITextChecker predictions + autocorrection
  EmojiPanel               emoji keyboard
  SettingsPanel            in-keyboard settings
Shared/
  Engine/Engines.swift     SwanalekhaEngine, JQueryIMEEngine, EngineLoader, ResourceLocator
  Engine/LayoutCatalog     catalog.json + direct layouts
  Engine/KeyboardSettings  UserDefaults-backed settings
  Resources/               catalog.json, Schemes/*.json, Layouts/*.json, emoji.json
Tests/                     EngineTests + golden.json
tools/                     converters, Python reference engine, project generator, engine check
```

## Typing pipeline

**Transliteration layouts (Swanalekha, Mozhi).** Latin keys go into `Composer.keys`. After each key the engine maps the *whole word's* keys to output (`engine.output(for:)`), and the composer replaces what it previously showed. By default the word is shown as marked (underlined) text — the iOS equivalent of Android's composing region — and committed on space, return, punctuation or a candidate tap. With *Underline word while typing* off, the composer edits the document directly: it deletes only the part that changed and re-inserts the rest, measuring each `deleteBackward()` because apps differ in whether it removes a code point or a whole grapheme cluster.

- *Swanalekha* is a greedy longest-match over a key → output table (max pattern length 5). Alternatives are the same pattern with `2`, `3`, … appended, which is what Tab cycles through on desktop.
- *jquery.ime* rules are regex patterns with optional key context, applied exactly like jquery.ime's `keypress` handler. States are cached per prefix so each extra key runs the rules once.

**Direct layouts** insert the key's output immediately.

**English** inserts letters directly. The bar reads the word before the cursor from `documentContextBeforeInput` and asks `EnglishSuggester` for a correction and completions. On space / return / punctuation the correction (if any) replaces the word; `lastCorrection` remembers it so the next backspace can undo it.

## Geometry

`KeyMetrics` holds the iOS numbers (side inset 3, key gap 6, key height 42, row gap 12, top inset 10 in portrait; smaller in landscape and for 5-row layouts). All letter rows share one key width — the widest row decides it — so rows line up like the system keyboard; character keys are centred (which produces the second-row indent) and shift / delete / page keys are pinned to the edges. The bottom row uses standard-key units with the space bar taking the remainder. If iOS grants less height than requested, all vertical metrics are scaled down proportionally.

## Data and provenance

| File | Source | Licence |
|---|---|---|
| `Schemes/ml-swanalekha.json` | `smc/swanalekha` `js/src/rules.json` | MIT |
| `Schemes/ml-transliteration.json` | `wikimedia/jquery.ime` `rules/ml/ml-transliteration.js` | GPLv3 |
| `Layouts/*.json` | Indic Keyboard `java/res/xml/rowkeys_malayalam*.xml` | Apache 2.0 |
| `emoji.json` | `unicode-emoji-json` 0.8.0 | MIT (Unicode data) |

`tools/build_data.sh <dir with the three clones>` regenerates the scheme and layout files and `Tests/golden.json`; `tools/make_emoji.py` builds `emoji.json`.

## Verification

- `tools/engine_prototype.py` is the reference implementation; `tools/build_data.sh` writes `Tests/golden.json` from it.
- `tools/enginecheck` compiles `Shared/Engine` with `swiftc` and checks it against `golden.json` on the Mac (fast, no simulator).
- `Tests/EngineTests.swift` runs the same checks under XCTest.
- Launch the app with `-focusTestField` to open the keyboard immediately — used for simulator screenshots.
