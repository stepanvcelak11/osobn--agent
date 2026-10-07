import Foundation

// MARK: - Posouzení akce (výstup „interpreta“)

public enum ActionCategory: String, CaseIterable, Codable, Sendable {
    case combat, explore, stealth, social, craft, rest, travel, build, trade, magic, other

    public var czechName: String {
        switch self {
        case .combat: return "boj"
        case .explore: return "průzkum"
        case .stealth: return "plížení"
        case .social: return "jednání"
        case .craft: return "řemeslo"
        case .rest: return "odpočinek"
        case .travel: return "cesta"
        case .build: return "stavba"
        case .trade: return "obchod"
        case .magic: return "magie"
        case .other: return "jiné"
        }
    }
    var defaultStat: Attribute? {
        switch self {
        case .combat: return .sila
        case .explore, .craft, .magic: return .duvtip
        case .stealth, .travel: return .obratnost
        case .social, .trade: return .charisma
        case .rest, .build, .other: return nil
        }
    }
}

public enum Difficulty: String, CaseIterable, Codable, Sendable {
    case trivial, easy, normal, hard, extreme, impossible
    public var dc: Int {
        switch self {
        case .trivial: return 0
        case .easy: return 8
        case .normal: return 12
        case .hard: return 15
        case .extreme: return 19
        case .impossible: return 99
        }
    }
    public var czechName: String {
        switch self {
        case .trivial: return "snadné"
        case .easy: return "lehké"
        case .normal: return "běžné"
        case .hard: return "těžké"
        case .extreme: return "extrémní"
        case .impossible: return "nemožné"
        }
    }
}

public enum Risk: String, CaseIterable, Codable, Sendable {
    case none, low, medium, high
    var damage: ClosedRange<Int> {
        switch self {
        case .none: return 0...0
        case .low: return 4...8
        case .medium: return 8...15
        case .high: return 14...26
        }
    }
}

/// Jak dlouho čin trvá v herním světě.
public enum ActionDuration: String, CaseIterable, Codable, Sendable {
    case moment, hour, hours, day, days
    public var hours: Double {
        switch self {
        case .moment: return 0.25
        case .hour: return 1
        case .hours: return 4
        case .day: return 24
        case .days: return 72
        }
    }
}

public struct ActionIntent: Equatable, Sendable {
    public var summary: String
    public var category: ActionCategory
    public var stat: Attribute?
    public var difficulty: Difficulty
    public var risk: Risk
    public var itemsUsed: [String]
    public var build: BuildingKind?
    public var duration: ActionDuration?

    public init(summary: String, category: ActionCategory, stat: Attribute? = nil, difficulty: Difficulty = .normal,
                risk: Risk = .low, itemsUsed: [String] = [], build: BuildingKind? = nil, duration: ActionDuration? = nil) {
        self.summary = summary; self.category = category; self.stat = stat ?? category.defaultStat
        self.difficulty = difficulty; self.risk = risk; self.itemsUsed = itemsUsed; self.build = build; self.duration = duration
    }

    /// Z JSON výstupu modelu (tolerantní k chybějícím polím).
    public static func parse(_ v: JSONValue, fallbackText: String) -> ActionIntent {
        let cat = v["category"]?.stringValue.flatMap(ActionCategory.init(rawValue:)) ?? .other
        let statRaw = v["stat"]?.stringValue ?? "none"
        let stat = Attribute(rawValue: statRaw) ?? (statRaw == "none" ? nil : cat.defaultStat)
        let diff = v["difficulty"]?.stringValue.flatMap(Difficulty.init(rawValue:)) ?? .normal
        let risk = v["risk"]?.stringValue.flatMap(Risk.init(rawValue:)) ?? .low
        let items = (v["items_used"]?.arrayValue ?? []).compactMap { $0.stringValue }.filter { !$0.isEmpty }
        let build = v["build"]?.stringValue.flatMap(BuildingKind.init(rawValue:))
        let summary = v.nonEmptyString("intent") ?? String(fallbackText.prefix(80))
        let duration = v["duration"]?.stringValue.flatMap(ActionDuration.init(rawValue:))
        var i = ActionIntent(summary: summary, category: build != nil ? .build : cat, stat: stat, difficulty: diff,
                             risk: risk, itemsUsed: Array(items.prefix(3)), build: build, duration: duration)
        if statRaw == "none" && i.category != .build { i.stat = cat.defaultStat }
        return i
    }
}

