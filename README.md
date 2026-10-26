# Indic Keyboard for iOS

A Malayalam keyboard for iPhone and iPad, ported from the open-source Android [Indic Keyboard](https://gitlab.com/indicproject/Indic-Keyboard) by the Indic Project / Swathanthra Malayalam Computing (SMC). It installs like any app and is then enabled as a system keyboard.

> ⚠️ **Status: alpha.** This app has just been built and **alpha testing is in progress**. Expect rough edges and changes. If something doesn't work, please open an [Issue](../../issues) describing what happened.

**Current version: 0.4.0 (alpha)** — see [CHANGELOG.md](CHANGELOG.md) for every version and change.

## How do I get it on my iPhone?

**Short answer: you need a Mac, a free Apple ID and about 30–60 minutes.** It's free, and you don't need to know how to code.

- ❌ **There is no file to download and tap.** iPhones don't allow installing apps from downloaded files. Apps come from the App Store, from TestFlight, or are built yourself.
- ❌ **It is not on the App Store yet.** It's still in alpha testing.
- ✅ **You can install it yourself:** download this project, open it in Apple's free **Xcode** app on a Mac, plug in your iPhone and press ▶. Xcode builds the app and puts it on your phone.

### 👉 Follow the step-by-step guide: [docs/INSTALL.md](docs/INSTALL.md)

It explains every click, from installing Xcode to turning the keyboard on, plus what to do if something goes wrong.

| You have… | Can you use it? |
|---|---|
| Mac + iPhone/iPad (iOS 16 or newer) | ✅ Yes, follow the guide |
| Only an iPhone, no Mac | ❌ Not yet. Ask a friend with a Mac to install it for you, or wait for an App Store / TestFlight release |
| An Android phone | Use the original [Indic Keyboard](https://f-droid.org/en/packages/org.smc.inputmethod.indic/) from F-Droid |

*With a free Apple ID, the app needs re-installing from Xcode every 7 days (one click). A paid Apple Developer account removes this.*

## Features

- **Swanalekha** phonetic typing (default), using SMC's official rules, with the alternatives for the last letter in the bar above the keys (`ka` → ക ഗ ഖ ഘ) and a `~` key for chillu (`njaan~` → ഞാൻ).
- **Mozhi-style ലിപ്യന്തരണം** transliteration.
- **Direct Malayalam layouts** from the Android app: Lalitha, Compact, Mobile InScript, InScript, Poorna InScript (hold a key for its extra letters).
- **English** QWERTY with **word suggestions** and **auto-correction** (Apple's on-device spell checker; backspace undoes a correction), sentence capitals and the double-space full stop.
- **Emoji keyboard** with categories and Frequently Used.
- Key sizes and spacing modelled on the iOS keyboard; light and dark mode.
- No Full Access needed — nothing you type leaves the phone.

## Install on your iPhone

> **New to Xcode or iPhone development?** Follow the detailed step‑by‑step guide:
> ### 👉 [docs/INSTALL.md — Installing Indic Keyboard, a beginner's guide](docs/INSTALL.md)

The short version, if you've done this before:

1. Open `IndicKeyboard.xcodeproj` in Xcode 16 or newer.
2. For **both** the `IndicKeyboard` and `Keyboard` targets: *Signing & Capabilities* → *Team* → your Apple ID, and change `com.ranjithkb` in the bundle identifiers to your own (the keyboard's ID must be the app's ID + `.Keyboard`).
3. Connect the iPhone (Developer Mode on: Settings → Privacy & Security), choose it as the destination, press ▶︎.
4. First time only: *Settings → General → VPN & Device Management* → trust your certificate.
5. *Settings → General → Keyboard → Keyboards → Add New Keyboard… → Indic Keyboard*, then hold 🌐 in any app.

With a free Apple ID the app must be re-run from Xcode every 7 days.

## Using it

| Key / gesture | Does |
|---|---|
| Layout key (next to space) | Cycles enabled layouts; label shows the next one (`EN`, `സ്വ`) |
| Hold layout key or space, or tap ⚙ | Choose layouts, settings |
| 😊 | Emoji keyboard (ABC to return) |
| Bar above keys | Swanalekha: tap an alternative to swap the last letter, the bold word to accept, the grey Latin word to type it as is. English: “typed” · **correction** · suggestion |
| Backspace after an autocorrection | Restores what you typed |
| Double-tap space | “. ” |

Settings (⚙): layouts on/off, *Underline word while typing*, *Auto-Correction*, *Predictive*, *"." Shortcut*, *Key clicks*.

## Project

- [docs/INSTALL.md](docs/INSTALL.md) — beginner's install guide.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how it fits together, typing pipeline, geometry, data sources.
- [CHANGELOG.md](CHANGELOG.md) — version history.
- `tools/build_data.sh` — regenerate all layout data from upstream.
- `tools/make_icon.swift` — draws the app icon (`swift tools/make_icon.swift App/Assets.xcassets/AppIcon.appiconset/AppIcon.png`).
- `tools/make_emoji.py` — regenerates the emoji data.
- `tools/enginecheck` — quick check of the transliteration engines on the Mac.
- `python3 tools/gen_xcodeproj.py` — regenerate the Xcode project (`BUNDLE_PREFIX`, `DEVELOPMENT_TEAM` env vars).

## Not yet

Malayalam word prediction (the Android app's dictionaries / Varnam), gesture typing, voice input. iOS never shows third-party keyboards in password fields.

## Credits and licences

- Indic Keyboard and its Malayalam layouts — Indic Project, SMC, Jishnu Mohan, ICFOSS — Apache 2.0
- Swanalekha — Santhosh Thottingal — MIT
- `ml-transliteration` rules — Junaid P V, Wikimedia jquery.ime — GPLv3. **Remove `Shared/Resources/Schemes/ml-transliteration.json` and its catalog entry before publishing on the App Store.**
- Emoji data — `unicode-emoji-json` (Unicode data) — MIT

Licence texts are in [LICENSES/](LICENSES).
