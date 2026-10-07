import Foundation

// MARK: - Módy

public enum GameMode: String, Codable, CaseIterable, Sendable {
    /// Krátká hra: jedno místo, jeden snadný cíl.
    case quest
    /// Delší hra: karavana putuje do nového domova.
    case campaign
    /// Dlouhá hra: vybudovat z osady město.
    case realm
    /// Nekonečná hra: stavět a rozšiřovat bez konce.
    case endless

    public var title: String {
        switch self {
        case .quest: return "Rychlá výprava"
        case .campaign: return "Cesta světem"
        case .realm: return "Vláda nad osadou"
        case .endless: return "Nekonečná říše"
        }
    }
    public var length: String {
        switch self {
        case .quest: return "Krátká hra"
        case .campaign: return "Delší hra"
        case .realm: return "Dlouhá hra"
        case .endless: return "Bez konce"
        }
    }
    public var subtitle: String {
        switch self {
        case .quest: return "Krátká hra · jeden snadný cíl"
        case .campaign: return "Delší hra · doveď karavanu do nového domova"
        case .realm: return "Dlouhá hra · vybuduj z osady město"
        case .endless: return "Bez konce · stav, rozšiřuj, přežij"
        }
    }
    public var icon: String {
        switch self {
        case .quest: return "flame"
        case .campaign: return "map"
        case .realm: return "building.columns"
        case .endless: return "infinity"
        }
    }
    /// Módy se správou osady (stavby, hrozby, čas).
    public var hasSettlement: Bool { self == .realm || self == .endless }
}

// MARK: - Hrdina

public enum Attribute: String, Codable, CaseIterable, Sendable {
    case sila, obratnost, duvtip, charisma
    public var czechName: String {
        switch self {
        case .sila: return "Síla"
        case .obratnost: return "Obratnost"
        case .duvtip: return "Důvtip"
        case .charisma: return "Charisma"
        }
    }
    public var icon: String {
        switch self {
        case .sila: return "figure.strengthtraining.traditional"
        case .obratnost: return "hare"
        case .duvtip: return "brain.head.profile"
        case .charisma: return "theatermasks"
        }
    }
}

public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case weapon, armor, tool, consumable, artifact, key, treasure
    public var czechName: String {
        switch self {
        case .weapon: return "Zbraň"
        case .armor: return "Zbroj"
        case .tool: return "Nástroj"
        case .consumable: return "Spotřební"
        case .artifact: return "Artefakt"
        case .key: return "Klíč"
        case .treasure: return "Poklad"
        }
    }
    public var icon: String {
        switch self {
        case .weapon: return "bolt.horizontal"
        case .armor: return "shield.lefthalf.filled"
        case .tool: return "wrench.and.screwdriver"
        case .consumable: return "drop"
        case .artifact: return "sparkles"
        case .key: return "key"
        case .treasure: return "diamond"
        }
    }
}

public struct Item: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var kind: ItemKind
    /// Počet použití (u spotřebních), nil = neomezeně.
    public var charges: Int?

    public init(id: String = UUID().uuidString, name: String, kind: ItemKind, charges: Int? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.charges = charges
    }

    public var label: String {
        if let c = charges, c > 1 { return "\(name) ×\(c)" }
        return name
    }

    /// Léčivý předmět?
    public var heals: Bool {
        let f = CzechText.fold(name)
        return kind == .consumable && ["bylin", "lektvar", "elixir", "obvaz", "mast", "lec"].contains { f.contains($0) }
    }
}

public struct Hero: Codable, Equatable, Sendable {
    public var name: String
    /// Pro správné skloňování ve vyprávění (šel/šla).
    public var feminine: Bool = false
    public var background: String
    public var attributes: [Attribute: Int]
    /// 0–100, na 0 = smrt
    public var hp: Int
    /// 0–100, vysoký stres = paranoia a postihy
    public var stress: Int
    public var items: [Item]
    /// Zkušenosti a úroveň (úroveň zvedá nejpoužívanější schopnost).
    public var xp = 0
    public var level = 1
    /// Kolikrát se zkoušela která schopnost.
    public var statUse: [String: Int] = [:]
    /// Hodiny od posledního spánku (únava).
    public var awakeHours: Double = 0
    public var conditions: [Condition] = []
    /// Povaha (id vlastností) a zvláštní schopnosti původu.
    public var traits: [String] = []
    public var abilities: [Ability] = []

