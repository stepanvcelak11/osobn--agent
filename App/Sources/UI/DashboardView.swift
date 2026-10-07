import SwiftUI
import RealmCore

/// Horní panel: 🏰 město, 👥 🪙 🍞 🛡️ a hrdina ❤️ 🧠 – podle módu.
struct DashboardView: View {
    let state: GameState
    var onMenu: () -> Void
    var onSettlement: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            topRow
            if state.mode == .quest { questRow } else { settlementRow }
            heroRow
            if state.mode == .campaign, let j = state.journey { JourneyBar(journey: j) }
            if state.mode == .realm { realmRow }
        }
        .padding(12)
        .panel(20)
        .padding(.horizontal, 10)
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            Text("🏰")
            VStack(alignment: .leading, spacing: 0) {
                Text(state.mode == .realm ? "\(Catalog.settlementRank(population: state.settlement.population)) \(state.settlement.name)" : state.settlement.name)
                    .font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment).lineLimit(1)
                Text("\(state.mode.title) · \(state.location)")
                    .font(.caption2).foregroundStyle(Theme.dimText).lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Image(systemName: Theme.phaseIcon(state.phase))
                Text("Den \(state.day)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(state.phase == 3 ? Color(red: 0.7, green: 0.75, blue: 1) : Theme.gold)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.white.opacity(0.06), in: Capsule())
            Button(action: onMenu) {
                Image(systemName: "ellipsis").font(.headline).frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .foregroundStyle(Theme.parchment)
            .accessibilityLabel("Menu")
        }
    }

    private var questRow: some View {
        let left = (state.quest?.turnLimit ?? 0) - state.turn
        return HStack(spacing: 8) {
            Text("🎯").font(.callout)
            Text(state.quest?.objective ?? "").font(.caption).foregroundStyle(Theme.parchment).lineLimit(2)
            Spacer(minLength: 4)
            StatPill(icon: "🪙", value: "\(state.settlement.gold)", color: Theme.gold)
            StatPill(icon: "⏳", value: "\(max(0, left))", color: left <= 3 ? Theme.blood : Theme.parchment)
        }
    }

    private var settlementRow: some View {
        Button(action: onSettlement) {
            HStack(spacing: 6) {
                StatPill(icon: "👥", value: "\(state.settlement.population)", color: Theme.pop)
                StatPill(icon: "🪙", value: "\(state.settlement.gold)", color: Theme.gold)
                StatPill(icon: "🍞", value: "\(state.settlement.foodPercent)%", color: state.settlement.foodPercent < 20 ? Theme.blood : Theme.food)
                StatPill(icon: "🛡️", value: "\(state.settlement.defense)", color: Theme.defense)
                StatPill(icon: "✊", value: "\(state.settlement.morale)", color: state.settlement.morale < 30 ? Theme.blood : Theme.morale)
            }
        }
        .buttonStyle(.plain)
    }

    private var heroRow: some View {
        HStack(spacing: 12) {
            MeterBar(icon: "❤️", label: "Zdraví", value: state.hero.hp, color: Theme.health, danger: state.hero.hp < 25)
            MeterBar(icon: "🧠", label: state.hero.stress >= 70 ? "Paranoia" : "Stres", value: state.hero.stress, color: Theme.stress, danger: state.hero.stress >= 70)
        }
    }

    private var realmRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                Text("⚡️").font(.caption)
                ForEach(0..<Simulation.actionPointsPerDay, id: \.self) { i in
                    Circle().fill(i < state.actionPoints ? Theme.gold : Color.white.opacity(0.12)).frame(width: 7, height: 7)
                }
            }
            Spacer()
            if !state.settlement.construction.isEmpty {
                Label("\(state.settlement.construction.count)", systemImage: "hammer.fill").font(.caption).foregroundStyle(Theme.parchment)
            }
            if !state.threats.isEmpty {
                Button(action: onSettlement) {
                    Label("\(state.threats.count) hrozby", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.blood)
                }
            }
        }
    }
}

struct StatPill: View {
    var icon: String
    var value: String
    var color: Color
    var body: some View {
        HStack(spacing: 3) {
            Text(icon).font(.caption)
            Text(value).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(color)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .padding(.horizontal, 7).padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.06), in: Capsule())
        .animation(.spring(duration: 0.5), value: value)
    }
}

struct MeterBar: View {
    var icon: String
    var label: String
    var value: Int
    var color: Color
    var danger: Bool
    @State private var flash = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(icon).font(.caption2)
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(danger ? Theme.blood : Theme.dimText)
                Spacer()
                Text("\(value)").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Theme.parchment)
                    .contentTransition(.numericText()).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(max(0, min(100, value))) / 100)
                        .shadow(color: color.opacity(flash ? 0.9 : 0.3), radius: flash ? 8 : 3)
                }
            }
            .frame(height: 7)
        }
        .animation(.spring(duration: 0.6), value: value)
        .onChange(of: value) { _, _ in
            flash = true
            withAnimation(.easeOut(duration: 0.8)) { flash = false }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) ze 100")
    }
}

struct JourneyBar: View {
    let journey: Journey
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(journey.stops.enumerated()), id: \.offset) { i, stop in
                let reached = i <= journey.index
                Image(systemName: i == journey.stops.count - 1 ? "sunrise.fill" : (i == journey.index ? "figure.walk" : "circle.fill"))
                    .font(.system(size: i == journey.index || i == journey.stops.count - 1 ? 12 : 6))
                    .foregroundStyle(reached ? Theme.ember : Color.white.opacity(0.25))
                    .frame(width: 18)
                    .accessibilityLabel(stop.name)
                if i < journey.stops.count - 1 {
                    Rectangle().fill(i < journey.index ? Theme.ember.opacity(0.7) : Color.white.opacity(0.12)).frame(height: 2)
                }
            }
        }
        .animation(.spring(duration: 0.8), value: journey.index)
    }
}
