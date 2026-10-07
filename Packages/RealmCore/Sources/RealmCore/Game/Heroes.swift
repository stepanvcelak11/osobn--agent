import Foundation

// MARK: - Zvláštní schopnosti

/// Schopnost původu: použije se v textu tahu („použiju Bojový řev“), má omezený počet použití za den.
public struct Ability: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var detail: String
    public var icon: String
    /// Bonus k hodu (jen u uvedených druhů činu; prázdné = u všech).
    public var bonus: Int
    public var categories: [ActionCategory]
    public var heal: Int
    public var stressRelief: Int
    /// Vyléčí krvácení a horečku.
    public var cures: Bool
    public var maxUses: Int
    public var usesLeft: Int

    public init(id: String, name: String, detail: String, icon: String, bonus: Int = 0, categories: [ActionCategory] = [],
                heal: Int = 0, stressRelief: Int = 0, cures: Bool = false, maxUses: Int = 2) {
        self.id = id; self.name = name; self.detail = detail; self.icon = icon; self.bonus = bonus
        self.categories = categories; self.heal = heal; self.stressRelief = stressRelief; self.cures = cures
        self.maxUses = maxUses; self.usesLeft = maxUses
    }

    public func helps(_ c: ActionCategory) -> Bool { categories.isEmpty || categories.contains(c) }
}

// MARK: - Povaha (vlastnosti)

public struct Trait: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let icon: String
    /// +1 k této schopnosti při tvorbě postavy.
    public let attribute: Attribute?
}

public enum Traits {
    public static let maxPicked = 2
    public static let freePoints = 2
    /// Nejvyšší hodnota schopnosti při tvorbě postavy (bez povahy).
    public static let startCap = 4

    public static let all: [Trait] = [
        Trait(id: "silak", name: "Silák", detail: "+1 Síla.", icon: "figure.strengthtraining.traditional", attribute: .sila),
        Trait(id: "hbity", name: "Hbitý", detail: "+1 Obratnost.", icon: "hare.fill", attribute: .obratnost),
        Trait(id: "bystry", name: "Bystrý", detail: "+1 Důvtip.", icon: "lightbulb.fill", attribute: .duvtip),
        Trait(id: "vyrecny", name: "Výřečný", detail: "+1 Charisma.", icon: "bubble.left.and.bubble.right.fill", attribute: .charisma),
        Trait(id: "odvazny", name: "Odvážný", detail: "Boje a nezdary ti přidají jen polovinu stresu.", icon: "flame.fill", attribute: nil),
        Trait(id: "otuzily", name: "Otužilý", detail: "Zranění o pětinu slabší, horečka se tě nechytí.", icon: "snowflake", attribute: nil),
        Trait(id: "nocni", name: "Noční pták", detail: "V noci +1 ke všem hodům místo postihu.", icon: "moon.stars.fill", attribute: nil),
        Trait(id: "stastlivec", name: "Šťastlivec", detail: "Když padne 1, kostka se jednou přehodí.", icon: "suit.club.fill", attribute: nil),
        Trait(id: "hledac", name: "Hledač pokladů", detail: "Úspěšný průzkum přinese o jeden nález víc.", icon: "sparkle.magnifyingglass", attribute: nil),
        Trait(id: "vudce", name: "Rozený vůdce", detail: "+1 k jednání; lidé tě rádi následují (morálka roste).", icon: "flag.fill", attribute: nil),
        Trait(id: "nespavec", name: "Nespavec", detail: "Únava přijde až po 26 hodinách bez spánku, vyčerpání po 40.", icon: "eye.fill", attribute: nil),
        Trait(id: "zelezna_vule", name: "Železná vůle", detail: "Vysoký stres ti nezhoršuje hody.", icon: "brain.head.profile", attribute: nil),
    ]

    public static func byId(_ id: String) -> Trait? { all.first { $0.id == id } }
}

extension Hero {
    public func has(_ trait: String) -> Bool { traits.contains(trait) }

    /// Schopnost podle jména z textu modelu nebo hráče.
    public func ability(named name: String) -> Ability? {
        let n = CzechText.fold(name).trimmingCharacters(in: .whitespaces)
        guard n.count >= 3 else { return nil }
        return abilities.first { CzechText.fold($0.name) == n }
            ?? abilities.first { CzechText.similarity($0.name, name) >= 0.6 }
            ?? abilities.first { CzechText.fold($0.name).contains(n) || n.contains(CzechText.fold($0.name)) }
    }

    /// Spánek nebo nový den obnoví schopnosti.
    mutating func refreshAbilities() {
        for i in abilities.indices { abilities[i].usesLeft = abilities[i].maxUses }
    }
}

extension Catalog {
    /// Výsledné schopnosti postavy: původ + volné body (nejvýš do startCap) + povaha.
    public static func startAttributes(background bg: Background, bonus: [Attribute: Int], traits: [String]) -> [Attribute: Int] {
        var a = bg.attributes
        var left = Traits.freePoints
        for attr in Attribute.allCases {
            let want = max(0, bonus[attr] ?? 0)
            let can = min(want, left, max(0, Traits.startCap - (a[attr] ?? 0)))
            a[attr] = (a[attr] ?? 0) + can
            left -= can
        }
        for t in validTraits(traits) {
            if let attr = Traits.byId(t)?.attribute { a[attr] = min(World.maxAttribute, (a[attr] ?? 0) + 1) }
        }
        return a
    }

    public static func validTraits(_ ids: [String]) -> [String] {
        var out: [String] = []
        for id in ids where Traits.byId(id) != nil && !out.contains(id) { out.append(id) }
        return Array(out.prefix(Traits.maxPicked))
    }
}
