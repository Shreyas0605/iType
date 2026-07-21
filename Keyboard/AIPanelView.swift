import UIKit

/// The AI panel that slides in above the keyboard. One rewrite per page (swipe
/// horizontally like Photos), a single horizontally-scrolling row of tone chips,
/// and a "Generate 3 More Rewrites" button. All labels are plain text.
final class AIPanelView: UIView {
    var onApply: ((String) -> Void)?
    var onSelectTone: ((RewriteTone) -> Void)?
    var onMore: (() -> Void)?
    var onClose: (() -> Void)?
    var onPasteKey: (() -> Void)?

    private let titleLabel = UILabel()
    private let pageLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let messageLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let moreButton = UIButton(type: .system)
    private let pasteKeyButton = UIButton(type: .system)

    private let cardsLayout = UICollectionViewFlowLayout()
    private let toneLayout = UICollectionViewFlowLayout()
    private let cardsCollection: UICollectionView
    private let toneCollection: UICollectionView

    private var rewrites: [String] = []
    private var selectedTone: RewriteTone = .professional
    private let tones = RewriteTone.allCases

    private let cardID = "card"
    private let toneID = "tone"

    override init(frame: CGRect) {
        cardsLayout.scrollDirection = .horizontal
        cardsLayout.minimumLineSpacing = 0
        cardsLayout.minimumInteritemSpacing = 0
        cardsLayout.sectionInset = .zero
        cardsCollection = UICollectionView(frame: .zero, collectionViewLayout: cardsLayout)

        toneLayout.scrollDirection = .horizontal
        toneLayout.minimumLineSpacing = 8
        toneLayout.minimumInteritemSpacing = 8
        toneLayout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        toneCollection = UICollectionView(frame: .zero, collectionViewLayout: toneLayout)

        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func build() {
        backgroundColor = KeyboardColors.keyboardBackground

        titleLabel.text = "Rewrite"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = KeyboardColors.keyText
        addSubview(titleLabel)

        pageLabel.font = .systemFont(ofSize: 13, weight: .regular)
        pageLabel.textColor = .secondaryLabel
        pageLabel.textAlignment = .center
        addSubview(pageLabel)

        closeButton.setTitle("Close", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)

        cardsCollection.backgroundColor = .clear
        cardsCollection.isPagingEnabled = true
        cardsCollection.showsHorizontalScrollIndicator = false
        cardsCollection.dataSource = self
        cardsCollection.delegate = self
        cardsCollection.register(RewriteCardCell.self, forCellWithReuseIdentifier: cardID)
        addSubview(cardsCollection)

        toneCollection.backgroundColor = .clear
        toneCollection.showsHorizontalScrollIndicator = false
        toneCollection.dataSource = self
        toneCollection.delegate = self
        toneCollection.register(ToneCell.self, forCellWithReuseIdentifier: toneID)
        addSubview(toneCollection)

        moreButton.setTitle("Generate 3 More Rewrites", for: .normal)
        moreButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        moreButton.setTitleColor(.white, for: .normal)
        moreButton.backgroundColor = KeyboardColors.accent
        moreButton.layer.cornerRadius = 10
        moreButton.layer.cornerCurve = .continuous
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        addSubview(moreButton)

        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = true
        addSubview(messageLabel)

        spinner.hidesWhenStopped = true
        addSubview(spinner)

        pasteKeyButton.setTitle("Paste API Key", for: .normal)
        pasteKeyButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        pasteKeyButton.setTitleColor(.white, for: .normal)
        pasteKeyButton.backgroundColor = KeyboardColors.accent
        pasteKeyButton.layer.cornerRadius = 10
        pasteKeyButton.layer.cornerCurve = .continuous
        pasteKeyButton.addTarget(self, action: #selector(pasteKeyTapped), for: .touchUpInside)
        pasteKeyButton.isHidden = true
        addSubview(pasteKeyButton)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let pad: CGFloat = 12
        let headerH: CGFloat = 28
        titleLabel.frame = CGRect(x: pad, y: 6, width: 120, height: headerH)
        closeButton.frame = CGRect(x: w - 76, y: 6, width: 64, height: headerH)
        pageLabel.frame = CGRect(x: w / 2 - 70, y: 6, width: 140, height: headerH)

        let cardsY = 6 + headerH + 4
        let moreH: CGFloat = 40
        let toneH: CGFloat = 34
        let bottomPad: CGFloat = 8
        let moreY = bounds.height - bottomPad - moreH
        let toneY = moreY - 8 - toneH
        let cardsH = toneY - 8 - cardsY

        cardsCollection.frame = CGRect(x: 0, y: cardsY, width: w, height: max(0, cardsH))
        cardsLayout.itemSize = CGSize(width: w, height: max(1, cardsH))
        cardsLayout.invalidateLayout()

        toneCollection.frame = CGRect(x: 0, y: toneY, width: w, height: toneH)
        moreButton.frame = CGRect(x: pad, y: moreY, width: w - pad * 2, height: moreH)

        messageLabel.frame = CGRect(x: 24, y: cardsCollection.frame.minY + 4,
                                    width: w - 48, height: max(0, cardsCollection.frame.height - 56))
        pasteKeyButton.frame = CGRect(x: w / 2 - 90, y: cardsCollection.frame.maxY - 46,
                                      width: 180, height: 38)
        spinner.center = CGPoint(x: cardsCollection.frame.midX, y: cardsCollection.frame.midY)
    }

    // MARK: - State

    func apply(state: RewriteEngine.State, tone: RewriteTone) {
        selectedTone = tone
        toneCollection.reloadData()

        switch state {
        case .idle:
            showMessage("Type something, then tap AI to rewrite it.")
        case .loading:
            pasteKeyButton.isHidden = true
            rewrites = []
            cardsCollection.reloadData()
            messageLabel.isHidden = true
            spinner.startAnimating()
            pageLabel.text = nil
            moreButton.isEnabled = false
            moreButton.alpha = 0.5
        case .loaded(let items):
            pasteKeyButton.isHidden = true
            spinner.stopAnimating()
            messageLabel.isHidden = true
            rewrites = items
            cardsCollection.reloadData()
            cardsCollection.setContentOffset(.zero, animated: false)
            updatePageLabel(page: 0)
            moreButton.isEnabled = true
            moreButton.alpha = 1
        case .error(let message):
            showMessage(message)
        case .needsKey:
            showMessage("Copy your Gemini API key (from the AI Keyboard app or ai.google.dev), then tap Paste API Key.")
            pasteKeyButton.isHidden = false
        case .noFullAccess:
            showMessage("Turn on \"Allow Full Access\" for AI Keyboard in Settings to use AI.")
        }
    }

    private func showMessage(_ text: String) {
        pasteKeyButton.isHidden = true
        spinner.stopAnimating()
        rewrites = []
        cardsCollection.reloadData()
        pageLabel.text = nil
        messageLabel.text = text
        messageLabel.isHidden = false
        moreButton.isEnabled = false
        moreButton.alpha = 0.5
    }

    private func updatePageLabel(page: Int) {
        guard !rewrites.isEmpty else { pageLabel.text = nil; return }
        pageLabel.text = "\(page + 1) of \(rewrites.count)"
    }

    // MARK: - Actions

    @objc private func closeTapped() { onClose?() }
    @objc private func moreTapped() { onMore?() }
    @objc private func pasteKeyTapped() { onPasteKey?() }
}

// MARK: - Collection data source / delegate

extension AIPanelView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView === cardsCollection ? rewrites.count : tones.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === cardsCollection {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cardID, for: indexPath) as! RewriteCardCell
            cell.configure(text: rewrites[indexPath.item])
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: toneID, for: indexPath) as! ToneCell
            let tone = tones[indexPath.item]
            cell.configure(title: tone.label, selected: tone == selectedTone)
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === cardsCollection {
            guard indexPath.item < rewrites.count else { return }
            onApply?(rewrites[indexPath.item])
        } else {
            let tone = tones[indexPath.item]
            selectedTone = tone
            collectionView.reloadData()
            onSelectTone?(tone)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView === cardsCollection {
            return CGSize(width: bounds.width, height: max(1, cardsCollection.bounds.height))
        }
        let title = tones[indexPath.item].label
        let width = (title as NSString).size(withAttributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium)
        ]).width + 28
        return CGSize(width: ceil(width), height: 34)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === cardsCollection, cardsCollection.bounds.width > 0 else { return }
        let page = Int((scrollView.contentOffset.x / cardsCollection.bounds.width).rounded())
        updatePageLabel(page: max(0, min(page, max(0, rewrites.count - 1))))
    }
}

