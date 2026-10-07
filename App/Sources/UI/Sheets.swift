import SwiftUI
import RealmCore

struct SheetContainer<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg0.ignoresSafeArea()
                ScrollView { content.padding(18) }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Hotovo") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bg0)
    }
}

struct InventorySheet: View {
    let hero: Hero
    var now: Date = Date()
    var onUse: (Item) -> Void

    var body: some View {
        SheetContainer(title: "🎒 Hrdina a inventář") {
            VStack(alignment: .leading, spacing: 14) {
                heroCard
                conditionsCard
                if hero.items.isEmpty {
                    Text("Nemáš nic. Jen to, co máš na sobě – a odvahu.").italic().foregroundStyle(Theme.dimText)
                }
                ForEach(hero.items) { item in
                    Button { onUse(item) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.kind.icon).font(.title3).foregroundStyle(Theme.ember).frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.label).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                                Text(item.kind.czechName + (item.heals ? " · léčí" : "")).font(.caption).foregroundStyle(Theme.dimText)
                            }
                            Spacer()
                            Text("Použít").font(.caption.weight(.semibold)).foregroundStyle(Theme.ember)
                        }
                        .padding(12).panel(14)
                    }
                    .buttonStyle(.plain)
                }
                Text("Předměty můžeš použít i volně v textu („rozbiju zámek paklíči“). Vypravěč ví, co neseš – a co ne.")
                    .font(.caption).foregroundStyle(Theme.dimText)
            }
        }
    }

    @ViewBuilder private var conditionsCard: some View {
        let conds = World.conditions(hero, at: now)
        if !conds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(conds, id: \.self) { c in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: c.icon).foregroundStyle(c.isGood ? Theme.gold : Theme.blood).frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.czechName).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                            Text(c.detail).font(.caption).foregroundStyle(Theme.dimText)
                        }
                    }
                }
            }
            .padding(14).panel()
        }
    }

    private var heroCard: some View {
        let lo = World.xpForLevel(hero.level), hi = World.xpForLevel(hero.level + 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(hero.name).font(Theme.title(22)).foregroundStyle(Theme.parchment)
                Spacer()
                Text(Catalog.background(hero.background).displayName(feminine: hero.feminine)).font(.caption).foregroundStyle(Theme.ember)
            }
            HStack(spacing: 8) {
                Label("Úroveň \(hero.level)", systemImage: "star.fill").font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                ProgressView(value: Double(hero.xp - lo), total: Double(max(1, hi - lo))).tint(Theme.gold)
                Text("\(hero.xp)/\(hi) zk.").font(.caption2).monospacedDigit().foregroundStyle(Theme.dimText)
            }
            Text("Schopnost, kterou používáš nejčastěji, se s každou úrovní zlepší.").font(.caption2).foregroundStyle(Theme.dimText)
            ForEach(hero.abilities) { ab in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: ab.icon).foregroundStyle(Theme.gold).frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(ab.name) · \(ab.usesLeft)/\(ab.maxUses) dnes").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.parchment)
                        Text(ab.detail + " Obnoví se po spánku nebo novým dnem.").font(.caption2).foregroundStyle(Theme.dimText)
                    }
                }
            }
            if !hero.traits.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(hero.traits.compactMap(Traits.byId)) { t in
                        Label(t.name, systemImage: t.icon).font(.caption).foregroundStyle(Theme.parchment)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Theme.ember.opacity(0.13), in: Capsule())
                    }
                }
                Text(hero.traits.compactMap(Traits.byId).map { "\($0.name): \($0.detail)" }.joined(separator: " "))
                    .font(.caption2).foregroundStyle(Theme.dimText)
            }
            HStack {
                ForEach(Attribute.allCases, id: \.self) { a in
                    VStack(spacing: 2) {
                        Image(systemName: a.icon).foregroundStyle(Theme.gold)
                        Text(a.czechName).font(.caption2).foregroundStyle(Theme.dimText)
                        Text(signed(hero.score(a))).font(.system(.headline, design: .rounded)).foregroundStyle(Theme.parchment)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14).panel()
    }
}

