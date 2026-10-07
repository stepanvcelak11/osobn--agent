import SwiftUI
import RealmCore

struct TitleView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var ai: AIService
    @EnvironmentObject var models: ModelManager
    @EnvironmentObject var downloader: ModelDownloader
    @State private var showNewGame = false
    @State private var showSaves = false
    @State private var showModels = false
    @State private var showSettings = false
    @State private var showAchievements = false
    @State private var showHelp = false
    @State private var glow = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 40)
                logo
                Spacer()
                buttons
                modelStatus.padding(.top, 18)
                bottomBar.padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background { SceneBackdrop(scene: .castle, phase: 3) }
        .onAppear {
            app.refreshSaves()
            #if DEBUG
            if Demo.mode == "newgame" { showNewGame = true }
            #endif
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
        }
        .fullScreenCover(isPresented: $showNewGame) { NewGameView() }
        .sheet(isPresented: $showSaves) { SavesView() }
        .sheet(isPresented: $showModels) { NavigationStack { ModelsView().toolbar { doneButton { showModels = false } } } }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView().toolbar { doneButton { showSettings = false } } } }
        .sheet(isPresented: $showAchievements) { AchievementsView(unlocked: app.unlockedAchievements()) }
        .sheet(isPresented: $showHelp) { HelpView() }
    }

    private var logo: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 34))
                .foregroundStyle(LinearGradient(colors: [Theme.gold, Theme.ember], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.ember.opacity(glow ? 0.9 : 0.3), radius: glow ? 18 : 6)
            Text("POCKET")
                .font(Theme.title(22)).tracking(14)
                .foregroundStyle(Theme.parchment.opacity(0.8))
            Text("REALM")
                .font(Theme.title(64)).tracking(6)
                .foregroundStyle(LinearGradient(colors: [Theme.gold, Theme.ember, Theme.blood], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.ember.opacity(glow ? 0.7 : 0.25), radius: glow ? 24 : 10)
            Text("Temné RPG s vypravěčem, který žije ve tvém telefonu")
                .font(.system(.subheadline, design: .serif)).italic()
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            if let last = app.latestUnfinished {
                Button { app.open(last.id) } label: {
                    VStack(spacing: 2) {
                        Text("Pokračovat")
                        Text("\(last.heroName) · \(last.title)").font(.caption).opacity(0.75).lineLimit(1)
                    }
                }
                .buttonStyle(EmberButtonStyle())
                Button("Nová hra") { showNewGame = true }.buttonStyle(EmberButtonStyle(prominent: false))
            } else {
                Button("Nová hra") { showNewGame = true }.buttonStyle(EmberButtonStyle())
            }
            if !app.saves.isEmpty {
                Button("Kroniky her (\(app.saves.count))") { showSaves = true }.buttonStyle(EmberButtonStyle(prominent: false))
            }
        }
    }

    @ViewBuilder private var modelStatus: some View {
        Button { showModels = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    statusIcon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle).font(.footnote.weight(.semibold)).foregroundStyle(Theme.parchment)
                        Text(statusDetail).font(.caption2).foregroundStyle(Theme.dimText).multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.dimText)
                }
                if let p = downloadProgress {
                    ProgressView(value: p).tint(Theme.ember)
                }
                if case .failed = downloader.phase, !ai.isLLMReady {
                    Button("Zkusit znovu") { downloader.retry(models: models) }
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.ember)
                }
            }
            .padding(12)
            .panel(14)
        }
        .buttonStyle(.plain)
    }

    private var downloadProgress: Double? {
        switch downloader.phase {
        case .downloading(_, let r, let t): return t > 0 ? min(1, Double(r) / Double(t)) : 0
        case .verifying(_, let p): return p
        default: return nil
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch ai.llmState {
        case .ready: Image(systemName: "sparkles").foregroundStyle(Theme.gold)
        case .loading: ProgressView().tint(Theme.ember)
        default:
            if case .failed = downloader.phase { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.blood) }
            else { Image(systemName: "arrow.down.circle.fill").foregroundStyle(Theme.ember) }
        }
    }

    private func gb(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }

    private var statusTitle: String {
        switch ai.llmState {
        case .ready(let n): return "Vypravěč připraven: \(n)"
        case .loading: return "Probouzím vypravěče…"
        default: break
        }
        switch downloader.phase {
        case .downloading(let n, let r, let t): return "Stahuji vypravěče (\(n)) – \(Int(Double(r) / Double(max(t, 1)) * 100)) %"
        case .verifying: return "Ověřuji staženého vypravěče…"
        case .waiting: return "Stahování čeká na připojení"
        case .failed: return "Stažení vypravěče se nepovedlo"
        default: return "Připravuji vypravěče…"
        }
    }

    private var statusDetail: String {
        switch ai.llmState {
        case .ready:
            if case .downloading(let n, let r, let t) = downloader.phase {
                return "Běží offline v telefonu. Na pozadí se stahuje \(n.lowercased()) (\(Int(Double(r) / Double(max(t, 1)) * 100)) %)."
            }
            return "Běží 100 % offline v telefonu."
        case .loading: return "První načtení může trvat i 20 sekund."
        default: break
        }
        switch downloader.phase {
        case .downloading(_, let r, let t): return "\(gb(r)) z \(gb(t)) · jednorázově, pak vše offline. Stahuje se i na pozadí – mezitím můžeš začít hrát."
        case .verifying: return "Kontroluji, že soubor dorazil celý a nepoškozený."
        case .waiting(let m): return m
        case .failed(let m): return m
        default: return "Vypravěč (jazykový model, asi 2,5 GB) se stáhne automaticky. Ideálně na Wi-Fi."
        }
    }

    private var bottomBar: some View {
        HStack {
            iconButton("questionmark.circle", "Jak hrát") { showHelp = true }
            Spacer()
            iconButton("trophy", "Úspěchy") { showAchievements = true }
            Spacer()
            iconButton("cpu", "Modely") { showModels = true }
            Spacer()
            iconButton("gearshape", "Nastavení") { showSettings = true }
        }
        .padding(.horizontal, 12)
    }

    private func iconButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(label).font(.caption2)
            }
            .foregroundStyle(Theme.parchment.opacity(0.85))
            .frame(minWidth: 60)
        }
        .accessibilityLabel(label)
    }
}

func doneButton(_ action: @escaping () -> Void) -> some ToolbarContent {
    ToolbarItem(placement: .confirmationAction) { Button("Hotovo", action: action) }
}
