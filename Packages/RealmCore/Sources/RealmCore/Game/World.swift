import Foundation

// MARK: - Roční období a počasí

/// Herní rok začíná jarem; každé období trvá `World.seasonDays` herních dní.
public enum Season: Int, Codable, CaseIterable, Sendable {
    case jaro, leto, podzim, zima

    public var czechName: String { ["Jaro", "Léto", "Podzim", "Zima"][rawValue] }
    public var icon: String { ["leaf.fill", "sun.max.fill", "wind", "snowflake"][rawValue] }
    /// Násobek úrody v osadě.
    public var harvest: Double { [0.9, 1.15, 1.25, 0.45][rawValue] }
}

public enum Weather: String, Codable, CaseIterable, Sendable {
    case jasno, zatazeno, dest, mlha, bourka, snih, mraz

    public var czechName: String {
        switch self {
        case .jasno: return "Jasno"
        case .zatazeno: return "Zataženo"
        case .dest: return "Déšť"
        case .mlha: return "Mlha"
        case .bourka: return "Bouřka"
        case .snih: return "Sněžení"
        case .mraz: return "Mráz"
        }
    }
    public var icon: String {
        switch self {
        case .jasno: return "sun.max"
        case .zatazeno: return "cloud"
        case .dest: return "cloud.rain"
        case .mlha: return "cloud.fog"
        case .bourka: return "cloud.bolt.rain"
        case .snih: return "cloud.snow"
        case .mraz: return "thermometer.snowflake"
        }
    }
    /// Pro vypravěče.
    public var mood: String {
        switch self {
        case .jasno: return "jasno, ostré světlo a dlouhé stíny"
        case .zatazeno: return "zataženo, šedivé nebe visí nízko"
        case .dest: return "prší, bláto, mokré šaty a kapky bubnují"
        case .mlha: return "hustá mlha, není vidět na deset kroků"
        case .bourka: return "bouřka, hromy, vichr a liják"
        case .snih: return "sněží, mráz štípe a stopy zůstávají ve sněhu"
        case .mraz: return "tuhý mráz, dech se mění v páru a led praská"
        }
    }

    /// Vliv počasí na hod podle druhu činu.
    public func modifier(_ c: ActionCategory) -> Int {
        switch (self, c) {
        case (.mlha, .stealth): return 2
        case (.mlha, .explore), (.mlha, .travel): return -1
        case (.dest, .stealth): return 1
        case (.dest, .travel): return -1
        case (.bourka, .travel): return -2
        case (.bourka, .combat), (.bourka, .explore): return -1
        case (.snih, .travel): return -2
        case (.snih, .stealth): return -1
        case (.mraz, .travel), (.mraz, .craft): return -1
        case (.jasno, .explore): return 1
        default: return 0
        }
    }
    /// Karavana a osada spotřebují víc jídla v zimě a za mrazu.
    public var foodFactor: Double {
        switch self {
        case .snih: return 1.2
        case .mraz: return 1.3
        default: return 1
        }
    }
}

// MARK: - Stavy hrdiny

public enum ConditionKind: String, Codable, CaseIterable, Sendable {
    /// Otevřená rána – každý tah bere zdraví, dokud se neošetří nebo nezacelí.
    case krvaceni
    /// Horečka – postih k hodům, zdraví pomalu ubývá.
    case horecka
    /// Odhodlání po skvělém úspěchu – bonus k hodům.
    case odhodlani
    /// Únava (počítá se z hodin bez spánku, neukládá se).
    case unava
    /// Vyčerpání – víc než 30 hodin bez spánku.
    case vycerpani