struct ChronicleSheet: View {
    let state: GameState
    var body: some View {
        SheetContainer(title: "📜 Kronika") {
            VStack(alignment: .leading, spacing: 12) {
                if state.chronicle.isEmpty {
                    Text("Kronika je zatím prázdná.").italic().foregroundStyle(Theme.dimText)
                }
                ForEach(Array(state.chronicle.enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1).").font(.system(.caption, design: .serif)).foregroundStyle(Theme.ember).frame(width: 26, alignment: .trailing)
                        Text(line).font(.system(.body, design: .serif)).foregroundStyle(Theme.parchment)
                    }
                }
            }
        }
    }
}

struct SettlementSheet: View {
    let state: GameState
    var onOrder: (String) -> Void

    var body: some View {
        SheetContainer(title: state.mode.hasSettlement ? "🏰 \(state.settlement.name)" : "🐎 Karavana") {
            VStack(alignment: .leading, spacing: 16) {
                overview
                if state.mode == .campaign, let j = state.journey { journey(j) }
                if state.mode == .realm { goal }
                if state.mode.hasSettlement {
                    threats
                    construction
                    buildings
                }
            }
        }
    }

    private var overview: some View {
        let st = state.settlement
        return VStack(alignment: .leading, spacing: 8) {
            row("👥", "Obyvatelé", "\(st.population)")
            row("🪙", "Zlato", "\(st.gold)")
            row("🍞", "Zásoby", "\(st.food) / \(st.foodCapacity) (\(st.foodPercent) %)")
            row("🛡️", "Obrana", "\(st.defense)")
            row("✊", "Morálka", "\(st.morale)")
            if state.mode.hasSettlement {
                let prod = Int((Double(8 + st.count(.farma) * 15 + st.population / 4) * state.season.harvest).rounded())
                let eat = Int((Double(st.population) * state.weather.foodFactor).rounded())
                row("🌾", "Bilance jídla / den (\(state.season.czechName.lowercased()))", signed(prod - eat))
                row("💰", "Příjem zlata / den", signed(5 + st.count(.trziste) * 12 + st.population / 10))
                row("🕰️", "Herní čas", "Den \(state.day), \(clock(state.worldTime))")
            }
        }
        .padding(14).panel()
    }

    private var goal: some View {
        let st = state.settlement
        return VStack(alignment: .leading, spacing: 8) {
            Text("🎯 Cíl: z osady město").font(.system(.headline, design: .serif)).foregroundStyle(Theme.gold)
            check("\(Catalog.realmGoalPopulation) obyvatel (\(st.population))", st.population >= Catalog.realmGoalPopulation)
            ForEach(Catalog.realmGoalBuildings, id: \.self) { b in check(b.czechName, st.count(b) > 0) }
        }
        .padding(14).panel()
    }

    private func check(_ text: String, _ ok: Bool) -> some View {
        Label(text, systemImage: ok ? "checkmark.circle.fill" : "circle")
            .font(.subheadline)
            .foregroundStyle(ok ? Theme.gold : Theme.parchment)
    }

