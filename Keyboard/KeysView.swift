//  KeysView.swift
//  Draws the key grid and does its own touch tracking (one view for all keys),
//  with key previews, long-press alternatives and touch rollover for fast typing.

import UIKit

protocol KeysViewDelegate: AnyObject {
    func keysView(_ v: KeysView, didTap key: KeySpec)
    func keysView(_ v: KeysView, didPressDown key: KeySpec)
    func keysView(_ v: KeysView, didRelease key: KeySpec)
    func keysView(_ v: KeysView, didLongPress key: KeySpec) -> Bool   // true = handled
    func keysView(_ v: KeysView, didChooseAlternative text: String, for key: KeySpec)
    func keysViewDidLayout(_ v: KeysView)
}

enum KeyColors {
    static let background = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.13, alpha: 1) : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1) }
    static let key = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.42, alpha: 1) : .white }
    static let functionKey = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.27, alpha: 1) : UIColor(red: 0.67, green: 0.69, blue: 0.74, alpha: 1) }
    static let pressed = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.55, alpha: 1) : UIColor(white: 0.78, alpha: 1) }
    static let shadow = UIColor { $0.userInterfaceStyle == .dark ? UIColor.black : UIColor(white: 0.53, alpha: 1) }
    static let text = UIColor.label
    static let hint = UIColor.secondaryLabel
    static let accent = UIColor.systemBlue
}

final class KeyCapView: UIView {
    let label = UILabel()
    let hintLabel = UILabel()
    var spec: KeySpec { didSet { configure() } }
    var isPressed = false { didSet { updateColor() } }
    var isActiveState = false { didSet { updateColor() } }   // e.g. shift on

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        layer.cornerRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 1
        layer.shadowRadius = 0
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.baselineAdjustment = .alignCenters
        hintLabel.textAlignment = .right
        hintLabel.font = .systemFont(ofSize: 10)
        hintLabel.textColor = KeyColors.hint
        addSubview(label)
        addSubview(hintLabel)
        isUserInteractionEnabled = false
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configure() {
        label.text = spec.label
        hintLabel.text = spec.hint
        let isLatinLetter = spec.label.count == 1 && spec.label.unicodeScalars.allSatisfy { $0.isASCII && CharacterSet.letters.contains($0) }
        if spec.isFunction {
            label.font = .systemFont(ofSize: spec.label.count > 2 ? 15 : 17)
        } else if spec.action == .space {
            label.font = .systemFont(ofSize: 15)
        } else if isLatinLetter {
            label.font = .systemFont(ofSize: 24)
        } else {
            label.font = .systemFont(ofSize: 22)
        }
        label.textColor = spec.action == .space ? KeyColors.hint : KeyColors.text
        updateColor()
    }

    private func updateColor() {
        let base = spec.isFunction ? KeyColors.functionKey : KeyColors.key
        if isActiveState { backgroundColor = KeyColors.key }
        else { backgroundColor = isPressed ? (spec.isFunction ? KeyColors.key : KeyColors.pressed) : base }
        layer.shadowColor = KeyColors.shadow.cgColor
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateColor()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 2, dy: 1)
        hintLabel.frame = CGRect(x: 2, y: 1, width: bounds.width - 5, height: 12)
    }
}

final class KeysView: UIView {
    weak var delegate: KeysViewDelegate?

    var rows: [[KeySpec]] = [] { didSet { if rows != oldValue || caps.isEmpty { rebuild() } else { refreshActive() } } }
    var activeKeyPredicate: ((KeySpec) -> Bool)? { didSet { refreshActive() } }

    private var caps: [[KeyCapView]] = []
    private let horizontalGap: CGFloat = 5
    private let verticalGap: CGFloat = 10

    // Touch tracking
    private final class Tracked {
        var row: Int; var col: Int
        var longPressTimer: Timer?
        var longPressed = false
        var altIndex: Int?
        init(row: Int, col: Int) { self.row = row; self.col = col }
    }
    private var touches: [UITouch: Tracked] = [:]
    private let preview = PreviewBalloon()
    private let alternatives = AlternativesPopup()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        clipsToBounds = false
        preview.isHidden = true
        alternatives.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    private func rebuild() {
        caps.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        caps = rows.map { row in row.map { spec in
            let v = KeyCapView(spec: spec)
            insertSubview(v, at: 0)
            return v
        } }
        if preview.superview == nil { addSubview(preview) }
        if alternatives.superview == nil { addSubview(alternatives) }
        bringSubviewToFront(preview)
        bringSubviewToFront(alternatives)
        refreshActive()
        setNeedsLayout()
    }