// MARK: - Vyhodnocení (deterministické)

public struct BuildOrder: Equatable, Sendable {
    public var kind: BuildingKind
    public var started: Bool
    public var reason: String
}

public struct ArrivalEvent: Equatable, Sendable {
    public var stop: Stop
    public var text: String
    public var delta: StatDelta
    public var isDestination: Bool
}

public struct Resolution: Equatable, Sendable {
    public var intent: ActionIntent
    public var roll: RollInfo
    public var usedItems: [Item]
    public var missingItems: [String]
    /// Povinné následky spočítané pravidly (vypravěč je musí popsat).
    public var mandatory: StatDelta
    /// Poznámky pro vypravěče (zbroj, lektvar, stavba…)
    public var notes: [String]
    public var build: BuildOrder?
    public var arrival: ArrivalEvent?
    /// Rychlá výprava: o kolik se tah přiblížil k cíli a zda ho dokončí.
    public var questGain = 0
    public var completesQuest = false
    /// Nezdar na výpravě a zda tím je cíl ztracen.
    public var questSetback = 0
    public var losesQuest = false
    /// Herní hodiny, které čin zabere.
    public var hours: Double = 1
    /// Stavy, které tah přidá nebo vyléčí.
    public var newConditions: [ConditionKind] = []
    public var cures: [ConditionKind] = []
    /// Tah může splnit aktivní zakázku (pokud to vypravěč potvrdí).
    public var contractEligible = false
    /// Jak hráč tah zadal.
    public var input: InputMode = .act
    /// Použité schopnosti (id).
    public var usedAbilities: [String] = []
}

public enum Rules {
    public static let maxItems = 12

    /// Kolik herních hodin čin zabere. Odhad vypravěče, s rozumnými mezemi podle druhu činu.
    public static func hours(for intent: ActionIntent, mode: GameMode) -> Double {
        var h = intent.duration?.hours ?? (intent.difficulty == .trivial ? 0.25 : 1)
        switch intent.category {
        case .rest: h = max(h, 6)
        case .travel: h = max(h, 12)
        case .build: h = max(h, 1)
        default: break
        }
        if mode == .quest { h = min(h, 24) }
        return min(h, 24 * 7)
    }

    static let questCategories: Set<ActionCategory> = [.combat, .explore, .stealth, .social, .magic, .craft]

    /// Modifikátor hodu: atribut + předmět + stav hrdiny + noc.
    static func modifier(state: GameState, intent: ActionIntent, used: [Item], notes: inout [String]) -> Int {
        var mod = intent.stat.map { state.hero.score($0) } ?? 0
        var itemBonus = 0
        for item in used {
            switch item.kind {
            case .weapon where intent.category == .combat: itemBonus += 2
            case .tool where [.craft, .explore, .stealth, .build].contains(intent.category): itemBonus += 2
            case .key where [.social, .explore, .stealth].contains(intent.category): itemBonus += 3
            case .artifact: itemBonus += 2
            case .treasure where [.trade, .social].contains(intent.category): itemBonus += 2
            case .consumable where !item.heals: itemBonus += 1
            default: break
            }
        }
        if itemBonus > 0 { notes.append("Předmět pomáhá (+\(min(itemBonus, 3)) k hodu).") }
        mod += min(itemBonus, 3)
        let s = state.hero.stress
        if !state.hero.has("zelezna_vule") {
            if s >= 90 { mod -= 3 } else if s >= 70 { mod -= 2 } else if s >= 50 { mod -= 1 }
        }
        if intent.category == .social && state.hero.has("vudce") { mod += 1 }
        let w = state.weather.modifier(intent.category)
        if w != 0 { notes.append("Počasí (\(state.weather.czechName.lowercased())): \(w > 0 ? "+" : "")\(w) k hodu.") }
        mod += w
        for c in World.conditions(state.hero, at: state.worldTime) { mod += c.rollModifier }
        let hp = state.hero.hp
        if hp < 25 { mod -= 2 } else if hp < 50 { mod -= 1 }
        if state.phase == 3 {
            if state.hero.has("nocni") { mod += 1 } else {
                if intent.category == .stealth { mod += 1 }
                if [.combat, .explore, .travel].contains(intent.category) { mod -= 1 }
            }
        }
        return mod
    }

