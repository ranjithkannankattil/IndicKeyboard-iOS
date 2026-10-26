//  EmojiPanel.swift
//  iOS-style emoji keyboard: horizontally scrolling grid by category, category
//  bar at the bottom with ABC and delete, and Frequently Used remembered on device.

import UIKit

struct EmojiCategory {
    let name: String
    let symbol: String
    var emoji: [String]
}

enum EmojiData {
    static let all: [EmojiCategory] = {
        guard let j = try? ResourceLocator.json("emoji", subdirectory: nil),
              let cats = j["categories"] as? [[String: Any]] else { return [] }
        return cats.compactMap { c in
            guard let n = c["name"] as? String, let e = c["emoji"] as? [String] else { return nil }
            return EmojiCategory(name: n, symbol: c["symbol"] as? String ?? "circle", emoji: e)
        }
    }()

    private static let recentsKey = "recentEmoji"
    static var recents: [String] { UserDefaults.standard.stringArray(forKey: recentsKey) ?? [] }
    static func noteUsed(_ e: String) {
        var r = recents.filter { $0 != e }
        r.insert(e, at: 0)
        UserDefaults.standard.set(Array(r.prefix(30)), forKey: recentsKey)
    }
}

final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onEmoji: ((String) -> Void)?
    var onABC: (() -> Void)?
    var onDelete: (() -> Void)?

    private var categories: [EmojiCategory]
    private let titleLabel = UILabel()
    private let flow = UICollectionViewFlowLayout()
    private let grid: UICollectionView
    private let bar = UIView()
    private let abcButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private var categoryButtons: [UIButton] = []
    private var deleteTimer: Timer?
    var landscape = false { didSet { setNeedsLayout() } }

    override init(frame: CGRect) {
        var cats = EmojiData.all
        let recents = EmojiData.recents
        cats.insert(EmojiCategory(name: "Frequently Used", symbol: "clock",
                                  emoji: recents.isEmpty ? ["😂", "❤️", "😍", "🙏", "👍", "😊", "😭", "🔥"] : recents), at: 0)
        categories = cats
        flow.scrollDirection = .horizontal
        flow.minimumInteritemSpacing = 0
        flow.minimumLineSpacing = 0
        grid = UICollectionView(frame: .zero, collectionViewLayout: flow)
        super.init(frame: frame)
        backgroundColor = KeyColors.canvas

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel

        grid.backgroundColor = .clear
        grid.showsHorizontalScrollIndicator = false
        grid.dataSource = self
        grid.delegate = self
        grid.register(EmojiCell.self, forCellWithReuseIdentifier: "e")
        grid.disableEdgeFades()

        abcButton.setTitle("ABC", for: .normal)
        abcButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        abcButton.setTitleColor(.label, for: .normal)
        abcButton.addTarget(self, action: #selector(abcTapped), for: .touchUpInside)

        deleteButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        deleteButton.tintColor = .label
        deleteButton.addTarget(self, action: #selector(deleteDown), for: .touchDown)
        deleteButton.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        for (i, c) in categories.enumerated() {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: c.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15)), for: .normal)
            b.tintColor = .secondaryLabel
            b.tag = i
            b.accessibilityLabel = c.name
            b.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            bar.addSubview(b)
            categoryButtons.append(b)
        }
        bar.addSubview(abcButton)
        bar.addSubview(deleteButton)
        addSubview(titleLabel)
        addSubview(grid)
        addSubview(bar)
        highlight(0)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let barH: CGFloat = landscape ? 34 : 40
        titleLabel.frame = CGRect(x: 12, y: 4, width: bounds.width - 24, height: 18)
        grid.frame = CGRect(x: 0, y: 24, width: bounds.width, height: bounds.height - 24 - barH)
        bar.frame = CGRect(x: 0, y: bounds.height - barH, width: bounds.width, height: barH)
        abcButton.frame = CGRect(x: 4, y: 0, width: 48, height: barH)
        deleteButton.frame = CGRect(x: bounds.width - 52, y: 0, width: 48, height: barH)
        let left: CGFloat = 56
        let w = (bounds.width - 112) / CGFloat(max(1, categoryButtons.count))
        for (i, b) in categoryButtons.enumerated() {
            b.frame = CGRect(x: left + CGFloat(i) * w, y: 0, width: w, height: barH)
        }
        let rows: CGFloat = landscape ? 3 : 5
        let side = max(20, floor(grid.bounds.height / rows))
        flow.itemSize = CGSize(width: side * 1.05, height: side)
        flow.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 12)
        flow.invalidateLayout()
    }

    // MARK: Data source

    func numberOfSections(in collectionView: UICollectionView) -> Int { categories.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        categories[section].emoji.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "e", for: indexPath) as! EmojiCell
        cell.label.text = categories[indexPath.section].emoji[indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let e = categories[indexPath.section].emoji[indexPath.item]
        collectionView.deselectItem(at: indexPath, animated: true)
        EmojiData.noteUsed(e)
        UIDevice.current.playInputClick()
        onEmoji?(e)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let probe = CGPoint(x: scrollView.contentOffset.x + 20, y: grid.bounds.height / 2)
        if let ip = grid.indexPathForItem(at: probe) ?? grid.indexPathsForVisibleItems.min() {
            highlight(ip.section)
        }
    }

    private func highlight(_ section: Int) {
        guard section < categories.count else { return }
        for (i, b) in categoryButtons.enumerated() { b.tintColor = i == section ? .label : .secondaryLabel }
        titleLabel.text = categories[section].name.uppercased()
    }

    // MARK: Actions

    @objc private func categoryTapped(_ b: UIButton) {
        guard b.tag < categories.count, !categories[b.tag].emoji.isEmpty else { return }
        grid.scrollToItem(at: IndexPath(item: 0, section: b.tag), at: .left, animated: false)
        highlight(b.tag)
    }

    @objc private func abcTapped() { onABC?() }

    @objc private func deleteDown() {
        onDelete?()
        deleteTimer?.invalidate()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in self?.onDelete?() }
        }
    }

    @objc private func deleteUp() {
        deleteTimer?.invalidate()
        deleteTimer = nil
    }
}

private final class EmojiCell: UICollectionViewCell {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 31)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        contentView.addSubview(label)
        let bg = UIView()
        bg.backgroundColor = UIColor.label.withAlphaComponent(0.12)
        bg.layer.cornerRadius = 8
        selectedBackgroundView = bg
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }
}
