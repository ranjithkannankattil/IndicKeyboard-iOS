//  KeyboardViewController.swift
//  The keyboard extension's entry point.

import UIKit

/// Input view that opts into the system keyboard-click sound.
final class KeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}

final class KeyboardViewController: UIInputViewController {
    private let settings = KeyboardSettings.shared
    private let candidateBar = CandidateBar()
    private let keysView = KeysView()
    private var settingsPanel: SettingsPanel?
    private var emojiPanel: EmojiPanel?
    private var heightConstraint: NSLayoutConstraint?
    private let globeButton = UIButton(type: .custom)

    private var layout: LayoutInfo = LayoutCatalog.all[0]
    private var engine: TransliterationEngine?
    private var direct: DirectLayout?
    private var page: KeyPage = .letters
    private var shift: ShiftState = .off
    private var lastShiftTap: TimeInterval = 0
    private var lastSpaceTap: TimeInterval = 0
    private var backspaceTimer: Timer?

    // English typing
    private lazy var english = EnglishSuggester()
    private var englishBar: [(value: String, literal: Bool)] = []
    private var lastCorrection: (original: String, corrected: String, separator: String)?

    // Swanalekha / Mozhi typing
    private var transliterationBar: [Candidate] = []

    private lazy var composer = Composer(proxy: { [unowned self] in self.textDocumentProxy })

    private var candidateHeight: CGFloat { isLandscape ? 36 : 44 }

    // MARK: Lifecycle

    override func loadView() {
        view = KeyboardInputView(frame: .zero, inputViewStyle: .keyboard)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KeyColors.background
        view.clipsToBounds = false

        candidateBar.onSelect = { [weak self] i in self?.candidateChosen(i) }
        candidateBar.onSettings = { [weak self] in self?.openSettings() }
        keysView.delegate = self

        // The globe key must be a real control so the system can show its keyboard list on long press.
        globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        globeButton.accessibilityLabel = "Next keyboard"

        view.addSubview(candidateBar)
        view.addSubview(keysView)
        keysView.addSubview(globeButton)

        loadLayout(settings.currentLayout)
        requestSupplementaryLexicon { [weak self] lex in self?.english.load(lexicon: lex) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        installHeightConstraint()
        applySettings()
        if layout.id != settings.currentLayout { loadLayout(settings.currentLayout) }
        updateAppearance()
        updateAutoShift()
        rebuildKeys()
        updateCandidates()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        heightConstraint?.constant = preferredHeight()
        keysView.landscape = isLandscape
        emojiPanel?.landscape = isLandscape
        candidateBar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: candidateHeight)
        keysView.frame = CGRect(x: 0, y: candidateHeight, width: view.bounds.width, height: view.bounds.height - candidateHeight)
        settingsPanel?.frame = view.bounds
        emojiPanel?.frame = view.bounds
    }

    /// iOS only honours a keyboard height constraint added once the input view is
    /// part of the window hierarchy, so this runs from viewWillAppear/viewDidAppear.
    private func installHeightConstraint() {
        let target = preferredHeight()
        if let h = heightConstraint {
            if h.constant != target { h.constant = target }
            return
        }
        let h = view.heightAnchor.constraint(equalToConstant: target)
        h.priority = UILayoutPriority(999)
        h.isActive = true
        heightConstraint = h
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installHeightConstraint()
    }

    private var isLandscape: Bool {
        let s = UIScreen.main.bounds.size
        return s.width > s.height
    }

    private func preferredHeight() -> CGFloat {
        let rows = currentRows().count + 1
        return candidateHeight + KeyMetrics.make(landscape: isLandscape, rowCount: rows).height(rows: rows)
    }

    override func textWillChange(_ textInput: UITextInput?) {}

    override func textDidChange(_ textInput: UITextInput?) {
        composer.documentChanged()
        updateAppearance()
        updateAutoShift()
        rebuildKeys()
        updateCandidates()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        composer.documentChanged()
        lastCorrection = nil
        updateCandidates()
    }

    // MARK: Layout & state

    private func loadLayout(_ id: String) {
        composer.commit()
        let info = LayoutCatalog.info(id) ?? LayoutCatalog.all[0]
        layout = info
        engine = nil
        direct = nil
        switch info.kind {
        case .transliteration:
            if let f = info.file { engine = try? EngineLoader.engine(file: f) }
        case .direct:
            if let f = info.file { direct = try? LayoutCatalog.directLayout(file: f) }
        case .english:
            break
        }
        composer.engine = engine
        settings.currentLayout = info.id
        page = .letters
        shift = .off
        lastCorrection = nil
        updateAutoShift()
        rebuildKeys()
        updateCandidates()
        heightConstraint?.constant = preferredHeight()
    }