    public init(name: String, feminine: Bool = false, background: String, attributes: [Attribute: Int], hp: Int,
                stress: Int, items: [Item]) {
        self.name = name; self.feminine = feminine; self.background = background; self.attributes = attributes
        self.hp = hp; self.stress = stress; self.items = items
    }

    public func score(_ a: Attribute) -> Int { attributes[a] ?? 0 }

    public func item(named name: String) -> Item? {
        let n = CzechText.fold(name).trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return nil }
        return items.first { CzechText.fold($0.name) == n }
            ?? items.first { CzechText.similarity($0.name, name) >= 0.5 }
            ?? items.first { CzechText.fold($0.name).contains(n) || n.contains(CzechText.fold($0.name)) }
    }
}

// MARK: - Osada / karavana

public enum BuildingKind: String, Codable, CaseIterable, Sendable {
    case farma, sypka, palisada, trziste, kaple, kasarna, ranhojicstvi, straznaVez = "strazna_vez"

    public var czechName: String {
        switch self {
        case .farma: return "Farma"
        case .sypka: return "Sýpka"
        case .palisada: return "Hradby"
        case .trziste: return "Tržiště"
        case .kaple: return "Kaple"
        case .kasarna: return "Kasárna"
        case .ranhojicstvi: return "Ranhojičství"
        case .straznaVez: return "Strážní věž"
        }
    }
    public var icon: String {
        switch self {
        case .farma: return "leaf"
        case .sypka: return "shippingbox"
        case .palisada: return "shield"
        case .trziste: return "cart"
        case .kaple: return "sparkle"
        case .kasarna: return "person.3"
        case .ranhojicstvi: return "cross.case"
        case .straznaVez: return "binoculars"
        }
    }
    public var effect: String {
        switch self {
        case .farma: return "+15 jídla denně"
        case .sypka: return "+150 kapacita zásob"
        case .palisada: return "+15 obrana"
        case .trziste: return "+15 zlata denně"
        case .kaple: return "+10 morálka, rychlejší úleva od stresu"
        case .kasarna: return "+10 obrana, hrozby slábnou"
        case .ranhojicstvi: return "léčení hrdiny, odolnost vůči nemocem"
        case .straznaVez: return "hrozby hlášeny dřív (+6 h na reakci)"
        }
    }
    public var goldCost: Int {
        switch self {
        case .farma: return 40
        case .sypka: return 50
        case .palisada: return 60
        case .trziste: return 80
        case .kaple: return 70
        case .kasarna: return 90
        case .ranhojicstvi: return 75
        case .straznaVez: return 55
        }
    }
    public var workers: Int {
        switch self {
        case .farma: return 4
        case .sypka, .straznaVez: return 3
        case .palisada, .kasarna: return 6
        case .trziste, .kaple, .ranhojicstvi: return 4
        }
    }
    /// Doba stavby v reálných hodinách (Živý simulátor).
    public var buildHours: Double {
        switch self {
        case .farma: return 6
        case .sypka: return 8
        case .palisada: return 10
        case .trziste: return 12
        case .kaple: return 12
        case .kasarna: return 14
        case .ranhojicstvi: return 10
        case .straznaVez: return 8
        }
    }
}

public struct Construction: Codable, Equatable, Identifiable, Sendable {
    public var id: String = UUID().uuidString
    public var kind: BuildingKind
    public var finishAt: Date
    public init(kind: BuildingKind, finishAt: Date) { self.kind = kind; self.finishAt = finishAt }
}

public struct Settlement: Codable, Equatable, Sendable {
    public var name: String
    public var population: Int
    public var gold: Int
    /// Zásoby v jednotkách (zobrazují se v %)
    public var food: Int
    public var foodCapacity: Int
    public var defense: Int
    /// 0–100
    public var morale: Int
    public var buildings: [BuildingKind: Int]
    public var construction: [Construction]