    public var czechName: String {
        switch self {
        case .krvaceni: return "Krvácení"
        case .horecka: return "Horečka"
        case .odhodlani: return "Odhodlání"
        case .unava: return "Únava"
        case .vycerpani: return "Vyčerpání"
        }
    }
    public var icon: String {
        switch self {
        case .krvaceni: return "drop.fill"
        case .horecka: return "thermometer.high"
        case .odhodlani: return "flame.fill"
        case .unava: return "zzz"
        case .vycerpani: return "bed.double.fill"
        }
    }
    public var isGood: Bool { self == .odhodlani }
    public var rollModifier: Int {
        switch self {
        case .krvaceni, .horecka, .unava: return -1
        case .vycerpani: return -2
        case .odhodlani: return 1
        }
    }
    public var detail: String {
        switch self {
        case .krvaceni: return "−2 zdraví každý tah, −1 k hodům. Ošetři se (léčivý předmět, odpočinek nebo ošetření ran)."
        case .horecka: return "−1 k hodům, zdraví pomalu ubývá. Pomůže léčivý předmět, odpočinek nebo ranhojič."
        case .odhodlani: return "+1 k hodům. Vyprchá za pár hodin."
        case .unava: return "Dlouho bez spánku: −1 k hodům. Odpočiň si aspoň 6 hodin."
        case .vycerpani: return "Přes 30 hodin bez spánku: −2 k hodům a roste stres. Nutně se vyspi."
        }
    }
    /// Pro vypravěče.
    var hint: String {
        switch self {
        case .krvaceni: return "krvácí z rány"
        case .horecka: return "má horečku"
        case .odhodlani: return "je plný odhodlání"
        case .unava: return "je unavený"
        case .vycerpani: return "je k smrti vyčerpaný"
        }
    }
}

public struct Condition: Codable, Equatable, Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public var kind: ConditionKind
    /// Herní čas, kdy stav sám odezní.
    public var until: Date
    public init(kind: ConditionKind, until: Date) { self.kind = kind; self.until = until }
}

// MARK: - Postavy, které hrdina potkal

public enum Attitude: String, Codable, CaseIterable, Sendable {
    case friend, neutral, hostile
    public var czechName: String {
        switch self {
        case .friend: return "přítel"
        case .neutral: return "neutrální"
        case .hostile: return "nepřítel"
        }
    }
    public var icon: String {
        switch self {
        case .friend: return "heart.fill"
        case .neutral: return "circle.lefthalf.filled"
        case .hostile: return "exclamationmark.triangle.fill"
        }
    }
}

public struct NPC: Codable, Equatable, Identifiable, Sendable {
    public var id: String = UUID().uuidString
    public var name: String
    public var role: String
    public var attitude: Attitude
    /// Tah, kdy se postava naposledy objevila.
    public var lastSeen: Int
    public var meetings = 1
    public init(name: String, role: String, attitude: Attitude, lastSeen: Int) {
        self.name = name; self.role = role; self.attitude = attitude; self.lastSeen = lastSeen
    }
}

// MARK: - Zakázky (vedlejší úkoly)

public struct Reward: Codable, Equatable, Sendable {
    public var gold = 0, food = 0, morale = 0, pop = 0, defense = 0
    public init(gold: Int = 0, food: Int = 0, morale: Int = 0, pop: Int = 0, defense: Int = 0) {
        self.gold = gold; self.food = food; self.morale = morale; self.pop = pop; self.defense = defense
    }
    public var delta: StatDelta { StatDelta(pop: pop, gold: gold, food: food, defense: defense, morale: morale) }
    public var text: String {
        var p: [String] = []
        if gold > 0 { p.append("\(gold) zlata") }
        if food > 0 { p.append("\(food) jídla") }
        if pop > 0 { p.append("\(pop) \(pop == 1 ? "nový člověk" : pop < 5 ? "noví lidé" : "nových lidí")") }
        if defense > 0 { p.append("+\(defense) obrana") }
        if morale > 0 { p.append("+\(morale) morálka") }
        return p.joined(separator: ", ")
    }
}

public struct Contract: Codable, Equatable, Identifiable, Sendable {
    public var id: String = UUID().uuidString
    public var title: String
    public var giver: String
    public var categories: [ActionCategory]
    public var reward: Reward
    public var deadline: Date
    public init(title: String, giver: String, categories: [ActionCategory], reward: Reward, deadline: Date) {
        self.title = title; self.giver = giver; self.categories = categories; self.reward = reward; self.deadline = deadline
    }
}

// MARK: - Pravidla světa

public enum World {
    public static let seasonDays = 20

    public static func season(day: Int) -> Season {
        Season(rawValue: ((max(1, day) - 1) / seasonDays) % 4) ?? .jaro
    }

    /// Rok podle herního dne (1. rok = dny 1–80).
    public static func year(day: Int) -> Int { (max(1, day) - 1) / (seasonDays * 4) + 1 }

