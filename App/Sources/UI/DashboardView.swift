import SwiftUI
import RealmCore

/// Horní panel: 🏰 město, 👥 🪙 🍞 🛡️ a hrdina ❤️ 🧠 – podle módu.
struct DashboardView: View {
    let state: GameState
    var onMenu: () -> Void
    var onSettlement: () -> Void
    var onHero: () -> Void = {}
    var onWorld: () -> Void = {}
    @AppStorage("dash.compact") private var compact = false

    var body: some View {
        VStack(spacing: 10) {
            topRow
            if !compact {
                worldRow
                if state.mode == .quest { questRow } else { settlementRow }
            }
            heroRow
            if !compact {
                if state.mode == .campaign, let j = state.journey { JourneyBar(journey: j) }
                if state.mode.hasSettlement { realmRow }
                if let c = state.contract { contractRow(c) }
            }
        }
        .padding(12)
        .panel(20)
        .padding(.horizontal, 10)
        .animation(.spring(duration: 0.35), value: compact)
    }

    private var title: String {
        switch state.mode {
        case .quest: return state.location
        case .campaign: return "Karavana z \(state.settlement.name)"
        case .realm, .endless: return state.settlement.name
        }
    }

    private var subtitle: String {
        switch state.mode {
        case .quest: return state.mode.title
        case .campaign: return "\(state.mode.title) · \(state.location)"
        case .realm, .endless: return "\(Catalog.settlementRank(population: state.settlement.population)) · \(state.mode.title)"
        }
    }