    private func timeLeft(_ d: Date) -> String {
        let h = d.timeIntervalSince(state.worldTime) / 3600
        return h <= 0 ? "teď" : "za " + Prompts.timeText(h).replacingOccurrences(of: "hodinu", with: "hodinu")
    }

    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack {
            Text(icon)
            Text(label).foregroundStyle(Theme.dimText)
            Spacer()
            Text(value).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Theme.parchment)
        }
        .font(.subheadline)
    }

    private func journey(_ j: Journey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cesta").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
            ForEach(Array(j.stops.enumerated()), id: \.offset) { i, s in
                HStack(spacing: 10) {
                    Image(systemName: i < j.index ? "checkmark.circle.fill" : (i == j.index ? "figure.walk.circle.fill" : "circle"))
                        .foregroundStyle(i <= j.index ? Theme.ember : Theme.dimText)
                    Image(systemName: s.scene.icon).foregroundStyle(Theme.dimText).frame(width: 22)
                    Text(s.name).foregroundStyle(i == j.index ? Theme.parchment : Theme.dimText)
                        .fontWeight(i == j.index ? .semibold : .regular)
                }
                .font(.subheadline)
            }
            Text("Napiš „vyrazíme dál“, když chceš pokračovat. Každý přesun stojí zásoby.").font(.caption).foregroundStyle(Theme.dimText)
        }
        .padding(14).panel()
    }

    @ViewBuilder private var threats: some View {
        if !state.threats.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("⚠️ Hrozby").font(.system(.headline, design: .serif)).foregroundStyle(Theme.blood)
                ForEach(state.threats.sorted { $0.deadline < $1.deadline }) { t in
                    HStack(spacing: 10) {
                        Image(systemName: t.kind.icon).foregroundStyle(Theme.blood).frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.parchment)
                            Text("\(t.kind.czechName) · síla \(t.strength) · ").font(.caption).foregroundStyle(Theme.dimText)
                            + Text("udeří \(timeLeft(t.deadline))").font(.caption).foregroundStyle(Theme.ember)
                        }
                        Spacer()
                        Button("Jednat") { onOrder("Připravím osadu na hrozbu „\(t.title)“: ") }
                            .font(.caption.weight(.semibold))
                    }
                }
                Text("Když hrozba udeří, osada se brání obranou (u nákazy ranhojičstvím, u bouře sýpkami). Můžeš ji i odvrátit odvážným činem.")
                    .font(.caption).foregroundStyle(Theme.dimText)
            }
            .padding(14).panel()
        }
    }

    @ViewBuilder private var construction: some View {
        if !state.settlement.construction.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("🔨 Rozestavěno").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                ForEach(state.settlement.construction) { c in
                    let total = c.kind.buildHours * 3600
                    let left = max(0, c.finishAt.timeIntervalSince(state.worldTime))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(c.kind.czechName, systemImage: c.kind.icon).foregroundStyle(Theme.parchment)
                            Spacer()
                            Text("hotovo \(timeLeft(c.finishAt))").font(.caption).foregroundStyle(Theme.ember)
                        }
                        .font(.subheadline)
                        ProgressView(value: max(0, min(1, 1 - left / total))).tint(Theme.ember)
                    }
                }
            }
            .padding(14).panel()
        }
    }

    private var buildings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stavby").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
            ForEach(BuildingKind.allCases, id: \.self) { b in
                HStack(spacing: 10) {
                    Image(systemName: b.icon).foregroundStyle(Theme.gold).frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(b.czechName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.parchment)
                            if state.settlement.count(b) > 0 { Text("×\(state.settlement.count(b))").font(.caption).foregroundStyle(Theme.ember) }
                        }
                        Text("\(b.effect) · 🪙 \(b.goldCost) · \(b.workers) dělníků · \(Int(b.buildHours)) h").font(.caption2).foregroundStyle(Theme.dimText)
                    }
                    Spacer()
                    Button("Postavit") { onOrder("Postavím \(b.czechName.lowercased()).") }
                        .font(.caption.weight(.semibold))
                        .disabled(state.settlement.gold < b.goldCost || state.settlement.construction.count >= 2)
                }
            }
        }
        .padding(14).panel()
    }
}

/// Svět kolem hrdiny: počasí, roční období, zakázka a postavy, které potkal.
struct WorldSheet: View {
    let state: GameState

    var body: some View {
        SheetContainer(title: "🌦️ Svět") {
            VStack(alignment: .leading, spacing: 16) {
                weatherCard
                if let c = state.contract { contractCard(c) } else if state.mode != .quest {
                    Text("Žádná zakázka. Lidé přicházejí s prosbami za úsvitu (v karavaně na zastávkách).")
                        .font(.caption).foregroundStyle(Theme.dimText).padding(.horizontal, 4)
                }
                people
            }
        }
    }

