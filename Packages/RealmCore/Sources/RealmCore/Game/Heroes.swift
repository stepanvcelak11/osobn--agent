import Foundation

/// Pět základních postav. Každá má jinou výbavu (vypravěč ji zná) a jiné silné a slabé stránky.
public struct HeroClass: Identifiable, Equatable, Sendable {
    public let id: String
    public let male: String
    public let female: String
    public let icon: String
    public let summary: String
    /// Výbava – jen tohle hrdina na začátku má.
    public let gear: String
    /// Vlastnosti od −1 do +3. Do hodu se počítají dvojnásobně.
    public let scores: [Attribute: Int]
    public let names: (male: String, female: String)

    public static func == (a: HeroClass, b: HeroClass) -> Bool { a.id == b.id }

    public func name(feminine: Bool) -> String { feminine ? female : male }
    public func defaultName(feminine: Bool) -> String { feminine ? names.female : names.male }

    public var best: Attribute { Attribute.allCases.max { (scores[$0] ?? 0) < (scores[$1] ?? 0) } ?? .sila }
    public var worst: Attribute { Attribute.allCases.min { (scores[$0] ?? 0) < (scores[$1] ?? 0) } ?? .sila }

    public static let all: [HeroClass] = [
        HeroClass(id: "valecnik", male: "Válečník", female: "Válečnice", icon: "shield.lefthalf.filled",
                  summary: "Voják z povolání. Nejlépe vyřeší věci mečem.",
                  gear: "dlouhý meč, dřevěný štít a kroužková košile",
                  scores: [.sila: 3, .obratnost: 1, .duvtip: -1, .charisma: 0], names: ("Bořek", "Radka")),
        HeroClass(id: "zlodej", male: "Zloděj", female: "Zlodějka", icon: "eye.slash.fill",
                  summary: "Stín z městských uliček. Projde tam, kam jiní nemohou.",
                  gear: "dvě dýky, sada paklíčů a tmavý plášť s kápí",
                  scores: [.sila: -1, .obratnost: 3, .duvtip: 1, .charisma: 0], names: ("Vít", "Alena")),
        HeroClass(id: "carodej", male: "Čaroděj", female: "Čarodějka", icon: "sparkles",
                  summary: "Učenec tajných nauk. Kouzla mají vždycky svou cenu.",
                  gear: "dubová hůl, kniha kouzel a váček bylin",
                  scores: [.sila: -1, .obratnost: 0, .duvtip: 3, .charisma: 1], names: ("Kryštof", "Dobromila")),
        HeroClass(id: "bard", male: "Bard", female: "Bardka", icon: "music.note",
                  summary: "Potulný pěvec. Slovem otevře dveře i srdce.",
                  gear: "loutna, krátká dýka a pestrý cestovní plášť",
                  scores: [.sila: -1, .obratnost: 1, .duvtip: 0, .charisma: 3], names: ("Jiřík", "Libuše")),
        HeroClass(id: "lovec", male: "Lovec", female: "Lovkyně", icon: "scope",
                  summary: "Stopař z hlubokých lesů. Zná divočinu jako vlastní dlaň.",
                  gear: "dlouhý luk, toulec šípů a lovecký nůž",
                  scores: [.sila: 1, .obratnost: 2, .duvtip: 1, .charisma: -1], names: ("Ctibor", "Vlasta")),
    ]

    public static func byId(_ id: String) -> HeroClass { all.first { $0.id == id } ?? all[0] }

    /// Staré postavy z verze 2 (11 původů) → nejbližší z pěti.
    public static func fromLegacy(_ background: String) -> String {
        switch background {
        case "stinochod", "hrobnik": return "zlodej"
        case "bylinkar", "knez", "vedma": return "carodej"
        case "bard", "kupec": return "bard"
        case "lovec": return "lovec"
        default: return "valecnik"
        }
    }
}
