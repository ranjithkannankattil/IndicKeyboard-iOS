# Indic Keyboard for iOS

An iOS port of [Indic Keyboard](https://gitlab.com/indicproject/Indic-Keyboard) (SMC / Indic Project) for Malayalam: one app you install, then enable as a system keyboard, like on Android.

**Layouts:** Swanalekha (default), English, Mozhi-style ലിപ്യന്തരണം, and the Android app's direct layouts: Lalitha, Compact, Mobile InScript, InScript and Poorna InScript.

## Install on your iPhone

1. Open `IndicKeyboard.xcodeproj` in Xcode.
2. Click the **IndicKeyboard** project → for **both** the `IndicKeyboard` and `Keyboard` targets: *Signing & Capabilities* → *Team* → your Apple ID (add it under Xcode → Settings → Accounts).
   - If Xcode says the bundle identifier is taken, change `com.ranjithkb` in both targets. The keyboard's ID must start with the app's ID.
3. Connect your iPhone (turn on *Developer Mode*: Settings → Privacy & Security), choose it as the destination, and press ▶︎ with the **IndicKeyboard** scheme.
4. On the phone, first time only: *Settings → General → VPN & Device Management* → trust your developer certificate.
5. *Settings → General → Keyboard → Keyboards → Add New Keyboard… → Indic Keyboard*.
6. In any app, hold 🌐 and pick Indic Keyboard.

With a free Apple ID the app stops launching after 7 days; press ▶︎ again to refresh it.

## Using it

- **Layout key** (next to 🌐): cycles your enabled layouts; its label shows where it goes next (`EN`, `സ്വ`).
- **Hold the layout key or space bar, or tap ⚙**: choose and enable layouts, settings.
- **Candidate bar** in Swanalekha: alternatives for the last letter (what Tab does on desktop), e.g. `njaan` → ഞാന് / ഞാൻ. Tap the bold word to accept, the grey Latin word to type it in English.
- Space runs Swanalekha's space rules (`malayaaLam␣` → മലയാളം).
- Direct layouts: hold a key for its extra letters, as on Android.
- If an app loses or doubles letters, turn off *Underline word while typing* in ⚙.

## Checking the engines

```
swiftc -O Shared/Engine/*.swift tools/enginecheck/main.swift -o build/ec/enginecheck
cp Shared/Resources/catalog.json Shared/Resources/*/*.json Tests/golden.json build/ec/ && build/ec/enginecheck
```
Compares the Swift engines with the Python reference (`tools/engine_prototype.py`) on 40 words. The same checks exist as XCTest (`Tests/`), but Xcode 27's runner can hang on host-less iOS test bundles, so the command above is the reliable route.

## Updating or adding layouts

- `tools/build_data.sh <folder with swanalekha/, Indic-Keyboard/, jquery.ime/ clones>` regenerates all data from upstream.
- New jquery.ime scheme: `node tools/convert_jqueryime.js <rules.js> Shared/Resources/Schemes/<id>.json`, then add it to `Shared/Resources/catalog.json`.
- New Android direct layout: add it to `LAYOUTS` in `tools/convert_android_layouts.py`.
- `python3 tools/gen_xcodeproj.py` regenerates the Xcode project (`BUNDLE_PREFIX=…` and `DEVELOPMENT_TEAM=…` env vars supported).

## Not in this version

Word suggestions/learning (Android's dictionaries and Varnam), gesture typing, emoji, voice. iOS doesn't allow third-party keyboards in password fields.

## Licences

Indic Keyboard and its direct layouts: Apache 2.0. Swanalekha rules: MIT (Santhosh Thottingal). `ml-transliteration` rules: GPLv3 (Wikimedia jquery.ime). Fine for personal use; **remove `Schemes/ml-transliteration.json` and its catalog entry before an App Store release.** Texts in `LICENSES/`.
