//  Composer.swift
//  Holds the Latin keys of the word being typed and keeps the document showing
//  the engine's output for them, either as marked (underlined) text like Android's
//  composing region, or written directly.

import UIKit

final class Composer {
    private let proxy: () -> UITextDocumentProxy
    var engine: TransliterationEngine?
    var useMarkedText = true

    /// Raw keys of the current word.
    private(set) var keys = ""
    /// What is currently in the document for this word.
    private var shown = ""
    /// Context snapshots used to tell our own edits apart from the user moving the cursor.
    private var wordStartContext: String?
    private var lastContext: String?

    var isComposing: Bool { !keys.isEmpty }

    init(proxy: @escaping () -> UITextDocumentProxy) { self.proxy = proxy }

    // MARK: Editing

    func type(_ key: String) {
        if keys.isEmpty { wordStartContext = proxy().documentContextBeforeInput }
        keys += key
        render()
    }

    /// Would appending this key change the word (rather than just add it)?
    func wouldTransform(_ key: String) -> Bool {
        guard let e = engine, isComposing else { return false }
        return e.output(for: keys + key) != e.output(for: keys) + key
    }

    /// Removes the last typed key. Returns false if nothing was being composed.
    @discardableResult
    func backspace() -> Bool {
        guard isComposing else { return false }
        keys.removeLast()
        if keys.isEmpty { finish(with: "") } else { render() }
        return true
    }

    func setKeys(_ newKeys: String) {
        if keys.isEmpty { wordStartContext = proxy().documentContextBeforeInput }
        keys = newKeys
        if keys.isEmpty { finish(with: "") } else { render() }
    }

    /// Commits the current word as the engine renders it.
    func commit() {
        guard isComposing, let e = engine else { return }
        finish(with: e.output(for: keys))
    }

    /// Commits the word followed by a space, letting the engine see the space
    /// (Swanalekha turns a final "m " into "ം ").
    func commitWithSpace() {
        guard isComposing, let e = engine else {
            proxy().insertText(" ")
            return
        }
        var out = e.output(for: keys + " ")
        if !out.hasSuffix(" ") { out += " " }
        finish(with: out)
    }

    /// Replaces the word with the given text and commits it (e.g. the raw Latin candidate).
    func commit(text: String) {
        guard isComposing else { proxy().insertText(text); return }
        finish(with: text)
    }

    /// Forget the composition without touching the document.
    func reset() {
        if useMarkedText, isComposing { proxy().unmarkText() }
        keys = ""
        shown = ""
        wordStartContext = nil
        lastContext = nil
    }

    /// Called from textDidChange/selectionDidChange. If the document changed in a way
    /// our own edits don't explain (cursor moved, text pasted), drop the composition.
    func documentChanged() {
        guard isComposing else { return }
        let ctx = proxy().documentContextBeforeInput ?? ""
        let explained = ctx == lastContext
            || (!shown.isEmpty && ctx.hasSuffix(shown))
            || ctx == (wordStartContext ?? "\u{0}")
        if !explained { reset() }
    }

    // MARK: Document output

    private func render() {
        guard let e = engine else { return }
        show(e.output(for: keys))
    }

    private func show(_ s: String) {
        if useMarkedText {
            let len = (s as NSString).length
            proxy().setMarkedText(s, selectedRange: NSRange(location: len, length: 0))
        } else {
            directUpdate(to: s)
        }
        shown = s
        lastContext = proxy().documentContextBeforeInput
    }

    private func finish(with final: String) {
        if useMarkedText {
            let len = (final as NSString).length
            proxy().setMarkedText(final, selectedRange: NSRange(location: len, length: 0))
            proxy().unmarkText()
        } else {
            directUpdate(to: final)
        }
        keys = ""
        shown = ""
        wordStartContext = nil
        lastContext = nil
    }

    /// Changes the document from `shown` to `new` by deleting the part that differs and
    /// inserting the rest. deleteBackward may remove a code point or a whole cluster
    /// depending on the app, so deletions are measured and any overshoot re-inserted.
    private func directUpdate(to new: String) {
        let old = shown as NSString
        let nw = new as NSString
        var common = 0
        let n = min(old.length, nw.length)
        while common < n, old.character(at: common) == nw.character(at: common) { common += 1 }
        if common > 0, common < old.length, UTF16.isTrailSurrogate(old.character(at: common)) { common -= 1 }
        let removed = deleteUnits(old.length - common)
        let resume = max(0, min(common, old.length - removed))
        if resume < nw.length { proxy().insertText(nw.substring(from: resume)) }
    }

    private func deleteUnits(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        var removed = 0
        var calls = 0
        while removed < n, calls < n + 8 {
            calls += 1
            let before = (proxy().documentContextBeforeInput ?? "") as NSString
            proxy().deleteBackward()
            let after = (proxy().documentContextBeforeInput ?? "") as NSString
            let d = before.length - after.length
            removed += (before.length > 0 && d > 0) ? d : 1
        }
        return removed
    }
}