    static func outcome(die: Int, total: Int, dc: Int) -> Outcome {
        if die == 20 { return .critSuccess }
        if die == 1 { return .critFail }
        if total >= dc + 10 { return .critSuccess }
        if total >= dc { return .success }
        if total >= dc - 3 { return .partial }
        return .fail
    }

    static func hasArmor(_ hero: Hero) -> Bool { hero.items.contains { $0.kind == .armor } }

    static func isDrink(_ item: Item) -> Bool {
        let f = CzechText.fold(item.name)
        return item.kind == .consumable && ["koral", "vin", "pivo", "medovin", "slivovic", "ral"].contains { f.contains($0) }
    }

    /// Hlavní krok: hod kostkou a povinné následky. Posouvá RNG ve stavu.
    public static func resolve(state: inout GameState, intent: ActionIntent, now: Date = Date()) -> Resolution {
        var notes: [String] = []
        var used: [Item] = []
        var missing: [String] = []
        var abilities: [Ability] = []
        var spent: [String] = []
        for name in intent.itemsUsed {
            if let ab = state.hero.ability(named: name) {
                if abilities.contains(where: { $0.id == ab.id }) || spent.contains(ab.name) { continue }
                if ab.usesLeft > 0 { abilities.append(ab) } else { spent.append(ab.name) }
            } else if let it = state.hero.item(named: name) {
                if !used.contains(where: { $0.id == it.id }) { used.append(it) }
            } else { missing.append(name) }
        }
        if !spent.isEmpty {
            notes.append("Schopnost \(spent.joined(separator: ", ")) je pro dnešek vyčerpaná – hrdinovi tentokrát nepomůže. Obnoví se po spánku.")
        }
        if !missing.isEmpty {
            notes.append("Hrdina NEMÁ: \(missing.joined(separator: ", ")). Tyto věci nesmí ve vyprávění použít.")
        }

        var intent = intent
        var mandatory = StatDelta()
        var res = Resolution(intent: intent, roll: RollInfo(die: 0, modifier: 0, dc: 0, stat: intent.stat, outcome: .auto),
                             usedItems: used, missingItems: missing, mandatory: mandatory, notes: [])

        // Spotřební předměty
        for it in used where it.kind == .consumable {
            if it.heals {
                let heal = state.random(15...25)
                mandatory.hp += heal
                notes.append("\(it.name): hrdina se ošetří (+\(heal) zdraví).")
            } else if isDrink(it) {
                mandatory.stress -= 15
                notes.append("\(it.name): nervy povolí (−15 stresu).")
            }
        }

        // Zvláštní schopnosti
        for ab in abilities {
            if ab.heal > 0 { mandatory.hp += ab.heal }
            if ab.stressRelief > 0 { mandatory.stress -= ab.stressRelief }
            if ab.cures { res.cures += [.krvaceni, .horecka] }
            notes.append("Hrdina použije svou schopnost „\(ab.name)“ (\(ab.detail)) – popiš to.")
        }
        res.usedAbilities = abilities.map(\.id)

        // Stavy hrdiny
        let active = World.conditions(state.hero, at: state.worldTime)
        let healed = used.contains { $0.kind == .consumable && $0.heals } || abilities.contains { $0.cures }
        if healed { res.cures += [.krvaceni, .horecka] }
        if active.contains(.krvaceni) && !healed {
            mandatory.hp -= 2
            notes.append("Hrdina krvácí z otevřené rány (zdraví −2), dokud ji neošetří.")
        }
        if active.contains(.horecka) && !healed {
            mandatory.hp -= 1
            notes.append("Hrdinu trápí horečka – třes, pot, mžitky před očima.")
        }
        if active.contains(.vycerpani) && intent.category != .rest {
            mandatory.stress += 3
            notes.append("Hrdina je k smrti vyčerpaný – oči se mu klíží, ruce se třesou. Potřebuje spánek.")
        } else if active.contains(.unava) && intent.category != .rest {
            notes.append("Hrdina je unavený – dlouho nespal.")
        }

        // Stavba (Živý simulátor)
        if state.mode.hasSettlement, let kind = intent.build {
            intent.category = .build
            let busy = state.settlement.construction.reduce(0) { $0 + $1.kind.workers }
            if state.settlement.construction.count >= 2 {
                res.build = BuildOrder(kind: kind, started: false, reason: "Už se staví dvě stavby, nejsou volné ruce.")
            } else if state.settlement.gold < kind.goldCost {
                res.build = BuildOrder(kind: kind, started: false, reason: "Chybí zlato (potřeba \(kind.goldCost), v pokladně \(state.settlement.gold)).")
            } else if state.settlement.population - busy < kind.workers + 5 {
                res.build = BuildOrder(kind: kind, started: false, reason: "Nedostatek volných dělníků (potřeba \(kind.workers)).")
            } else {
                mandatory.gold -= kind.goldCost
                let hours = kind.buildHours
                res.build = BuildOrder(kind: kind, started: true,
                                       reason: "Stavba zahájena, hotovo za \(Int(hours)) h. Pracuje na ní \(kind.workers) lidí.")
            }
            notes.append("Stavba – \(kind.czechName): \(res.build!.reason)")
        }

        // Hod
        let roll: RollInfo
        if intent.difficulty == .impossible {
            roll = RollInfo(die: 0, modifier: 0, dc: 0, stat: intent.stat, outcome: .impossible)
        } else if intent.difficulty == .trivial || intent.category == .build || (intent.category == .rest && intent.risk == .none) {
            roll = RollInfo(die: 0, modifier: 0, dc: 0, stat: intent.stat, outcome: .auto)
        } else {
            var mod = modifier(state: state, intent: intent, used: used, notes: &notes)
            for ab in abilities where ab.bonus > 0 && ab.helps(intent.category) { mod += ab.bonus }
            var dc = intent.difficulty.dc
            if !missing.isEmpty { dc += 2 }
            var die = state.d20()
            if die == 1 && state.hero.has("stastlivec") {
                die = state.d20()
                notes.append("Šťastlivec: osud dal hrdinovi druhou šanci.")
            }
            roll = RollInfo(die: die, modifier: mod, dc: dc, stat: intent.stat, outcome: outcome(die: die, total: die + mod, dc: dc))
        }

        // Povinné následky
        var damage = 0
        let dmgRange = intent.risk.damage
        switch roll.outcome {
        case .critFail:
            damage = Int(Double(state.random(dmgRange)) * 1.5)
            mandatory.stress += state.random(8...12)
        case .fail:
            damage = state.random(dmgRange)
            mandatory.stress += state.random(4...8)
        case .partial:
            damage = state.random(dmgRange) / 2
            mandatory.stress += state.random(2...4)
        case .critSuccess:
            mandatory.stress -= 5
        default: break
        }
        if damage > 0 && state.hero.has("otuzily") { damage = damage * 4 / 5 }
        if state.hero.has("odvazny") && mandatory.stress > 0 { mandatory.stress = (mandatory.stress + 1) / 2 }
        if damage > 0 && hasArmor(state.hero) {
            let absorbed = max(1, damage * 3 / 10)
            damage -= absorbed
            notes.append("Zbroj pohltila část zásahu.")
        }
        mandatory.hp -= damage
        // Nové stavy podle výsledku
        if damage > 0 && (roll.outcome == .critFail && intent.risk != .low || roll.outcome == .fail && intent.risk == .high && state.chance(50)) {
            res.newConditions.append(.krvaceni)
            notes.append("Hrdina utrží krvácející ránu – dokud ji neošetří, bude slábnout.")
        }
        if [.fail, .critFail].contains(roll.outcome) && state.scene == .swamp && !state.hero.has("otuzily") && state.chance(35) {
            res.newConditions.append(.horecka)
            notes.append("Z bažiny si hrdina odnáší horečku.")
        }
        if roll.outcome == .critSuccess {
            res.newConditions.append(.odhodlani)
        }
        if intent.category == .craft && [.success, .critSuccess].contains(roll.outcome) && active.contains(.krvaceni) {
            res.cures.append(.krvaceni)
        }
        if intent.category == .combat && roll.outcome != .impossible {
            mandatory.stress += state.hero.has("odvazny") ? 1 : 3
        }
        if intent.category == .rest {
            res.cures.append(.krvaceni)
            switch state.mode {
            case .quest: mandatory.hp += 5; mandatory.stress -= 8
            case .campaign: mandatory.hp += 8; mandatory.stress -= 10; mandatory.food -= max(1, state.settlement.population / 8)
            case .realm, .endless: mandatory.hp += 10; mandatory.stress -= 12
            }
        }

        // Čas činu (bouřka a sníh cestu zdrží)
        var hours = hours(for: intent, mode: state.mode)
        if intent.category == .travel && [.bourka, .snih].contains(state.weather) {
            hours *= 1.5
            notes.append("\(state.weather.czechName) cestu zdržuje.")
        }

        // Cesta světem: přesun a spotřeba podle uplynulého času
        if state.mode == .campaign {
            if intent.category == .travel, let journey = state.journey, !journey.isFinished {
                switch roll.outcome {
                case .fail, .critFail:
                    hours = max(hours / 2, 8)
                    notes.append("Karavana zabloudila a ztratila čas – zásoby ubývají.")
                case .impossible: break
                default:
                    let arrival = rollArrival(state: &state, to: journey.stops[journey.index + 1],
                                              isDestination: journey.index + 1 == journey.stops.count - 1)
                    mandatory = mandatory + arrival.delta
                    if state.hero.has("vudce") { mandatory.morale += 3 }
                    res.arrival = arrival
                    notes.append("Karavana dorazí do: \(arrival.stop.name) (\(arrival.stop.scene.czechName)). \(arrival.text)")
                }
            }
            // Karavana sní za den zhruba 0,4 jídla na člověka
            mandatory.food -= Int((Double(state.settlement.population) * 0.4 * state.weather.foodFactor * hours / 24).rounded())
        }
        res.hours = hours

        // Hlad v karavaně
        if state.mode == .campaign && state.settlement.food + mandatory.food <= 0 {
            mandatory.pop -= max(1, state.settlement.population / 12)
            mandatory.morale -= 8
            mandatory.stress += 6
            notes.append("HLAD: zásoby došly, lidé umírají a utíkají. Popiš zoufalství karavany.")
        }

        // Rychlá výprava: postup k cíli
        if state.mode == .quest, let q = state.quest, questCategories.contains(intent.category) {
            switch roll.outcome {
            case .critSuccess: res.questGain = 2
            case .success: res.questGain = 1
            default: break
            }
            res.completesQuest = res.questGain > 0 && q.progress + res.questGain >= q.steps
            switch roll.outcome {
            case .critFail: res.questSetback = 2
            case .fail: res.questSetback = 1
            default: break
            }
            res.losesQuest = res.questSetback > 0 && q.setbacks + res.questSetback >= q.maxSetbacks
        }

        // Zakázka
        if let c = state.contract, [.success, .critSuccess].contains(roll.outcome), c.categories.contains(intent.category) {
            res.contractEligible = true
        }

        res.intent = intent
        res.roll = roll
        res.mandatory = mandatory
        res.notes = notes
        return res
    }

