import SwiftUI
import RealmCore

/// Jeden záznam deníku.
struct LogEntryView: View {
    let entry: LogEntry
    var paranoid = false
    @AppStorage("text.scale") private var textScale = 1.0

    var body: some View {
        switch entry.kind {
        case .narration: narration
        case .player: player
        case .system: system
        case .event: event
        }
    }

    private var narration: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let roll = entry.roll { RollBadge(roll: roll) }
            Text(entry.text)
                .font(.system(size: 17 * textScale, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(paranoid ? Color(red: 0.95, green: 0.8, blue: 0.78) : Theme.parchment)
                .textSelection(.enabled)
            if let d = entry.delta, !d.isZero { DeltaChips(delta: d) }
            if let h = entry.hours, h >= 0.25 {
                Label(Prompts.timeText(h), systemImage: "hourglass").font(.caption2).foregroundStyle(Theme.dimText)
            }
            if !entry.itemsAdded.isEmpty || !entry.itemsRemoved.isEmpty {
                ItemChangeChips(added: entry.itemsAdded, removed: entry.itemsRemoved)
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(LinearGradient(colors: [Theme.ember, Theme.ember.opacity(0.1)], startPoint: .top, endPoint: .bottom))
                .frame(width: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var player: some View {
        HStack {
            Spacer(minLength: 50)
            Text(entry.text)
                .font(.system(size: 15 * textScale, design: .serif)).italic()
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(LinearGradient(colors: [Theme.parchment, Theme.parchment.opacity(0.85)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var system: some View {
        Text(entry.text)
            .font(.footnote).italic()
            .foregroundStyle(Theme.dimText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
    }

    private var event: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(entry.text).font(.footnote).foregroundStyle(Theme.parchment)
                Spacer(minLength: 0)
                Text(entry.date, format: .dateTime.hour().minute()).font(.caption2).foregroundStyle(Theme.dimText)
            }
            if let d = entry.delta, !d.isZero { DeltaChips(delta: d) }
        }
        .padding(10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke))
    }
}

struct RollBadge: View {
    let roll: RollInfo
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "dice.fill")
            Text("\(roll.die)").font(.system(.caption, design: .rounded).weight(.heavy))
            if roll.modifier != 0 { Text(signed(roll.modifier)).font(.caption2) }
            Text("= \(roll.total) / \(roll.dc)").font(.caption2).opacity(0.8)
            Text("· \(roll.outcome.czechName)").font(.caption.weight(.semibold))
            if let s = roll.stat { Text("(\(s.czechName))").font(.caption2).opacity(0.7) }
        }
        .foregroundStyle(Theme.color(roll.outcome))
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Theme.color(roll.outcome).opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct DeltaChips: View {
    let delta: StatDelta
    var body: some View {
        FlowRow(spacing: 6) {
            ForEach(Array(delta.chips.enumerated()), id: \.offset) { _, c in
                Text("\(c.0) \(signed(c.1))")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(c.1 >= 0 ? c.2 : Theme.blood)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((c.1 >= 0 ? c.2 : Theme.blood).opacity(0.13), in: Capsule())
            }
        }
    }
}

struct ItemChangeChips: View {
    let added: [String]
    let removed: [String]
    var body: some View {
        FlowRow(spacing: 6) {
            ForEach(added, id: \.self) { n in
                Text("🎒 + \(n)").font(.caption.weight(.semibold)).foregroundStyle(Theme.gold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.gold.opacity(0.13), in: Capsule())
            }
            ForEach(removed, id: \.self) { n in
                Text("🎒 − \(n)").font(.caption).foregroundStyle(Theme.dimText).strikethrough()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }
        }
    }
}

/// Jednoduché zalamování čipů do řádků.
struct FlowRow: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: width, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// Rozepsané vyprávění (streamuje se token po tokenu).
struct StreamingNarration: View {
    let busy: GameSession.Busy
    let text: String
    let roll: RollInfo?
    @AppStorage("text.scale") private var textScale = 1.0
    @State private var blink = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let roll, roll.outcome != .auto, busy != .rolling { RollBadge(roll: roll) }
            if text.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.ember)
                    Text(busy.label).font(.system(.subheadline, design: .serif)).italic().foregroundStyle(Theme.dimText)
                }
            } else {
                (Text(text) + Text(blink ? " ▍" : "  ").foregroundColor(Theme.ember))
                    .font(.system(size: 17 * textScale, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(Theme.parchment)
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(Theme.ember.opacity(0.6)).frame(width: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { blink = true }
        }
    }
}

/// Animace hodu kostkou k20.
struct DiceOverlay: View {
    let roll: RollInfo
    var onDone: () -> Void
    @State private var shown = 1
    @State private var settled = false
    @State private var spin = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 130))
                        .foregroundStyle(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
                        .overlay(Image(systemName: "hexagon").font(.system(size: 130)).foregroundStyle(settled ? Theme.color(roll.outcome) : Theme.ember.opacity(0.6)))
                        .rotationEffect(.degrees(spin))
                    Text("\(shown)")
                        .font(.system(size: 52, weight: .heavy, design: .serif))
                        .foregroundStyle(settled ? Theme.color(roll.outcome) : Theme.parchment)
                        .contentTransition(.numericText())
                }
                .shadow(color: settled ? Theme.color(roll.outcome).opacity(0.8) : .clear, radius: 24)
                if settled {
                    VStack(spacing: 4) {
                        Text(roll.outcome.czechName.uppercased())
                            .font(Theme.title(24)).tracking(3)
                            .foregroundStyle(Theme.color(roll.outcome))
                        Text("\(roll.die) \(signed(roll.modifier)) = \(roll.total)  ·  potřeba \(roll.dc)")
                            .font(.caption).foregroundStyle(Theme.dimText)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onTapGesture { onDone() }
        .task {
            for i in 0..<12 {
                try? await Task.sleep(nanoseconds: UInt64(45_000_000 + i * 12_000_000))
                withAnimation(.easeOut(duration: 0.08)) {
                    shown = Int.random(in: 1...20)
                    spin += 30
                }
                Haptics.impact(.light)
            }
            withAnimation(.spring(duration: 0.4)) {
                shown = roll.die
                spin = 0
                settled = true
            }
            Haptics.outcome(roll.outcome)
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            onDone()
        }
        .accessibilityLabel("Hod kostkou: \(roll.die), \(roll.outcome.czechName)")
    }
}