    private func applySettings() {
        composer.useMarkedText = settings.underlineWhileComposing
    }

    private func updateAppearance() {
        switch textDocumentProxy.keyboardAppearance ?? .default {
        case .dark: view.overrideUserInterfaceStyle = .dark
        case .light: view.overrideUserInterfaceStyle = .light
        default: view.overrideUserInterfaceStyle = .unspecified
        }
    }

    private func currentRows() -> [[KeySpec]] {
        switch page {
        case .numbers: return KeyboardRows.numbers()
        case .symbols: return KeyboardRows.symbols()
        case .letters:
            if let d = direct { return KeyboardRows.direct(d, shift: shift) }
            return KeyboardRows.latin(shift: shift, transliteration: layout.kind == .transliteration)
        }
    }

    private func rebuildKeys() {
        var rows = currentRows()
        let enabled = settings.enabledLayouts
        let look = returnKeyLook()
        rows.append(KeyboardRows.bottomRow(page: page,
                                           showGlobe: needsInputModeSwitchKey,
                                           layoutShort: enabled.count > 1 ? nextLayoutLabel() : nil,
                                           spaceLabel: layout.kind == .english ? "space" : layout.name,
                                           returnLabel: look.label,
                                           returnIsAccent: look.accent))
        keysView.rows = rows
    }

    /// The layout key shows where it will take you next.
    private func nextLayoutLabel() -> String {
        let enabled = settings.enabledLayouts
        guard let i = enabled.firstIndex(of: layout.id) else { return LayoutCatalog.info(enabled[0])?.short ?? "⋯" }
        let next = enabled[(i + 1) % enabled.count]
        return LayoutCatalog.info(next)?.short ?? "⋯"
    }

