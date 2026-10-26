//  ContentView.swift

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var testText = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var isEnabled = KeyboardStatus.isEnabled()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "keyboard")
                            .font(.title2)
                            .foregroundStyle(isEnabled ? Color.green : Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isEnabled ? "Keyboard is enabled" : "Keyboard not enabled yet")
                                .font(.headline)
                            Text(isEnabled ? "Switch to it with the 🌐 key in any app."
                                           : "Follow the three steps below.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Set up") {
                    Step(n: 1, text: "Open Settings → General → Keyboard → Keyboards")
                    Step(n: 2, text: "Tap Add New Keyboard… and choose Indic Keyboard")
                    Step(n: 3, text: "In any app, hold 🌐 and pick Indic Keyboard")
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }
                    Text("Full Access is not needed. The keyboard never leaves your phone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Try it") {
                    TextField("Type here…", text: $testText, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.title3)
                }

                Section("Using the keyboard") {
                    Tip(icon: "globe", text: "The layout key (next to 🌐) switches between your layouts, e.g. സ്വ ↔ EN.")
                    Tip(icon: "hand.tap", text: "Hold the layout key or the space bar, or tap ⚙, to choose layouts and settings.")
                    Tip(icon: "text.cursor", text: "While typing, the bar above the keys shows alternatives: tap one to swap the last letter, the bold word to accept, or the grey Latin word to type it in English.")
                }

                Section("Swanalekha quick guide") {
                    ForEach(SwanalekhaGuide.examples, id: \.0) { ex in
                        HStack {
                            Text(ex.0).font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(ex.1).font(.title3)
                        }
                    }
                    Link("Full Swanalekha scheme", destination: URL(string: "https://swanalekha.smc.org.in/")!)
                }

                Section("Layouts included") {
                    ForEach(LayoutCatalog.all) { l in
                        VStack(alignment: .leading) {
                            Text(l.name)
                            Text(l.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Credits") {
                    Text("Ported from Indic Keyboard by the Indic Project / SMC (Apache 2.0). Swanalekha by Santhosh Thottingal (MIT). Malayalam transliteration rules from Wikimedia jquery.ime by Junaid P V (GPLv3). Direct layouts by Jishnu Mohan, SMC & ICFOSS (Apache 2.0).")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Indic Keyboard")
        }
        .onChange(of: scenePhase) { _ in isEnabled = KeyboardStatus.isEnabled() }
    }
}

private struct Step: View {
    let n: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.subheadline.bold())
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(text)
        }
    }
}

private struct Tip: View {
    let icon: String
    let text: String
    var body: some View {
        Label { Text(text) } icon: { Image(systemName: icon) }
    }
}

enum SwanalekhaGuide {
    static let examples: [(String, String)] = [
        ("malayaaLam", "മലയാളമ്"),
        ("malayaaLam␣", "മലയാളം"),
        ("ente", "എന്റെ"),
        ("njaan~", "ഞാൻ"),
        ("avaL~", "അവൾ"),
        ("kaaR~", "കാർ"),
        ("nanni", "നന്നി"),
        ("kshamikkuka", "ക്ഷമിക്കുക"),
        ("ka → tap alt.", "ഗ · ഖ · ഘ"),
    ]
}

enum KeyboardStatus {
    /// Best-effort check of whether our keyboard has been added in Settings.
    static func isEnabled() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let keyboards = UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String] ?? []
        return keyboards.contains { $0.hasPrefix(id + ".") }
    }
}
