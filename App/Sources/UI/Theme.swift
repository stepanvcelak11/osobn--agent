import SwiftUI
import UIKit
import RealmCore

/// Klidný tmavý vzhled: téměř černé pozadí (šetří baterii na OLED displeji), teplý tlumený text
/// (nebolí oči), žádné animace ani rozmazávání. Jedna barva zvýraznění.
enum Theme {
    static let bg0 = Color(red: 0.055, green: 0.051, blue: 0.047)
    static let bg1 = Color(red: 0.102, green: 0.094, blue: 0.086)
    static let bg2 = Color(red: 0.149, green: 0.137, blue: 0.125)
    static let parchment = Color(red: 0.902, green: 0.875, blue: 0.827)
    static let dimText = Color(red: 0.902, green: 0.875, blue: 0.827).opacity(0.6)
    static let ember = Color(red: 0.851, green: 0.537, blue: 0.290)
    static let gold = Color(red: 0.788, green: 0.647, blue: 0.353)
    static let blood = Color(red: 0.753, green: 0.325, blue: 0.247)
    static let good = Color(red: 0.498, green: 0.718, blue: 0.494)
    static let stroke = Color.white.opacity(0.08)

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .serif) }

    static func color(_ o: Outcome) -> Color {
        switch o {
        case .critSuccess: return gold
        case .success: return good
        case .partial: return Color(red: 0.86, green: 0.7, blue: 0.4)
        case .fail: return Color(red: 0.86, green: 0.47, blue: 0.38)
        case .critFail: return blood
        }
    }
}

struct PanelBackground: ViewModifier {
    var radius: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .background(Theme.bg1, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.stroke))
    }
}

extension View {
    func panel(_ radius: CGFloat = 14) -> some View { modifier(PanelBackground(radius: radius)) }
}

/// Tlačítko: plná tlumená barva, bez stínů a animací.
struct EmberButtonStyle: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .serif))
            .foregroundStyle(prominent ? Theme.bg0 : Theme.parchment)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(prominent ? Theme.ember : Theme.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(prominent ? Color.clear : Theme.stroke))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "fx.haptics") as? Bool ?? true }
    static func outcome(_ o: Outcome) {
        guard enabled else { return }
        let g = UINotificationFeedbackGenerator()
        switch o {
        case .critSuccess, .success: g.notificationOccurred(.success)
        case .partial: g.notificationOccurred(.warning)
        case .fail, .critFail: g.notificationOccurred(.error)
        }
    }
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : (v < 0 ? "−\(-v)" : "0") }

func doneButton(_ action: @escaping () -> Void) -> some ToolbarContent {
    ToolbarItem(placement: .confirmationAction) { Button("Hotovo", action: action) }
}

/// Velikost písma příběhu (nastavení).
enum TextSize {
    static let key = "text.scale"
    static func narration(_ scale: Double) -> Font { .system(size: 19 * scale, design: .serif) }
}