    /// Label for the return key, and whether iOS would draw it blue.
    private func returnKeyLook() -> (label: String, accent: Bool) {
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: return ("go", true)
        case .google, .yahoo, .search: return ("search", true)
        case .join: return ("join", true)
        case .next: return ("next", false)
        case .route: return ("route", true)
        case .send: return ("send", true)
        case .done: return ("done", true)
        case .emergencyCall: return ("SOS", true)
        case .continue: return ("continue", true)
        default: return ("return", false)
        }
    }

    // MARK: Candidates

    private func updateCandidates() {
        if layout.kind == .transliteration, composer.isComposing, let e = engine {
            let keys = composer.keys
            let current = e.output(for: keys)
            var list = e.candidates(for: keys).filter { $0.text != current }
            list.insert(Candidate(text: current, keys: keys), at: 0)
            if keys != current { list.append(Candidate(text: keys, keys: nil)) }   // the Latin word itself
            transliterationBar = list
            englishBar = []
            candidateBar.show(list.enumerated().map { pair in
                BarItem(title: pair.element.text, bold: pair.offset == 0, dim: pair.element.keys == nil)
            })
            return
        }
        transliterationBar = []
        if layout.kind == .english, page == .letters, settings.predictive {
            let word = currentEnglishWord()
            if !word.isEmpty {
                let correction = settings.autocorrect ? english.autocorrection(for: word) : nil
                let others = english.suggestions(for: word, limit: 3).filter { $0 != correction }
                var values: [(value: String, literal: Bool)] = [(word, true)]
                var items = [BarItem(title: "“\(word)”", dim: true)]
                if let c = correction {
                    values.append((c, false))
                    items.append(BarItem(title: c, bold: true))
                    if let o = others.first {
                        values.append((o, false))
                        items.append(BarItem(title: o))
                    }
                } else {
                    for o in others.prefix(2) {
                        values.append((o, false))
                        items.append(BarItem(title: o))
                    }
                }
                englishBar = values
                candidateBar.show(items)
                return
            }
        }
        englishBar = []
        candidateBar.showIdle(layout.subtitle.isEmpty ? layout.name : "\(layout.name) · \(layout.subtitle)")
    }

    private func candidateChosen(_ index: Int) {
        click()
        if !transliterationBar.isEmpty, index < transliterationBar.count {
            let c = transliterationBar[index]
            if let k = c.keys, index != 0 {
                composer.setKeys(k)          // pick an alternative; keep typing the word
            } else if c.keys == nil {
                composer.commit(text: c.text)
            } else {
                composer.commit()            // tapping the bold word accepts it
            }
        } else if index < englishBar.count {
            let choice = englishBar[index]
            let word = currentEnglishWord()
            if choice.literal { english.ignore(word) }
            replaceCurrentWord(word, with: choice.value)
            insert(" ")
            lastCorrection = nil
            updateAutoShift()
            rebuildKeys()
        }
        updateCandidates()
    }

    // MARK: English helpers

    /// The word immediately before the cursor (letters and apostrophes).
    private func currentEnglishWord() -> String {
        if let after = textDocumentProxy.documentContextAfterInput, let f = after.first, f.isLetter { return "" }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        var word = ""
        for ch in before.reversed() {
            if ch.isLetter || ch == "'" || ch == "’" { word.insert(ch, at: word.startIndex) } else { break }
        }
        return word
    }

    private func replaceCurrentWord(_ word: String, with replacement: String) {
        guard word != replacement else { return }
        for _ in 0..<word.count { textDocumentProxy.deleteBackward() }
        insert(replacement)
    }

    /// Applies autocorrection to the word before the cursor, ahead of a separator.
    private func autocorrectBeforeSeparator(_ separator: String) {
        guard layout.kind == .english, settings.autocorrect else { return }
        let word = currentEnglishWord()
        guard !word.isEmpty, let c = english.autocorrection(for: word), c != word else { return }
        replaceCurrentWord(word, with: c)
        lastCorrection = (word, c, separator)
    }

    /// Backspace straight after an autocorrection puts the original word back.
    private func undoAutocorrectionIfJustMade() -> Bool {
        guard let lc = lastCorrection else { return false }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard before.hasSuffix(lc.corrected + lc.separator) else { lastCorrection = nil; return false }
        for _ in 0..<(lc.corrected.count + lc.separator.count) { textDocumentProxy.deleteBackward() }
        insert(lc.original)
        english.ignore(lc.original)
        lastCorrection = nil
        return true
    }

    // MARK: Emoji panel

    private func openEmoji() {
        composer.commit()
        let p = EmojiPanel(frame: view.bounds)
        p.landscape = isLandscape
        p.onEmoji = { [weak self] e in
            self?.insert(e)
            self?.lastCorrection = nil
        }
        p.onABC = { [weak self] in self?.closeEmoji() }
        p.onDelete = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        view.addSubview(p)
        emojiPanel = p
    }

    private func closeEmoji() {
        emojiPanel?.removeFromSuperview()
        emojiPanel = nil
        page = .letters
        updateAutoShift()
        rebuildKeys()
        updateCandidates()
    }

    // MARK: Settings panel

    private func openSettings() {
        composer.commit()
        updateCandidates()
        let p = SettingsPanel(current: layout.id)
        p.onClose = { [weak self] in self?.closeSettings() }
        p.onChoose = { [weak self] id in
            self?.loadLayout(id)
            self?.closeSettings()
        }
        p.onChange = { [weak self] in
            guard let self = self else { return }
            self.applySettings()
            if !self.settings.enabledLayouts.contains(self.layout.id) {
                self.loadLayout(self.settings.enabledLayouts[0])
            } else {
                self.rebuildKeys()
            }
        }
        p.frame = view.bounds
        view.addSubview(p)
        settingsPanel = p
    }

    private func closeSettings() {
        settingsPanel?.removeFromSuperview()
        settingsPanel = nil
        rebuildKeys()
        updateCandidates()
    }

    // MARK: Typing

    private func click() {
        if settings.keyClicks { UIDevice.current.playInputClick() }
    }

    private func insert(_ s: String) {
        textDocumentProxy.insertText(s)
    }

    private static let sentencePunctuation: Set<String> = [".", ",", "!", "?", ";", ":"]

    private func handleCharacter(_ s: String) {
        switch layout.kind {
        case .transliteration where page == .letters:
            composer.type(s)
        case .transliteration:
            // Symbols and digits join the word only when they change it (Swanalekha's ~, _, ^, 2, 3 …).
            if composer.wouldTransform(s) { composer.type(s) } else { composer.commit(); insert(s) }
        case .english, .direct:
            composer.commit()
            if Self.sentencePunctuation.contains(s) {
                autocorrectBeforeSeparator(s)
            } else {
                lastCorrection = nil
            }
            insert(s)
        }
        if page == .letters, shift == .on {
            shift = .off
            rebuildKeys()
        }
        if page != .letters, s == "'" {
            page = .letters
            rebuildKeys()
        }
        updateCandidates()
    }

    private func handleSpace() {
        let now = Date().timeIntervalSince1970
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        if composer.isComposing {
            composer.commitWithSpace()
        } else if settings.doubleSpacePeriod, now - lastSpaceTap < 0.6, before.hasSuffix(" "),
                  let prev = before.dropLast().last, prev.isLetter || prev.isNumber || prev == ")" || prev == "\"" {
            textDocumentProxy.deleteBackward()
            insert(". ")
            lastCorrection = nil
        } else {
            autocorrectBeforeSeparator(" ")
            insert(" ")
        }
        lastSpaceTap = now
        if page != .letters { page = .letters }
        updateAutoShift()
        rebuildKeys()
        updateCandidates()
    }

    private func handleReturn() {
        composer.commit()
        autocorrectBeforeSeparator("\n")
        insert("\n")
        updateAutoShift()
        rebuildKeys()
        updateCandidates()
    }

    private func handleBackspace() {
        if composer.backspace() {
            // removed one key of the word being composed
        } else if undoAutocorrectionIfJustMade() {
            // restored the word the user typed
        } else {
            textDocumentProxy.deleteBackward()
        }
        updateAutoShift()
        rebuildKeys()
        updateCandidates()
    }

    private func handleShift() {
        let now = Date().timeIntervalSince1970
        if direct != nil && !(direct?.hasShift ?? false) { return }
        if now - lastShiftTap < 0.3 {
            shift = .locked
        } else {
            shift = shift == .off ? .on : .off
        }
        lastShiftTap = now
        rebuildKeys()
    }

    private func nextLayout() {
        let enabled = settings.enabledLayouts
        guard enabled.count > 1 else { return }
        let i = enabled.firstIndex(of: layout.id) ?? -1
        loadLayout(enabled[(i + 1) % enabled.count])
    }

    /// Sentence-start capitals for English only (case changes meaning in Swanalekha).
    private func updateAutoShift() {
        guard layout.kind == .english, page == .letters, shift != .locked else { return }
        let type = textDocumentProxy.autocapitalizationType ?? .sentences
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let trimmed = before.replacingOccurrences(of: " ", with: "")
        var cap = false
        switch type {
        case .allCharacters: cap = true
        case .words: cap = before.isEmpty || before.hasSuffix(" ") || before.hasSuffix("\n")
        case .sentences:
            cap = trimmed.isEmpty || trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!") || before.hasSuffix("\n")
            if !before.isEmpty, !(before.hasSuffix(" ") || before.hasSuffix("\n")) { cap = false }
        default: cap = false
        }
        shift = cap ? .on : .off
    }

    // MARK: Backspace repeat

    private func startBackspaceRepeat() {
        backspaceTimer?.invalidate()
        backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.handleBackspace()
            }
        }
    }

    private func stopBackspaceRepeat() {
        backspaceTimer?.invalidate()
        backspaceTimer = nil
    }
}

