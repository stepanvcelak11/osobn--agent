import Foundation

/// Pojistka: stav hry musí vždy dávat smysl, ať se stane cokoli (chyba v pravidlech, divný výstup modelu,
/// poškozené uložení). `violations()` jen hlásí (pro testy), `repair()` opraví a vrátí, co opravil.
extension GameState {
    public static let maxLog = 500
    public static let maxChronicle = 60

    public func violations() -> [String] {
        var v: [String] = []
        let h = hero
        if !(0...100).contains(h.hp) { v.append("hp \(h.hp)") }
        if !(0...100).contains(h.stress) { v.append("stres \(h.stress)") }
        if h.level < 1 || h.xp < 0 { v.append("úroveň \(h.level)/\(h.xp)") }
        if !h.awakeHours.isFinite || h.awakeHours < 0 { v.append("bdění \(h.awakeHours)") }
        for (a, x) in h.attributes where !(-3...World.maxAttribute).contains(x) { v.append("\(a.rawValue) \(x)") }
        if h.items.count > Rules.maxItems { v.append("předmětů \(h.items.count)") }
        if Set(h.items.map(\.id)).count != h.items.count { v.append("duplicitní předměty") }
        if h.items.contains(where: { ($0.charges ?? 1) <= 0 || $0.name.isEmpty }) { v.append("prázdný předmět") }
        if h.abilities.contains(where: { !(0...$0.maxUses).contains($0.usesLeft) }) { v.append("použití schopnosti") }
        let st = settlement
        if st.population < 0 || st.gold < 0 || st.food < 0 || st.defense < 0 { v.append("záporné zásoby") }
        if st.food > max(st.foodCapacity, 0) && mode != .quest { v.append("jídlo nad kapacitou \(st.food)/\(st.foodCapacity)") }
        if !(0...100).contains(st.morale) { v.append("morálka \(st.morale)") }
        if st.buildings.values.contains(where: { $0 < 0 }) { v.append("záporné stavby") }
        if let j = journey, !(0..<max(1, j.stops.count)).contains(j.index) { v.append("cesta \(j.index)") }
        if let q = quest, !(0...q.steps).contains(q.progress) || !(0...q.maxSetbacks).contains(q.setbacks) { v.append("výprava") }
        if !(0...3).contains(phase) { v.append("fáze \(phase)") }
        if day < 1 || turn < 0 { v.append("den/tah") }
        if log.count > Self.maxLog { v.append("deník \(log.count)") }
        if chronicle.count > Self.maxChronicle { v.append("kronika \(chronicle.count)") }
        if characters.count > World.maxCharacters { v.append("postav \(characters.count)") }
        if end == nil && hero.hp <= 0 { v.append("mrtvý hrdina bez konce hry") }
        if end == nil && mode != .quest && settlement.population <= 0 { v.append("zaniklá osada bez konce hry") }
        return v
    }

    /// Opraví stav do platných mezí. Vrací popis oprav (prázdné = vše v pořádku).
    @discardableResult
    public mutating func repair() -> [String] {
        let found = violations()
        guard !found.isEmpty else { return [] }
        hero.hp = max(0, min(100, hero.hp))
        hero.stress = max(0, min(100, hero.stress))
        hero.level = max(1, hero.level)
        hero.xp = max(0, hero.xp)
        if !hero.awakeHours.isFinite || hero.awakeHours < 0 { hero.awakeHours = 0 }
        for (a, x) in hero.attributes { hero.attributes[a] = max(-3, min(World.maxAttribute, x)) }
        var seen = Set<String>()
        hero.items = hero.items.filter { ($0.charges ?? 1) > 0 && !$0.name.isEmpty && seen.insert($0.id).inserted }
        if hero.items.count > Rules.maxItems { hero.items = Array(hero.items.prefix(Rules.maxItems)) }
        for i in hero.abilities.indices {
            hero.abilities[i].usesLeft = max(0, min(hero.abilities[i].maxUses, hero.abilities[i].usesLeft))
        }
        settlement.population = max(0, settlement.population)
        settlement.gold = max(0, settlement.gold)
        settlement.defense = max(0, settlement.defense)
        settlement.foodCapacity = max(0, settlement.foodCapacity)
        settlement.food = max(0, mode == .quest ? settlement.food : min(settlement.foodCapacity, settlement.food))
        settlement.morale = max(0, min(100, settlement.morale))
        for (b, n) in settlement.buildings where n < 0 { settlement.buildings[b] = 0 }
        if var j = journey { j.index = max(0, min(j.stops.count - 1, j.index)); journey = j }
        if var q = quest {
            q.progress = max(0, min(q.steps, q.progress)); q.setbacks = max(0, min(q.maxSetbacks, q.setbacks)); quest = q
        }
        phase = max(0, min(3, phase))
        day = max(1, day)
        turn = max(0, turn)
        if log.count > Self.maxLog { log.removeFirst(log.count - Self.maxLog) }
        if chronicle.count > Self.maxChronicle { chronicle.removeFirst(chronicle.count - Self.maxChronicle) }
        if characters.count > World.maxCharacters { characters = Array(characters.suffix(World.maxCharacters)) }
        if end == nil && hero.hp <= 0 { end = .death }
        if end == nil && mode != .quest && settlement.population <= 0 { end = .ruin }
        return found
    }
}
