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
    private var heightConstraint: NSLayoutConstraint?
    private let globeButton = UIButton(type: .custom)

    private var layout: LayoutInfo = LayoutCatalog.all[0]
    private var engine: TransliterationEngine?
    private var direct: DirectLayout?
    private var page: KeyPage = .letters
    private var shift: ShiftState = .off
    private var lastShiftTap: TimeInterval = 0
    private var backspaceTimer: Timer?
    private var backspaceRepeats = 0

    private lazy var composer = Composer(proxy: { [unowned self] in self.textDocumentProxy })

    // MARK: Lifecycle

    override func loadView() {
        view = KeyboardInputView(frame: .zero, inputViewStyle: .keyboard)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KeyColors.background
        view.clipsToBounds = false

        candidateBar.onSelect = { [weak self] c, i in self?.candidateChosen(c, index: i) }
        candidateBar.onSettings = { [weak self] in self?.openSettings() }
        keysView.delegate = self

        // The globe key must be a real control so the system can show its keyboard list on long press.
        globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        globeButton.accessibilityLabel = "Next keyboard"

        view.addSubview(candidateBar)
        view.addSubview(keysView)
        keysView.addSubview(globeButton)

        let h = view.heightAnchor.constraint(equalToConstant: preferredHeight())
        h.priority = UILayoutPriority(999)
        h.isActive = true
        heightConstraint = h

        loadLayout(settings.currentLayout)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applySettings()
        if layout.id != settings.currentLayout { loadLayout(settings.currentLayout) }
        updateAppearance()
        updateAutoShift()
        rebuildKeys()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        heightConstraint?.constant = preferredHeight()
        let candH = isLandscape ? 36.0 : 44.0
        candidateBar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: candH)
        keysView.frame = CGRect(x: 0, y: candH, width: view.bounds.width, height: view.bounds.height - candH - 2)
        settingsPanel?.frame = view.bounds
    }

    private var isLandscape: Bool {
        let s = UIScreen.main.bounds.size
        return s.width > s.height
    }

    private func preferredHeight() -> CGFloat {
        let rows = CGFloat(max(4, currentRows().count + 1))
        let rowH: CGFloat = isLandscape ? 38 : (rows > 4 ? 47 : 54)
        return (isLandscape ? 36 : 44) + rows * rowH + 2
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
        rows.append(KeyboardRows.bottomRow(page: page,
                                           showGlobe: needsInputModeSwitchKey,
                                           layoutShort: enabled.count > 1 ? nextLayoutLabel() : nil,
                                           spaceLabel: layout.name,
                                           returnLabel: returnLabel()))
        keysView.rows = rows
        keysView.activeKeyPredicate = { [weak self] spec in
            spec.action == .shift && (self?.shift ?? .off) != .off
        }
    }

    /// The layout key shows where it will take you next.
    private func nextLayoutLabel() -> String {
        let enabled = settings.enabledLayouts
        guard let i = enabled.firstIndex(of: layout.id) else { return LayoutCatalog.info(enabled[0])?.short ?? "⋯" }
        let next = enabled[(i + 1) % enabled.count]
        return LayoutCatalog.info(next)?.short ?? "⋯"
    }

    private func returnLabel() -> String {
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: return "go"
        case .google, .yahoo, .search: return "search"
        case .join: return "join"
        case .next: return "next"
        case .route: return "route"
        case .send: return "send"
        case .done: return "done"
        case .emergencyCall: return "SOS"
        case .continue: return "continue"
        default: return "return"
        }
    }

    // MARK: Candidates

    private func updateCandidates() {
        guard composer.isComposing, let e = engine else {
            candidateBar.showIdle(layout.subtitle.isEmpty ? layout.name : "\(layout.name) · \(layout.subtitle)")
            return
        }
        let keys = composer.keys
        let current = e.output(for: keys)
        var list = e.candidates(for: keys).filter { $0.text != current }
        list.insert(Candidate(text: current, keys: keys), at: 0)
        if keys != current { list.append(Candidate(text: keys, keys: nil)) }   // the Latin word itself
        candidateBar.show(list)
    }

    private func candidateChosen(_ c: Candidate, index: Int) {
        click()
        if let k = c.keys, index != 0 {
            composer.setKeys(k)          // pick an alternative; keep typing the word
        } else if c.keys == nil {
            composer.commit(text: c.text)
        } else {
            composer.commit()            // tapping the bold word accepts it
        }
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
    }

    // MARK: Typing

    private func click() {
        if settings.keyClicks { UIDevice.current.playInputClick() }
    }

    private func insert(_ s: String) {
        textDocumentProxy.insertText(s)
    }

    private func handleCharacter(_ s: String) {
        switch layout.kind {
        case .transliteration where page == .letters:
            composer.type(s)
        case .transliteration:
            // Symbols and digits join the word only when they change it (Swanalekha's ~, _, ^, 2, 3 …).
            if composer.wouldTransform(s) { composer.type(s) } else { composer.commit(); insert(s) }
        case .english, .direct:
            composer.commit()
            insert(s)
        }
        if page == .letters, shift == .on {
            shift = .off
            rebuildKeys()
        }
        if layout.kind == .english, page != .letters, s == "'" {
            page = .letters
            rebuildKeys()
        }
        updateCandidates()
    }

    private func handleSpace() {
        if composer.isComposing { composer.commitWithSpace() } else { insert(" ") }
        if page != .letters { page = .letters }
        updateAutoShift()
        rebuildKeys()
        updateCandidates()
    }

    private func handleReturn() {
        composer.commit()
        insert("\n")
        updateAutoShift()
        rebuildKeys()
        updateCandidates()
    }

    private func handleBackspace() {
        if !composer.backspace() { textDocumentProxy.deleteBackward() }
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
        backspaceRepeats = 0
        backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.backspaceRepeats += 1
                self.handleBackspace()
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
