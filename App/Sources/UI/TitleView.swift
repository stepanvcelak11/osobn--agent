import SwiftUI
import RealmCore

struct TitleView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var ai: AIService
    @EnvironmentObject var models: ModelManager
    @EnvironmentObject var downloader: ModelDownloader
    @State private var showNewGame = false
    @State private var showSaves = false
    @State private var showSettings = false
    @State private var showHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                logo.padding(.top, 36)
                if !app.running.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROZEHRANÉ HRY").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(Theme.dimText)
                        ForEach(app.running.prefix(4)) { g in runningRow(g) }
                    }
                }
                VStack(spacing: 10) {
                    Button("Nová hra") { showNewGame = true }.buttonStyle(EmberButtonStyle(prominent: app.running.isEmpty))
                    if app.saves.count > app.running.prefix(4).count {
                        Button("Všechny hry (\(app.saves.count))") { showSaves = true }.buttonStyle(EmberButtonStyle(prominent: false))
                    }
                }
                narratorStatus
                HStack(spacing: 10) {
                    Button { showHelp = true } label: { Label("Jak hrát", systemImage: "questionmark.circle") }
                        .buttonStyle(EmberButtonStyle(prominent: false))
                    Button { showSettings = true } label: { Label("Nastavení", systemImage: "gearshape") }
                        .buttonStyle(EmberButtonStyle(prominent: false))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.bg0)
        .onAppear {
            app.refreshSaves()
            #if DEBUG
            if Demo.mode == "newgame" { showNewGame = true }
            if Demo.mode == "settings" { showSettings = true }
            #endif
        }
        .fullScreenCover(isPresented: $showNewGame) { NewGameView() }
        .sheet(isPresented: $showSaves) { SavesView() }
        .sheet(isPresented: $showSettings) { NavigationStack { SettingsView().toolbar { doneButton { showSettings = false } } } }
        .sheet(isPresented: $showHelp) { HelpView() }
    }

    private var logo: some View {
        VStack(spacing: 6) {
            Text("POCKET REALM")
                .font(Theme.title(34)).tracking(3)
                .foregroundStyle(Theme.ember)
            Text("Textové dobrodružství s vypravěčem, který žije ve tvém telefonu")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
        }
    }

    private func runningRow(_ g: SaveSummary) -> some View {
        Button { app.open(g.id) } label: {
            HStack(spacing: 12) {
                Image(systemName: HeroClass.byId(g.classId).icon)
                    .font(.title3)
                    .foregroundStyle(Theme.ember)
                    .frame(width: 40, height: 40)
                    .background(Theme.bg2, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(g.title).font(.system(.body, design: .serif).weight(.semibold)).foregroundStyle(Theme.parchment).lineLimit(1)
                    Text("\(g.heroName) · \(g.mode.title)").font(.footnote).foregroundStyle(Theme.dimText).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(g.updatedAt, format: .relative(presentation: .named)).font(.caption).foregroundStyle(Theme.dimText)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.dimText)
            }
            .padding(12).panel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pokračovat: \(g.title)")
    }

    // MARK: Stav vypravěče

    private var narratorStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.parchment)
                    Text(statusDetail).font(.footnote).foregroundStyle(Theme.dimText)
                }
                Spacer(minLength: 0)
            }
            if let p = downloadProgress { ProgressView(value: p).tint(Theme.ember) }
            if case .failed = downloader.phase, !ai.isLLMReady {
                Button("Zkusit znovu") { downloader.retry(models: models) }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.ember)
            }
            if ai.onlineActive {
                Label("Online vypravěč zapnutý – bez signálu vypráví telefon", systemImage: "cloud")
                    .font(.footnote).foregroundStyle(Theme.dimText)
            }
        }
        .padding(14)
        .panel()
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
        case .ready: Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good)
        case .loading: ProgressView().tint(Theme.ember)
        default:
            if case .failed = downloader.phase { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.blood) }
            else { Image(systemName: "arrow.down.circle").foregroundStyle(Theme.ember) }
        }
    }

    private func size(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }

    private var statusTitle: String {
        switch ai.llmState {
        case .ready: return "Vypravěč připraven"
        case .loading: return "Probouzím vypravěče…"
        default: break
        }
        switch downloader.phase {
        case .downloading(_, let r, let t): return "Stahuji vypravěče – \(Int(Double(r) / Double(max(t, 1)) * 100)) %"
        case .verifying: return "Ověřuji staženého vypravěče…"
        case .waiting: return "Stahování čeká na připojení"
        case .failed: return "Stažení vypravěče se nepovedlo"
        default: return "Připravuji vypravěče…"
        }
    }

    private var statusDetail: String {
        switch ai.llmState {
        case .ready: return "Běží offline přímo v telefonu."
        case .loading: return "První načtení trvá asi 20 sekund."
        default: break
        }
        switch downloader.phase {
        case .downloading(_, let r, let t): return "\(size(r)) z \(size(t)). Jen jednou, pak vše offline. Hrát můžeš už teď (zatím s jednodušším vypravěčem)."
        case .verifying: return "Kontroluji, že soubor dorazil celý."
        case .waiting(let m): return m
        case .failed(let m): return m
        default: return "Vypravěč (asi 2,5 GB) se stáhne automaticky, ideálně přes Wi-Fi."
        }
    }
}
