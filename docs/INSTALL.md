# Installing Indic Keyboard on your iPhone — a beginner's guide

> ⚠️ **Status: alpha.** This app has just been built and **alpha testing is in progress**. Expect rough edges and changes. If something doesn't work, please open an [Issue](../../../issues) describing what happened.

This app is not on the App Store. You put it on your own iPhone yourself, using a free Apple program called **Xcode** on a Mac. You **don't** need to know how to code, and you **don't** need to pay Apple anything.

It takes about **30–60 minutes the first time**, mostly waiting for Xcode to download. After that, updating takes about 2 minutes.

> **Words used in this guide**
> - **Xcode**: Apple's free app for building iPhone apps. It runs only on a Mac.
> - **Project**: the folder of code you download from GitHub. Xcode opens it and turns it into an app.
> - **Build / Run**: Xcode turns the project into an app and copies it to your iPhone. The **▶ (Play) button** does this.
> - **Developer Mode**: a switch on the iPhone that allows apps that don't come from the App Store.
> - **Apple ID**: the email and password you already use for the App Store or iCloud.

---

## What you need

| | |
|---|---|
| 💻 **A Mac** | A recent macOS (Sonoma 14.5 or newer) and about **40 GB free disk space** for Xcode |
| 📱 **An iPhone or iPad** | iOS 16 or newer |
| 🔌 **A cable** | To connect the iPhone to the Mac (USB‑C or Lightning) |
| 🍎 **An Apple ID** | The one you already have is fine. You don't need a paid developer account |
| 🌐 **Internet** | Xcode is a large download (several GB) |

---

## Part 1 — Install Xcode (one time only)

1. On the Mac, open the **App Store** app.
2. Search for **Xcode**. It is by Apple and has a blue hammer icon.
3. Click **Get**, then **Install**. Enter your Apple ID password if asked.
   ⏳ *This can take 20–60 minutes. You can keep using the Mac while it downloads.*
4. When it finishes, open **Xcode** from the Launchpad or the Applications folder.
5. The first time, Xcode asks to install extra components. A window titled something like *"Select the platforms you want to develop for"* appears:
   - Make sure **iOS** is ticked.
   - Click **Download & Install**, or **Install**, and wait.
   - If it asks for your **Mac password** (the one you use to log in to the Mac), type it.
6. When you see the *"Welcome to Xcode"* window, Xcode is ready. You can close that window.

---

## Part 2 — Sign in to Xcode with your Apple ID (one time only)

