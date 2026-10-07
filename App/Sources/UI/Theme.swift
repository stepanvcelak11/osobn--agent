import SwiftUI
import UIKit
import RealmCore

enum Theme {
    static let bg0 = Color(red: 0.067, green: 0.055, blue: 0.098)
    static let bg1 = Color(red: 0.11, green: 0.082, blue: 0.15)
    static let parchment = Color(red: 0.92, green: 0.875, blue: 0.784)
    static let dimText = Color(red: 0.92, green: 0.875, blue: 0.784).opacity(0.62)
    static let ember = Color(red: 0.957, green: 0.549, blue: 0.235)
    static let gold = Color(red: 0.91, green: 0.714, blue: 0.298)
    static let blood = Color(red: 0.784, green: 0.259, blue: 0.227)
    static let health = Color(red: 0.88, green: 0.32, blue: 0.29)
    static let stress = Color(red: 0.61, green: 0.42, blue: 1.0)
    static let food = Color(red: 0.85, green: 0.65, blue: 0.36)
    static let defense = Color(red: 0.56, green: 0.66, blue: 0.77)
    static let pop = Color(red: 0.56, green: 0.82, blue: 0.56)
    static let morale = Color(red: 0.95, green: 0.8, blue: 0.45)
    static let panel = Color.black.opacity(0.38)
    static let stroke = Color.white.opacity(0.09)

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) }
    static let narration = Font.system(.body, design: .serif)

    static func color(_ o: Outcome) -> Color {
        switch o {
        case .critSuccess: return gold
        case .success: return Color(red: 0.45, green: 0.8, blue: 0.5)
        case .partial: return Color(red: 0.95, green: 0.75, blue: 0.35)
        case .fail: return Color(red: 0.92, green: 0.45, blue: 0.35)
        case .critFail: return blood
        case .auto: return dimText
        case .impossible: return Color.gray
        }
    }

    /// Barvy oblohy podle denní doby (0 ráno, 1 den, 2 večer, 3 noc).
    static func sky(_ phase: Int) -> [Color] {
        switch phase {
        case 0: return [Color(red: 0.12, green: 0.12, blue: 0.24), Color(red: 0.36, green: 0.2, blue: 0.27), Color(red: 0.6, green: 0.35, blue: 0.3)]
        case 1: return [Color(red: 0.13, green: 0.15, blue: 0.2), Color(red: 0.22, green: 0.22, blue: 0.24), Color(red: 0.36, green: 0.3, blue: 0.24)]
        case 2: return [Color(red: 0.1, green: 0.07, blue: 0.18), Color(red: 0.3, green: 0.1, blue: 0.2), Color(red: 0.55, green: 0.22, blue: 0.14)]
        default: return [Color(red: 0.03, green: 0.03, blue: 0.08), Color(red: 0.06, green: 0.05, blue: 0.13), Color(red: 0.12, green: 0.07, blue: 0.14)]
        }
    }

    static func sceneTint(_ s: SceneKind) -> Color {
        switch s {
        case .forest: return Color(red: 0.1, green: 0.3, blue: 0.15)
        case .ruins: return Color(red: 0.3, green: 0.27, blue: 0.22)
        case .dungeon: return Color(red: 0.15, green: 0.15, blue: 0.2)
        case .town: return Color(red: 0.35, green: 0.22, blue: 0.12)
        case .road: return Color(red: 0.3, green: 0.24, blue: 0.16)
        case .river: return Color(red: 0.1, green: 0.22, blue: 0.35)
        case .mountain: return Color(red: 0.25, green: 0.28, blue: 0.35)
        case .swamp: return Color(red: 0.2, green: 0.28, blue: 0.12)
        case .battle: return Color(red: 0.45, green: 0.1, blue: 0.08)
        case .camp: return Color(red: 0.4, green: 0.2, blue: 0.08)
        case .castle: return Color(red: 0.25, green: 0.18, blue: 0.3)
        }
    }

    static func phaseIcon(_ phase: Int) -> String {
        ["sunrise.fill", "sun.max.fill", "sunset.fill", "moon.stars.fill"][max(0, min(3, phase))]
    }
    static func phaseName(_ phase: Int) -> String {
        ["Ráno", "Den", "Večer", "Noc"][max(0, min(3, phase))]
    }
}

