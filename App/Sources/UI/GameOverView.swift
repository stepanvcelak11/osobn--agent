import SwiftUI
import RealmCore

struct GameOverView: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var session: GameSession
    var onClose: () -> Void
    @State private var appear = false

    var state: GameState { session.state }

    private var icon: String {
        switch state.end {
        case .death: return "☠️"
        case .victory: return "🏆"
        case .ruin: return "🔥"
        default: return "⌛"
        }
    }

    private var headline: String {
        switch state.end {
        case .death: return state.hero.feminine ? "Padla jsi" : "Padl jsi"
        case .victory: return "Vítězství"
        case .ruin: return "Vše je ztraceno"
        default: return "Konec výpravy"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text(icon).font(.system(size: 64)).scaleEffect(appear ? 1 : 0.4)
                    Text(headline.uppercased())
                        .font(Theme.title(32)).tracking(3)
                        .foregroundStyle(state.end == .victory
                                         ? LinearGradient(colors: [Theme.gold, Theme.ember], startPoint: .top, endPoint: .bottom)
                                         : LinearGradient(colors: [Theme.blood, Theme.ember.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    Text(state.end?.czechName ?? "").font(.caption).foregroundStyle(Theme.dimText)
                    epilogue
                    stats
                    achievements
                    VStack(spacing: 10) {
                        Button("Nová hra") { app.closeSession() }.buttonStyle(EmberButtonStyle())
                        Button("Pročíst příběh") { onClose() }.buttonStyle(EmberButtonStyle(prominent: false))
                    }
                    .padding(.top, 6)
                }
                .padding(24)
                .padding(.top, 30)
            }
        }
        .onAppear { withAnimation(.spring(duration: 0.8)) { appear = true } }
    }

    @ViewBuilder private var epilogue: some View {
        let text = state.epilogue ?? session.streamingText
        VStack(alignment: .leading, spacing: 8) {
            Text("EPILOG").font(.caption.weight(.bold)).tracking(3).foregroundStyle(Theme.ember)
            if text.isEmpty {
                HStack { ProgressView().tint(Theme.ember); Text("Píše se legenda…").italic().foregroundStyle(Theme.dimText) }
            } else {
                Text(text).font(.system(.body, design: .serif)).italic().lineSpacing(5).foregroundStyle(Theme.parchment)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).panel()
    }

    private var stats: some View {
        let items: [(String, String)] = [
            ("Tahů", "\(state.turn)"),
            ("Dní", "\(state.day)"),
            ("Zlato", "\(state.settlement.gold)"),
            (state.mode == .quest ? "Předmětů" : "Lidí", state.mode == .quest ? "\(state.hero.items.count)" : "\(state.settlement.population)"),
        ]
        return HStack {
            ForEach(items, id: \.0) { i in
                VStack(spacing: 2) {
                    Text(i.1).font(.system(.title3, design: .serif).weight(.bold)).foregroundStyle(Theme.parchment)
                    Text(i.0).font(.caption2).foregroundStyle(Theme.dimText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12).panel(14)
    }

    @ViewBuilder private var achievements: some View {
        let list = state.achievements.compactMap(Achievements.byId)
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("ÚSPĚCHY").font(.caption.weight(.bold)).tracking(3).foregroundStyle(Theme.gold)
                ForEach(list) { a in
                    Label(a.title, systemImage: a.icon).font(.subheadline).foregroundStyle(Theme.parchment)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).panel()
        }
    }
}