    private func refreshActive() {
        for (r, row) in caps.enumerated() {
            for (c, cap) in row.enumerated() { cap.isActiveState = activeKeyPredicate?(rows[r][c]) ?? false }
        }
    }

    func frame(where match: (KeySpec) -> Bool) -> CGRect? {
        for (r, row) in rows.enumerated() {
            for (c, spec) in row.enumerated() where match(spec) { return caps[r][c].frame }
        }
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !rows.isEmpty else { return }
        let W = bounds.width
        let rowH = bounds.height / CGFloat(rows.count)
        let letterRows = rows.dropLast()
        let maxUnits = max(10, letterRows.map { $0.reduce(0) { $0 + $1.width } }.max() ?? 10)
        let unit = W / maxUnits
        for (r, row) in rows.enumerated() {
            let y = CGFloat(r) * rowH
            let isBottom = r == rows.count - 1
            let rowUnit = isBottom ? W / 10 : unit
            let fixed = row.filter { !$0.flexible }.reduce(0) { $0 + $1.width } * rowUnit
            let flexCount = CGFloat(row.filter { $0.flexible }.count)
            let flexWidth = flexCount > 0 ? max(rowUnit, (W - fixed) / flexCount) : 0
            let total = row.reduce(0) { $0 + ($1.flexible ? flexWidth : $1.width * rowUnit) }
            var x = max(0, (W - total) / 2)
            for (c, spec) in row.enumerated() {
                let w = spec.flexible ? flexWidth : spec.width * rowUnit
                caps[r][c].frame = CGRect(x: x + horizontalGap / 2, y: y + verticalGap / 2,
                                          width: w - horizontalGap, height: rowH - verticalGap).integral
                x += w
            }
        }
        delegate?.keysViewDidLayout(self)
    }

    // MARK: Hit testing

    private func keyIndex(at p: CGPoint) -> (Int, Int)? {
        guard !rows.isEmpty, bounds.height > 0 else { return nil }
        let rowH = bounds.height / CGFloat(rows.count)
        let r = min(rows.count - 1, max(0, Int(p.y / rowH)))
        var best: (Int, CGFloat)?
        for (c, cap) in caps[r].enumerated() {
            let f = cap.frame.insetBy(dx: -horizontalGap / 2, dy: 0)
            if p.x >= f.minX && p.x < f.maxX { return (r, c) }
            let d = abs(p.x - f.midX)
            if best == nil || d < best!.1 { best = (c, d) }
        }
        return best.map { (r, $0.0) }
    }

    // MARK: Touches

    override func touchesBegan(_ set: Set<UITouch>, with event: UIEvent?) {
        // Rollover: a new finger lands while another is still down → finish the earlier key first.
        for (t, tr) in touches where !tr.longPressed {
            guard let spec = specFor(tr) else { continue }
            if case .character = spec.action {
                finish(t, tr, fire: true)
            }
        }
        for t in set {
            guard let idx = keyIndex(at: t.location(in: self)) else { continue }
            let tr = Tracked(row: idx.0, col: idx.1)
            touches[t] = tr
            press(tr)
        }
    }

    override func touchesMoved(_ set: Set<UITouch>, with event: UIEvent?) {
        for t in set {
            guard let tr = touches[t] else { continue }
            let p = t.location(in: self)
            if tr.longPressed {
                if !alternatives.isHidden { tr.altIndex = alternatives.index(at: convert(p, to: alternatives)) }
                continue
            }
            guard let idx = keyIndex(at: p), idx != (tr.row, tr.col), let spec = specFor(tr) else { continue }
            let (r, c) = idx
            // Slide between character keys like the system keyboard; function keys stay put.
            guard case .character = spec.action, case .character = rows[r][c].action else { continue }
            release(tr)
            tr.row = r; tr.col = c
            press(tr)
        }
    }

    override func touchesEnded(_ set: Set<UITouch>, with event: UIEvent?) {
        for t in set { if let tr = touches[t] { finish(t, tr, fire: true) } }
    }

    override func touchesCancelled(_ set: Set<UITouch>, with event: UIEvent?) {
        for t in set { if let tr = touches[t] { finish(t, tr, fire: false) } }
    }

    private func specFor(_ tr: Tracked) -> KeySpec? {
        guard tr.row < rows.count, tr.col < rows[tr.row].count, tr.row < caps.count, tr.col < caps[tr.row].count else { return nil }
        return rows[tr.row][tr.col]
    }

