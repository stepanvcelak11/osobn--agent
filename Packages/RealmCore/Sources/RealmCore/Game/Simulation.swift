import Foundation

/// Plánované lokální oznámení (Živý simulátor). Text neobsahuje nic citlivého – jen herní dění.
public struct PlannedNotification: Equatable, Sendable {
    public var id: String
    public var date: Date
    public var title: String
    public var body: String
}

public struct SimulationReport: Sendable {
    public var entries: [LogEntry] = []
    public var days = 0
    public var skippedDays = 0
    public var isEmpty: Bool { entries.isEmpty }
}

/// Živý simulátor: osada žije v reálném čase. Každý úsvit (6:00 místního času) = nový den.
public enum Simulation {
    public static let dawnHour = 6
    public static let maxCatchUpDays = 14
    /// Kolik skutečného času se nejvýš započítá, když hráč nehraje.
    public static let maxRealCatchUp: TimeInterval = 3 * 24 * 3600

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    /// Klíč herního dne – den začíná úsvitem, ne půlnocí.
    public static func dayKey(_ date: Date) -> String {
        let shifted = date.addingTimeInterval(-Double(dawnHour) * 3600)
        let c = calendar.dateComponents([.year, .month, .day], from: shifted)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 0 ráno (5–11), 1 den (11–17), 2 večer (17–21), 3 noc.
    public static func phase(for date: Date) -> Int {
        let h = calendar.component(.hour, from: date)
        switch h {
        case 5..<11: return 0
        case 11..<17: return 1
        case 17..<21: return 2
        default: return 3
        }
    }

    /// Úsvity v intervalu (from, to].
    static func dawns(after from: Date, upTo to: Date) -> [Date] {
        guard to > from else { return [] }
        var comps = calendar.dateComponents([.year, .month, .day], from: from)
        comps.hour = dawnHour; comps.minute = 0; comps.second = 0
        guard var d = calendar.date(from: comps) else { return [] }
        if d <= from { d = calendar.date(byAdding: .day, value: 1, to: d)! }
        var out: [Date] = []
        while d <= to && out.count < 400 {
            out.append(d)
            d = calendar.date(byAdding: .day, value: 1, to: d)!
        }
        return out
    }

    public static func foodCapacity(_ s: Settlement) -> Int { 200 + s.count(.sypka) * 150 }

    /// Osada žije i když hráč nehraje: skutečně uplynulý čas (nejvýš 3 dny) se přičte k hernímu.
    @discardableResult
    public static func syncRealTime(_ s: inout GameState, now: Date) -> SimulationReport {
        guard s.mode.hasSettlement, !s.isOver else { return SimulationReport() }
        let elapsed = now.timeIntervalSince(s.lastRealTime)
        s.lastRealTime = now
        guard elapsed > 60 else { return SimulationReport() }
        // Kdo byl dlouho pryč, ten se mezitím vyspal.
        if elapsed >= 6 * 3600 { s.hero.awakeHours = 0 }
        s.worldTime = World.whole(s.worldTime.addingTimeInterval(min(elapsed, maxRealCatchUp)))
        return advance(&s, to: s.worldTime)
    }

    /// Dožene herní čas: stavby, hrozby, denní hospodaření, události.
    @discardableResult
    public static func advance(_ s: inout GameState, to now: Date) -> SimulationReport {
        var report = SimulationReport()
        guard s.mode.hasSettlement, !s.isOver, now > s.lastTickAt else { return report }
        var all = dawns(after: s.lastTickAt, upTo: now)
        if all.count > maxCatchUpDays {
            report.skippedDays = all.count - maxCatchUpDays
            all = Array(all.suffix(maxCatchUpDays))
            report.entries.append(LogEntry(kind: .event, text: "Uplynulo mnoho času. Osada \(report.skippedDays) dní živořila bez tvé ruky – kroniky o tom mlčí.", date: now))
        }
        for dawn in all {
            processUntil(&s, dawn, &report)
            if s.isOver { break }
            dailyTick(&s, at: dawn, &report)
            report.days += 1
            if s.isOver { break }
        }
        if !s.isOver { processUntil(&s, now, &report) }

        s.phase = phase(for: now)
        s.day = max(1, daysBetween(s.createdAt, now) + 1)
        s.lastTickAt = now
        s.log.append(contentsOf: report.entries)
        World.updateWeather(&s)
        s.hero.conditions.removeAll { $0.until <= now }
        let fixed = s.repair()
        if !fixed.isEmpty { s.stats["repairs", default: 0] += 1; s.stats["repair_" + (fixed.first ?? "?").prefix(20), default: 0] += 1 }
        _ = Achievements.evaluate(&s)
        return report
    }

    public static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let ka = a.addingTimeInterval(-Double(dawnHour) * 3600), kb = b.addingTimeInterval(-Double(dawnHour) * 3600)
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: ka), to: calendar.startOfDay(for: kb)).day ?? 0
    }

    /// Dokončí stavby a vyhodnotí hrozby s termínem do `date`.
    static func processUntil(_ s: inout GameState, _ date: Date, _ report: inout SimulationReport) {
        let done = s.settlement.construction.filter { $0.finishAt <= date }.sorted { $0.finishAt < $1.finishAt }
        for c in done {
            s.settlement.construction.removeAll { $0.id == c.id }
            s.settlement.buildings[c.kind, default: 0] += 1
            switch c.kind {
            case .palisada: s.settlement.defense += 15
            case .kasarna: s.settlement.defense += 10
            case .straznaVez: s.settlement.defense += 3
            case .kaple: s.settlement.morale = min(100, s.settlement.morale + 10)
            default: break
            }
            s.settlement.foodCapacity = foodCapacity(s.settlement)
            s.stats["built", default: 0] += 1
            report.entries.append(LogEntry(kind: .event, text: "🔨 Dokončeno: \(c.kind.czechName) (\(c.kind.effect)).", date: c.finishAt))
        }
        if let c = s.contract, c.deadline <= date {
            s.contract = nil
            applyDelta(&s, StatDelta(morale: -5))
            s.stats["contracts_failed", default: 0] += 1
            report.entries.append(LogEntry(kind: .event, text: "⌛ Zakázka propadla: \(c.title). Lidé si to pamatují (morálka −5).",
                                           date: c.deadline, delta: StatDelta(morale: -5)))
        }
        let due = s.threats.filter { $0.deadline <= date }.sorted { $0.deadline < $1.deadline }
        for t in due {
            s.threats.removeAll { $0.id == t.id }
            resolveThreat(&s, t, &report)
            if s.isOver { return }
        }
    }

    static func resolveThreat(_ s: inout GameState, _ t: Threat, _ report: inout SimulationReport) {
        let st = s.settlement
        let roll = s.d20()
        let power: Int
        switch t.kind {
        case .plague: power = st.count(.ranhojicstvi) * 15 + st.morale / 5 + roll
        case .storm: power = st.count(.sypka) * 10 + 10 + roll
        default: power = st.defense + st.count(.kasarna) * 5 + roll
        }
        var d = StatDelta()
        let text: String
        if power >= t.strength {
            d.morale = 5; d.stress = -3
            s.stats["threats_repelled", default: 0] += 1
            text = "🛡️ \(t.title): osada odolala."
        } else {
            let diff = t.strength - power
            switch t.kind {
            case .raid, .bandits:
                d.pop = -(1 + diff / 5)
                d.gold = -min(st.gold, 10 + diff * 2)
                d.food = -(10 + diff * 2)
                d.defense = -3
                if t.kind == .raid { d.hp = -(5 + diff / 2) }
            case .beast:
                d.pop = -s.random(1...2); d.food = -15
            case .plague:
                d.pop = -(1 + diff / 4)
            case .storm:
                d.food = -(15 + diff * 2); d.defense = -2
            }
            d.morale -= 8; d.stress += 8
            text = "🔥 \(t.title): osada utrpěla ztráty."
        }
        applyDelta(&s, d)
        report.entries.append(LogEntry(kind: .event, text: text, date: t.deadline, delta: d))
        checkEnd(&s)
    }

    static func applyDelta(_ s: inout GameState, _ d: StatDelta) {
        s.settlement.population = max(0, s.settlement.population + d.pop)
        s.settlement.gold = max(0, s.settlement.gold + d.gold)
        s.settlement.foodCapacity = foodCapacity(s.settlement)
        s.settlement.food = max(0, min(s.settlement.foodCapacity, s.settlement.food + d.food))
        s.settlement.defense = max(0, s.settlement.defense + d.defense)
        s.settlement.morale = max(0, min(100, s.settlement.morale + d.morale))
        s.hero.hp = max(0, min(100, s.hero.hp + d.hp))
        s.hero.stress = max(0, min(100, s.hero.stress + d.stress))
        if d.pop < 0 { s.stats["pop_lost", default: 0] -= d.pop }
    }

    static func checkEnd(_ s: inout GameState) {
        if s.hero.hp <= 0 { s.end = .death }
        else if s.settlement.population <= 0 { s.end = .ruin }
        else if s.settlement.morale <= 0 {
            s.end = .defeat
            s.log.append(LogEntry(kind: .event, text: "⚔️ Povstání! Lid ztratil víru a svrhl tě."))
        }
    }

    static let threatTitles: [ThreatKind: [String]] = [
        .raid: ["Nájezdníci ze severu", "Válečná družina pod černou korouhví", "Žoldnéři bez pána"],
        .bandits: ["Lapkové z Vlčího lesa", "Banda Jednookého Matěje", "Pašeráci z bažin"],
        .beast: ["Smečka vlkodlaků", "Medvěd, který zabíjí pro radost", "Něco velkého v lese"],
        .plague: ["Horečka z bažin", "Krvavý kašel", "Černé puchýře"],
        .storm: ["Krupobití", "Vichřice z hor", "Povodeň po tání"],
    ]

    static func dailyTick(_ s: inout GameState, at dawn: Date, _ report: inout SimulationReport) {
        let st = s.settlement
        var d = StatDelta()
        var notes: [String] = []
        // Hospodaření: úroda podle ročního období, v mrazu se jí víc
        let season = World.season(day: daysBetween(s.createdAt, dawn) + 1)
        let production = Int((Double(8 + st.count(.farma) * 15 + st.population / 4) * season.harvest).rounded())
        let consumption = Int((Double(st.population) * s.weather.foodFactor).rounded())
        d.food = production - consumption
        d.gold = 5 + st.count(.trziste) * 12 + st.population / 10
        let foodAfter = st.food + d.food
        if foodAfter <= 0 {
            let lost = max(1, st.population / 15)
            d.pop -= lost; d.morale -= 10; d.stress += 8
            notes.append("Hladomor – \(lost) lidí zemřelo nebo uteklo")
        } else if Double(foodAfter) / Double(max(1, foodCapacity(st))) < 0.2 {
            d.morale -= 5; d.stress += 4
            notes.append("zásoby docházejí, lidé panikaří")
        }
        // Morálka tíhne k rovnováze
        let target = 50 + st.count(.kaple) * 10 + (st.foodPercent >= 60 ? 5 : 0)
        let diff = target - (st.morale + d.morale)
        d.morale += diff > 0 ? min(3, diff) : max(-3, diff)
        // Růst
        if foodAfter > 0 && Double(foodAfter) / Double(max(1, foodCapacity(st))) >= 0.5 && st.morale >= 50 {
            let born = max(1, st.population / 10)
            d.pop += born
            notes.append("přibylo \(born) obyvatel")
        }
        if s.hero.has("vudce") { d.morale += 2 }
        s.hero.refreshAbilities()
        // Hrdina si odpočine; ranhojič vyléčí horečku i rány
        d.hp += 5 + st.count(.ranhojicstvi) * 5
        d.stress -= 5 + st.count(.kaple) * 5
        if st.count(.ranhojicstvi) > 0 && s.hero.conditions.contains(where: { $0.kind == .horecka || $0.kind == .krvaceni }) {
            s.hero.conditions.removeAll { $0.kind == .horecka || $0.kind == .krvaceni }
            notes.append("ranhojič tě dal do pořádku")
        }
        applyDelta(&s, d)
        s.stats["days", default: 0] += 1
        let dayN = (s.stats["days"] ?? 0) + 1
        var text = "🌅 Úsvit \(dayN). dne. Jídlo \(signed(d.food)), zlato \(signed(d.gold))"
        if !notes.isEmpty { text += "; " + notes.joined(separator: "; ") }
        report.entries.append(LogEntry(kind: .event, text: text + ".", date: dawn, delta: d))
        checkEnd(&s)
        if s.isOver { return }

        // Nová hrozba
        if dayN >= 2 && s.threats.count < 3 && s.chance(min(55, 25 + dayN)) {
            let kind = s.pick(ThreatKind.allCases)
            let strength = 10 + dayN * 2 + s.random(0...8)
            let hours = Double(s.random(24...48) + s.settlement.count(.straznaVez) * 6)
            let t = Threat(kind: kind, title: s.pick(threatTitles[kind]!), strength: strength,
                           deadline: dawn.addingTimeInterval(hours * 3600))
            s.threats.append(t)
            report.entries.append(LogEntry(kind: .event, text: "⚠️ Hrozba: \(t.title) (\(kind.czechName.lowercased())) – udeří za \(Int(hours)) h. Připrav osadu, nebo jednej.", date: dawn))
        }
        // Zakázka od obyvatel
        if dayN >= 2 && s.contract == nil && s.chance(45), let e = World.offerContract(&s, at: dawn) {
            report.entries.append(e)
        }
        // Náhodná událost
        if s.chance(40) {
            var e = StatDelta()
            let text: String
            switch s.random(1...7) {
            case 1: e.gold = s.random(15...30); text = "Kočovný kupec zaplatil za nocleh."
            case 2: e.food = s.random(20...40); text = "Les byl štědrý – houby, zvěřina, med."
            case 3: e.food = -s.random(15...30); e.morale = -5; text = "V noci vyhořela stodola."
            case 4: e.pop = s.random(2...4); text = "Do osady přišli poutníci a zůstali."
            case 5: e.pop = -s.random(1...3); e.morale = -3; text = "Pár lidí v noci zběhlo s ukradenými zásobami."
            case 6:
                if s.settlement.count(.ranhojicstvi) > 0 { text = "Ranhojič zastavil začínající nákazu." }
                else { e.pop = -s.random(1...2); text = "Zimnice si vzala nejslabší." }
            default: e.food = -10; text = "Vlci roztrhali část stáda."
            }
            applyDelta(&s, e)
            report.entries.append(LogEntry(kind: .event, text: "📜 " + text, date: dawn, delta: e.isZero ? nil : e))
            checkEnd(&s)
        }
    }

    static func signed(_ v: Int) -> String { v >= 0 ? "+\(v)" : "\(v)" }

    /// Oznámení k naplánování (hrozby 2 h předem, dokončené stavby, nový den).
    public static func plannedNotifications(_ s: GameState, now: Date = Date(), includeDawn: Bool = true) -> [PlannedNotification] {
        guard s.mode.hasSettlement, !s.isOver else { return [] }
        // Herní čas běží dál skutečným tempem, když hráč nehraje.
        func real(_ world: Date) -> Date { now.addingTimeInterval(world.timeIntervalSince(s.worldTime)) }
        var out: [PlannedNotification] = []
        for t in s.threats {
            let at = real(t.deadline).addingTimeInterval(-2 * 3600)
            if at > now {
                out.append(PlannedNotification(id: "threat-\(t.id)", date: at, title: "⚠️ \(s.settlement.name) v ohrožení",
                                               body: "\(t.title) udeří za 2 hodiny."))
            }
        }
        for c in s.settlement.construction where real(c.finishAt) > now {
            out.append(PlannedNotification(id: "build-\(c.id)", date: real(c.finishAt), title: "🔨 \(s.settlement.name)",
                                           body: "Stavba dokončena: \(c.kind.czechName)."))
        }
        if includeDawn, let dawn = dawns(after: s.worldTime, upTo: s.worldTime.addingTimeInterval(26 * 3600)).first {
            out.append(PlannedNotification(id: "dawn-\(s.id)", date: real(dawn), title: "🌅 Nový den v \(s.settlement.name)",
                                           body: "Hrdina nabral síly. Osada čeká na tvé rozkazy."))
        }
        return out
    }
}