    public var foodPercent: Int { foodCapacity > 0 ? Int((Double(food) / Double(foodCapacity) * 100).rounded()) : 0 }
    public func count(_ b: BuildingKind) -> Int { buildings[b] ?? 0 }
}

// MARK: - Cesta (B) a výprava (A)

public enum SceneKind: String, Codable, CaseIterable, Sendable {
    case forest, ruins, dungeon, town, road, river, mountain, swamp, battle, camp, castle
    public var czechName: String {
        switch self {
        case .forest: return "les"
        case .ruins: return "ruiny"
        case .dungeon: return "podzemí"
        case .town: return "osada"
        case .road: return "cesta"
        case .river: return "řeka"
        case .mountain: return "hory"
        case .swamp: return "bažina"
        case .battle: return "bitva"
        case .camp: return "tábor"
        case .castle: return "tvrz"
        }
    }
    public var icon: String {
        switch self {
        case .forest: return "tree"
        case .ruins: return "building.columns"
        case .dungeon: return "door.left.hand.closed"
        case .town: return "house.lodge"
        case .road: return "road.lanes"
        case .river: return "water.waves"
        case .mountain: return "mountain.2"
        case .swamp: return "aqi.medium"
        case .battle: return "flame"
        case .camp: return "tent"
        case .castle: return "building.2"
        }
    }
}

public struct Stop: Codable, Equatable, Sendable {
    public var name: String
    public var scene: SceneKind
}

public struct Journey: Codable, Equatable, Sendable {
    public var stops: [Stop]
    /// Index aktuální zastávky (0 = start)
    public var index: Int
    public var current: Stop { stops[min(index, stops.count - 1)] }
    public var isFinished: Bool { index >= stops.count - 1 }
}

public struct QuestInfo: Codable, Equatable, Sendable {
    public var objective: String
    /// Kolik zdařilých kroků je potřeba ke splnění cíle.
    public var steps: Int
    public var progress: Int = 0
    /// Nezdary – když dosáhnou maxima, cíl je ztracen.
    public var setbacks: Int = 0
    public var maxSetbacks: Int = 4
    /// Etapy cesty k cíli (jedna na každý zdařilý krok).
    public var stages: [String] = []

    public init(objective: String, steps: Int, stages: [String] = []) {
        self.objective = objective; self.steps = steps; self.stages = stages
    }

    /// Co hrdinu čeká teď.
    public var currentStage: String? {
        guard progress < steps, progress < stages.count else { return nil }
        return stages[progress]
    }
}

// MARK: - Hrozby (C)

public enum ThreatKind: String, Codable, CaseIterable, Sendable {
    case raid, bandits, beast, plague, storm
    public var czechName: String {
        switch self {
        case .raid: return "Nájezd"
        case .bandits: return "Lapkové"
        case .beast: return "Bestie"
        case .plague: return "Nákaza"
        case .storm: return "Bouře"
        }
    }
    public var icon: String {
        switch self {
        case .raid: return "flame"
        case .bandits: return "figure.fencing"
        case .beast: return "pawprint"
        case .plague: return "allergens"
        case .storm: return "cloud.bolt.rain"
        }
    }
}

public struct Threat: Codable, Equatable, Identifiable, Sendable {
    public var id: String = UUID().uuidString
    public var kind: ThreatKind
    public var title: String
    public var strength: Int
    public var deadline: Date
    public init(kind: ThreatKind, title: String, strength: Int, deadline: Date) {
        self.kind = kind; self.title = title; self.strength = strength; self.deadline = deadline
    }
}

// MARK: - Deník

public struct StatDelta: Codable, Equatable, Sendable {
    public var pop = 0, gold = 0, food = 0, defense = 0, morale = 0, hp = 0, stress = 0
    public init(pop: Int = 0, gold: Int = 0, food: Int = 0, defense: Int = 0, morale: Int = 0, hp: Int = 0, stress: Int = 0) {
        self.pop = pop; self.gold = gold; self.food = food; self.defense = defense; self.morale = morale; self.hp = hp; self.stress = stress
    }
    public var isZero: Bool { self == StatDelta() }