    private func press(_ tr: Tracked) {
        guard let spec = specFor(tr) else { return }
        let cap = caps[tr.row][tr.col]
        cap.isPressed = true
        if case .character = spec.action { preview.show(spec.label, above: cap.frame, in: bounds) }
        delegate?.keysView(self, didPressDown: spec)
        tr.longPressTimer?.invalidate()
        tr.longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.42, repeats: false) { [weak self, weak tr] _ in
            guard let self = self, let tr = tr, let spec = self.specFor(tr) else { return }
            if !spec.more.isEmpty {
                tr.longPressed = true
                self.preview.isHidden = true
                let options = [spec.action.characterText ?? spec.label] + spec.more
                self.alternatives.show(options, above: self.caps[tr.row][tr.col].frame, in: self.bounds)
                tr.altIndex = 0
            } else if self.delegate?.keysView(self, didLongPress: spec) == true {
                tr.longPressed = true
                self.preview.isHidden = true
            }
        }
    }

    private func release(_ tr: Tracked) {
        tr.longPressTimer?.invalidate()
        preview.isHidden = true
        guard let spec = specFor(tr) else { return }
        caps[tr.row][tr.col].isPressed = false
        delegate?.keysView(self, didRelease: spec)
    }

    private func finish(_ t: UITouch, _ tr: Tracked, fire: Bool) {
        touches[t] = nil
        guard let spec = specFor(tr) else { tr.longPressTimer?.invalidate(); alternatives.isHidden = true; preview.isHidden = true; return }
        release(tr)
        if tr.longPressed {
            if !alternatives.isHidden {
                let options = alternatives.options
                alternatives.isHidden = true
                if fire, let i = tr.altIndex, i < options.count {
                    delegate?.keysView(self, didChooseAlternative: options[i], for: spec)
                }
            }
            return
        }
        if fire { delegate?.keysView(self, didTap: spec) }
    }
}

extension KeyAction {
    var characterText: String? { if case .character(let s) = self { return s } else { return nil } }
}

// MARK: - Popups

final class PreviewBalloon: UIView {
    private let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyColors.key
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 30)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.4
        label.textColor = KeyColors.text
        addSubview(label)
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    func show(_ text: String, above keyFrame: CGRect, in bounds: CGRect) {
        label.text = text
        let w = max(keyFrame.width + 16, 46)
        let h = keyFrame.height + 8
        var x = keyFrame.midX - w / 2
        x = min(max(0, x), bounds.width - w)
        frame = CGRect(x: x, y: max(-40, keyFrame.minY - h - 4), width: w, height: h)
        label.frame = self.bounds.insetBy(dx: 4, dy: 2)
        isHidden = false
        superview?.bringSubviewToFront(self)
    }
}

final class AlternativesPopup: UIView {
    private(set) var options: [String] = []
    private var labels: [UILabel] = []
    private let cellWidth: CGFloat = 40
    private var selected: Int? { didSet { highlight() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyColors.key
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    func show(_ opts: [String], above keyFrame: CGRect, in bounds: CGRect) {
        options = opts
        labels.forEach { $0.removeFromSuperview() }
        labels = opts.map { o in
            let l = UILabel()
            l.text = o
            l.textAlignment = .center
            l.font = .systemFont(ofSize: 22)
            l.adjustsFontSizeToFitWidth = true
            l.minimumScaleFactor = 0.5
            l.layer.cornerRadius = 6
            l.clipsToBounds = true
            addSubview(l)
            return l
        }
        let w = cellWidth * CGFloat(opts.count) + 8
        let h = keyFrame.height + 6
        var x = keyFrame.midX - w / 2
        x = min(max(0, x), max(0, bounds.width - w))
        frame = CGRect(x: x, y: max(-40, keyFrame.minY - h - 4), width: w, height: h)
        for (i, l) in labels.enumerated() {
            l.frame = CGRect(x: 4 + CGFloat(i) * cellWidth, y: 3, width: cellWidth, height: h - 6)
        }
        selected = 0
        isHidden = false
        superview?.bringSubviewToFront(self)
    }

    func index(at p: CGPoint) -> Int? {
        guard !options.isEmpty else { return nil }
        let i = Int((p.x - 4) / cellWidth)
        selected = min(options.count - 1, max(0, i))
        return selected
    }

    private func highlight() {
        for (i, l) in labels.enumerated() {
            l.backgroundColor = i == selected ? KeyColors.accent : .clear
            l.textColor = i == selected ? .white : KeyColors.text
        }
    }
}
