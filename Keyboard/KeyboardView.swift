import UIKit

/// Definition of a single key.
struct KeyModel: Equatable {
    enum Action: Equatable {
        case char(String)
        case backspace
        case shift
        case modeLetters
        case modeNumbers
        case modeSymbols
        case space
        case ret
        case nextKeyboard
    }
    let action: Action
    var display: String = ""
    var symbol: String? = nil          // SF Symbol name (system keys only)
    var symbolPointSize: CGFloat = 20
    var widthWeight: CGFloat = 1
    var showsPopup: Bool = false
    var style: KeyButton.Style = .letter
}

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didInsert text: String)
    func keyboardViewDidBackspace(_ view: KeyboardView)
    func keyboardViewDidReturn(_ view: KeyboardView)
    func keyboardViewDidTapSpace(_ view: KeyboardView)
    func keyboardViewAdvanceInputMode(_ view: KeyboardView)
}

/// The QWERTY keyboard surface: letters, numbers and symbols with a shift key,
/// mode switching, space, return, delete (with auto-repeat) and the globe key.
final class KeyboardView: UIView {
    weak var delegate: KeyboardViewDelegate?

    enum Mode { case letters, numbers, symbols }
    enum ShiftState { case off, on, locked }

    private(set) var mode: Mode = .letters
    private(set) var shift: ShiftState = .on

    /// Whether to show the globe key (driven by `needsInputModeSwitchKey`).
    var showsNextKeyboard: Bool = true { didSet { if oldValue != showsNextKeyboard { rebuild() } } }