1. With Xcode open, click **Xcode** in the menu bar at the very top‑left of the screen, then choose **Settings…** (on older versions it's called **Preferences…**).
2. Click the **Accounts** tab.
3. Click the small **+** button at the bottom‑left, choose **Apple ID**, and click **Continue**.
4. Sign in with your Apple ID email and password.
5. When you're signed in, your name appears in the list with **"Personal Team"** next to it. ✅
6. Close the Settings window.

---

## Part 3 — Download the keyboard project

1. On the project's GitHub page, click the green **`<> Code`** button.
2. Click **Download ZIP**.
3. Open your **Downloads** folder and double‑click the ZIP file to unzip it. You get a folder named something like **`IndicKeyboard-iOS-main`**.
4. *(Recommended)* Move that folder to your **Documents** folder so it doesn't get deleted by accident.
5. Open the folder and double‑click **`IndicKeyboard.xcodeproj`**. It has a blue icon.
   Xcode opens the project.
   - If macOS says the file was *downloaded from the Internet*, click **Open**.
   - If Xcode asks *"Do you trust and open IndicKeyboard?"*, click **Trust and Open**.

---

## Part 4 — Tell Xcode to sign the app with your Apple ID (one time only)

Apple only lets an app run on an iPhone when it is "signed" with someone's Apple ID. Here you tell Xcode to use yours.

1. In the **left sidebar** of Xcode, click the very top item, **IndicKeyboard**, the one with the blue icon.
2. In the middle of the window, under **TARGETS**, you'll see **IndicKeyboard**, **Keyboard** and **IndicKeyboardTests**.
3. Click **IndicKeyboard** under TARGETS.
4. Near the top of the middle area, click the **Signing & Capabilities** tab.
5. Make sure **Automatically manage signing** is ticked ✅.
6. Next to **Team**, open the drop‑down and choose **your name (Personal Team)**.
7. Look at **Bundle Identifier**. It says `com.ranjithkb.IndicKeyboard`. **Change `ranjithkb` to something unique to you**, for example your name with no spaces:
   ```
   com.yourname.IndicKeyboard
   ```
   *(Every app in the world needs its own identifier, and the original one is already taken.)*
8. Now click **Keyboard** under TARGETS and do the same three things:
   - ✅ **Automatically manage signing**
   - **Team** → your name (Personal Team)
   - **Bundle Identifier** → the **same name you used above plus `.Keyboard`**:
     ```
     com.yourname.IndicKeyboard.Keyboard
     ```
   ⚠️ The keyboard's identifier **must** be the app's identifier followed by `.Keyboard`. Otherwise iOS won't accept it.
9. You can ignore **IndicKeyboardTests**.

If a red error remains under *Signing*, see **Troubleshooting** at the end.

---

## Part 5 — Get your iPhone ready (one time only)

1. **Connect** the iPhone to the Mac with the cable and **unlock** the iPhone.
2. If the iPhone asks **"Trust This Computer?"**, tap **Trust** and enter your iPhone passcode.
3. In Xcode, at the **top centre** of the window there's a bar that shows where the app will run, for example *"IndicKeyboard › iPhone 16 Pro"*. Click the device name and choose **your iPhone** from the list. It is usually at the top, under *iOS Device*.
   - The first time, Xcode may say it is **"Preparing iPhone…"** or **"Copying shared cache"**. ⏳ Wait until it finishes, which can take 5–10 minutes.
4. **Turn on Developer Mode** on the iPhone:
   - On the iPhone, open **Settings → Privacy & Security**.
   - Scroll all the way to the bottom and tap **Developer Mode**.
     *(If you don't see it, make sure the iPhone is connected and selected in Xcode as in step 3, then close and reopen Settings.)*
   - Turn **Developer Mode** on. The iPhone asks to **restart**. Tap **Restart**.
   - After it restarts and you unlock it, a message asks **"Turn On Developer Mode?"**. Tap **Turn On** and enter your passcode.

---

## Part 6 — Install the app on your iPhone

1. Keep the iPhone connected and unlocked.
2. In Xcode, check that **IndicKeyboard** and **your iPhone** are shown in the bar at the top centre.
3. Press the **▶ (Play)** button at the top‑left of the Xcode window, or press **⌘ R** on the keyboard.
4. Xcode builds the app. You'll see *"Building…"* at the top. The first time takes a minute or two.
5. **The first time only**, the app won't open and the iPhone says something like **"Untrusted Developer"**. That's normal. Do this on the iPhone:
   - Open **Settings → General → VPN & Device Management**.
   - Under *Developer App*, tap **Apple Development: your‑email@…**.
   - Tap **Trust "Apple Development: …"**, then **Trust** again.
   - Go back to Xcode and press **▶** again.
6. The **Indic Keyboard** app opens on your iPhone. 🎉 Its icon is a blue key with **ര**.

You can now **unplug** the iPhone.

---

## Part 7 — Turn the keyboard on

1. On the iPhone, open **Settings → General → Keyboard → Keyboards**.
2. Tap **Add New Keyboard…**.
3. Under *Third‑Party Keyboards*, tap **Indic Keyboard**.
4. That's it. You **don't** need to turn on *Allow Full Access*. The keyboard works without it, and nothing you type leaves your phone.

### Using it

- In any app (Notes, WhatsApp, Messages…), tap a text box.
- Tap the **🌐 globe** key to switch keyboards, or **hold** it and choose **Indic Keyboard**.
- The key next to the space bar switches between layouts (for example **Swanalekha ⇄ English**). Its label shows the layout it will switch to next.
- Tap **⚙** at the top‑left of the keyboard to choose which layouts to use and to change settings.
- In Swanalekha, type Malayalam sounds in English letters: `malayaaLam` → മലയാളം, `njaan~` → ഞാൻ. Alternatives for the last letter appear in the bar above the keys.

---

## ⏰ Important: the 7‑day limit (free Apple ID)

With a free Apple ID, apps you install this way **stop opening after 7 days**. The keyboard disappears from the list or stops working. Nothing is lost, and the fix takes 1 minute:

1. Connect the iPhone to the Mac.
2. Open the project in Xcode (double‑click `IndicKeyboard.xcodeproj`).
3. Press **▶**.

This renews it for another 7 days. *(A paid Apple Developer account, $99 a year, makes it last a full year.)*

---

## Updating to a new version

1. Download the new ZIP from GitHub (Part 3) and unzip it.
2. Open the new `IndicKeyboard.xcodeproj`.
3. Repeat **Part 4**, using the **same identifiers** as before.
4. Connect the iPhone and press **▶**. Your keyboard settings are kept.

---

## Trying it without an iPhone (simulator)

Xcode includes a pretend iPhone that runs on the Mac.

1. In the bar at the top centre, choose a simulator such as **iPhone 16 Pro**.
2. Press **▶**. A virtual iPhone opens on the Mac.
3. In the virtual iPhone, open **Settings → General → Keyboard → Keyboards → Add New Keyboard → Indic Keyboard**.
4. Open the app, tap the text box, and switch keyboards with 🌐.

*(No Apple ID signing is needed for the simulator.)*

---

## Troubleshooting

| What you see | What to do |
|---|---|
| **"Failed to register bundle identifier"** or **"…is not available"** | The identifier is already used. Go back to **Part 4** and pick a more unique name, e.g. `com.yourname2026.IndicKeyboard` (and `….IndicKeyboard.Keyboard` for the keyboard). |
| **"Signing for 'Keyboard' requires a development team"** | You set the Team for one target but not the other. Do Part 4 for **both** IndicKeyboard and Keyboard. |
| **"Embedded binary's bundle identifier is not prefixed with the parent app's"** | The keyboard's identifier must be exactly the app's identifier + `.Keyboard`. |
| **"Developer Mode disabled"** or the iPhone isn't in Xcode's list | Do Part 5 step 4. Unplug and reconnect, unlock the phone, and tap **Trust** if asked. |
| **"Untrusted Developer"** on the iPhone | Part 6 step 5: Settings → General → VPN & Device Management → Trust. |
| **"Could not locate device support files"** or **"iOS version not supported"** | Your iPhone has a newer iOS than your Xcode knows about. Update Xcode from the App Store. |
| **"Your maximum App ID limit has been reached"** | Free accounts can create 10 identifiers a week. Wait a few days, or reuse identifiers you made before. |
| **"Unable to install … maximum number of apps"** | Free accounts can have 3 self‑installed apps on a phone at once. Delete one you don't use. |
| The app was working, and now it won't open | The 7 days are up. See **The 7‑day limit** above. |
| **Indic Keyboard** isn't in *Add New Keyboard…* | Open the Indic Keyboard app once, then look again. If it's still missing, restart the iPhone. |
| The keyboard doesn't appear in a password box | That's normal. iOS never allows third‑party keyboards in password fields. |
| Something else | Take a screenshot of the red error in Xcode and open an *Issue* on the GitHub page. |

---

*Indic Keyboard for iOS is a port of the open‑source Android [Indic Keyboard](https://gitlab.com/indicproject/Indic-Keyboard) by the Indic Project / SMC. See [README](../README.md) for credits and licences.*