    static let weatherOdds: [Season: [(Weather, Int)]] = [
        .jaro: [(.jasno, 30), (.zatazeno, 25), (.dest, 30), (.mlha, 15)],
        .leto: [(.jasno, 50), (.zatazeno, 15), (.dest, 15), (.bourka, 20)],
        .podzim: [(.jasno, 15), (.zatazeno, 30), (.dest, 25), (.mlha, 25), (.bourka, 5)],
        .zima: [(.jasno, 15), (.zatazeno, 25), (.snih, 35), (.mraz, 20), (.mlha, 5)],
    ]

    /// Nové počasí, když začne nový den.
    static func updateWeather(_ s: inout GameState) {
        guard s.weatherDay != s.day else { return }
        let odds = weatherOdds[season(day: s.day)]!
        var r = s.random(1...odds.reduce(0) { $0 + $1.1 })
        var w = Weather.jasno
        for (kind, p) in odds { r -= p; if r <= 0 { w = kind; break } }
        let changedSeason = s.weatherDay > 0 && season(day: s.weatherDay) != season(day: s.day)
        s.weather = w
        s.weatherDay = s.day
        if changedSeason {
            let sea = season(day: s.day)
            let text: String
            switch sea {
            case .jaro: text = "🌱 Přichází jaro. Sníh taje, pole se zelenají – nový rok začíná."
            case .leto: text = "☀️ Začíná léto. Dlouhé dny, krátké noci, bouřky nad obzorem."
            case .podzim: text = "🍂 Nastal podzim – čas sklizně. Plň sýpky, zima se blíží."
            case .zima: text = "❄️ Přišla zima. Úroda slábne, mráz bere slabé. Kdo nemá zásoby, trpí."
            }
            s.log.append(LogEntry(kind: .event, text: text, date: s.worldTime))
        }
    }

    // MARK: Úrovně

    /// Kolik zkušeností potřebuje úroveň `level` (celkem). Úroveň 1 = 0.
    public static func xpForLevel(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        return (2...level).reduce(0) { $0 + 60 + ($1 - 2) * 40 }
    }

    public static let maxAttribute = 6

    static func xp(for outcome: Outcome) -> Int {
        switch outcome {
        case .critSuccess: return 25
        case .success: return 15
        case .partial: return 8
        case .fail, .critFail: return 5
        case .auto: return 2
        case .impossible: return 0
        }
    }

    /// Přidá zkušenosti; při nové úrovni zvedne nejpoužívanější schopnost a vrátí záznamy do deníku.
    static func gainXP(_ s: inout GameState, _ amount: Int) -> [LogEntry] {
        guard amount > 0 else { return [] }
        s.hero.xp += amount
        var out: [LogEntry] = []
        while s.hero.xp >= xpForLevel(s.hero.level + 1) {
            s.hero.level += 1
            let order = Attribute.allCases.sorted {
                let a = s.hero.statUse[$0.rawValue] ?? 0, b = s.hero.statUse[$1.rawValue] ?? 0
                return a != b ? a > b : s.hero.score($0) > s.hero.score($1)
            }
            var text = "⭐ Úroveň \(s.hero.level)! "
            if let attr = order.first(where: { s.hero.score($0) < maxAttribute }) {
                s.hero.attributes[attr] = s.hero.score(attr) + 1
                text += "\(attr.czechName) +1 – učíš se tím, co děláš. "
            }
            s.hero.hp = min(100, s.hero.hp + 20)
            s.hero.stress = max(0, s.hero.stress - 15)
            text += "Zdraví +20, stres −15."
            out.append(LogEntry(kind: .event, text: text, date: s.worldTime))
        }
        return out
    }

    // MARK: Stavy

    /// Aktivní stavy včetně únavy spočtené z hodin bez spánku.
    public static func conditions(_ h: Hero, at now: Date) -> [ConditionKind] {
        var out = h.conditions.filter { $0.until > now }.map(\.kind)
        if h.awakeHours >= 30 { out.append(.vycerpani) } else if h.awakeHours >= 18 { out.append(.unava) }
        return out
    }