// MARK: - Cells

/// A premium rewrite card. Tapping it applies the rewrite.
final class RewriteCardCell: UICollectionViewCell {
    private let card = UIView()
    private let textLabel = UILabel()
    private let hintLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        card.backgroundColor = KeyboardColors.dynamic(.white, UIColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1))
        card.layer.cornerRadius = 14
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.10
        card.layer.shadowRadius = 6
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.addSubview(card)

        textLabel.numberOfLines = 0
        textLabel.font = .systemFont(ofSize: 17, weight: .regular)
        textLabel.textColor = KeyboardColors.keyText
        card.addSubview(textLabel)

        hintLabel.text = "Tap to use"
        hintLabel.font = .systemFont(ofSize: 12, weight: .medium)
        hintLabel.textColor = .secondaryLabel
        card.addSubview(hintLabel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        card.frame = contentView.bounds.insetBy(dx: 12, dy: 2)
        let inset: CGFloat = 16
        hintLabel.frame = CGRect(x: inset, y: card.bounds.height - 26,
                                 width: card.bounds.width - inset * 2, height: 18)
        textLabel.frame = CGRect(x: inset, y: inset,
                                 width: card.bounds.width - inset * 2,
                                 height: card.bounds.height - inset - 30)
    }

    func configure(text: String) { textLabel.text = text }
}

/// A tone chip. Selected state fills with the accent colour.
final class ToneCell: UICollectionViewCell {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 17
        contentView.layer.cornerCurve = .continuous
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        contentView.addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }

    func configure(title: String, selected: Bool) {
        label.text = title
        if selected {
            contentView.backgroundColor = KeyboardColors.accent
            label.textColor = .white
        } else {
            contentView.backgroundColor = KeyboardColors.dynamic(.white, UIColor(red: 0.28, green: 0.28, blue: 0.30, alpha: 1))
            label.textColor = KeyboardColors.keyText
        }
    }
}