    static func rollArrival(state: inout GameState, to stop: Stop, isDestination: Bool) -> ArrivalEvent {
        if isDestination {
            return ArrivalEvent(stop: stop, text: "Konečně cíl cesty – nový domov na dohled.",
                                delta: StatDelta(morale: 15, stress: -15), isDestination: true)
        }
        let index = state.journey?.index ?? 0
        let r = state.random(1...100)
        switch r {
        case 1...30:
            let strength = 8 + index * 3 + state.random(1...6)
            let power = state.settlement.defense / 2 + state.d20() + state.hero.score(.sila)
            if power >= strength {
                return ArrivalEvent(stop: stop, text: "Na místě čeká přepadení lapků, ale stráže je odrazí.",
                                    delta: StatDelta(morale: 5, stress: 5), isDestination: false)
            }
            let lost = state.random(1...3)
            return ArrivalEvent(stop: stop, text: "Přepadení! Lapkové udeří ze zálohy, \(lost) lidí padne a část nákladu je pryč.",
                                delta: StatDelta(pop: -lost, gold: -10, food: -10, defense: -2, morale: -8, stress: 10),
                                isDestination: false)
        case 31...45:
            let f = state.random(20...35)
            return ArrivalEvent(stop: stop, text: "Najdou opuštěné zásoby.", delta: StatDelta(food: f), isDestination: false)
        case 46...60:
            let p = state.random(2...4)
            return ArrivalEvent(stop: stop, text: "Připojí se \(p) uprchlíků – další ruce, ale i hladové krky.",
                                delta: StatDelta(pop: p, morale: -2), isDestination: false)
        case 61...70:
            return ArrivalEvent(stop: stop, text: "Mezi lidmi propukne horečka.",
                                delta: StatDelta(pop: -1, morale: -5, stress: 3), isDestination: false)
        default:
            let calm = stop.scene == .town ? "Je tu trh – dá se obchodovat a doplnit zásoby." : "Na místě je zatím klid."
            return ArrivalEvent(stop: stop, text: calm, delta: StatDelta(), isDestination: false)
        }
    }

