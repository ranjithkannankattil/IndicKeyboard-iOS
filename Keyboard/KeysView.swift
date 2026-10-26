//  KeysView.swift
//  Draws the key grid with iOS-keyboard geometry and does its own touch tracking
//  (one view for all keys), with key previews, long-press alternatives and touch
//  rollover for fast typing.

import UIKit

protocol KeysViewDelegate: AnyObject {
    func keysView(_ v: KeysView, didTap key: KeySpec)
    func keysView(_ v: KeysView, didPressDown key: KeySpec)
    func keysView(_ v: KeysView, didRelease key: KeySpec)
    func keysView(_ v: KeysView, didLongPress key: KeySpec) -> Bool   // true = handled
    func keysView(_ v: KeysView, didChooseAlternative text: String, for key: KeySpec)
    func keysViewDidLayout(_ v: KeysView)
}

extension UIScrollView {
    /// iOS 26 softly fades scroll content at its edges; keyboard panels must stay crisp.
    func disableEdgeFades() {
        if #available(iOS 26.0, *) {
            topEdgeEffect.isHidden = true
            bottomEdgeEffect.isHidden = true
            leftEdgeEffect.isHidden = true
            rightEdgeEffect.isHidden = true
        }
    }
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

/// iOS keyboard geometry (iPhone). Measured from the system keyboard: 3pt side
/// margins, 6pt between keys, ~42pt keys with ~12pt between rows in portrait.
struct KeyMetrics {
    let sideInset: CGFloat
    let hGap: CGFloat
    let vGap: CGFloat
    let keyHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat

    static func make(landscape: Bool, rowCount: Int) -> KeyMetrics {
        if landscape {
            if rowCount > 4 {
                return KeyMetrics(sideInset: 3, hGap: 6, vGap: 5, keyHeight: 29, topInset: 5, bottomInset: 3)
            }
            return KeyMetrics(sideInset: 3, hGap: 6, vGap: 6, keyHeight: 34, topInset: 6, bottomInset: 4)
        }
        if rowCount > 4 {
            // Same overall height as the 4-row keyboard, so switching layouts never resizes it.
            return KeyMetrics(sideInset: 3, hGap: 5, vGap: 8, keyHeight: 38, topInset: 8, bottomInset: 6)
        }
        return KeyMetrics(sideInset: 3, hGap: 6, vGap: 12, keyHeight: 45, topInset: 10, bottomInset: 6)
    }

    /// Height of the key area. Fixed per orientation (based on the 4-row keyboard), so the
    /// keyboard is the same height for every layout, page and panel, and apps can place
    /// the text box above it once, before it appears.
    static func keyAreaHeight(landscape: Bool) -> CGFloat {
        make(landscape: landscape, rowCount: 4).height(rows: 4)
    }

    func height(rows: Int) -> CGFloat {
        topInset + CGFloat(rows) * keyHeight + CGFloat(max(0, rows - 1)) * vGap + bottomInset
    }

    static var cornerRadius: CGFloat {
        if #available(iOS 26.0, *) { return 8.5 }
        return 5
    }
}

final class KeyCapView: UIView {
    let label = UILabel()
    let hintLabel = UILabel()
    let icon = UIImageView()
    var spec: KeySpec { didSet { if spec != oldValue { configure() } } }
    var isPressed = false { didSet { updateColor() } }

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: .zero)
        layer.cornerRadius = KeyMetrics.cornerRadius
        layer.cornerCurve = .continuous
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 1
        layer.shadowRadius = 0
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.45
        label.baselineAdjustment = .alignCenters
        hintLabel.textAlignment = .right
        hintLabel.font = .systemFont(ofSize: 10)
        hintLabel.textColor = KeyColors.hint
        icon.contentMode = .center
        addSubview(label)
        addSubview(hintLabel)
        addSubview(icon)
        isUserInteractionEnabled = false
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configure() {
        label.text = spec.label
        hintLabel.text = spec.hint
        if let s = spec.symbol {
            icon.image = UIImage(systemName: s, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
            icon.isHidden = false
        } else {
            icon.image = nil
            icon.isHidden = true
        }
        let isLatinLetter = spec.label.count == 1 && spec.label.unicodeScalars.allSatisfy { $0.isASCII && CharacterSet.letters.contains($0) }
        if spec.isFunction || spec.isAccent {
            label.font = .systemFont(ofSize: 16)
        } else if spec.action == .space {
            label.font = .systemFont(ofSize: 16)
        } else if isLatinLetter {
            label.font = .systemFont(ofSize: 25)
        } else {
            label.font = .systemFont(ofSize: 23)
        }
        label.textColor = spec.isAccent ? .white : (spec.action == .space ? KeyColors.hint : KeyColors.text)
        icon.tintColor = KeyColors.text
        updateColor()
    }

    private func updateColor() {
        if spec.isAccent {
            backgroundColor = isPressed ? KeyColors.functionKey : KeyColors.accent
        } else if spec.isFunction {
            backgroundColor = isPressed ? KeyColors.key : KeyColors.functionKey
        } else {
            backgroundColor = isPressed ? KeyColors.pressed : KeyColors.key
        }
        layer.shadowColor = KeyColors.shadow.cgColor
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateColor()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 2, dy: 1)
        icon.frame = bounds
        hintLabel.frame = CGRect(x: 2, y: 1, width: bounds.width - 5, height: 12)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }
}