// MARK: - KeysViewDelegate

extension KeyboardViewController: KeysViewDelegate {
    func keysView(_ v: KeysView, didPressDown key: KeySpec) {
        click()
        if key.action == .backspace {
            handleBackspace()
            startBackspaceRepeat()
        }
    }

    func keysView(_ v: KeysView, didRelease key: KeySpec) {
        if key.action == .backspace { stopBackspaceRepeat() }
    }

    func keysView(_ v: KeysView, didTap key: KeySpec) {
        switch key.action {
        case .character(let s): handleCharacter(s)
        case .space: handleSpace()
        case .returnKey: handleReturn()
        case .backspace: break                    // handled on press-down
        case .shift: handleShift()
        case .nextLayout: nextLayout()
        case .globe: advanceToNextInputMode()
        case .emoji: openEmoji()
        case .page(let p):
            if layout.kind != .transliteration { composer.commit() }
            page = p
            if p == .letters { updateAutoShift() }
            rebuildKeys()
            updateCandidates()
        }
    }

    func keysView(_ v: KeysView, didLongPress key: KeySpec) -> Bool {
        switch key.action {
        case .nextLayout, .space:
            openSettings()
            return true
        default:
            return false
        }
    }

    func keysView(_ v: KeysView, didChooseAlternative text: String, for key: KeySpec) {
        click()
        handleCharacter(text)
    }

    func keysViewDidLayout(_ v: KeysView) {
        if needsInputModeSwitchKey, let f = v.frame(where: { $0.action == .globe }) {
            globeButton.frame = f
            globeButton.isHidden = false
            v.bringSubviewToFront(globeButton)
        } else {
            globeButton.isHidden = true
        }
    }
}