    static func addCondition(_ s: inout GameState, _ kind: ConditionKind, hours: Double) -> Bool {
        let until = s.worldTime.addingTimeInterval(hours * 3600)
        if let i = s.hero.conditions.firstIndex(where: { $0.kind == kind }) {
            s.hero.conditions[i].until = max(s.hero.conditions[i].until, until)
            return false
        }
        s.hero.conditions.append(Condition(kind: kind, until: until))
        return true
    }

    // MARK: Postavy

    public static let maxCharacters = 12

    static func meet(_ s: inout GameState, name raw: String, role rawRole: String, attitude: Attitude) {
        guard let name = Rules.cleanItemName(raw), name.count <= 40 else { return }
        let role = Rules.cleanItemName(rawRole)?.lowercased() ?? "neznámý"
        let banned = ["ty", "hrdina", "vypravec", "nikdo", "zadny", "null", "none", CzechText.fold(s.hero.name)]
        if banned.contains(CzechText.fold(name)) { return }
        if let i = s.characters.firstIndex(where: { sameName($0.name, name) }) {
            s.characters[i].attitude = attitude
            s.characters[i].lastSeen = s.turn
            s.characters[i].meetings += 1
            if s.characters[i].role == "neznámý" { s.characters[i].role = role }
            return
        }
        s.characters.append(NPC(name: name, role: String(role.prefix(40)), attitude: attitude, lastSeen: s.turn))
        if s.characters.count > maxCharacters {
            if let oldest = s.characters.enumerated().min(by: { $0.element.lastSeen < $1.element.lastSeen })?.offset {
                s.characters.remove(at: oldest)
            }
        }
    }

    /// „Hubert“ = „hubert“ = „Starý Hubert“, ale „Poutník 1“ ≠ „Poutník 2“.
    static func sameName(_ a: String, _ b: String) -> Bool {
        let wa = Set(CzechText.fold(a).split(separator: " ").map(String.init))
        let wb = Set(CzechText.fold(b).split(separator: " ").map(String.init))
        guard !wa.isEmpty, !wb.isEmpty else { return false }
        if wa == wb { return true }
        let (small, big) = wa.count <= wb.count ? (wa, wb) : (wb, wa)
        return small.isSubset(of: big) && small.contains { $0.count >= 4 }
    }

    // MARK: Zakázky

    struct ContractTemplate {
        var title: String
        var giver: String
        var categories: [ActionCategory]
        var reward: Reward
    }

    static let settlementContracts: [ContractTemplate] = [
        .init(title: "Najdi mlynářovu dceru, která se ztratila v lese", giver: "mlynář Kuba", categories: [.explore, .combat, .social], reward: Reward(gold: 30, morale: 8)),
        .init(title: "Ulov vlka, který zadávil ovce u pastviny", giver: "pastýřka Dora", categories: [.combat, .explore], reward: Reward(gold: 15, food: 30)),
        .init(title: "Rozsuď spor dvou rodů o hraniční pole", giver: "stařešina Bohuš", categories: [.social], reward: Reward(morale: 12)),
        .init(title: "Přines železnou rudu ze staré štoly pro kováře", giver: "kovář Radek", categories: [.explore, .craft], reward: Reward(gold: 20, defense: 6)),
        .init(title: "Dopadni lapku Rudovouse, na kterého je vypsaná odměna", giver: "výběrčí z hradu", categories: [.combat, .stealth], reward: Reward(gold: 60)),
        .init(title: "Připrav lék pro nemocné děti v dolní čtvrti", giver: "vdova Marta", categories: [.craft, .magic, .explore], reward: Reward(morale: 10, pop: 2)),
        .init(title: "Doprovoď kupce s osivem bezpečně k brodu", giver: "kupec Šimon", categories: [.combat, .social, .explore], reward: Reward(gold: 25, food: 40)),
        .init(title: "Zjisti, kdo v noci krade z obecní sýpky", giver: "správce sýpky", categories: [.stealth, .social, .explore], reward: Reward(food: 35, morale: 6)),
        .init(title: "Vyžeň ducha ze zvonice, kterého se lidé bojí", giver: "kněz Ambrož", categories: [.magic, .explore, .combat], reward: Reward(gold: 10, morale: 14)),
        .init(title: "Přemluv tlupu uprchlíků z hor, ať se usadí v osadě", giver: "tvoje rada", categories: [.social, .trade], reward: Reward(pop: 6)),
    ]