    private var weatherCard: some View {
        let w = state.weather
        let effects = ActionCategory.allCases.compactMap { c -> String? in
            let m = w.modifier(c)
            return m == 0 ? nil : "\(c.czechName) \(m > 0 ? "+" : "")\(m)"
        }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: w.icon).symbolRenderingMode(.multicolor).font(.largeTitle).frame(width: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.czechName).font(Theme.title(22)).foregroundStyle(Theme.parchment)
                    Text("\(state.season.czechName), \(World.year(day: state.day)). rok · den \(state.day)").font(.caption).foregroundStyle(Theme.dimText)
                }
            }
            Text(effects.isEmpty ? "Počasí tvé činy neovlivňuje." : "Vliv na hody: " + effects.joined(separator: ", ") + ".")
                .font(.caption).foregroundStyle(Theme.parchment)
            if w.foodFactor > 1 { Text("V mrazu a sněhu se sní víc jídla.").font(.caption).foregroundStyle(Theme.food) }
            if state.mode != .quest {
                Text("Úroda: jaro ×0,9 · léto ×1,15 · podzim ×1,25 · zima ×0,45. Každé období trvá \(World.seasonDays) dní – na zimu si nachystej sýpky.")
                    .font(.caption2).foregroundStyle(Theme.dimText)
            }
        }
        .padding(14).panel()
    }

    private func contractCard(_ c: Contract) -> some View {
        let h = max(0, Int((c.deadline.timeIntervalSince(state.worldTime) / 3600).rounded(.up)))
        return VStack(alignment: .leading, spacing: 8) {
            Label("Zakázka", systemImage: "scroll.fill").font(.system(.headline, design: .serif)).foregroundStyle(Theme.ember)
            Text(c.title).font(.system(.title3, design: .serif)).foregroundStyle(Theme.parchment)
            Text("Zadává: \(c.giver)").font(.caption).foregroundStyle(Theme.dimText)
            HStack {
                Text("Odměna: \(c.reward.text)").font(.caption.weight(.semibold)).foregroundStyle(Theme.gold)
                Spacer()
                Text("zbývá \(h) h").font(.caption.weight(.bold)).foregroundStyle(h < 12 ? Theme.blood : Theme.dimText)
            }
            Text("Splníš ji zdařilým činem, který se jí přímo týká (\(c.categories.map(\.czechName).joined(separator: ", "))). Když propadne, lidé si to zapamatují.")
                .font(.caption2).foregroundStyle(Theme.dimText)
        }
        .padding(14).panel()
    }

    private var people: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("👥 Postavy").font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
            if state.characters.isEmpty {
                Text("Zatím nikoho neznáš. Mluv s lidmi – vypravěč si je zapamatuje.").font(.caption).italic().foregroundStyle(Theme.dimText)
            }
            ForEach(state.characters.sorted { $0.lastSeen > $1.lastSeen }) { p in
                HStack(spacing: 12) {
                    Text(String(p.name.prefix(1)))
                        .font(.system(.headline, design: .serif).weight(.bold))
                        .foregroundStyle(Theme.bg0)
                        .frame(width: 34, height: 34)
                        .background(color(p.attitude), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.system(.subheadline, design: .serif).weight(.semibold)).foregroundStyle(Theme.parchment)
                        Text("\(p.role) · setkání: \(p.meetings)").font(.caption2).foregroundStyle(Theme.dimText)
                    }
                    Spacer()
                    Label(p.attitude.czechName, systemImage: p.attitude.icon).font(.caption2.weight(.semibold)).foregroundStyle(color(p.attitude))
                }
            }
        }
        .padding(14).panel()
    }

    private func color(_ a: Attitude) -> Color {
        switch a {
        case .friend: return Color(red: 0.45, green: 0.8, blue: 0.5)
        case .neutral: return Theme.gold
        case .hostile: return Theme.blood
        }
    }
}

/// Paměť vypravěče a poznámka ke stylu (jako „Memory“ a „Author's Note“ v AI Dungeon).
struct MemorySheet: View {
    let state: GameState
    var onSave: (String, String) -> Void
    @State private var memory = ""
    @State private var note = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetContainer(title: "🧠 Paměť vypravěče") {
            VStack(alignment: .leading, spacing: 16) {
                field("Co si má vypravěč vždy pamatovat",
                      "Důležitá fakta tvého příběhu: kdo je tvůj nepřítel, co jsi slíbil(a), tajemství hrdiny…",
                      text: $memory, limit: 500)
                field("Poznámka k vyprávění",
                      "Styl a nálada: „víc hororu“, „černý humor“, „krátké úderné věty“, „víc dialogů“… Pravidla hry tím nezměníš.",
                      text: $note, limit: 300)
                if !state.premise.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Zápletka hry").font(.system(.headline, design: .serif)).foregroundStyle(Theme.ember)
                        Text(state.premise).font(.subheadline).foregroundStyle(Theme.parchment)
                    }
                }
                Button("Uložit") { onSave(memory, note); dismiss() }.buttonStyle(EmberButtonStyle())
                Text("Vypravěč dostává poslední kroniku, známé postavy a tuto paměť v každém tahu.")
                    .font(.caption2).foregroundStyle(Theme.dimText)
            }
        }
        .onAppear { memory = state.memory; note = state.authorsNote }
    }

    private func field(_ title: String, _ hint: String, text: Binding<String>, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.ember)
            Text(hint).font(.caption).foregroundStyle(Theme.dimText)
            TextField("", text: text, axis: .vertical)
                .lineLimit(3...8)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.parchment)
                .padding(12).panel(12)
                .onChange(of: text.wrappedValue) { _, v in if v.count > limit { text.wrappedValue = String(v.prefix(limit)) } }
            Text("\(text.wrappedValue.count)/\(limit)").font(.caption2).foregroundStyle(Theme.dimText).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct AchievementsView: View {
    let unlocked: Set<String>
    var body: some View {
        SheetContainer(title: "🏆 Úspěchy") {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(unlocked.count) z \(Achievements.all.count)").font(.caption).foregroundStyle(Theme.dimText)
                ForEach(Achievements.all) { a in
                    let got = unlocked.contains(a.id)
                    HStack(spacing: 12) {
                        Image(systemName: got ? a.icon : "lock.fill").font(.title3)
                            .foregroundStyle(got ? Theme.gold : Theme.dimText).frame(width: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title).font(.system(.headline, design: .serif)).foregroundStyle(got ? Theme.parchment : Theme.dimText)
                            Text(a.detail).font(.caption).foregroundStyle(Theme.dimText)
                        }
                        Spacer()
                    }
                    .padding(10).panel(12)
                    .opacity(got ? 1 : 0.6)
                }
            }
        }
    }
}