    private var badgeIcon: String {
        switch state.mode {
        case .quest: return state.scene.icon
        case .campaign: return "map.fill"
        case .realm, .endless: return "building.columns.fill"
        }
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            Button { compact.toggle(); Haptics.impact(.light) } label: {
                HStack(spacing: 10) {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .frame(width: 34, height: 34)
                        .background(LinearGradient(colors: [Theme.gold, Theme.ember], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                        .shadow(color: Theme.ember.opacity(0.4), radius: 6)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment).lineLimit(1)
                            .minimumScaleFactor(0.75)
                        HStack(spacing: 4) {
                            Text(subtitle).lineLimit(1)
                            Image(systemName: compact ? "chevron.down" : "chevron.up").font(.system(size: 8, weight: .bold))
                        }
                        .font(.caption2).foregroundStyle(Theme.dimText)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(compact ? "Rozbalit panel" : "Sbalit panel")
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Image(systemName: Theme.phaseIcon(state.phase))
                Text("Den \(state.day) · \(clock(state.worldTime))")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(state.phase == 3 ? Color(red: 0.7, green: 0.75, blue: 1) : Theme.gold)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.white.opacity(0.06), in: Capsule())
            .fixedSize()
            Button(action: onMenu) {
                Image(systemName: "ellipsis").font(.headline).frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .foregroundStyle(Theme.parchment)
            .accessibilityLabel("Menu")
        }
    }

    /// Počasí, úroveň a stavy hrdiny.
    private var worldRow: some View {
        let conds = World.conditions(state.hero, at: state.worldTime)
        let lvl = state.hero.level
        let lo = World.xpForLevel(lvl), hi = World.xpForLevel(lvl + 1)
        let p = Double(state.hero.xp - lo) / Double(max(1, hi - lo))
        return HStack(spacing: 6) {
            Button(action: onWorld) {
                HStack(spacing: 4) {
                    Image(systemName: state.weather.icon).symbolRenderingMode(.multicolor)
                    Text(state.weather.czechName)
                    Text("·").opacity(0.5)
                    Image(systemName: state.season.icon).font(.system(size: 9))
                    Text(state.season.czechName)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.parchment.opacity(0.85))
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Počasí \(state.weather.czechName), \(state.season.czechName)")
            Button(action: onHero) {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(Theme.gold)
                    Text("\(lvl)").font(.system(.caption2, design: .rounded).weight(.heavy)).foregroundStyle(Theme.gold)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(Theme.gold).frame(width: 34 * max(0.04, min(1, p)))
                    }
                    .frame(width: 34, height: 4)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.06), in: Capsule())
                .animation(.spring(duration: 0.6), value: state.hero.xp)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Úroveň \(lvl), zkušenosti \(state.hero.xp) z \(hi)")
            Spacer(minLength: 0)
            ForEach(conds, id: \.self) { c in
                Image(systemName: c.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(c.isGood ? Theme.gold : Theme.blood)
                    .frame(width: 24, height: 24)
                    .background((c.isGood ? Theme.gold : Theme.blood).opacity(0.15), in: Circle())
                    .accessibilityLabel(c.czechName)
                    .onTapGesture(perform: onHero)
            }
        }
    }

    private var questRow: some View {
        let q = state.quest
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "scope").font(.callout).foregroundStyle(Theme.ember).padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(q?.objective ?? "").font(.caption.weight(.semibold)).foregroundStyle(Theme.parchment).lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let st = q?.currentStage {
                    Label(st, systemImage: "arrow.turn.down.right").font(.caption2).foregroundStyle(Theme.gold)
                        .labelStyle(TightIconLabel())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 3) {
                    ForEach(0..<(q?.steps ?? 3), id: \.self) { i in
                        Image(systemName: i < (q?.progress ?? 0) ? "flag.fill" : "flag")
                            .font(.system(size: 11))
                            .foregroundStyle(i < (q?.progress ?? 0) ? Theme.gold : Color.white.opacity(0.25))
                    }
                }
                .accessibilityLabel("Postup k cíli \(q?.progress ?? 0) z \(q?.steps ?? 3)")
                if let q, q.setbacks > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<q.maxSetbacks, id: \.self) { i in
                            Text("💀").font(.system(size: 9)).opacity(i < q.setbacks ? 1 : 0.18)
                        }
                    }
                    .accessibilityLabel("Nezdary \(q.setbacks) z \(q.maxSetbacks)")
                }
                StatPill(icon: "🪙", value: "\(state.settlement.gold)", color: Theme.gold, expand: false)
            }
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
            if state.mode == .realm {
                let p = min(1, Double(state.settlement.population) / Double(Catalog.realmGoalPopulation))
                HStack(spacing: 6) {
                    Image(systemName: "scope").font(.caption).foregroundStyle(Theme.ember)
                    ProgressView(value: p).tint(Theme.gold).frame(width: 70)
                    Text("\(state.settlement.population)/\(Catalog.realmGoalPopulation)").font(.caption2).foregroundStyle(Theme.dimText)
                }
            } else {
                Label("\(state.settlement.buildings.values.reduce(0, +)) staveb · rok \(World.year(day: state.day))", systemImage: "infinity")
                    .font(.caption).foregroundStyle(Theme.dimText)
            }
            Spacer()
            if !state.settlement.construction.isEmpty {
                Label("\(state.settlement.construction.count)", systemImage: "hammer.fill").font(.caption).foregroundStyle(Theme.parchment)
            }
            if !state.threats.isEmpty {
                Button(action: onSettlement) {
                    Label("\(state.threats.count) \(state.threats.count == 1 ? "hrozba" : "hrozby")", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.blood)
                }
            }
        }
    }

    private func contractRow(_ c: Contract) -> some View {
        let h = max(0, Int((c.deadline.timeIntervalSince(state.worldTime) / 3600).rounded(.up)))
        return Button(action: onWorld) {
            HStack(spacing: 8) {
                Image(systemName: "scroll.fill").font(.caption).foregroundStyle(Theme.ember)
                Text(c.title).font(.caption).foregroundStyle(Theme.parchment).lineLimit(1)
                Spacer(minLength: 4)
                Text("\(h) h").font(.caption2.weight(.bold)).monospacedDigit()
                    .foregroundStyle(h < 12 ? Theme.blood : Theme.dimText)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.ember.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Zakázka: \(c.title), zbývá \(h) hodin")
    }
}

struct TightIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            configuration.icon.font(.system(size: 8, weight: .bold))
            configuration.title
        }
    }
}

struct StatPill: View {
    var icon: String
    var value: String
    var color: Color
    var expand = true
    var body: some View {
        HStack(spacing: 3) {
            Text(icon).font(.caption)
            Text(value).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(color)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .padding(.horizontal, 7).padding(.vertical, 5)
        .frame(maxWidth: expand ? .infinity : nil)
        .frame(minWidth: expand ? 0 : 62)
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
