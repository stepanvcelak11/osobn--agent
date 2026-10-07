import Foundation

/// Pevný obsah hry: původy hrdinů, výpravy, zastávky na cestě, výchozí hodnoty.
public enum Catalog {

    // MARK: Původy hrdiny

    public struct Background: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let feminineName: String
        public let blurb: String
        public let attributes: [Attribute: Int]
        public let items: [Item]
        public let bonusGold: Int

        public func displayName(feminine: Bool) -> String { feminine ? feminineName : name }
    }

    public static let backgrounds: [Background] = [
        Background(id: "zoldner", name: "Žoldnéř", feminineName: "Žoldnéřka",
                   blurb: "Přežil(a) tři války. Silná paže, málo slov.",
                   attributes: [.sila: 3, .obratnost: 1, .duvtip: 0, .charisma: 0],
                   items: [Item(name: "Těžký meč", kind: .weapon),
                           Item(name: "Kroužková košile", kind: .armor),
                           Item(name: "Lahev kořalky", kind: .consumable, charges: 2)],
                   bonusGold: 0),
        Background(id: "stinochod", name: "Stínochod", feminineName: "Stínochodka",
                   blurb: "Zloděj(ka) ze slumů. Každý zámek je jen otázka času.",
                   attributes: [.sila: 0, .obratnost: 3, .duvtip: 1, .charisma: 0],
                   items: [Item(name: "Pár dýk", kind: .weapon),
                           Item(name: "Paklíče", kind: .tool),
                           Item(name: "Kouřová bomba", kind: .consumable, charges: 2)],
                   bonusGold: 10),
        Background(id: "bylinkar", name: "Bylinkář", feminineName: "Bylinkářka",
                   blurb: "Zná jedy i léky. Ví, co roste na hrobech.",
                   attributes: [.sila: 0, .obratnost: 0, .duvtip: 3, .charisma: 1],
                   items: [Item(name: "Jasanová hůl", kind: .weapon),
                           Item(name: "Brašna léčivých bylin", kind: .consumable, charges: 3),
                           Item(name: "Kniha receptur", kind: .tool)],
                   bonusGold: 0),
        Background(id: "kupec", name: "Kupec", feminineName: "Kupkyně",
                   blurb: "Měšec, úsměv a pečeť, která otevírá dveře.",
                   attributes: [.sila: 0, .obratnost: 0, .duvtip: 1, .charisma: 3],
                   items: [Item(name: "Krátký meč", kind: .weapon),
                           Item(name: "Pečetní prsten", kind: .key),
                           Item(name: "Hedvábí na prodej", kind: .treasure)],
                   bonusGold: 40),
        Background(id: "rytir", name: "Vyhnaný rytíř", feminineName: "Vyhnaná rytířka",
                   blurb: "Ztratil(a) erb i čest. Meč zůstal.",
                   attributes: [.sila: 2, .obratnost: 0, .duvtip: 0, .charisma: 2],
                   items: [Item(name: "Rodový meč", kind: .weapon),
                           Item(name: "Štít s vyškrábaným erbem", kind: .armor)],
                   bonusGold: 15),
    ]

    public static func background(_ id: String) -> Background {
        backgrounds.first { $0.id == id } ?? backgrounds[0]
    }

    // MARK: Rychlá výprava (A)

    public struct QuestTemplate: Sendable {
        public let objective: String
        public let location: String
        public let scene: SceneKind
        public let hook: String
    }

    public static let quests: [QuestTemplate] = [
        QuestTemplate(objective: "Vynes Srdce mlhy z kobky pod vypáleným klášterem",
                      location: "Kobka pod klášterem sv. Havla", scene: .dungeon,
                      hook: "Mniši zmizeli před třemi zimami. Od té doby z kobky stoupá mlha, která zabíjí dobytek."),
        QuestTemplate(objective: "Zabij Šedou vlčici, která terorizuje cestu k městu",
                      location: "Vlčí roklina", scene: .forest,
                      hook: "Kupci přestali jezdit. Na stromech visí roztrhané plachty vozů."),
        QuestTemplate(objective: "Osvoboď kováře, kterého drží lapkové ve staré mýtnici",
                      location: "Stará mýtnice u brodu", scene: .ruins,
                      hook: "Bez kováře nebudou zbraně ani hřeby. Lapkové chtějí výkupné, které nikdo nemá."),
        QuestTemplate(objective: "Zjisti, kdo otravuje studnu na náměstí, a zastav ho",
                      location: "Náměstí a podzemní stoky", scene: .town,
                      hook: "Třetí dítě tento týden. Voda páchne železem a lidé si šeptají o čarodějnici."),
        QuestTemplate(objective: "Získej zpět ukradenou korouhev z tábora nájezdníků",
                      location: "Tábor nájezdníků v Černém dole", scene: .camp,
                      hook: "Bez korouhve se městská rada rozpadne a každý cech půjde svou cestou."),
        QuestTemplate(objective: "Dones lék z bylinářčiny chatrče uprostřed Mrtvé bažiny",
                      location: "Mrtvá bažina", scene: .swamp,
                      hook: "Horečka kosí čtvrť u přístavu. Stará bylinářka prý lék má – pokud ještě žije."),
        QuestTemplate(objective: "Zapal znovu signální oheň na Havraní věži",
                      location: "Havraní věž", scene: .mountain,
                      hook: "Oheň zhasl a z hor se blíží něco, co chce, aby zůstal zhasnutý."),
        QuestTemplate(objective: "Vynes z hrobky prvního krále jeho prsten dřív, než ji vykradou jiní",
                      location: "Královská hrobka", scene: .dungeon,
                      hook: "Kdo nosí prsten, toho rada poslechne. Za úsvitu dorazí žoldáci, kteří ho chtějí také."),
    ]

    /// Kolik zdařilých kroků vede ke splnění cíle Rychlé výpravy.
    public static let questSteps = 3

    // MARK: Vláda nad osadou (C) – cíl

    public static let realmGoalPopulation = 100
    public static let realmGoalBuildings: [BuildingKind] = [.palisada, .trziste, .kaple, .kasarna]

    public static func realmGoalMet(_ s: Settlement) -> Bool {
        s.population >= realmGoalPopulation && realmGoalBuildings.allSatisfy { s.count($0) > 0 }
    }

    // MARK: Cesta světem (B)

    public static let campaignWaypoints: [Stop] = [
        Stop(name: "Šibeniční rozcestí", scene: .road),
        Stop(name: "Brod u Utopenců", scene: .river),
        Stop(name: "Hvozd Šepotů", scene: .forest),
        Stop(name: "Ruiny Starého Hradiště", scene: .ruins),
        Stop(name: "Bažiny Bludiček", scene: .swamp),
        Stop(name: "Průsmyk Krkavců", scene: .mountain),
        Stop(name: "Městečko Mlýnec", scene: .town),
        Stop(name: "Opuštěný důl", scene: .dungeon),
        Stop(name: "Tábor poutníků", scene: .camp),
        Stop(name: "Spálená tvrz", scene: .castle),
        Stop(name: "Kamenný most", scene: .river),
        Stop(name: "Trh v Lipnici", scene: .town),
    ]
    public static let campaignDestination = Stop(name: "Údolí Úsvitu", scene: .castle)
    public static let campaignMiddleStops = 4

    // MARK: Výchozí hodnoty

    public static func startSettlement(mode: GameMode, name: String, bonusGold: Int) -> Settlement {
        switch mode {
        case .quest:
            return Settlement(name: name, population: 0, gold: 15 + bonusGold, food: 0, foodCapacity: 0,
                              defense: 0, morale: 50, buildings: [:], construction: [])
        case .campaign:
            return Settlement(name: name, population: 24, gold: 60 + bonusGold, food: 120, foodCapacity: 200,
                              defense: 12, morale: 60, buildings: [:], construction: [])
        case .realm, .endless:
            return Settlement(name: name, population: 30, gold: 80 + bonusGold, food: 120, foodCapacity: 200,
                              defense: 10, morale: 55, buildings: [.farma: 1], construction: [])
        }
    }

    public static func startStress(_ mode: GameMode) -> Int {
        switch mode {
        case .quest: return 10
        case .campaign: return 15
        case .realm, .endless: return 20
        }
    }

    /// Hodnost osady podle počtu obyvatel (Živý simulátor).
    public static func settlementRank(population: Int) -> String {
        switch population {
        case ..<20: return "Tábořiště"
        case ..<45: return "Osada"
        case ..<80: return "Ves"
        case ..<130: return "Městečko"
        case ..<200: return "Město"
        default: return "Hrad a podhradí"
        }
    }

    public static let defaultCityNames = ["Vranov", "Černá Lhota", "Popelín", "Mlhov", "Kamenice", "Vlčí Brod", "Soumrak", "Hořany"]
}
