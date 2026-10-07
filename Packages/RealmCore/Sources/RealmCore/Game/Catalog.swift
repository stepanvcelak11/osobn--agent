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
        public let ability: Ability
        /// Symbol pro výběr postavy.
        public let icon: String

        public func displayName(feminine: Bool) -> String { feminine ? feminineName : name }
    }

    public static let backgrounds: [Background] = [
        Background(id: "zoldner", name: "Žoldnéř", feminineName: "Žoldnéřka",
                   blurb: "Přežil(a) tři války. Silná paže, málo slov.",
                   attributes: [.sila: 3, .obratnost: 1, .duvtip: 0, .charisma: 0],
                   items: [Item(name: "Těžký meč", kind: .weapon),
                           Item(name: "Kroužková košile", kind: .armor),
                           Item(name: "Lahev kořalky", kind: .consumable, charges: 2)],
                   bonusGold: 0,
                   ability: Ability(id: "bojovy_rev", name: "Bojový řev", detail: "+4 k hodu v boji a stres −5.", icon: "megaphone.fill",
                                    bonus: 4, categories: [.combat], stressRelief: 5),
                   icon: "shield.lefthalf.filled"),
        Background(id: "stinochod", name: "Stínochod", feminineName: "Stínochodka",
                   blurb: "Zloděj(ka) ze slumů. Každý zámek je jen otázka času.",
                   attributes: [.sila: 0, .obratnost: 3, .duvtip: 1, .charisma: 0],
                   items: [Item(name: "Pár dýk", kind: .weapon),
                           Item(name: "Paklíče", kind: .tool),
                           Item(name: "Kouřová bomba", kind: .consumable, charges: 2)],
                   bonusGold: 10,
                   ability: Ability(id: "splynuti", name: "Splynutí se stínem", detail: "+5 k plížení a krádeži.", icon: "moon.fill",
                                    bonus: 5, categories: [.stealth]),
                   icon: "eye.slash.fill"),
        Background(id: "bylinkar", name: "Bylinkář", feminineName: "Bylinkářka",
                   blurb: "Zná jedy i léky. Ví, co roste na hrobech.",
                   attributes: [.sila: 0, .obratnost: 0, .duvtip: 3, .charisma: 1],
                   items: [Item(name: "Jasanová hůl", kind: .weapon),
                           Item(name: "Brašna léčivých bylin", kind: .consumable, charges: 3),
                           Item(name: "Kniha receptur", kind: .tool)],
                   bonusGold: 0,
                   ability: Ability(id: "lecive_ruce", name: "Léčivé ruce", detail: "Zdraví +25, zastaví krvácení i horečku.", icon: "cross.case.fill",
                                    heal: 25, cures: true),
                   icon: "leaf.fill"),
        Background(id: "kupec", name: "Kupec", feminineName: "Kupkyně",
                   blurb: "Měšec, úsměv a pečeť, která otevírá dveře.",
                   attributes: [.sila: 0, .obratnost: 0, .duvtip: 1, .charisma: 3],
                   items: [Item(name: "Krátký meč", kind: .weapon),
                           Item(name: "Pečetní prsten", kind: .key),
                           Item(name: "Hedvábí na prodej", kind: .treasure)],
                   bonusGold: 40,
                   ability: Ability(id: "obchodni_nos", name: "Obchodní nos", detail: "+4 k obchodu a vyjednávání.", icon: "scalemass.fill",
                                    bonus: 4, categories: [.trade, .social]),
                   icon: "dollarsign.circle.fill"),
        Background(id: "rytir", name: "Vyhnaný rytíř", feminineName: "Vyhnaná rytířka",
                   blurb: "Ztratil(a) erb i čest. Meč zůstal.",
                   attributes: [.sila: 2, .obratnost: 0, .duvtip: 0, .charisma: 2],
                   items: [Item(name: "Rodový meč", kind: .weapon),
                           Item(name: "Štít s vyškrábaným erbem", kind: .armor)],
                   bonusGold: 15,
                   ability: Ability(id: "prisaha", name: "Rytířská přísaha", detail: "+3 k jakémukoli hodu a stres −10.", icon: "hand.raised.fill",
                                    bonus: 3, stressRelief: 10),
                   icon: "crown.fill"),
        Background(id: "lovec", name: "Lovec", feminineName: "Lovkyně",
                   blurb: "Les je tvůj domov. Stopy čteš jako jiní písmo.",
                   attributes: [.sila: 1, .obratnost: 2, .duvtip: 1, .charisma: 0],
                   items: [Item(name: "Luk a toulec", kind: .weapon),
                           Item(name: "Lovecký nůž", kind: .tool),
                           Item(name: "Obvazy", kind: .consumable, charges: 2)],
                   bonusGold: 5,
                   ability: Ability(id: "stopar", name: "Stopařův instinkt", detail: "+4 k průzkumu, stopování a cestě.", icon: "pawprint.fill",
                                    bonus: 4, categories: [.explore, .travel]),
                   icon: "tree.fill"),
        Background(id: "knez", name: "Potulný kněz", feminineName: "Potulná kněžka",
                   blurb: "Víra ti zůstala, i když chrámy shořely.",
                   attributes: [.sila: 1, .obratnost: 0, .duvtip: 1, .charisma: 2],
                   items: [Item(name: "Okovaná palice", kind: .weapon),
                           Item(name: "Svěcená voda", kind: .consumable, charges: 2),
                           Item(name: "Modlitební kniha", kind: .tool)],
                   bonusGold: 0,
                   ability: Ability(id: "pozehnani", name: "Požehnání", detail: "+3 k jednání a rituálům, stres −15.", icon: "sun.max.fill",
                                    bonus: 3, categories: [.social, .magic], stressRelief: 15),
                   icon: "sparkle"),
        Background(id: "vedma", name: "Vědmák", feminineName: "Vědma",
                   blurb: "Lidé se tě bojí a chodí za tebou potajmu.",
                   attributes: [.sila: 0, .obratnost: 1, .duvtip: 2, .charisma: 1],
                   items: [Item(name: "Obětní dýka", kind: .weapon),
                           Item(name: "Kostěné runy", kind: .artifact),
                           Item(name: "Lektvar z blínu", kind: .consumable, charges: 1)],
                   bonusGold: 0,
                   ability: Ability(id: "kletba", name: "Kletba", detail: "+4 k magii a v boji – nepřítel ochabne.", icon: "wand.and.stars",
                                    bonus: 4, categories: [.magic, .combat]),
                   icon: "moon.stars.fill"),
        Background(id: "bard", name: "Bard", feminineName: "Bardka",
                   blurb: "Písní otevřeš dveře, které meč nerozrazí.",
                   attributes: [.sila: 0, .obratnost: 1, .duvtip: 0, .charisma: 3],
                   items: [Item(name: "Loutna", kind: .tool),
                           Item(name: "Rapír", kind: .weapon),
                           Item(name: "Lahev vína", kind: .consumable, charges: 2)],
                   bonusGold: 10,
                   ability: Ability(id: "pisen", name: "Píseň odvahy", detail: "+3 k jednání a stres −15.", icon: "music.note",
                                    bonus: 3, categories: [.social, .trade], stressRelief: 15),
                   icon: "music.quarternote.3"),
        Background(id: "kovar", name: "Kovář", feminineName: "Kovářka",
                   blurb: "Železo poslouchá tvé kladivo – a lidé taky.",
                   attributes: [.sila: 2, .obratnost: 0, .duvtip: 2, .charisma: 0],
                   items: [Item(name: "Kovářské kladivo", kind: .weapon),
                           Item(name: "Kleště a pilník", kind: .tool),
                           Item(name: "Kožená zástěra", kind: .armor)],
                   bonusGold: 5,
                   ability: Ability(id: "mistrovska_prace", name: "Mistrovská práce", detail: "+5 k výrobě, opravám a stavbě.", icon: "hammer.fill",
                                    bonus: 5, categories: [.craft, .build]),
                   icon: "hammer.fill"),
        Background(id: "hrobnik", name: "Hrobník", feminineName: "Hrobnice",
                   blurb: "Mrtví ti nikdy neublížili. Živí ano.",
                   attributes: [.sila: 1, .obratnost: 1, .duvtip: 2, .charisma: 0],
                   items: [Item(name: "Lopata", kind: .weapon),
                           Item(name: "Lucerna", kind: .tool),
                           Item(name: "Stříbrné mince z hrobů", kind: .treasure)],
                   bonusGold: 10,
                   ability: Ability(id: "rec_mrtvych", name: "Řeč s mrtvými", detail: "+4 k průzkumu a magii, stres −5 – mrtví ti napoví.", icon: "flame",
                                    bonus: 4, categories: [.explore, .magic], stressRelief: 5),
                   icon: "moon.zzz.fill"),
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
        /// Tři etapy cesty k cíli.
        public let stages: [String]
    }

    public static let quests: [QuestTemplate] = [
        QuestTemplate(objective: "Vynes Srdce mlhy z kobky pod vypáleným klášterem",
                      location: "Kobka pod klášterem sv. Havla", scene: .dungeon,
                      hook: "Mniši zmizeli před třemi zimami. Od té doby z kobky stoupá mlha, která zabíjí dobytek.",
                      stages: ["Najdi cestu do kobky pod spáleništěm", "Projdi chodby zamořené mlhou", "Vyrvi Srdce mlhy jeho strážci"]),
        QuestTemplate(objective: "Zabij Šedou vlčici, která terorizuje cestu k městu",
                      location: "Vlčí roklina", scene: .forest,
                      hook: "Kupci přestali jezdit. Na stromech visí roztrhané plachty vozů.",
                      stages: ["Vystopuj vlčici v roklině", "Najdi její doupě", "Postav se Šedé vlčici"]),
        QuestTemplate(objective: "Osvoboď kováře, kterého drží lapkové ve staré mýtnici",
                      location: "Stará mýtnice u brodu", scene: .ruins,
                      hook: "Bez kováře nebudou zbraně ani hřeby. Lapkové chtějí výkupné, které nikdo nemá.",
                      stages: ["Zjisti, kolik lapků mýtnici hlídá", "Dostaň se dovnitř", "Vyveď kováře na svobodu"]),
        QuestTemplate(objective: "Zjisti, kdo otravuje studnu na náměstí, a zastav ho",
                      location: "Náměstí a podzemní stoky", scene: .town,
                      hook: "Třetí dítě tento týden. Voda páchne železem a lidé si šeptají o čarodějnici.",
                      stages: ["Vyptej se lidí a najdi stopu", "Sestup do stok k pramenu jedu", "Zastav travíře"]),
        QuestTemplate(objective: "Získej zpět ukradenou korouhev z tábora nájezdníků",
                      location: "Tábor nájezdníků v Černém dole", scene: .camp,
                      hook: "Bez korouhve se městská rada rozpadne a každý cech půjde svou cestou.",
                      stages: ["Dostaň se k táboru nepozorovaně", "Najdi stan, kde leží korouhev", "Uteč i s korouhví"]),
        QuestTemplate(objective: "Dones lék z bylinářčiny chatrče uprostřed Mrtvé bažiny",
                      location: "Mrtvá bažina", scene: .swamp,
                      hook: "Horečka kosí čtvrť u přístavu. Stará bylinářka prý lék má – pokud ještě žije.",
                      stages: ["Najdi bezpečnou stezku bažinou", "Dojdi k chatrči a získej lék", "Vrať se z bažiny živý"]),
        QuestTemplate(objective: "Zapal znovu signální oheň na Havraní věži",
                      location: "Havraní věž", scene: .mountain,
                      hook: "Oheň zhasl a z hor se blíží něco, co chce, aby zůstal zhasnutý.",
                      stages: ["Vystoupej po útesu k věži", "Projdi věží až k ohništi", "Zapal signální oheň"]),
        QuestTemplate(objective: "Vynes z hrobky prvního krále jeho prsten dřív, než ji vykradou jiní",
                      location: "Královská hrobka", scene: .dungeon,
                      hook: "Kdo nosí prsten, toho rada poslechne. Za úsvitu dorazí žoldáci, kteří ho chtějí také.",
                      stages: ["Najdi tajný vchod do hrobky", "Projdi pastmi a kryptami", "Vezmi prsten a uteč před žoldáky"]),
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