    public static func + (a: StatDelta, b: StatDelta) -> StatDelta {
        StatDelta(pop: a.pop + b.pop, gold: a.gold + b.gold, food: a.food + b.food, defense: a.defense + b.defense,
                  morale: a.morale + b.morale, hp: a.hp + b.hp, stress: a.stress + b.stress)
    }
}

public enum Outcome: String, Codable, Sendable {
    case critFail, fail, partial, success, critSuccess, auto, impossible

    public var czechName: String {
        switch self {
        case .critFail: return "Katastrofa"
        case .fail: return "Neúspěch"
        case .partial: return "Částečný úspěch"
        case .success: return "Úspěch"
        case .critSuccess: return "Skvělý úspěch"
        case .auto: return "Bez hodu"
        case .impossible: return "Nemožné"
        }
    }
    /// Pro vypravěče (instrukce v promptu)
    public var narrativeHint: String {
        switch self {
        case .critFail: return "KATASTROFA – akce se úplně zvrtne, s vážnými následky."
        case .fail: return "NEÚSPĚCH – akce se nepovede a má to cenu."
        case .partial: return "ČÁSTEČNÝ ÚSPĚCH – povede se jen zčásti nebo za cenu komplikace."
        case .success: return "ÚSPĚCH – akce se povede."
        case .critSuccess: return "SKVĚLÝ ÚSPĚCH – nečekaně dobrý výsledek, možná i bonus."
        case .auto: return "Běžná akce bez hodu – popiš, co se stane."
        case .impossible: return "NEMOŽNÉ – tohle v tomto světě nejde; popiš proč, bez odměny."
        }
    }
}

public struct RollInfo: Codable, Equatable, Sendable {
    public var die: Int
    public var modifier: Int
    public var dc: Int
    public var stat: Attribute?
    public var outcome: Outcome
    public var total: Int { die + modifier }
    public init(die: Int, modifier: Int, dc: Int, stat: Attribute?, outcome: Outcome) {
        self.die = die; self.modifier = modifier; self.dc = dc; self.stat = stat; self.outcome = outcome
    }
}

public struct LogEntry: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case narration, player, system, event }
    public var id: String = UUID().uuidString
    public var kind: Kind
    public var text: String
    public var date: Date = Date()
    public var roll: RollInfo?
    public var delta: StatDelta?
    public var itemsAdded: [String] = []
    public var itemsRemoved: [String] = []
    /// Kolik herního času čin zabral.
    public var hours: Double?
    /// Herní den, kdy čin začal (pro oddělovače dní v deníku).
    public var day: Int?
    /// Jak hráč tah zadal (čin, řeč, příběh, pokračuj).
    public var input: InputMode?

    public init(kind: Kind, text: String, date: Date = Date(), roll: RollInfo? = nil, delta: StatDelta? = nil,
                itemsAdded: [String] = [], itemsRemoved: [String] = [], hours: Double? = nil) {
        self.kind = kind; self.text = text; self.date = date; self.roll = roll; self.delta = delta
        self.itemsAdded = itemsAdded; self.itemsRemoved = itemsRemoved; self.hours = hours
    }
}

public enum GameEnd: String, Codable, Sendable {
    case death, victory, ruin, defeat, abandoned
    public var czechName: String {
        switch self {
        case .death: return "Smrt hrdiny"
        case .victory: return "Vítězství"
        case .ruin: return "Zánik osady"
        case .defeat: return "Porážka"
        case .abandoned: return "Konec výpravy"
        }
    }
}

// MARK: - Způsob zadání tahu (jako v AI Dungeon)

public enum InputMode: String, Codable, CaseIterable, Sendable {
    /// Čin: co hrdina udělá (posoudí se a případně hodí kostkou).
    case act
    /// Řeč: co hrdina řekne nahlas.
    case say
    /// Příběh: hráč sám napíše, co se v příběhu stane; vypravěč naváže (bez hodu a bez odměn).
    case story
    /// Pokračuj: vypravěč vypráví dál bez zásahu hráče.
    case proceed

