import SwiftUI
import AgentCore

enum Theme {
    static let accent = Color.accentColor
    static let corner: CGFloat = 18
    static let cardPadding: CGFloat = 16

    static func color(for kind: EntityKind) -> Color {
        switch kind {
        case .note: return .yellow
        case .task: return .green
        case .event: return .blue
        case .reminder: return .orange
        }
    }

    static func icon(for kind: EntityKind) -> String {
        switch kind {
        case .note: return "note.text"
        case .task: return "checkmark.circle"
        case .event: return "calendar"
        case .reminder: return "bell"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case dark, light, system
    var id: String { rawValue }
    var title: String {
        switch self { case .dark: return "Tmavý"; case .light: return "Světlý"; case .system: return "Podle systému" }
    }
    var scheme: ColorScheme? {
        switch self { case .dark: return .dark; case .light: return .light; case .system: return nil }
    }
}

/// Velikost písma nastavitelná v aplikaci (navíc k systémovému nastavení).
enum TextScale {
    static let sizes: [DynamicTypeSize] = [.small, .medium, .large, .xLarge, .xxLarge, .xxxLarge, .accessibility1, .accessibility2]
    static let labels = ["Malé", "Menší", "Výchozí", "Větší", "Velké", "Velmi velké", "Největší", "Maximální"]
}

struct Card<Content: View>: View {
    var padding: CGFloat = Theme.cardPadding
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}

struct SectionHeader: View {
    var title: String
    var systemImage: String?
    var trailing: String?
    var action: (() -> Void)?
    var body: some View {
        HStack {
            if let systemImage { Image(systemName: systemImage).foregroundStyle(.secondary) }
            Text(title).font(.headline)
            Spacer()
            if let trailing, let action {
                Button(trailing, action: action).font(.subheadline)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

struct KindBadge: View {
    var kind: EntityKind
    var body: some View {
        Image(systemName: Theme.icon(for: kind))
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.color(for: kind))
            .frame(width: 34, height: 34)
            .background(Theme.color(for: kind).opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityLabel(kind.czechName)
    }
}

struct EmptyHint: View {
    var text: String
    var systemImage: String = "sparkles"
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage).foregroundStyle(.secondary)
            Text(text).foregroundStyle(.secondary).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ToastView: View {
    var toast: Toast
    var onUndo: (String) -> Void
    var body: some View {
        HStack(spacing: 12) {
            Text(toast.text).font(.subheadline).lineLimit(2)
            Spacer(minLength: 8)
            if let id = toast.undoActionId {
                Button("Zpět") { onUndo(id) }.font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.thinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .padding(.horizontal, 16)
    }
}

/// Pruh zobrazující průběh modelu („Přemýšlím…“).
struct ThinkingIndicator: View {
    var text: String
    @State private var phase = 0.0
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
