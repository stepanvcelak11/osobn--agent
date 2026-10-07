import SwiftUI
import RealmCore

/// Společný rám pro listy.
struct SheetContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView { content.padding(20) }
                .background(Theme.bg0)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { doneButton { dismiss() } }
        }
        .presentationBackground(Theme.bg0)
    }
}

/// Postava, její výbava a vlastnosti, cíl příběhu. Dílčí úkoly se neukazují – žádné nápovědy.
struct StorySheet: View {
    let story: Story

    var body: some View {
        SheetContainer(title: "Postava a cíl") {
            VStack(alignment: .leading, spacing: 18) {
                let k = story.hero.heroClass
                HStack(spacing: 14) {
                    Image(systemName: k.icon).font(.title).foregroundStyle(Theme.ember)
                        .frame(width: 56, height: 56).background(Theme.bg2, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(story.hero.name).font(Theme.title(24)).foregroundStyle(Theme.parchment)
                        Text(story.hero.className).font(.subheadline).foregroundStyle(Theme.dimText)
                    }
                }
                section("Výbava") { Text(k.gear.prefix(1).uppercased() + k.gear.dropFirst() + ".").foregroundStyle(Theme.parchment) }
                section("Vlastnosti") {
                    VStack(spacing: 8) {
                        ForEach(Attribute.allCases, id: \.self) { a in
                            let v = story.hero.score(a)
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.czechName).foregroundStyle(Theme.parchment)
                                    Text(a.usage).font(.caption).foregroundStyle(Theme.dimText)
                                }
                                Spacer()
                                Text(signed(v)).font(.system(.headline, design: .rounded)).monospacedDigit()
                                    .foregroundStyle(v >= 2 ? Theme.good : (v < 0 ? Theme.blood : Theme.parchment))
                                Text("\(Dice.chance(score: v)) %").font(.caption.monospacedDigit()).foregroundStyle(Theme.dimText)
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                    }
                }
                Text("Procenta = šance, že riskantní čin s touto vlastností aspoň napůl vyjde. Otázky a běžné činy se nehází.")
                    .font(.caption).foregroundStyle(Theme.dimText)
                section("Cíl příběhu") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(story.goal).foregroundStyle(Theme.parchment)
                        if story.mode == .endless {
                            Text("Říše se rozrostla \(story.completedStages)×.").font(.footnote).foregroundStyle(Theme.dimText)
                        } else {
                            Text("Postup: \(story.completedStages) z \(story.stages.count)").font(.footnote).foregroundStyle(Theme.dimText)
                        }
                        Text("Nezdary: \(story.setbacks) z \(story.maxSetbacks) – při posledním příběh skončí prohrou. Každý další krok k cíli jeden nezdar smaže.")
                            .font(.footnote).foregroundStyle(Theme.dimText)
                    }
                }
            }
            .font(.system(.body, design: .serif))
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(Theme.ember)
            c()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .panel()
    }
}

/// Paměť vypravěče a poznámka ke stylu (jako Memory a Author's note v AI Dungeon).
struct MemorySheet: View {
    let story: Story
    var onSave: (String, String) -> Void
    @State private var memory = ""
    @State private var note = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SheetContainer(title: "Paměť vypravěče") {
            VStack(alignment: .leading, spacing: 18) {
                field("Co si má vypravěč vždy pamatovat",
                      "Důležitá fakta tvého příběhu: kdo je tvůj nepřítel, co jsi slíbil(a), jak se jmenuje tvůj kůň…",
                      text: $memory, limit: 500)
                field("Styl vyprávění",
                      "Např. „víc hororu“, „víc dialogů“, „černý humor“.",
                      text: $note, limit: 200)
                Button("Uložit") { onSave(memory, note); dismiss() }.buttonStyle(EmberButtonStyle())
            }
        }
        .onAppear { memory = story.memory; note = story.note }
    }

    private func field(_ title: String, _ hint: String, text: Binding<String>, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
            Text(hint).font(.footnote).foregroundStyle(Theme.dimText)
            TextField("", text: text, axis: .vertical)
                .lineLimit(3...8)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.parchment)
                .padding(12).panel()
                .onChange(of: text.wrappedValue) { _, v in if v.count > limit { text.wrappedValue = String(v.prefix(limit)) } }
        }
    }
}

