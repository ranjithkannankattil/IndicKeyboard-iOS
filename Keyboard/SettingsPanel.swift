//  SettingsPanel.swift
//  In-keyboard settings: tap a layout to switch to it, flip its switch to
//  include it in the layout key's rotation. Opened with ⚙ or by holding the layout key.

import UIKit

final class SettingsPanel: UIView {
    var onClose: (() -> Void)?
    var onChoose: ((String) -> Void)?
    var onChange: (() -> Void)?

    private let settings = KeyboardSettings.shared
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let header = UIView()
    private let title = UILabel()
    private let done = UIButton(type: .system)
    private var current: String

    init(current: String) {
        self.current = current
        super.init(frame: .zero)
        backgroundColor = KeyColors.canvas

        title.text = "Layouts"
        title.font = .boldSystemFont(ofSize: 16)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .boldSystemFont(ofSize: 16)
        done.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        header.addSubview(title)
        header.addSubview(done)
        addSubview(header)

        scroll.disableEdgeFades()
        stack.axis = .vertical
        stack.spacing = 1
        scroll.addSubview(stack)
        addSubview(scroll)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let enabled = Set(settings.enabledLayouts)
        for info in LayoutCatalog.all {
            stack.addArrangedSubview(row(title: info.name, subtitle: info.subtitle,
                                         isOn: enabled.contains(info.id),
                                         isCurrent: info.id == current) { [weak self] on in
                self?.settings.setEnabled(info.id, on)
                self?.onChange?()
                self?.build()
            } tapped: { [weak self] in
                self?.settings.setEnabled(info.id, true)
                self?.onChoose?(info.id)
            })
        }
        stack.addArrangedSubview(sectionLabel("Speed check — type a bit, then open ⚙"))
        for (name, value) in SpeedMeter.shared.lines {
            let v = UIView()
            v.backgroundColor = KeyColors.key
            let t = UILabel(), s = UILabel()
            t.text = name; t.font = .systemFont(ofSize: 15); t.textColor = KeyColors.text
            s.text = value; s.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular); s.textColor = KeyColors.hint
            s.adjustsFontSizeToFitWidth = true; s.minimumScaleFactor = 0.7
            let col = UIStackView(arrangedSubviews: [t, s])
            col.axis = .vertical; col.spacing = 2
            col.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(col)
            NSLayoutConstraint.activate([
                col.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 14),
                col.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -14),
                col.centerYAnchor.constraint(equalTo: v.centerYAnchor),
                v.heightAnchor.constraint(equalToConstant: 50),
            ])
            stack.addArrangedSubview(v)
        }
        stack.addArrangedSubview(sectionLabel("Typing"))
        stack.addArrangedSubview(row(title: "Underline word while typing",
                                     subtitle: "Turn off if an app duplicates or loses letters",
                                     isOn: settings.underlineWhileComposing, isCurrent: false,
                                     toggled: { [weak self] on in
            self?.settings.underlineWhileComposing = on
            self?.onChange?()
        }, tapped: nil))
        stack.addArrangedSubview(row(title: "Auto-Correction", subtitle: "English: fix misspelt words when you type space",
                                     isOn: settings.autocorrect, isCurrent: false,
                                     toggled: { [weak self] on in
            self?.settings.autocorrect = on
            self?.onChange?()
        }, tapped: nil))
        stack.addArrangedSubview(row(title: "Leave Manglish alone", subtitle: "English: don't correct Malayalam typed in English letters (enthu, alle, machane)",
                                     isOn: settings.manglishFriendly, isCurrent: false,
                                     toggled: { [weak self] on in
            self?.settings.manglishFriendly = on
            self?.onChange?()
        }, tapped: nil))
        stack.addArrangedSubview(row(title: "Predictive", subtitle: "English: word suggestions above the keys",
                                     isOn: settings.predictive, isCurrent: false,
                                     toggled: { [weak self] on in
            self?.settings.predictive = on
            self?.onChange?()
        }, tapped: nil))
        stack.addArrangedSubview(row(title: "\".\" Shortcut", subtitle: "Double-tap space to type a full stop",
                                     isOn: settings.doubleSpacePeriod, isCurrent: false,
                                     toggled: { [weak self] on in
            self?.settings.doubleSpacePeriod = on
            self?.onChange?()
        }, tapped: nil))
        stack.addArrangedSubview(row(title: "Key clicks", subtitle: "Follows the system keyboard-click setting",
                                     isOn: settings.keyClicks, isCurrent: false,
                                     toggled: { [weak self] on in
            self?.settings.keyClicks = on
            self?.onChange?()
        }, tapped: nil))
        setNeedsLayout()
    }

    private func sectionLabel(_ text: String) -> UIView {
        let l = UILabel()
        l.text = "  " + text.uppercased()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .secondaryLabel
        l.heightAnchor.constraint(equalToConstant: 30).isActive = true
        return l
    }

    private func row(title: String, subtitle: String, isOn: Bool, isCurrent: Bool,
                     toggled: @escaping (Bool) -> Void, tapped: (() -> Void)?) -> UIView {
        let v = RowView(toggled: toggled, tapped: tapped)
        v.backgroundColor = KeyColors.key
        v.titleLabel.text = title
        v.subtitleLabel.text = subtitle
        v.toggle.isOn = isOn
        v.check.isHidden = !isCurrent
        v.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return v
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        header.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 40)
        title.frame = CGRect(x: 14, y: 0, width: 200, height: 40)
        done.frame = CGRect(x: bounds.width - 80, y: 0, width: 70, height: 40)
        scroll.frame = CGRect(x: 0, y: 40, width: bounds.width, height: bounds.height - 40)
        let h = stack.systemLayoutSizeFitting(CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height),
                                              withHorizontalFittingPriority: .required,
                                              verticalFittingPriority: .fittingSizeLevel).height
        stack.frame = CGRect(x: 0, y: 0, width: bounds.width, height: h)
        scroll.contentSize = CGSize(width: bounds.width, height: h)
    }

    @objc private func closeTapped() { onClose?() }
}

private final class RowView: UIView {
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let toggle = UISwitch()
    let check = UIImageView(image: UIImage(systemName: "checkmark"))
    private let toggled: (Bool) -> Void
    private let tapped: (() -> Void)?

    init(toggled: @escaping (Bool) -> Void, tapped: (() -> Void)?) {
        self.toggled = toggled
        self.tapped = tapped
        super.init(frame: .zero)
        titleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabel
        check.tintColor = KeyColors.accent
        toggle.addTarget(self, action: #selector(switched), for: .valueChanged)
        [check, titleLabel, subtitleLabel, toggle].forEach(addSubview)
        if tapped != nil {
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rowTapped)))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let sw = toggle.intrinsicContentSize
        toggle.frame = CGRect(x: bounds.width - sw.width - 12, y: (bounds.height - sw.height) / 2, width: sw.width, height: sw.height)
        check.frame = CGRect(x: 10, y: (bounds.height - 18) / 2, width: 18, height: 18)
        let x: CGFloat = 36
        let w = toggle.frame.minX - x - 8
        titleLabel.frame = CGRect(x: x, y: 7, width: w, height: 21)
        subtitleLabel.frame = CGRect(x: x, y: 28, width: w, height: 15)
    }

    @objc private func switched() { toggled(toggle.isOn) }
    @objc private func rowTapped() { tapped?() }
}
