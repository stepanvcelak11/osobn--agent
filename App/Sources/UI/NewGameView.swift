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
    @State private var traits: [String] = []
    @State private var bonus: [Attribute: Int] = [:]
    @State private var liveWorld = true
    @FocusState private var focus: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                TabView(selection: $step) {
                    modeStep.tag(0)
                    heroStep.tag(1)
                    traitStep.tag(2)
                    cityStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
                footer
            }
        }
        .background { SceneBackdrop(scene: [.road, .camp, .forest, .town][min(step, 3)], phase: step == 0 ? 2 : 3) }
        .onTapGesture { focus = false }
        .onAppear {
            #if DEBUG
            if let st = Demo.step {
                step = st; heroName = "Ráchel"; feminine = true; backgroundId = "vedma"
                traits = ["nocni", "odvazny"]; bonus = [.duvtip: 1, .charisma: 1]
            }
            #endif
        }
    }

    private var header: some View {
        HStack {
            Button { if step > 0 { step -= 1 } else { dismiss() } } label: {
                Image(systemName: step > 0 ? "chevron.left" : "xmark").font(.headline)
                    .frame(width: 40, height: 40).background(Color.white.opacity(0.07), in: Circle())
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<4) { i in
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
                HStack(spacing: 10) {
                    Image(systemName: bg.icon).font(.headline)
                        .foregroundStyle(selected ? Color.black.opacity(0.8) : Theme.gold)
                        .frame(width: 34, height: 34)
                        .background(selected ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Theme.ember], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(0.07)), in: Circle())
                    Text(bg.displayName(feminine: feminine)).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                    Spacer()
                    if bg.bonusGold > 0 { Text("🪙 +\(bg.bonusGold)").font(.caption).foregroundStyle(Theme.gold) }
                }
                Text(bg.blurb).font(.caption).italic().foregroundStyle(Theme.dimText)
                HStack(spacing: 10) {
                    ForEach(Attribute.allCases, id: \.self) { a in attributePips(a, bg.attributes[a] ?? 0) }
                }
                Label { Text("\(bg.ability.name): ").bold() + Text(bg.ability.detail + " 2× denně.") } icon: { Image(systemName: bg.ability.icon) }
                    .font(.caption2).foregroundStyle(Theme.ember)
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
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 1.5).fill(i < v ? Theme.ember : Color.white.opacity(0.12)).frame(width: 9, height: 5)
                }
            }
        }
    }

    // MARK: 3 – povaha a schopnosti

    private var pointsLeft: Int { Traits.freePoints - bonus.values.reduce(0, +) }

    private var traitStep: some View {
        let bg = Catalog.background(backgroundId)
        let final = Catalog.startAttributes(background: bg, bonus: bonus, traits: traits)
        return ScrollView {
            VStack(spacing: 14) {
                stepTitle("Povaha a schopnosti", "Čím vynikáš – a čím se lišíš od ostatních.")
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Schopnosti").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                        Spacer()
                        Text(pointsLeft > 0 ? "Zbývá \(pointsLeft) \(pointsLeft == 1 ? "bod" : "body")" : "Body rozděleny")
                            .font(.caption.weight(.semibold)).foregroundStyle(pointsLeft > 0 ? Theme.ember : Theme.dimText)
                    }
                    ForEach(Attribute.allCases, id: \.self) { a in attributeRow(a, base: bg.attributes[a] ?? 0, final: final[a] ?? 0) }
                    Text("Každý hod = k20 + schopnost. Na nových úrovních se zlepší ta, kterou používáš nejčastěji.")
                        .font(.caption2).foregroundStyle(Theme.dimText)
                }
                .padding(16).panel()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Povaha").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                        Spacer()
                        Text("\(traits.count)/\(Traits.maxPicked)").font(.caption.weight(.semibold)).foregroundStyle(Theme.ember)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(Traits.all) { t in traitCard(t) }
                    }
                }
                .padding(16).panel()

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: bg.ability.icon).font(.title2).foregroundStyle(Theme.gold).frame(width: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Zvláštní schopnost: \(bg.ability.name)").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                        Text(bg.ability.detail + " Použiješ ji 2× za den – napiš třeba „použiju \(bg.ability.name.lowercased())“ nebo klepni na ⚡ nad polem pro tah. Obnoví se po spánku.")
                            .font(.caption).foregroundStyle(Theme.dimText)
                    }
                }
                .padding(16).panel()
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private func attributeRow(_ a: Attribute, base: Int, final: Int) -> some View {
        let added = bonus[a] ?? 0
        return HStack(spacing: 10) {
            Image(systemName: a.icon).foregroundStyle(Theme.gold).frame(width: 24)
            Text(a.czechName).font(.subheadline).foregroundStyle(Theme.parchment)
            Spacer()
            Button { if added > 0 { bonus[a] = added - 1; Haptics.impact(.light) } } label: {
                Image(systemName: "minus.circle.fill").font(.title3)
            }
            .disabled(added == 0)
            .foregroundStyle(added == 0 ? Theme.dimText.opacity(0.4) : Theme.parchment)
            Text(signed(final)).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                .foregroundStyle(final > base ? Theme.ember : Theme.parchment)
                .frame(width: 38)
                .contentTransition(.numericText())
            Button {
                if pointsLeft > 0 && base + added < Traits.startCap { bonus[a] = added + 1; Haptics.impact(.light) }
            } label: { Image(systemName: "plus.circle.fill").font(.title3) }
            .disabled(pointsLeft == 0 || base + added >= Traits.startCap)
            .foregroundStyle(pointsLeft == 0 || base + added >= Traits.startCap ? Theme.dimText.opacity(0.4) : Theme.ember)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25), value: final)
    }

    private func traitCard(_ t: Trait) -> some View {
        let on = traits.contains(t.id)
        let full = traits.count >= Traits.maxPicked
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                if on { traits.removeAll { $0 == t.id } } else if !full { traits.append(t.id) }
            }
            Haptics.impact(.light)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: t.icon).font(.caption).foregroundStyle(on ? Theme.gold : Theme.dimText)
                    Text(t.name).font(.system(.subheadline, design: .serif).weight(.semibold)).foregroundStyle(Theme.parchment)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(t.detail).font(.caption2).foregroundStyle(Theme.dimText).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
            .padding(10)
            .background(on ? Theme.ember.opacity(0.14) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Theme.ember : Theme.stroke, lineWidth: on ? 1.5 : 1))
            .opacity(!on && full ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: 4 – město

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

                if mode.hasSettlement {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $liveWorld) {
                            Text("Osada žije, i když nehraješ").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                        }
                        .tint(Theme.ember)
                        Text(liveWorld ? "Čas běží i ve skutečnosti (nejvýš 3 dny) – vracíš se „podívat, co je nového“."
                                       : "Hra se zastaví, kdykoli odejdeš. Dá se změnit i později v přehledu osady.")
                            .font(.caption).foregroundStyle(Theme.dimText)
                    }
                    .padding(16).panel()
                }
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
            if step < 3 { step += 1 } else { start() }
        } label: {
            Text(step < 3 ? "Dál" : "Vstoupit do temnoty")
        }
        .buttonStyle(EmberButtonStyle())
        .disabled(step == 1 && heroName.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(step == 1 && heroName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        .padding(.horizontal, 20).padding(.bottom, 10)
    }

    private func start() {
        let setup = NewGameSetup(mode: mode, heroName: heroName, cityName: cityName, backgroundId: backgroundId, feminine: feminine,
                                 premise: premise, traits: traits, bonusPoints: bonus, liveWorld: liveWorld)
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