    public var czechName: String {
        switch self {
        case .act: return "Čin"
        case .say: return "Řeč"
        case .story: return "Příběh"
        case .proceed: return "Pokračuj"
        }
    }
    public var icon: String {
        switch self {
        case .act: return "figure.walk"
        case .say: return "quote.bubble"
        case .story: return "book"
        case .proceed: return "forward"
        }
    }
    public var placeholder: String {
        switch self {
        case .act: return "Co uděláš?"
        case .say: return "Co řekneš?"
        case .story: return "Co se v příběhu stane?"
        case .proceed: return ""
        }
    }
}

// MARK: - Stav hry

public struct GameState: Codable, Equatable, Identifiable, Sendable {
    public var id: String = UUID().uuidString
    public var version = 1
    public var mode: GameMode
    public var hero: Hero
    public var settlement: Settlement
    public var journey: Journey?
    public var quest: QuestInfo?
    public var threats: [Threat] = []
    public var location: String
    public var scene: SceneKind
    public var turn = 0
    public var day = 1
    /// 0 ráno, 1 den, 2 večer, 3 noc
    public var phase = 0
    /// Herní čas osady: plyne s tahy (3 h za akci) i ve skutečnosti, když hráč nehraje.
    public var worldTime: Date = Date()
    /// Kdy hráč naposledy hrál (pro dohnání skutečného času).
    public var lastRealTime: Date = Date()
    /// Do kdy je simulace osady spočítaná (herní čas).
    public var lastTickAt: Date = Date()
    public var rngState: UInt64
    public var log: [LogEntry] = []
    public var chronicle: [String] = []
    public var achievements: [String] = []
    public var end: GameEnd?
    public var epilogue: String?
    public var createdAt = Date()
    public var updatedAt = Date()
    /// Počítadla pro úspěchy a pravidla
    public var stats: [String: Int] = [:]
    /// Počasí platí pro jeden herní den.
    public var weather: Weather = .jasno
    public var weatherDay = 0
    /// Postavy, které hrdina potkal (paměť vypravěče).
    public var characters: [NPC] = []
    /// Aktivní zakázka (vedlejší úkol) a nedávno zadané (aby se neopakovaly).
    public var contract: Contract?
    public var recentContracts: [String] = []
    /// Vlastní zápletka, kterou hráč zadal při založení hry.
    public var premise = ""
    /// „Paměť vypravěče“: co hráč chce, aby vypravěč nikdy nezapomněl.
    public var memory = ""
    /// „Poznámka k vyprávění“: přání ke stylu a náladě (nemění pravidla).
    public var authorsNote = ""

    public var season: Season { World.season(day: day) }

    public var isOver: Bool { end != nil }

    public var title: String {
        switch mode {
        case .quest: return quest?.objective ?? "Výprava"
        case .campaign: return "Karavana \(settlement.name)"
        case .realm, .endless: return settlement.name
        }
    }
}

public struct NewGameSetup: Sendable {
    public var mode: GameMode
    public var heroName: String
    public var cityName: String
    public var backgroundId: String
    public var feminine: Bool
    public var seed: UInt64
    public var premise: String
    /// Povaha (nejvýš 2 vlastnosti) a volné body do schopností.
    public var traits: [String]
    public var bonusPoints: [Attribute: Int]

    public init(mode: GameMode, heroName: String, cityName: String, backgroundId: String, feminine: Bool = false,
                seed: UInt64 = UInt64.random(in: 1...UInt64.max), premise: String = "",
                traits: [String] = [], bonusPoints: [Attribute: Int] = [:]) {
        self.traits = traits; self.bonusPoints = bonusPoints
        self.mode = mode; self.heroName = heroName; self.cityName = cityName; self.backgroundId = backgroundId
        self.feminine = feminine; self.seed = seed; self.premise = premise
    }
}
