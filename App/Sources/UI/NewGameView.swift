import SwiftUI
import RealmCore

/// Nová hra ve třech krocích: druh příběhu → postava → téma.
struct NewGameView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var mode: GameMode = .quest
    @State private var classId = "valecnik"
    @State private var feminine = false
    @State private var name = ""
    @State private var place = ""
    @State private var premise = ""

    private var heroClass: HeroClass { HeroClass.byId(classId) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch step {
                    case 0: modeStep
                    case 1: heroStep
                    default: storyStep
                    }
                }
                .padding(20)
            }
            .background(Theme.bg0)
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle(["Druh příběhu", "Tvoje postava", "Téma příběhu"][min(step, 2)])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == 0 ? "Zavřít" : "Zpět") { if step == 0 { dismiss() } else { step -= 1 } }
                }
            }
        }
        .onAppear {
            #if DEBUG
            if let s = Demo.step { step = s }
            #endif
        }
    }

    // MARK: Krok 1 – mód

    private var modeStep: some View {
        VStack(spacing: 10) {
            ForEach(GameMode.allCases) { m in
                Button { mode = m } label: {
                    HStack(spacing: 14) {
                        Image(systemName: m.icon).font(.title2).foregroundStyle(Theme.ember).frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(m.title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                                Text(m.length).font(.caption).foregroundStyle(Theme.dimText)
                            }
                            Text(m.tagline).font(.subheadline).foregroundStyle(Theme.dimText).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: mode == m ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(mode == m ? Theme.ember : Theme.dimText)
                    }
                    .padding(14)
                    .panel()
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(mode == m ? Theme.ember : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Krok 2 – postava

    private var heroStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(HeroClass.all) { k in
                Button { classId = k.id; name = "" } label: { classCard(k) }.buttonStyle(.plain)
            }
            Picker("Pohlaví", selection: $feminine) {
                Text("Muž").tag(false)
                Text("Žena").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: feminine) { _, _ in name = "" }
            TextField("", text: $name, prompt: Text("Jméno (\(heroClass.defaultName(feminine: feminine)))").foregroundColor(Theme.dimText))
                .font(.system(.body, design: .serif))
                .padding(14)
                .panel()
                .textInputAutocapitalization(.words)
        }
    }

    private func classCard(_ k: HeroClass) -> some View {
        let selected = classId == k.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: k.icon).font(.title3).foregroundStyle(Theme.ember).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(k.name(feminine: feminine)).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
                    Text(k.summary).font(.footnote).foregroundStyle(Theme.dimText)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? Theme.ember : Theme.dimText)
            }
            if selected {
                Text("Výbava: \(k.gear)").font(.footnote).foregroundStyle(Theme.parchment.opacity(0.85))
                HStack(spacing: 6) {
                    ForEach(Attribute.allCases, id: \.self) { a in
                        let v = k.scores[a] ?? 0
                        VStack(spacing: 2) {
                            Text(signed(v)).font(.system(.headline, design: .rounded)).monospacedDigit()
                                .foregroundStyle(v >= 2 ? Theme.good : (v < 0 ? Theme.blood : Theme.parchment))
                            Text(a.czechName).font(.caption2).foregroundStyle(Theme.dimText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.bg2, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(14)
        .panel()
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.ember : .clear, lineWidth: 1.5))
    }

    // MARK: Krok 3 – téma

    private var storyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            if mode.needsPlaceName {
                Text(mode == .campaign ? "Jak se jmenovalo padlé město?" : "Jak se jmenuje tvoje osada?")
                    .font(.subheadline).foregroundStyle(Theme.dimText)
                TextField("", text: $place, prompt: Text("Nech prázdné pro náhodné jméno").foregroundColor(Theme.dimText))
                    .font(.system(.body, design: .serif))
                    .padding(14).panel()
            }
            Text(mode == .quest ? "O čem má výprava být? Nech prázdné a vypravěč vybere náhodný příběh."
                                : "Chceš do příběhu přidat vlastní zápletku? (nepovinné)")
                .font(.subheadline).foregroundStyle(Theme.dimText)
            TextField("", text: $premise, prompt: Text(mode == .quest ? "Např. Drak unesl princeznu z hradu Bezděz." : "Např. V lesích za osadou se objevili vlkodlaci.").foregroundColor(Theme.dimText), axis: .vertical)
                .font(.system(.body, design: .serif))
                .lineLimit(3...6)
                .padding(14).panel()
            if mode == .quest {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(["Ve vsi mizí děti a stopy vedou k mlýnu.", "Musím doručit dopis králi dřív, než ho najdou vrazi.", "Na hřbitově se v noci pohybují mrtví."], id: \.self) { idea in
                        Button { premise = idea } label: {
                            Label(idea, systemImage: "lightbulb").font(.footnote).foregroundStyle(Theme.parchment.opacity(0.85))
                        }
                    }
                }
            }
        }
    }

    // MARK: Spodní lišta

    private var footer: some View {
        Button(step < 2 ? "Dál" : "Začít příběh") {
            if step < 2 { step += 1; return }
            app.startNewGame(NewStory(mode: mode, heroName: name, classId: classId, feminine: feminine, place: place, premise: premise))
            dismiss()
        }
        .buttonStyle(EmberButtonStyle())
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.bg0)
    }
}