final class KeysView: UIView {
    weak var delegate: KeysViewDelegate?

    var rows: [[KeySpec]] = [] { didSet { if rows != oldValue || caps.isEmpty { rebuild() } } }
    var landscape = false { didSet { if landscape != oldValue { setNeedsLayout() } } }

    private var caps: [[KeyCapView]] = []
    private var rowBands: [ClosedRange<CGFloat>] = []
    private var metrics: KeyMetrics { KeyMetrics.make(landscape: landscape, rowCount: rows.count) }
    private var fitted: KeyMetrics?

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

    /// Reuses key views where the row shapes match, so shift / page changes don't flicker.
    private func rebuild() {
        let sameShape = caps.count == rows.count && zip(caps, rows).allSatisfy { $0.count == $1.count }
        if sameShape {
            for (r, row) in rows.enumerated() { for (c, spec) in row.enumerated() { caps[r][c].spec = spec } }
        } else {
            caps.flatMap { $0 }.forEach { $0.removeFromSuperview() }
            caps = rows.map { row in row.map { spec in
                let v = KeyCapView(spec: spec)
                insertSubview(v, at: 0)
                return v
            } }
        }
        if preview.superview == nil { addSubview(preview) }
        if alternatives.superview == nil { addSubview(alternatives) }
        bringSubviewToFront(preview)
        bringSubviewToFront(alternatives)
        setNeedsLayout()
    }

    func frame(where match: (KeySpec) -> Bool) -> CGRect? {
        for (r, row) in rows.enumerated() {
            for (c, spec) in row.enumerated() where match(spec) { return caps[r][c].frame }
        }
        return nil
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !rows.isEmpty, caps.count == rows.count else { return }
        var m = metrics
        let ideal = m.height(rows: rows.count)
        if bounds.height > 0, bounds.height < ideal {
            // iOS gave less height than requested. Like the system keyboard, squeeze the margins
            // and gaps first and keep the keys as tall as possible.
            let n = CGFloat(rows.count)
            let top = min(m.topInset, landscape ? 4 : 6)
            let bottom = min(m.bottomInset, landscape ? 2 : 3)
            let minGap: CGFloat = landscape ? 4 : (rows.count > 4 ? 6 : 8)
            let keyH = min(m.keyHeight, (bounds.height - top - bottom - (n - 1) * minGap) / n)
            let gap = n > 1 ? max(0, (bounds.height - top - bottom - n * keyH) / (n - 1)) : 0
            m = KeyMetrics(sideInset: m.sideInset, hGap: m.hGap, vGap: gap,
                           keyHeight: keyH, topInset: top, bottomInset: bottom)
        }
        fitted = m
        let W = bounds.width
        let usable = W - 2 * m.sideInset
        let standardKey = (usable - 9 * m.hGap) / 10

        // One letter-key width for all letter rows: the widest row must fit,
        // leaving each function key at least one key wide.
        var keyW = standardKey
        for row in rows.dropLast() {
            let chars = row.filter { !isEdgeFunction($0) }
            let fns = row.count - chars.count
            let units = chars.reduce(0) { $0 + $1.width } + CGFloat(fns)
            let gaps = CGFloat(max(0, row.count - 1)) * m.hGap
            if units > 0 { keyW = min(keyW, (usable - gaps) / units) }
        }

        rowBands = []
        var y = m.topInset
        for (r, row) in rows.enumerated() {
            let frames = r == rows.count - 1
                ? bottomRowFrames(row, standardKey: standardKey, m: m, W: W)
                : letterRowFrames(row, keyW: keyW, m: m, W: W)
            for (c, f) in frames.enumerated() {
                caps[r][c].frame = CGRect(x: f.minX, y: y, width: f.width, height: m.keyHeight).integral
            }
            rowBands.append((y - m.vGap / 2)...(y + m.keyHeight + m.vGap / 2))
            y += m.keyHeight + m.vGap
        }
        delegate?.keysViewDidLayout(self)
    }

    private func isEdgeFunction(_ k: KeySpec) -> Bool {
        switch k.action {
        case .shift, .backspace: return true
        case .page: return k.isFunction
        default: return false
        }
    }

