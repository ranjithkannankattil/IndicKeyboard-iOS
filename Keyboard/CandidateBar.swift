//  CandidateBar.swift
//  The strip above the keys. English: iOS-style slots ("typed", correction,
//  completion). Swanalekha: the alternatives for the last letter (the phone version
//  of pressing Tab), scrollable. Idle: just ⚙.

import UIKit

struct BarItem: Equatable {
    var title: String
    var bold = false        // the suggestion that space will apply
    var dim = false         // e.g. the literal typed word
}

final class CandidateBar: UIView {
    var onSelect: ((Int) -> Void)?
    var onSettings: (() -> Void)?

    private let settingsButton = UIButton(type: .system)
    private let scroll = UIScrollView()
    private var buttons: [UIButton] = []
    private var separators: [UIView] = []
    private let idleLabel = UILabel()
    private var items: [BarItem] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = .secondaryLabel
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        settingsButton.accessibilityLabel = "Keyboard settings"

        scroll.showsHorizontalScrollIndicator = false
        scroll.disableEdgeFades()
        scroll.alwaysBounceHorizontal = false

        idleLabel.font = .systemFont(ofSize: 14)
        idleLabel.textColor = .secondaryLabel
        idleLabel.textAlignment = .center

        addSubview(scroll)
        addSubview(idleLabel)
        addSubview(settingsButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        settingsButton.isHidden = !items.isEmpty
        settingsButton.frame = CGRect(x: 4, y: 0, width: 40, height: h)
        idleLabel.frame = bounds.insetBy(dx: 48, dy: 0)
        scroll.frame = bounds
        layoutButtons()
    }

    private var hairline: CGFloat { 1 / max(1, window?.screen.scale ?? 2) }

    private func layoutButtons() {
        let h = scroll.bounds.height
        let W = scroll.bounds.width
        if items.count <= 3 {
            // Equal slots across the bar, like the iOS predictive bar.
            let slot = W / CGFloat(max(1, items.count))
            for (i, b) in buttons.prefix(items.count).enumerated() {
                b.frame = CGRect(x: CGFloat(i) * slot + 3, y: 2, width: slot - 6, height: h - 4)
            }
            for (i, s) in separators.prefix(max(0, items.count - 1)).enumerated() {
                s.frame = CGRect(x: slot * CGFloat(i + 1), y: h * 0.25, width: hairline, height: h * 0.5)
            }
            scroll.contentSize = scroll.bounds.size
        } else {
            var x: CGFloat = 4
            for (i, b) in buttons.prefix(items.count).enumerated() {
                let w = max(56, b.intrinsicContentSize.width + 24)
                b.frame = CGRect(x: x, y: 2, width: w, height: h - 4)
                x += w
                if i < items.count - 1, i < separators.count {
                    separators[i].frame = CGRect(x: x, y: h * 0.25, width: hairline, height: h * 0.5)
                }
            }
            scroll.contentSize = CGSize(width: x + 4, height: h)
        }
    }

    /// Updates the bar in place: buttons are kept and only their text and style change,
    /// so a refresh between two key taps costs almost nothing.
    func show(_ list: [BarItem]) {
        guard list != items else { return }
        items = list
        idleLabel.isHidden = !list.isEmpty
        while buttons.count < list.count {
            let b = UIButton(type: .custom)
            b.titleLabel?.adjustsFontSizeToFitWidth = true
            b.titleLabel?.minimumScaleFactor = 0.6
            b.titleLabel?.lineBreakMode = .byTruncatingMiddle
            b.layer.cornerRadius = 8
            b.layer.cornerCurve = .continuous
            b.tag = buttons.count
            b.addTarget(self, action: #selector(candidateTapped(_:)), for: .touchUpInside)
            scroll.addSubview(b)
            buttons.append(b)
        }
        while separators.count < max(0, list.count - 1) {
            let s = UIView()
            s.backgroundColor = .separator
            scroll.addSubview(s)
            separators.append(s)
        }
        for (i, b) in buttons.enumerated() {
            guard i < list.count else { b.isHidden = true; continue }
            let item = list[i]
            b.isHidden = false
            b.setTitle(item.title, for: .normal)
            b.titleLabel?.font = item.bold ? Self.boldFont : Self.plainFont
            b.setTitleColor(item.dim ? .secondaryLabel : .label, for: .normal)
            b.setTitleColor(.tertiaryLabel, for: .highlighted)
            b.backgroundColor = item.bold ? UIColor.label.withAlphaComponent(0.08) : nil
        }
        for (i, s) in separators.enumerated() { s.isHidden = i >= list.count - 1 }
        scroll.contentOffset = .zero
        setNeedsLayout()
    }

    private static let plainFont = UIFont.systemFont(ofSize: 18)
    private static let boldFont = UIFont.systemFont(ofSize: 18, weight: .semibold)

    func showIdle(_ text: String) {
        show([])
        idleLabel.text = text
        setNeedsLayout()
    }

    @objc private func candidateTapped(_ b: UIButton) {
        guard b.tag < items.count else { return }
        onSelect?(b.tag)
    }

    @objc private func settingsTapped() { onSettings?() }
}