struct HelpView: View {
    var body: some View {
        SheetContainer(title: "Jak hrát") {
            VStack(alignment: .leading, spacing: 16) {
                item("text.bubble", "Piš, co chceš udělat",
                     "Žádné nabídky ani tlačítka s volbami – napiš cokoli, jako v AI Dungeon. Vypravěč odpoví, co se stane.")
                item("figure.walk", "Čin, Řeč, Příběh",
                     "Čin = co uděláš („Plížím se k bráně“). Řeč = co řekneš nahlas. Příběh = sám vypravuješ, co se stane. Šipka ⏩ s prázdným polem = vypravěč pokračuje sám.")
                item("questionmark.bubble", "Ptej se",
                     "„Kde to jsem?“, „Kdo tu je?“ – vypravěč popíše, co vidíš. Na otázky se nehází a nic se kvůli nim nestane.")
                item("dice", "Kostky jen u riskantních činů",
                     "Boj, plížení, šplhání, kouzla, přesvědčování nebo stopování se hází. Postava v tom, v čem je dobrá, uspěje častěji – válečník v boji, bard v přesvědčování.")
                item("flag", "Cíl a nezdary",
                     "Každý příběh má cíl. Tečky nahoře ukazují, jak daleko jsi. Kroky k cíli musíš najít sám – hra ti neradí. Nepovedené riskantní činy přidávají nezdary (✕); když jich je moc, příběh skončí prohrou.")
                item("arrow.clockwise", "Znovu a Vrátit",
                     "Znovu = vypravěč napíše poslední tah jinak (hod kostkou zůstane). Vrátit = vezmi poslední tah zpět.")
                item("brain", "Paměť vypravěče",
                     "V menu ☰ napiš, co si má vypravěč vždy pamatovat, a jaký styl vyprávění chceš.")
                item("square.stack", "Víc her najednou",
                     "Každá hra se ukládá po každém tahu. Na úvodní obrazovce mezi nimi přepínáš.")
                item("cloud", "Online vypravěč (nepovinné)",
                     "V Nastavení můžeš připojit lepšího online vypravěče (Claude nebo Gemini) s vlastním klíčem. Bez signálu hra sama vypráví offline.")
            }
        }
    }

    private func item(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.ember).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                Text(text).font(.subheadline).foregroundStyle(Theme.dimText)
            }
        }
    }
}

/// Všechny hry: rozehrané a dohrané.
struct SavesView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                let running = app.saves.filter { $0.end == nil }, done = app.saves.filter { $0.end != nil }
                if !running.isEmpty { Section("Rozehrané") { ForEach(running) { row($0) }.onDelete { delete(running, $0) } } }
                if !done.isEmpty { Section("Dohrané") { ForEach(done) { row($0) }.onDelete { delete(done, $0) } } }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg0)
            .navigationTitle("Hry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { doneButton { dismiss() } }
        }
    }

    private func row(_ g: SaveSummary) -> some View {
        Button { dismiss(); app.open(g.id) } label: {
            HStack(spacing: 12) {
                Image(systemName: HeroClass.byId(g.classId).icon).foregroundStyle(Theme.ember).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.title).font(.system(.body, design: .serif)).foregroundStyle(Theme.parchment).lineLimit(1)
                    Text("\(g.heroName) · \(g.mode.title) · \(g.turns) tahů\(g.end.map { " · \($0.czechName)" } ?? "")")
                        .font(.caption).foregroundStyle(Theme.dimText)
                }
            }
        }
        .listRowBackground(Theme.bg1)
    }

    private func delete(_ list: [SaveSummary], _ idx: IndexSet) {
        for i in idx { app.delete(list[i].id) }
    }
}
