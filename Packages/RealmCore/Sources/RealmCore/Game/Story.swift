import Foundation

// MARK: - Módy

/// Čtyři druhy příběhu. Všechny mají cíl rozdělený do úkolů; všechny jdou prohrát.
public enum GameMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case quest, campaign, realm, endless
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .quest: return "Rychlá výprava"
        case .campaign: return "Cesta světem"
        case .realm: return "Vláda nad osadou"
        case .endless: return "Nekonečná říše"
        }
    }

    public var icon: String {
        switch self {
        case .quest: return "flag.fill"
        case .campaign: return "map.fill"
        case .realm: return "house.lodge.fill"
        case .endless: return "crown.fill"
        }
    }

    public var tagline: String {
        switch self {
        case .quest: return "Jeden cíl, tři úkoly. Na jedno odpoledne."
        case .campaign: return "Doveď karavanu přeživších přes divočinu do bezpečí."
        case .realm: return "Ujmi se osady na okraji divočiny a udělej z ní město."
        case .endless: return "Vládni a rozšiřuj říši, dokud tě štěstí neopustí."
        }
    }

    public var length: String {
        switch self {
        case .quest: return "krátká"
        case .campaign: return "střední"
        case .realm: return "dlouhá"
        case .endless: return "bez konce"
        }
    }

    /// Kolik nezdarů příběh snese, než skončí prohrou.
    public var maxSetbacks: Int {
        switch self {
        case .quest: return 3
        case .campaign, .realm: return 4
        case .endless: return 3
        }
    }

    /// Mód potřebuje jméno osady / města.
    public var needsPlaceName: Bool { self != .quest }
}

// MARK: - Způsob tahu (jako v AI Dungeon)

public enum InputMode: String, Codable, CaseIterable, Sendable {
    case act, say, story, proceed

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
        case .say: return "quote.bubble.fill"
        case .story: return "book.fill"
        case .proceed: return "forward.fill"
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
        case .obratnost: return "hare.fill"
        case .duvtip: return "brain.head.profile"
        case .charisma: return "person.wave.2.fill"
        }
    }

    /// K čemu se vlastnost hodí (pro nápovědu).
    public var usage: String {
        switch self {
        case .sila: return "boj zblízka, vyrážení dveří, zvedání"
        case .obratnost: return "plížení, šplhání, střelba, kapsářství"
        case .duvtip: return "kouzla, stopování, luštění, léčení"
        case .charisma: return "přesvědčování, smlouvání, lhaní, zastrašení"
        }
    }
}

public struct Hero: Codable, Equatable, Sendable {
    public var name: String
    public var classId: String
    public var feminine: Bool

    public init(name: String, classId: String, feminine: Bool) {
        self.name = name; self.classId = classId; self.feminine = feminine
    }

    public var heroClass: HeroClass { HeroClass.byId(classId) }
    public var className: String { heroClass.name(feminine: feminine) }
    public func score(_ a: Attribute) -> Int { heroClass.scores[a] ?? 0 }
}

// MARK: - Kostky

public enum Outcome: String, Codable, Sendable {
    case critSuccess, success, partial, fail, critFail

    public var czechName: String {
        switch self {
        case .critSuccess: return "Skvělý úspěch"
        case .success: return "Úspěch"
        case .partial: return "Napůl"
        case .fail: return "Nezdar"
        case .critFail: return "Těžký nezdar"
        }
    }

    public var isSuccess: Bool { self == .critSuccess || self == .success || self == .partial }

    /// Kolik nezdarů pokus přidá.
    public var setbacks: Int {
        switch self {
        case .fail: return 1
        case .critFail: return 2
        default: return 0
        }
    }
}

public struct Roll: Codable, Equatable, Sendable {
    public var attribute: Attribute
    public var die: Int
    public var bonus: Int
    public var target: Int
    public var outcome: Outcome
    public var total: Int { die + bonus }
}

// MARK: - Deník

public enum EntryKind: String, Codable, Sendable { case player, narration, event }

