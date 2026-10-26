//  KeyModel.swift
//  What keys exist on each page. Widths are in "letter key" units; KeysView turns
//  them into iOS-like geometry.

import UIKit

enum KeyAction: Equatable {
    case character(String)      // a letter/symbol key
    case shift
    case backspace
    case space
    case returnKey
    case nextLayout             // cycles our own layouts; long-press lists them
    case globe                  // the system "next keyboard" key
    case emoji                  // opens the emoji panel
    case page(KeyPage)
}

enum KeyPage: Equatable { case letters, numbers, symbols }

enum ShiftState { case off, on, locked }

struct KeySpec: Equatable {
    var label: String
    var hint: String? = nil
    var action: KeyAction
    var more: [String] = []
    var width: CGFloat = 1          // in letter-key units
    var isFunction: Bool = false    // drawn with the darker function-key colour
    var flexible: Bool = false      // takes the leftover width of its row (space bar)
    var symbol: String? = nil       // SF Symbol drawn instead of the label
    var isAccent: Bool = false      // blue return key (send, search, go …)
}

enum KeyboardRows {
    static let qwerty = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

    /// Letter rows for English / transliteration layouts.
    /// Transliteration layouts get a ~ key after m (Swanalekha chillu: njaan~ → ഞാൻ),
    /// with _ and ^ on long press.
    static func latin(shift: ShiftState, transliteration: Bool = false) -> [[KeySpec]] {
        var rows = qwerty.map { row in
            row.map { ch -> KeySpec in
                let s = shift == .off ? String(ch) : String(ch).uppercased()
                return KeySpec(label: s, action: .character(s))
            }
        }
        if transliteration {
            rows[2].append(KeySpec(label: "~", hint: "_^", action: .character("~"), more: ["_", "^"]))
        }
        rows[2].insert(shiftKey(shift), at: 0)
        rows[2].append(backspaceKey)
        return rows
    }

    /// Letter rows for a direct Malayalam layout converted from the Android app.
    static func direct(_ layout: DirectLayout, shift: ShiftState) -> [[KeySpec]] {
        let src = shift == .off ? layout.rows : layout.shiftedRows
        var rows: [[KeySpec]] = []
        for (i, row) in src.enumerated() {
            var keys = row.map { k in
                KeySpec(label: k.label, hint: k.hint, action: .character(k.output), more: k.more)
            }
            let flags = i < layout.rowFlags.count ? layout.rowFlags[i] : DirectLayout.RowFlags(shift: false, delete: false)
            if flags.shift && layout.hasShift { keys.insert(shiftKey(shift), at: 0) }
            if flags.delete { keys.append(backspaceKey) }
            rows.append(keys)
        }
        if !rows.contains(where: { $0.contains { $0.action == .backspace } }), !rows.isEmpty {
            rows[rows.count - 1].append(backspaceKey)
        }
        if layout.hasShift, !rows.contains(where: { $0.contains { $0.action == .shift } }), !rows.isEmpty {
            rows[rows.count - 1].insert(shiftKey(shift), at: 0)
        }
        return rows
    }

    static func numbers() -> [[KeySpec]] {
        var rows = [
            "1234567890".map { KeySpec(label: String($0), action: .character(String($0))) },
            ["-", "/", ":", ";", "(", ")", "₹", "&", "@", "\""].map { KeySpec(label: $0, action: .character($0)) },
            [".", ",", "?", "!", "'"].map { KeySpec(label: $0, action: .character($0), width: 1.4) },
        ]
        rows[1][6].more = ["$", "€", "£", "¥", "₩"]
        rows[2][0].more = ["…"]
        rows[2][4].more = ["’", "‘", "`"]
        rows[2].insert(KeySpec(label: "#+=", action: .page(.symbols), width: 1.35, isFunction: true), at: 0)
        rows[2].append(backspaceKey)
        return rows
    }

    static func symbols() -> [[KeySpec]] {
        var rows = [
            ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map { KeySpec(label: $0, action: .character($0)) },
            ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"].map { KeySpec(label: $0, action: .character($0)) },
            [".", ",", "?", "!", "'"].map { KeySpec(label: $0, action: .character($0), width: 1.4) },
        ]
        rows[2].insert(KeySpec(label: "123", action: .page(.numbers), width: 1.35, isFunction: true), at: 0)
        rows[2].append(backspaceKey)
        return rows
    }

    static func bottomRow(page: KeyPage, showGlobe: Bool, layoutShort: String?,
                          spaceLabel: String, returnLabel: String, returnIsAccent: Bool) -> [KeySpec] {
        var row: [KeySpec] = []
        row.append(KeySpec(label: page == .letters ? "123" : "ABC",
                           action: .page(page == .letters ? .numbers : .letters),
                           width: 1.3, isFunction: true))
        if showGlobe {
            row.append(KeySpec(label: "", action: .globe, width: 1.3, isFunction: true, symbol: "globe"))
        }
        row.append(KeySpec(label: "", action: .emoji, width: 1.3, isFunction: true, symbol: "face.smiling"))
        if let s = layoutShort {
            row.append(KeySpec(label: s, action: .nextLayout, width: 1.3, isFunction: true))
        }
        row.append(KeySpec(label: spaceLabel, action: .space, flexible: true))
        row.append(KeySpec(label: returnLabel, action: .returnKey, width: 2.7, isFunction: !returnIsAccent,
                           isAccent: returnIsAccent))
        return row
    }

    static func shiftKey(_ s: ShiftState) -> KeySpec {
        let symbol: String
        switch s {
        case .off: symbol = "shift"
        case .on: symbol = "shift.fill"
        case .locked: symbol = "capslock.fill"
        }
        return KeySpec(label: "", action: .shift, width: 1.35, isFunction: true, symbol: symbol)
    }

    static let backspaceKey = KeySpec(label: "", action: .backspace, width: 1.35, isFunction: true, symbol: "delete.left")
}