    // MARK: Meze pro změny navržené vypravěčem

    struct Span { var lo: Int; var hi: Int }

    /// Kolik smí vypravěč přidat/ubrat navíc k povinným následkům, podle výsledku hodu.
    static func spans(for outcome: Outcome) -> (hp: Span, stress: Span, gold: Span, food: Span, pop: Span, defense: Span, morale: Span) {
        switch outcome {
        case .critFail: return (Span(lo: -10, hi: 0), Span(lo: 0, hi: 10), Span(lo: -40, hi: 0), Span(lo: -30, hi: 0),
                                Span(lo: -4, hi: 0), Span(lo: -8, hi: 0), Span(lo: -15, hi: 0))
        case .fail: return (Span(lo: -6, hi: 0), Span(lo: 0, hi: 6), Span(lo: -25, hi: 0), Span(lo: -20, hi: 0),
                            Span(lo: -2, hi: 0), Span(lo: -4, hi: 0), Span(lo: -8, hi: 0))
        case .partial: return (Span(lo: -4, hi: 3), Span(lo: -3, hi: 5), Span(lo: -15, hi: 20), Span(lo: -10, hi: 15),
                               Span(lo: -1, hi: 2), Span(lo: -2, hi: 3), Span(lo: -4, hi: 5))
        case .success: return (Span(lo: -2, hi: 8), Span(lo: -8, hi: 3), Span(lo: -10, hi: 40), Span(lo: -5, hi: 30),
                               Span(lo: 0, hi: 4), Span(lo: 0, hi: 6), Span(lo: 0, hi: 10))
        case .critSuccess: return (Span(lo: 0, hi: 15), Span(lo: -15, hi: 0), Span(lo: 0, hi: 80), Span(lo: 0, hi: 50),
                                   Span(lo: 0, hi: 6), Span(lo: 0, hi: 10), Span(lo: 0, hi: 15))
        case .auto: return (Span(lo: -3, hi: 5), Span(lo: -8, hi: 4), Span(lo: -80, hi: 15), Span(lo: -30, hi: 20),
                            Span(lo: -1, hi: 3), Span(lo: 0, hi: 3), Span(lo: -5, hi: 6))
        case .impossible: return (Span(lo: 0, hi: 0), Span(lo: 0, hi: 3), Span(lo: 0, hi: 0), Span(lo: 0, hi: 0),
                                  Span(lo: 0, hi: 0), Span(lo: 0, hi: 0), Span(lo: 0, hi: 0))
        }
    }

