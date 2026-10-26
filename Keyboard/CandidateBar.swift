//  CandidateBar.swift
//  The strip above the keys: Swanalekha alternatives while typing (the phone
//  version of pressing Tab), the raw Latin word, and the ⚙ button when idle.

import UIKit

final class CandidateBar: UIView {
    var onSelect: ((Candidate, Int) -> Void)?
    var onSettings: (() -> Void)?

    private let settingsButton = UIButton(type: .system)
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let idleLabel = UILabel()
    private var candidates: [Candidate] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.tintColor = .secondaryLabel
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        settingsButton.accessibilityLabel = "Keyboard settings"

        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        stack.axis = .horizontal
        stack.spacing = 0
        stack.alignment = .fill
        scroll.addSubview(stack)

        idleLabel.font = .systemFont(ofSize: 14)
        idleLabel.textColor = .secondaryLabel

        addSubview(settingsButton)
        addSubview(scroll)
        addSubview(idleLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        settingsButton.frame = CGRect(x: 4, y: 0, width: 40, height: h)
        scroll.frame = CGRect(x: 48, y: 0, width: bounds.width - 52, height: h)
        idleLabel.frame = scroll.frame.insetBy(dx: 6, dy: 0)
        layoutStack()
    }

    private func layoutStack() {
        let size = stack.systemLayoutSizeFitting(CGSize(width: UIView.layoutFittingCompressedSize.width, height: scroll.bounds.height))
        stack.frame = CGRect(x: 0, y: 0, width: max(size.width, 1), height: scroll.bounds.height)
        scroll.contentSize = stack.frame.size
    }

    /// Shows candidates; index 0 is the word as currently rendered (highlighted).
    func show(_ list: [Candidate]) {
        candidates = list
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        idleLabel.isHidden = !list.isEmpty
        for (i, c) in list.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(c.text, for: .normal)
            let isLatin = c.keys == nil
            b.titleLabel?.font = i == 0 ? .boldSystemFont(ofSize: 19) : .systemFont(ofSize: isLatin ? 16 : 19)
            b.setTitleColor(isLatin ? .secondaryLabel : .label, for: .normal)
            b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            b.tag = i
            b.addTarget(self, action: #selector(candidateTapped(_:)), for: .touchUpInside)
            if i > 0 {
                let sep = UIView()
                sep.backgroundColor = .separator
                sep.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
                stack.addArrangedSubview(sep)
            }
            stack.addArrangedSubview(b)
        }
        scroll.contentOffset = .zero
        setNeedsLayout()
    }

    func showIdle(_ text: String) {
        show([])
        idleLabel.text = text
    }

    @objc private func candidateTapped(_ b: UIButton) {
        guard b.tag < candidates.count else { return }
        onSelect?(candidates[b.tag], b.tag)
    }

    @objc private func settingsTapped() { onSettings?() }
}