    static let caravanContracts: [ContractTemplate] = [
        .init(title: "Najdi syna vdovy, který se ztratil při posledním přepadu", giver: "vdova Hedvika", categories: [.explore, .combat, .social], reward: Reward(morale: 10, pop: 1)),
        .init(title: "Oprav zlomenou osu hlavního vozu", giver: "vozka Lojza", categories: [.craft], reward: Reward(food: 10, morale: 6, defense: 2)),
        .init(title: "Odhal zloděje, který v noci krade zásoby", giver: "kuchařka Bára", categories: [.stealth, .social, .explore], reward: Reward(food: 30, morale: 6)),
        .init(title: "Zbav místní vesnici vlků výměnou za průvodce", giver: "stařešina z vesnice", categories: [.combat, .explore], reward: Reward(gold: 30, morale: 5)),
        .init(title: "Vyjednej s převozníkem levnější přechod", giver: "převozník Kilián", categories: [.social, .trade], reward: Reward(gold: 35)),
        .init(title: "Ulov zvěř, ať karavana nemusí sahat do zásob", giver: "lovec Jíra", categories: [.explore, .combat], reward: Reward(food: 45)),
    ]

    /// Případně nabídne novou zakázku (osada: za úsvitu, karavana: po příjezdu).
    static func offerContract(_ s: inout GameState, at date: Date) -> LogEntry? {
        guard s.mode != .quest, s.contract == nil, !s.isOver else { return nil }
        let pool = s.mode == .campaign ? caravanContracts : settlementContracts
        let recent = Set(s.recentContracts)
        let fresh = pool.filter { !recent.contains($0.title) }
        let t = s.pick(fresh.isEmpty ? pool : fresh)
        let hours = Double(s.random(36...72))
        var reward = t.reward
        if s.mode == .endless {
            // Nekonečná říše: odměny rostou s velikostí osady.
            let scale = 1 + Double(s.settlement.population) / 150
            reward.gold = Int(Double(reward.gold) * scale); reward.food = Int(Double(reward.food) * scale)
        }
        s.contract = Contract(title: t.title, giver: t.giver, categories: t.categories, reward: reward,
                              deadline: date.addingTimeInterval(hours * 3600))
        s.recentContracts.append(t.title)
        if s.recentContracts.count > 5 { s.recentContracts.removeFirst() }
        return LogEntry(kind: .event, text: "📜 Zakázka: \(t.title) (zadává \(t.giver)). Odměna: \(reward.text). Čas: \(Int(hours)) h.", date: date)
    }

    /// Propadlá zakázka.
    static func expireContract(_ s: inout GameState) -> LogEntry? {
        guard let c = s.contract, c.deadline <= s.worldTime else { return nil }
        s.contract = nil
        s.settlement.morale = max(0, s.settlement.morale - 5)
        s.stats["contracts_failed", default: 0] += 1
        return LogEntry(kind: .event, text: "⌛ Zakázka propadla: \(c.title). Lidé si to pamatují (morálka −5).",
                        date: c.deadline, delta: StatDelta(morale: -5))
    }

    // MARK: Hodnost osady

    static let ranks = ["Tábořiště", "Osada", "Ves", "Městečko", "Město", "Hrad a podhradí"]

    /// Když osada povýší (Osada → Ves → Městečko…), oslaví se to a hrdina získá zkušenosti.
    static func checkRank(_ s: inout GameState) -> [LogEntry] {
        guard s.mode.hasSettlement else { return [] }
        let rank = Catalog.settlementRank(population: s.settlement.population)
        let idx = ranks.firstIndex(of: rank) ?? 0
        let best = s.stats["rank_best"] ?? (ranks.firstIndex(of: Catalog.settlementRank(population: s.stats["start_pop"] ?? 30)) ?? 1)
        guard idx > best else {
            if s.stats["rank_best"] == nil { s.stats["rank_best"] = best }
            return []
        }
        s.stats["rank_best"] = idx
        s.settlement.morale = min(100, s.settlement.morale + 5)
        var out = [LogEntry(kind: .event, text: "🏰 \(s.settlement.name) povýšila: \(rank)! Lidé slaví na návsi (morálka +5).", date: s.worldTime)]
        out += gainXP(&s, 30)
        return out
    }
}