/// Pozadí scény: obloha podle denní doby, nádech prostředí, obří symbol místa a žhavé jiskry.
struct SceneBackdrop: View {
    var scene: SceneKind
    var phase: Int
    var embers = true
    @AppStorage("fx.embers") private var embersEnabled = true

    var body: some View {
        ZStack {
            LinearGradient(colors: Theme.sky(phase), startPoint: .top, endPoint: .bottom)
            Theme.sceneTint(scene).opacity(0.35).blendMode(.overlay)
            Image(systemName: scene.icon)
                .font(.system(size: 240, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.045))
                .offset(y: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            if embers && embersEnabled { EmberField(count: phase == 3 ? 26 : 18) }
            RadialGradient(colors: [.clear, .black.opacity(0.7)], center: .center, startRadius: 120, endRadius: 520)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.2), value: phase)
        .animation(.easeInOut(duration: 1.2), value: scene)
    }
}

/// Stoupající žhavé jiskry (levné: jedno plátno, 20 snímků/s).
struct EmberField: View {
    var count = 20
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 20.0)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let seed = Double(i) * 12.9898
                    let speed = 18 + (sin(seed) * 0.5 + 0.5) * 30
                    let h = Double(size.height) + 40
                    let y = h - (t * speed + seed * 37).truncatingRemainder(dividingBy: h)
                    let baseX = (sin(seed * 3.1) * 0.5 + 0.5) * Double(size.width)
                    let x = baseX + sin(t * 0.8 + seed) * 18
                    let life = y / h
                    let r = 1.2 + (cos(seed) * 0.5 + 0.5) * 2.2
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    ctx.opacity = 0.15 + life * 0.75
                    ctx.fill(Path(ellipseIn: rect.insetBy(dx: -r * 1.5, dy: -r * 1.5)), with: .color(Theme.ember.opacity(0.18)))
                    ctx.fill(Path(ellipseIn: rect), with: .color(Color(red: 1, green: 0.75 + 0.2 * life, blue: 0.4)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Rudá pulzující vinětace – nízké zdraví nebo paranoia.
struct DangerVignette: View {
    var intensity: Double
    @State private var pulse = false
    var body: some View {
        RadialGradient(colors: [.clear, Theme.blood.opacity(0.55 * intensity)], center: .center,
                       startRadius: pulse ? 170 : 210, endRadius: 520)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .opacity(intensity > 0 ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

struct PanelBackground: ViewModifier {
    var radius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.stroke))
    }
}

extension View {
    func panel(_ radius: CGFloat = 18) -> some View { modifier(PanelBackground(radius: radius)) }
}

/// Hlavní tlačítko v žhavém stylu.
struct EmberButtonStyle: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .serif))
            .foregroundStyle(prominent ? Color.black.opacity(0.85) : Theme.parchment)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background {
                if prominent {
                    LinearGradient(colors: [Theme.gold, Theme.ember], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color.white.opacity(0.07)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(prominent ? Theme.gold.opacity(0.6) : Theme.stroke))
            .shadow(color: prominent ? Theme.ember.opacity(0.35) : .clear, radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
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
        default: break
        }
    }
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

extension StatDelta {
    /// Čipy změn pro zobrazení (emoji jako v zadání hry).
    var chips: [(String, Int, Color)] {
        var out: [(String, Int, Color)] = []
        if hp != 0 { out.append(("❤️", hp, Theme.health)) }
        if stress != 0 { out.append(("🧠", stress, Theme.stress)) }
        if pop != 0 { out.append(("👥", pop, Theme.pop)) }
        if gold != 0 { out.append(("🪙", gold, Theme.gold)) }
        if food != 0 { out.append(("🍞", food, Theme.food)) }
        if defense != 0 { out.append(("🛡️", defense, Theme.defense)) }
        if morale != 0 { out.append(("✊", morale, Theme.morale)) }
        return out
    }
}

/// Herní čas vždy ve 24h formátu („21:30“).
func clock(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "cs_CZ")
    f.dateFormat = "H:mm"
    return f.string(from: d)
}

func signed(_ v: Int) -> String { v > 0 ? "+\(v)" : (v < 0 ? "−\(-v)" : "0") }
