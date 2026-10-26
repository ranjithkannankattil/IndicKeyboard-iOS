//  KeyboardSettings.swift
//  Settings live inside the keyboard extension (edited from the keyboard's ⚙ panel),
//  so they work without Full Access or an App Group.

import Foundation

public final class KeyboardSettings {
    public static let shared = KeyboardSettings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "enabledLayouts"
        static let current = "currentLayout"
        static let underline = "underlineWhileComposing"
        static let clicks = "keyClicks"
    }

    /// Enabled layout ids, in catalog order. Never empty.
    public var enabledLayouts: [String] {
        get {
            let stored = defaults.stringArray(forKey: Key.enabled) ?? LayoutCatalog.defaultEnabled
            let valid = LayoutCatalog.all.map(\.id).filter { stored.contains($0) }
            return valid.isEmpty ? [LayoutCatalog.all.first?.id ?? "en"] : valid
        }
        set {
            let v = newValue.isEmpty ? [LayoutCatalog.all.first?.id ?? "en"] : newValue
            defaults.set(v, forKey: Key.enabled)
        }
    }

    public var currentLayout: String {
        get {
            let enabled = enabledLayouts
            if let c = defaults.string(forKey: Key.current), enabled.contains(c) { return c }
            return enabled[0]
        }
        set { defaults.set(newValue, forKey: Key.current) }
    }

    /// true: the word being typed is shown underlined (marked text) until committed, like Android's composing text.
    /// false: text is written directly; use this for apps that handle marked text badly.
    public var underlineWhileComposing: Bool {
        get { defaults.object(forKey: Key.underline) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.underline) }
    }

    public var keyClicks: Bool {
        get { defaults.object(forKey: Key.clicks) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.clicks) }
    }

    public func setEnabled(_ id: String, _ on: Bool) {
        var set = Set(enabledLayouts)
        if on { set.insert(id) } else { set.remove(id) }
        if set.isEmpty { return }  // keep at least one
        enabledLayouts = LayoutCatalog.all.map(\.id).filter { set.contains($0) }
    }
}
