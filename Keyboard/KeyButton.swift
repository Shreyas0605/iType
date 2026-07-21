import UIKit

/// A single keyboard key. Draws a rounded cap with a subtle bottom shadow,
/// highlights on press, and shows a magnified popup above letter keys.
///
/// Most keys are text. The three universal system keys — shift, delete and the
/// keyboard-switch (globe) — are rendered with SF Symbols, exactly as the native
/// keyboard does; every AI-panel and tone button remains plain text.
final class KeyButton: UIControl {
    enum Style { case letter, special, accent }

    let key: KeyModel
    private let style: Style
    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private var popupView: UIView?
    private var isPressed = false

    var onTap: ((KeyModel) -> Void)?
    var onLongPressRepeat: ((KeyModel) -> Void)?
    private var repeatTimer: Timer?

    init(key: KeyModel, style: Style) {
        self.key = key
        self.style = style
        super.init(frame: .zero)
        configure()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func configure() {
        layer.cornerRadius = KeyboardMetrics.cornerRadius
        layer.cornerCurve = .continuous
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.shadowOpacity = 1

        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.55
        titleLabel.baselineAdjustment = .alignCenters
        addSubview(titleLabel)

        iconView.contentMode = .center
        iconView.isUserInteractionEnabled = false
        iconView.isHidden = true
        addSubview(iconView)

        addTarget(self, action: #selector(down), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(up), for: .touchUpInside)
        addTarget(self, action: #selector(exit), for: [.touchUpOutside, .touchCancel, .touchDragExit])

        apply(highlighted: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = bounds
        iconView.frame = bounds
    }

    func setTitle(_ text: String, font: UIFont) {
        titleLabel.text = text
        titleLabel.font = font
        titleLabel.isHidden = false
        iconView.isHidden = true
    }

    func setSymbol(_ name: String, pointSize: CGFloat) {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        iconView.image = UIImage(systemName: name, withConfiguration: config)?.withRenderingMode(.alwaysTemplate)
        iconView.isHidden = false
        titleLabel.isHidden = true
    }

    // MARK: - Appearance

    private var baseColor: UIColor {
        switch style {
        case .letter:  return KeyboardColors.letterKey
        case .special: return KeyboardColors.specialKey
        case .accent:  return KeyboardColors.accent
        }
    }
    private var highlightColor: UIColor {
        switch style {
        case .letter:  return KeyboardColors.letterKeyHighlight
        case .special: return KeyboardColors.specialKeyHighlight
        case .accent:  return KeyboardColors.accent.withAlphaComponent(0.82)
        }
    }
    private var textColor: UIColor { style == .accent ? .white : KeyboardColors.keyText }

    func apply(highlighted: Bool) {
        backgroundColor = highlighted ? highlightColor : baseColor
        titleLabel.textColor = textColor
        iconView.tintColor = textColor
        layer.shadowColor = KeyboardColors.keyShadow.cgColor
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        apply(highlighted: isPressed)
    }

    // MARK: - Touch

    @objc private func down() {
        isPressed = true
        apply(highlighted: true)
        Haptics.tap()
        if key.showsPopup { showPopup() }
        if key.action == .backspace { startRepeat() }
    }

    @objc private func up() {
        isPressed = false
        apply(highlighted: false)
        hidePopup()
        stopRepeat()
        onTap?(key)
    }

    @objc private func exit() {
        isPressed = false
        apply(highlighted: false)
        hidePopup()
        stopRepeat()
    }

    // MARK: - Backspace auto-repeat

    private func startRepeat() {
        stopRepeat()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] _ in
                guard let self = self, self.isPressed else { return }
                self.onLongPressRepeat?(self.key)
                Haptics.tap()
            }
        }
    }
    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    // MARK: - Popup

    private func showPopup() {
        guard popupView == nil, let window = window, let text = titleLabel.text, !text.isEmpty else { return }
        let frameInWindow = convert(bounds, to: window)
        let w = max(bounds.width * 1.4, 34)
        let h = bounds.height * 1.6
        var rect = CGRect(x: frameInWindow.midX - w / 2, y: frameInWindow.minY - h - 3, width: w, height: h)
        rect.origin.x = min(max(4, rect.origin.x), window.bounds.width - w - 4)

        let popup = UIView(frame: rect)
        popup.backgroundColor = KeyboardColors.popupBackground
        popup.layer.cornerRadius = 8
        popup.layer.cornerCurve = .continuous
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.20
        popup.layer.shadowRadius = 5
        popup.layer.shadowOffset = CGSize(width: 0, height: 2)

        let label = UILabel(frame: popup.bounds)
        label.textAlignment = .center
        label.text = text
        label.textColor = KeyboardColors.keyText
        label.font = .systemFont(ofSize: 26, weight: .regular)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popup.addSubview(label)

        popup.alpha = 0
        popup.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        window.addSubview(popup)
        popupView = popup
        UIView.animate(withDuration: 0.06) {
            popup.alpha = 1
            popup.transform = .identity
        }
    }

    private func hidePopup() {
        guard let popup = popupView else { return }
        popupView = nil
        UIView.animate(withDuration: 0.05, animations: { popup.alpha = 0 }) { _ in
            popup.removeFromSuperview()
        }
    }
}