    /// Character keys centred (this is what indents the second row); shift / page
    /// keys pinned to the left edge and delete to the right, like iOS.
    private func letterRowFrames(_ row: [KeySpec], keyW: CGFloat, m: KeyMetrics, W: CGFloat) -> [CGRect] {
        // Edge keys at the start and end of the row; anything between stays inline.
        let first = row.firstIndex { !isEdgeFunction($0) } ?? row.count
        let last = row.lastIndex { !isEdgeFunction($0) } ?? -1
        let leading = Array(0..<min(first, row.count))
        let middle: [Int] = first <= last ? Array(first...last) : []
        let trailing: [Int] = last + 1 < row.count ? Array(max(last + 1, first)..<row.count) : []
        var frames = [CGRect](repeating: .zero, count: row.count)
        let charsWidth = middle.reduce(CGFloat(0)) { $0 + row[$1].width * keyW } + CGFloat(max(0, middle.count - 1)) * m.hGap
        var cx = (W - charsWidth) / 2
        for i in middle {
            let w = row[i].width * keyW
            frames[i] = CGRect(x: cx, y: 0, width: w, height: 0)
            cx += w + m.hGap
        }
        let room = (W - charsWidth) / 2 - m.sideInset
        func place(_ idx: [Int], fromLeft: Bool) {
            guard !idx.isEmpty else { return }
            // iOS leaves a wider gap between shift/delete and the letters than between letters.
            let edgeGap = max(m.hGap, min(room * 0.25, 14))
            let fit = (room - edgeGap - CGFloat(idx.count - 1) * m.hGap) / CGFloat(idx.count)
            let each = max(keyW * 0.8, min(fit, row[idx[0]].width * keyW))
            let ordered: [Int] = fromLeft ? idx : Array(idx.reversed())
            let step = each + m.hGap
            var x = fromLeft ? m.sideInset : W - m.sideInset - each
            for i in ordered {
                frames[i] = CGRect(x: x, y: 0, width: each, height: 0)
                if fromLeft { x += step } else { x -= step }
            }
        }
        place(leading, fromLeft: true)
        place(trailing, fromLeft: false)
        return frames
    }

    private func bottomRowFrames(_ row: [KeySpec], standardKey: CGFloat, m: KeyMetrics, W: CGFloat) -> [CGRect] {
        func fixedWidth(_ k: KeySpec) -> CGFloat { k.width * standardKey + max(0, k.width - 1) * m.hGap * 0.5 }
        let fixed = row.filter { !$0.flexible }.reduce(CGFloat(0)) { $0 + fixedWidth($1) }
        let gaps = CGFloat(max(0, row.count - 1)) * m.hGap
        let flexCount = CGFloat(row.filter(\.flexible).count)
        let flex = flexCount > 0 ? max(standardKey, (W - 2 * m.sideInset - fixed - gaps) / flexCount) : 0
        var x = m.sideInset
        var out: [CGRect] = []
        for k in row {
            let w = k.flexible ? flex : fixedWidth(k)
            out.append(CGRect(x: x, y: 0, width: w, height: 0))
            x += w + m.hGap
        }
        return out
    }

    // MARK: Hit testing

    private func keyIndex(at p: CGPoint) -> (Int, Int)? {
        guard !rows.isEmpty, rowBands.count == rows.count else { return nil }
        var r = rowBands.firstIndex { $0.contains(p.y) } ?? (p.y < rowBands[0].lowerBound ? 0 : rows.count - 1)
        r = min(max(0, r), rows.count - 1)
        let gap = (fitted ?? metrics).hGap
        var best: (Int, CGFloat)?
        for (c, cap) in caps[r].enumerated() {
            let f = cap.frame.insetBy(dx: -gap / 2, dy: 0)
            if p.x >= f.minX && p.x < f.maxX { return (r, c) }
            let d = min(abs(p.x - f.minX), abs(p.x - f.maxX))
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
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 34)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.4
        label.textColor = KeyColors.text
        addSubview(label)
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    func show(_ text: String, above keyFrame: CGRect, in bounds: CGRect) {
        label.text = text
        let w = max(keyFrame.width + 18, 48)
        let h = keyFrame.height + 12
        var x = keyFrame.midX - w / 2
        x = min(max(0, x), bounds.width - w)
        frame = CGRect(x: x, y: max(-50, keyFrame.minY - h - 2), width: w, height: h)
        label.frame = self.bounds.insetBy(dx: 4, dy: 2)
        layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: 10).cgPath
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
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
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
            l.font = .systemFont(ofSize: 24)
            l.adjustsFontSizeToFitWidth = true
            l.minimumScaleFactor = 0.5
            l.layer.cornerRadius = 7
            l.clipsToBounds = true
            addSubview(l)
            return l
        }
        let w = cellWidth * CGFloat(opts.count) + 8
        let h = keyFrame.height + 6
        var x = keyFrame.midX - w / 2
        x = min(max(0, x), max(0, bounds.width - w))
        frame = CGRect(x: x, y: max(-50, keyFrame.minY - h - 4), width: w, height: h)
        for (i, l) in labels.enumerated() {
            l.frame = CGRect(x: 4 + CGFloat(i) * cellWidth, y: 3, width: cellWidth, height: h - 6)
        }
        selected = 0
        layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: 10).cgPath
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