    static func clampExtra(_ proposed: Int, mandatory: Int, span: Span) -> Int {
        // Vypravěč posílá celkovou změnu; povinný základ je vždy zachován, navíc jen v mezích.
        let extra = proposed - mandatory
        return mandatory + min(max(extra, span.lo), span.hi)
    }

    /// Výsledná změna statistik = povinné následky + omezený návrh vypravěče.
    public static func finalDelta(mode: GameMode, outcome: Outcome, mandatory: StatDelta, proposed: StatDelta,
                                  settlement: Settlement) -> StatDelta {
        let s = spans(for: outcome)
        var d = StatDelta()
        d.hp = clampExtra(proposed.hp, mandatory: mandatory.hp, span: s.hp)
        d.stress = clampExtra(proposed.stress, mandatory: mandatory.stress, span: s.stress)
        d.gold = clampExtra(proposed.gold, mandatory: mandatory.gold, span: s.gold)
        if mode == .quest {
            d.food = 0; d.pop = 0; d.defense = 0; d.morale = 0
            d.gold = min(d.gold, mandatory.gold + 30)
        } else {
            d.food = clampExtra(proposed.food, mandatory: mandatory.food, span: s.food)
            d.pop = clampExtra(proposed.pop, mandatory: mandatory.pop, span: s.pop)
            d.defense = clampExtra(proposed.defense, mandatory: mandatory.defense, span: s.defense)
            d.morale = clampExtra(proposed.morale, mandatory: mandatory.morale, span: s.morale)
        }
        // Nelze utratit víc, než je v pokladně.
        if settlement.gold + d.gold < 0 { d.gold = -settlement.gold }
        if settlement.food + d.food < 0 { d.food = -settlement.food }
        return d
    }

    /// Kolik nových předmětů smí vypravěč dát podle výsledku.
    public static func allowedNewItems(_ outcome: Outcome) -> Int {
        switch outcome {
        case .critSuccess: return 2
        case .success, .partial, .auto: return 1
        case .fail, .critFail, .impossible: return 0
        }
    }

    /// Očištění jména předmětu od modelu.
    public static func cleanItemName(_ raw: String) -> String? {
        var s = PromptSanitizer.clean(raw)
        s = s.replacingOccurrences(of: "\n", with: " ")
        s = CzechText.collapseSpaces(s).trimmingCharacters(in: CharacterSet(charactersIn: " .,;:!\"'"))
        guard s.count >= 2 else { return nil }
        if s.count > 40 { s = String(s.prefix(40)).trimmingCharacters(in: .whitespaces) }
        return CzechText.capitalizeFirst(s)
    }
}
