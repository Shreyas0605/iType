import UIKit

/// Layout metrics tuned to feel close to the native portrait keyboard.
enum KeyboardMetrics {
    static let keyHeight: CGFloat = 43
    static let rowSpacing: CGFloat = 11
    static let keySpacing: CGFloat = 6
    static let sideInset: CGFloat = 3
    static let topInset: CGFloat = 8
    static let bottomInset: CGFloat = 4
    static let cornerRadius: CGFloat = 5
    static let suggestionBarHeight: CGFloat = 46
    static let panelHeight: CGFloat = 210

    static var keyboardHeight: CGFloat {
        topInset + keyHeight * 4 + rowSpacing * 3 + bottomInset
    }
}

/// Dynamic colours approximating the native keyboard in light and dark mode.
enum KeyboardColors {
    static func dynamic(_ light: UIColor, _ dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    static let keyboardBackground = dynamic(
        UIColor(red: 0.820, green: 0.835, blue: 0.859, alpha: 1),
        UIColor(red: 0.106, green: 0.106, blue: 0.118, alpha: 1))
    static let letterKey = dynamic(
        .white,
        UIColor(red: 0.420, green: 0.420, blue: 0.439, alpha: 1))
    static let letterKeyHighlight = dynamic(
        UIColor(red: 0.706, green: 0.722, blue: 0.749, alpha: 1),
        UIColor(red: 0.549, green: 0.549, blue: 0.569, alpha: 1))
    static let specialKey = dynamic(
        UIColor(red: 0.671, green: 0.694, blue: 0.729, alpha: 1),
        UIColor(red: 0.267, green: 0.267, blue: 0.286, alpha: 1))
    static let specialKeyHighlight = dynamic(
        .white,
        UIColor(red: 0.420, green: 0.420, blue: 0.439, alpha: 1))
    static let keyText = dynamic(.black, .white)
    static let keyShadow = dynamic(
        UIColor(red: 0.529, green: 0.545, blue: 0.576, alpha: 1),
        UIColor(red: 0, green: 0, blue: 0, alpha: 0.6))
    static let popupBackground = dynamic(
        .white,
        UIColor(red: 0.463, green: 0.463, blue: 0.482, alpha: 1))
    static let accent = UIColor.systemBlue
}

/// Haptic feedback. Only fires when the keyboard has Full Access; otherwise it's
/// a silent no-op, which is fine.
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
