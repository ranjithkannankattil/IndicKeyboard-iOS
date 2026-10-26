//  CandidateBar.swift
//  The strip above the keys. English: iOS-style slots ("typed", correction,
//  completion). Swanalekha: the alternatives for the last letter (the phone version
//  of pressing Tab), scrollable. Idle: ⚙ and the layout name.

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
            for (i, b) in buttons.enumerated() {
                b.frame = CGRect(x: CGFloat(i) * slot + 3, y: 4, width: slot - 6, height: h - 8)
            }
            for (i, s) in separators.enumerated() {
                s.frame = CGRect(x: slot * CGFloat(i + 1), y: h * 0.25, width: hairline, height: h * 0.5)
            }
            scroll.contentSize = scroll.bounds.size
        } else {
            var x: CGFloat = 4
            for (i, b) in buttons.enumerated() {
                let w = max(56, b.intrinsicContentSize.width + 24)
                b.frame = CGRect(x: x, y: 4, width: w, height: h - 8)
                x += w
                if i < separators.count {
                    separators[i].frame = CGRect(x: x, y: h * 0.25, width: hairline, height: h * 0.5)
                }
            }
            scroll.contentSize = CGSize(width: x + 4, height: h)
        }
    }

    func show(_ list: [BarItem]) {
        guard list != items || buttons.count != list.count else { return }
        items = list
        buttons.forEach { $0.removeFromSuperview() }
        separators.forEach { $0.removeFromSuperview() }
        buttons = []
        separators = []
        idleLabel.isHidden = !list.isEmpty
        for (i, item) in list.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(item.title, for: .normal)
            b.titleLabel?.font = item.bold ? .systemFont(ofSize: 18, weight: .semibold) : .systemFont(ofSize: 18)
            b.titleLabel?.adjustsFontSizeToFitWidth = true
            b.titleLabel?.minimumScaleFactor = 0.6
            b.titleLabel?.lineBreakMode = .byTruncatingMiddle
            b.setTitleColor(item.dim ? .secondaryLabel : .label, for: .normal)
            if item.bold {
                b.backgroundColor = UIColor.label.withAlphaComponent(0.08)
                b.layer.cornerRadius = 8
                b.layer.cornerCurve = .continuous
            }
            b.tag = i
            b.addTarget(self, action: #selector(candidateTapped(_:)), for: .touchUpInside)
            scroll.addSubview(b)
            buttons.append(b)
            if i < list.count - 1 {
                let s = UIView()
                s.backgroundColor = .separator
                scroll.addSubview(s)
                separators.append(s)
            }
        }
        scroll.contentOffset = .zero
        setNeedsLayout()
    }

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