public struct Entry: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var kind: EntryKind
    public var text: String
    public var input: InputMode?
    public var roll: Roll?
    /// Přesná zpráva, kterou dostal model (u vyprávění) – historie se pak skládá stejně a model nemusí přepočítávat.
    public var prompt: String?
    /// Surový výstup modelu (u vyprávění), ze stejného důvodu.
    public var raw: String?

    public init(kind: EntryKind, text: String, input: InputMode? = nil, roll: Roll? = nil, prompt: String? = nil, raw: String? = nil) {
        self.id = UUID().uuidString
        self.kind = kind; self.text = text; self.input = input; self.roll = roll; self.prompt = prompt; self.raw = raw
    }
}

public enum Ending: String, Codable, Sendable {
    case victory, defeat, abandoned

    public var czechName: String {
        switch self {
        case .victory: return "Vítězství"
        case .defeat: return "Prohra"
        case .abandoned: return "Příběh uzavřen"
        }
    }
}

// MARK: - Příběh

public struct Story: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var version = 3
    public var createdAt: Date
    public var updatedAt: Date
    public var mode: GameMode
    public var hero: Hero
    /// Osada (vláda, říše) nebo padlé město (cesta světem).
    public var place: String
    /// Vlastní téma od hráče (prázdné = náhodný příběh).
    public var premise: String
    public var title: String
    public var goal: String
    /// Jak hrdina k příběhu přijde (pro klidný úvod).
    public var opening: String
    public var stages: [String]
    public var stage: Int = 0
    public var setbacks: Int = 0
    public var turnsInStage: Int = 0
    public var turns: Int = 0
    public var log: [Entry] = []
    /// Paměť (AI Dungeon „Memory“): co si má vypravěč vždy pamatovat.
    public var memory: String = ""
    /// Poznámka ke stylu (AI Dungeon „Author's note“).
    public var note: String = ""
    public var end: Ending?
    public var epilogue: String?
    public var rng: UInt64

    public init(id: String = UUID().uuidString, now: Date = Date(), mode: GameMode, hero: Hero, place: String, premise: String,
                title: String, goal: String, opening: String, stages: [String], rng: UInt64) {
        self.id = id; self.createdAt = Story.whole(now); self.updatedAt = Story.whole(now)
        self.mode = mode; self.hero = hero; self.place = place; self.premise = premise
        self.title = title; self.goal = goal; self.opening = opening; self.stages = stages; self.rng = rng
    }

    /// Čas na celé sekundy – po uložení a načtení vyjde přesně stejný.
    public static func whole(_ d: Date) -> Date { Date(timeIntervalSince1970: d.timeIntervalSince1970.rounded()) }

    public var isOver: Bool { end != nil }
    public var maxSetbacks: Int { mode.maxSetbacks }
    public var currentStage: String? { stage < stages.count ? stages[stage] : nil }
    /// Splněné úkoly (u nekonečné říše roste donekonečna).
    public var completedStages: Int { min(stage, stages.count) }
    public var needsIntro: Bool { !log.contains { $0.kind == .narration } }

    public mutating func random(_ range: ClosedRange<Int>) -> Int {
        var g = SplitMix64(seed: rng)
        let v = Int.random(in: range, using: &g)
        rng = g.state
        return v
    }

    public mutating func pick<T>(_ items: [T]) -> T { items[random(0...(items.count - 1))] }
}

/// Řádek v seznamu her.
public struct SaveSummary: Identifiable, Equatable, Sendable {
    public var id: String
    public var mode: GameMode
    public var title: String
    public var heroName: String
    public var classId: String
    public var feminine: Bool
    public var turns: Int
    public var stage: Int
    public var stageCount: Int
    public var updatedAt: Date
    public var end: Ending?

    public init(_ s: Story) {
        id = s.id; mode = s.mode; title = s.title; heroName = s.hero.name; classId = s.hero.classId; feminine = s.hero.feminine
        turns = s.turns; stage = s.completedStages; stageCount = s.mode == .endless ? 0 : s.stages.count
        updatedAt = s.updatedAt; end = s.end
    }
}
