import SwiftUI
import RealmCore

/// Úvodní scénář: výběr osudu (módu), hrdiny a jména města.
struct NewGameView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var mode: GameMode = .quest
    @State private var heroName = ""
    @State private var feminine = false
    @State private var backgroundId = Catalog.backgrounds[0].id
    @State private var cityName = ""
    @State private var premise = ""
    @FocusState private var focus: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                TabView(selection: $step) {
                    modeStep.tag(0)
                    heroStep.tag(1)
                    cityStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
                footer
            }
        }
        .background { SceneBackdrop(scene: step == 2 ? .town : (step == 1 ? .camp : .road), phase: step == 0 ? 2 : 3) }
        .onTapGesture { focus = false }
    }

    private var header: some View {
        HStack {
            Button { if step > 0 { step -= 1 } else { dismiss() } } label: {
                Image(systemName: step > 0 ? "chevron.left" : "xmark").font(.headline)
                    .frame(width: 40, height: 40).background(Color.white.opacity(0.07), in: Circle())
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Capsule().fill(i <= step ? Theme.ember : Color.white.opacity(0.15)).frame(width: i == step ? 26 : 10, height: 6)
                }
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .foregroundStyle(Theme.parchment)
        .padding(.horizontal, 20).padding(.top, 8)
    }

    private func stepTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(Theme.title(30)).foregroundStyle(Theme.parchment)
            Text(subtitle).font(.system(.subheadline, design: .serif)).italic().foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 18).padding(.bottom, 12)
    }

    // MARK: 1 – mód

    private var modeStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                stepTitle("Vyber svůj osud", "Svět je temný a nemilosrdný. Jak dlouhý příběh chceš prožít?")
                ForEach(GameMode.allCases, id: \.self) { m in modeCard(m) }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private func modeDetails(_ m: GameMode) -> [String] {
        switch m {
        case .quest: return ["Jedno nebezpečné místo a jeden snadný cíl", "Stačí pár odvážných činů", "Bez správy města"]
        case .campaign: return ["Vedeš karavanu přeživších přes 6 zastávek", "Den cesty = den zásob", "Přepady, nemoci, uprchlíci"]
        case .realm: return ["Stavby, hrozby, obchod, den a noc", "Cíl: 100 obyvatel, hradby, tržiště, kaple a kasárna", "Osada žije, i když zrovna nehraješ"]
        case .endless: return ["Žádný konec – stav, rozšiřuj, objevuj", "Z vesnice město, z města říše", "Hraj, kolik chceš"]
        }
    }

    private func modeCard(_ m: GameMode) -> some View {
        let selected = mode == m
        return Button { withAnimation(.spring(duration: 0.3)) { mode = m } } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: m.icon).font(.title2)
                    .foregroundStyle(selected ? Theme.gold : Theme.dimText)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(selected ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(m.title).font(.system(.title3, design: .serif).weight(.bold)).foregroundStyle(Theme.parchment)
                    Text(m.length).font(.caption.weight(.semibold)).foregroundStyle(Theme.ember)
                    ForEach(modeDetails(m), id: \.self) { d in
                        Label(d, systemImage: "smallcircle.filled.circle").font(.caption).foregroundStyle(Theme.dimText)
                            .labelStyle(TightLabel())
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .panel()
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Theme.ember : .clear, lineWidth: 2))
            .shadow(color: selected ? Theme.ember.opacity(0.3) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: 2 – hrdina

    private var heroStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                stepTitle("Kdo jsi?", "Jméno, které budou jednou šeptat u ohňů.")
                TextField("", text: $heroName, prompt: Text("Jméno hrdiny").foregroundColor(Theme.dimText))
                    .font(.system(.title3, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(14).panel(14)
                    .focused($focus)
                    .submitLabel(.done)
                Picker("Oslovení", selection: $feminine) {
                    Text("Hrdina (on)").tag(false)
                    Text("Hrdinka (ona)").tag(true)
                }
                .pickerStyle(.segmented)
                Text("Původ").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                ForEach(Catalog.backgrounds) { bg in backgroundCard(bg) }
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private func backgroundCard(_ bg: Catalog.Background) -> some View {
        let selected = backgroundId == bg.id
        return Button { withAnimation(.spring(duration: 0.3)) { backgroundId = bg.id } } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(bg.displayName(feminine: feminine)).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                    Spacer()
                    if bg.bonusGold > 0 { Text("🪙 +\(bg.bonusGold)").font(.caption).foregroundStyle(Theme.gold) }
                }
                Text(bg.blurb).font(.caption).italic().foregroundStyle(Theme.dimText)
                HStack(spacing: 10) {
                    ForEach(Attribute.allCases, id: \.self) { a in attributePips(a, bg.attributes[a] ?? 0) }
                }
                Text("🎒 " + bg.items.map(\.label).joined(separator: " · ")).font(.caption2).foregroundStyle(Theme.parchment.opacity(0.8))
            }
            .padding(14)
            .panel(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.ember : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func attributePips(_ a: Attribute, _ v: Int) -> some View {
        VStack(spacing: 3) {
            Text(String(a.czechName.prefix(3)).uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.dimText)
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 1.5).fill(i < v ? Theme.ember : Color.white.opacity(0.12)).frame(width: 9, height: 5)
                }
            }
        }
    }

    // MARK: 3 – město

    private var cityTitle: String {
        switch mode {
        case .quest: return "Odkud pocházíš?"
        case .campaign: return "Které město padlo?"
        case .realm, .endless: return "Pojmenuj svou osadu"
        }
    }

    private var citySubtitle: String {
        switch mode {
        case .quest: return "Město, za které dnes riskuješ život."
        case .campaign: return "Z jeho trosek vyráží tvá karavana."
        case .realm, .endless: return "Pár chatrčí na okraji divočiny. Zatím."
        }
    }

    private var cityStep: some View {
        let bg = Catalog.background(backgroundId)
        let st = Catalog.startSettlement(mode: mode, name: cityName, bonusGold: bg.bonusGold)
        return ScrollView {
            VStack(spacing: 14) {
                stepTitle(cityTitle, citySubtitle)
                HStack {
                    TextField("", text: $cityName, prompt: Text("🏰 Jméno města").foregroundColor(Theme.dimText))
                        .font(.system(.title3, design: .serif))
                        .focused($focus)
                        .submitLabel(.done)
                    Button { cityName = Catalog.defaultCityNames.randomElement()! } label: {
                        Image(systemName: "dice.fill").font(.title3).foregroundStyle(Theme.ember)
                    }
                }
                .padding(14).panel(14)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Výchozí stav").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                    HStack {
                        statPreview("❤️", "100")
                        statPreview("🧠", "\(Catalog.startStress(mode))")
                        statPreview("🪙", "\(st.gold)")
                    }
                    if mode != .quest {
                        HStack {
                            statPreview("👥", "\(st.population)")
                            statPreview("🍞", "\(st.foodPercent) %")
                            statPreview("🛡️", "\(st.defense)")
                        }
                    }
                    Text(modeHint).font(.caption).foregroundStyle(Theme.dimText)
                }
                .padding(16).panel()

                premiseCard
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    static let premiseIdeas = [
        "Hledám ztraceného bratra, který odešel s poutníky.",
        "Nesu v sobě kletbu – každou noc slyším hlas z hlubin.",
        "Dlužím peníze nebezpečnému cechu a jeho lidé mi jdou po krku.",
        "Jsem posledním svědkem vraždy knížete.",
        "Krajem táhne mor a kněží tvrdí, že je to trest.",
    ]

    /// Vlastní zápletka (jako vlastní scénář v AI Dungeon) – nepovinná.
    private var premiseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vlastní zápletka").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
            Text("Nepovinné. Napiš, o čem má tvůj příběh být – vypravěč ho do hry vplete.").font(.caption).foregroundStyle(Theme.dimText)
            TextField("", text: $premise, prompt: Text("Např. hledám ztraceného bratra…").foregroundColor(Theme.dimText), axis: .vertical)
                .lineLimit(2...5)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.parchment)
                .focused($focus)
                .padding(12)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: premise) { _, v in if v.count > 400 { premise = String(v.prefix(400)) } }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.premiseIdeas, id: \.self) { idea in
                        Button { premise = idea } label: {
                            Text(idea).font(.caption2).lineLimit(1)
                                .foregroundStyle(Theme.parchment)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.white.opacity(0.07), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16).panel()
    }

    private var modeHint: String {
        switch mode {
        case .quest: return "Piš volně, co hrdina dělá – vypravěč a kostky rozhodnou o výsledku. Tři zdařilé činy a cíl je tvůj."
        case .campaign: return "Napiš třeba „vyrazíme dál“ – cesta k další zastávce trvá den a sní den zásob."
        case .realm: return "Stavěj („postav farmu“), hlídej hrozby, obchoduj. Každý čin zabere tolik času, kolik by trval ve skutečnosti."
        case .endless: return "Nekonečná hra: stav, rozšiřuj a objevuj okolí. Každý čin zabere tolik času, kolik by trval ve skutečnosti."
        }
    }

    private func statPreview(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(icon)
            Text(value).font(.system(.body, design: .serif).weight(.semibold)).foregroundStyle(Theme.parchment)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Patička

    private var footer: some View {
        Button {
            focus = false
            if step < 2 { step += 1 } else { start() }
        } label: {
            Text(step < 2 ? "Dál" : "Vstoupit do temnoty")
        }
        .buttonStyle(EmberButtonStyle())
        .disabled(step == 1 && heroName.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(step == 1 && heroName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        .padding(.horizontal, 20).padding(.bottom, 10)
    }

    private func start() {
        let setup = NewGameSetup(mode: mode, heroName: heroName, cityName: cityName, backgroundId: backgroundId, feminine: feminine,
                                 premise: premise)
        dismiss()
        app.startNewGame(setup)
    }
}

struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 5)).opacity(0.6)
            configuration.title
        }
    }
}