struct HelpView: View {
    var body: some View {
        SheetContainer(title: "Jak hrát") {
            VStack(alignment: .leading, spacing: 14) {
                section("Absolutní svoboda", "Žádná tlačítka s volbami. Napiš (nebo řekni), co tvůj hrdina udělá – „plížím se kolem stráže“, „nabídnu lapkům polovinu zlata“, „pojedu na koni do sousední vesnice“. Hraješ, jak dlouho chceš – žádné limity tahů.")
                section("Čin, Řeč, Příběh, Pokračuj", "Tlačítkem vlevo od textu přepínáš, jak tah zadáváš. ČIN: co hrdina udělá (posoudí se a hodí kostkou). ŘEČ: co řekne nahlas – postavy odpoví. PŘÍBĚH: sám napíšeš, co se stane, a vypravěč naváže (bez kostek a bez odměn). Prázdné pole a šipka ⏩ = POKRAČUJ: vypravěč vypráví dál a svět jedná sám.")
                section("Znovu a Vrátit", "Nelíbí se ti vyprávění? „Znovu“ ho převypráví – hod kostkou ale zůstane stejný, osud se přepsat nedá. „Vrátit tah“ vezme poslední tah zpět (jen dokud hra neskončila). Podržením prstu na textu ho zkopíruješ nebo necháš přečíst.")
                section("🧠 Paměť vypravěče", "V menu si zapiš, co si má vypravěč vždy pamatovat (tajemství, sliby, nepřátele), a poznámku ke stylu („víc hororu“, „černý humor“). Při založení hry můžeš zadat i vlastní zápletku.")
                section("Tvoje postava", "Vybíráš z 11 původů (Žoldnéř, Stínochod, Bylinkář, Kupec, Vyhnaný rytíř, Lovec, Potulný kněz, Vědmák, Bard, Kovář, Hrobník) – každý má jiné schopnosti, výbavu a zvláštní schopnost. K tomu 2 volné body a 2 vlastnosti povahy (Odvážný, Otužilý, Noční pták, Šťastlivec…).")
                section("⚡ Zvláštní schopnost", "Každý původ má svou schopnost (Bojový řev, Léčivé ruce, Splynutí se stínem…). Použiješ ji 2× za den: klepni na zlatý čip nad polem pro tah, nebo ji prostě zmiň v textu. Po spánku se obnoví.")
                section("⭐ Úrovně", "Každý čin dává zkušenosti – úspěch víc, ale i z nezdaru se učíš. Na nové úrovni se zlepší schopnost, kterou používáš nejčastěji, a hrdina nabere síly.")
                section("🩸 Stavy hrdiny", "Krvácení bere každý tah zdraví, dokud ránu neošetříš (léčivý předmět, odpočinek). Horečka oslabuje. Dlouho bez spánku přijde únava (−1) a vyčerpání (−2) – spánek aspoň 6 hodin pomůže. Skvělý úspěch dodá odhodlání (+1).")
                section("🌦️ Počasí a roční období", "Každý den má své počasí: mlha pomáhá plížení, bouřka a sníh zdržují cestu, mráz zvedá spotřebu jídla. Rok začíná jarem, každé období trvá 20 dní. Na podzim je nejbohatší úroda, v zimě skoro nic neroste.")
                section("📜 Zakázky a 👥 postavy", "Lidé přicházejí s prosbami – najdi ztracenou dceru, ulov vlka, rozsuď spor. Splň je včas a dostaneš odměnu, jinak klesne morálka. Vypravěč si pamatuje postavy, které potkáš, i to, jestli jsou ti přáteli, nebo nepřáteli.")
                section("Čas běží podle činů", "Každý čin trvá tolik, kolik by trval ve skutečnosti: rozhlédnutí pár minut, prohledání domu hodinu, jízda do další vesnice celý den, výprava do hor i několik dní. Podle toho se střídá den a noc, karavana jí zásoby a osada mezitím sklízí, staví a čelí hrozbám.")
                section("Kostky rozhodují", "Riskantní činy se házejí kostkou k20 + schopnost hrdiny (Síla, Obratnost, Důvtip, Charisma) + vhodný předmět. Výsledek je katastrofa, neúspěch, částečný úspěch, úspěch nebo skvělý úspěch. Vypravěč ho nesmí změnit – ani když prosíš.")
                section("❤️ Zdraví a 🧠 stres", "Zdraví na nule = konec hry. Boje a hrůzy zvedají stres; nad 70 se vypravěč stane paranoidním a tvé hody jsou horší. Odpočinek, kořalka nebo kaple pomáhají.")
                section("🎒 Předměty", "Vypravěč ví, co neseš. Předměty dávají bonus k hodu, léčivé byliny léčí. Co nemáš, použít nemůžeš. Nové věci najdeš jako kořist – a často se hodí později.")
                section("Rychlá výprava", "Krátká hra: jedno místo, jeden snadný cíl. Tři zdařilé činy (🚩🚩🚩) a cíl je splněn. Ale pozor – po čtyřech nezdarech (💀) je cíl nenávratně ztracen.")
                section("Jak se prohrává", "Každý mód jde prohrát: smrtí hrdiny, hladem a zánikem osady či karavany, vzpourou nebo svržením, když morálka ✊ spadne na nulu, a na výpravě ztrátou cíle.")
                section("Cesta světem", "Delší hra: vedeš karavanu přes 6 zastávek do Údolí Úsvitu. „Vyrazíme dál“ = den cesty a den zásob 🍞. Na zastávkách čekají přepady, nemoci i poklady.")
                section("Vláda nad osadou", "Dlouhá hra: z osady vybuduj město – 100 obyvatel, hradby, tržiště, kaple a kasárna. Každé ráno sklizeň, daně, růst i nové hrozby.")
                section("Nekonečná říše", "Bez konce: stav, rozšiřuj, objevuj okolí a hraj, kolik chceš. Osada žije i když nehraješ (skutečný čas se započítá, nejvýš 3 dny).")
                section("Soukromí", "Vypravěč se jednou automaticky stáhne (z Hugging Face, ověřený kontrolním součtem) a pak vše běží offline v telefonu. Žádné účty, žádná analytika, nic se neodesílá.")
            }
        }
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.ember)
            Text(text).font(.subheadline).foregroundStyle(Theme.parchment)
        }
    }
}

struct SavesView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(app.saves) { s in
                    Button {
                        dismiss()
                        app.open(s.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: s.mode.icon).foregroundStyle(s.end == nil ? Theme.ember : Theme.dimText).frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(s.title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment).lineLimit(1)
                                Text("\(s.heroName) · \(s.mode.title) · tah \(s.turn)").font(.caption).foregroundStyle(Theme.dimText)
                                Text(s.end.map { "Konec: \($0.czechName)" } ?? "Rozehráno – ❤️ \(s.hp)").font(.caption2)
                                    .foregroundStyle(s.end == nil ? Theme.ember : Theme.dimText)
                            }
                            Spacer()
                            Text(s.updatedAt, format: .dateTime.day().month().hour().minute()).font(.caption2).foregroundStyle(Theme.dimText)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
                .onDelete { idx in for i in idx { app.delete(app.saves[i].id) } }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg0)
            .navigationTitle("Kroniky her")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneButton { dismiss() } }
        }
    }
}