    private var rowModels: [[KeyModel]] = []
    private var rowButtons: [[KeyButton]] = []
    private var lastShiftTap: TimeInterval = 0

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil && rowButtons.isEmpty {
            rebuild()
        }
    }

    // MARK: - Build & layout

    private func rebuild() {
        rowButtons.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        rowButtons.removeAll()
        rowModels = makeRows()

        for row in rowModels {
            var buttons: [KeyButton] = []
            for model in row {
                let button = KeyButton(key: model, style: model.style)
                if let symbol = model.symbol {
                    button.setSymbol(symbol, pointSize: model.symbolPointSize)
                } else {
                    button.setTitle(model.display, font: font(for: model))
                }
                button.onTap = { [weak self] key in self?.handle(key) }
                button.onLongPressRepeat = { [weak self] key in
                    if key.action == .backspace { self?.delegate?.keyboardViewDidBackspace(self!) }
                }
                addSubview(button)
                buttons.append(button)
            }
            rowButtons.append(buttons)
        }
        setNeedsLayout()
    }

    private func font(for model: KeyModel) -> UIFont {
        switch model.action {
        case .char where model.display.count > 1, .modeLetters, .modeNumbers, .modeSymbols:
            return .systemFont(ofSize: 16, weight: .regular)
        case .ret, .space:
            return .systemFont(ofSize: 16, weight: .regular)
        default:
            return .systemFont(ofSize: 22, weight: .regular)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let m = KeyboardMetrics.self
        guard !rowButtons.isEmpty else { return }
        let rowCount = rowButtons.count
        let usableHeight = bounds.height - m.topInset - m.bottomInset
        let rowH = (usableHeight - m.rowSpacing * CGFloat(rowCount - 1)) / CGFloat(rowCount)
        var y = m.topInset
        for (i, buttons) in rowButtons.enumerated() {
            let models = rowModels[i]
            let totalWeight = models.reduce(0) { $0 + $1.widthWeight }
            let available = bounds.width - 2 * m.sideInset - m.keySpacing * CGFloat(models.count - 1)
            var x = m.sideInset
            for (j, button) in buttons.enumerated() {
                let w = models[j].widthWeight / totalWeight * available
                button.frame = CGRect(x: x, y: y, width: w, height: rowH)
                x += w + m.keySpacing
            }
            y += rowH + m.rowSpacing
        }
    }

    // MARK: - Rows

    private func charKey(_ s: String, popup: Bool = true) -> KeyModel {
        KeyModel(action: .char(s), display: s, widthWeight: 1, showsPopup: popup, style: .letter)
    }

    private func backspaceKey() -> KeyModel {
        KeyModel(action: .backspace, symbol: "delete.left", symbolPointSize: 20,
                 widthWeight: 1.5, showsPopup: false, style: .special)
    }

    private func shiftKey() -> KeyModel {
        let symbol: String
        switch shift {
        case .off:    symbol = "shift"
        case .on:     symbol = "shift.fill"
        case .locked: symbol = "capslock.fill"
        }
        return KeyModel(action: .shift, symbol: symbol, symbolPointSize: 20,
                        widthWeight: 1.5, showsPopup: false, style: .special)
    }

    private func bottomRow() -> [KeyModel] {
        let modeKey: KeyModel
        switch mode {
        case .letters: modeKey = KeyModel(action: .modeNumbers, display: "123", widthWeight: 1.5, style: .special)
        default:       modeKey = KeyModel(action: .modeLetters, display: "ABC", widthWeight: 1.5, style: .special)
        }
        var row: [KeyModel] = [modeKey]
        if showsNextKeyboard {
            row.append(KeyModel(action: .nextKeyboard, symbol: "globe", symbolPointSize: 20,
                                widthWeight: 1.1, style: .special))
        }
        row.append(KeyModel(action: .space, display: "space", widthWeight: 5, style: .letter))
        row.append(KeyModel(action: .ret, display: "return", widthWeight: 1.8, style: .special))
        return row
    }

    private func makeRows() -> [[KeyModel]] {
        switch mode {
        case .letters:
            let upper = shift != .off
            func letters(_ s: String) -> [KeyModel] {
                s.map { ch in
                    let d = upper ? String(ch).uppercased() : String(ch)
                    return charKey(d)
                }
            }
            var row3: [KeyModel] = [shiftKey()]
            row3 += letters("zxcvbnm")
            row3.append(backspaceKey())
            return [letters("qwertyuiop"), letters("asdfghjkl"), row3, bottomRow()]

        case .numbers:
            let r1 = "1234567890".map { charKey(String($0)) }
            let r2 = "-/:;()$&@\"".map { charKey(String($0)) }
            var r3: [KeyModel] = [KeyModel(action: .modeSymbols, display: "#+=", widthWeight: 1.5, style: .special)]
            r3 += ".,?!'".map { charKey(String($0)) }
            r3.append(backspaceKey())
            return [r1, r2, r3, bottomRow()]

        case .symbols:
            let r1 = "[]{}#%^*+=".map { charKey(String($0)) }
            let r2 = "_\\|~<>€£¥•".map { charKey(String($0)) }
            var r3: [KeyModel] = [KeyModel(action: .modeNumbers, display: "123", widthWeight: 1.5, style: .special)]
            r3 += ".,?!'".map { charKey(String($0)) }
            r3.append(backspaceKey())
            return [r1, r2, r3, bottomRow()]
        }
    }

    // MARK: - Key handling

    private func handle(_ key: KeyModel) {
        switch key.action {
        case .char(let s):
            delegate?.keyboardView(self, didInsert: s)
            if shift == .on { shift = .off; rebuild() }   // auto-lowercase after one capital
        case .backspace:
            delegate?.keyboardViewDidBackspace(self)
        case .shift:
            toggleShift()
        case .modeLetters:
            mode = .letters; rebuild()
        case .modeNumbers:
            mode = .numbers; rebuild()
        case .modeSymbols:
            mode = .symbols; rebuild()
        case .space:
            delegate?.keyboardViewDidTapSpace(self)
        case .ret:
            delegate?.keyboardViewDidReturn(self)
        case .nextKeyboard:
            delegate?.keyboardViewAdvanceInputMode(self)
        }
    }

    private func toggleShift() {
        let now = Date().timeIntervalSince1970
        if now - lastShiftTap < 0.3 {
            shift = .locked          // double-tap → caps lock
        } else {
            switch shift {
            case .off:    shift = .on
            case .on:     shift = .off
            case .locked: shift = .off
            }
        }
        lastShiftTap = now
        rebuild()
    }

    /// Reset to a capitalised letters layout (called when a new field begins).
    func resetForNewInput() {
        mode = .letters
        shift = .on
        rebuild()
    }
}
