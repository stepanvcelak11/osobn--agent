import Foundation

/// Záložní „vypravěč“ bez jazykového modelu: klíčová slova + šablony.
/// Hra díky tomu jde hrát (a testovat) i bez importovaného modelu nebo když model selže.
public enum Fallback {

    static let keywords: [(ActionCategory, [String])] = [
        (.build, ["postav", "stavet", "vybuduj", "zbuduj", "stavb"]),
        (.travel, ["vyraz", "pokracuj", "cestuj", "jedeme", "jdeme dal", "dal na cestu", "dalsi zastav", "pohneme", "vyrazime"]),
        (.rest, ["odpocin", "spim", "vyspim", "utabor", "pauza", "nabiram sil", "ošetř", "osetr"]),
        (.combat, ["utoc", "zautoc", "bojuj", "zabij", "sekn", "bodn", "udeř", "uder", "strel", "zastrel", "rozsekn", "napadn", "bran"]),
        (.stealth, ["plizi", "pliz", "schov", "ukradn", "ukrast", "potichu", "nepozorovan", "vplizi", "krad"]),
        (.social, ["promluv", "zeptam", "rekni", "rikam", "presvedc", "vyjedn", "domluv", "zastras", "prosim", "pozdrav", "mluv"]),
        (.trade, ["koupi", "kupuj", "prodam", "prodat", "smen", "obchod", "nakoup"]),
        (.craft, ["vyrob", "oprav", "uvar", "sestroj", "zpevn", "ukuj"]),
        (.magic, ["kouzl", "ritual", "zaklin", "modl", "runy", "magi"]),
        (.explore, ["prozkoum", "prohled", "hledam", "rozhlid", "podivam", "zkoumam", "najdu", "vylez", "slezu", "otevr", "jdu", "vstoupim"]),
    ]

    public static func interpret(_ text: String, state: GameState) -> ActionIntent {
        let f = CzechText.fold(text)
        var category: ActionCategory = .other
        for (cat, words) in keywords where words.contains(where: { f.contains(CzechText.fold($0)) }) {
            if cat == .build && !state.mode.hasSettlement { continue }
            if cat == .travel && state.mode != .campaign { continue }
            category = cat
            break
        }
        var build: BuildingKind?
        if category == .build {
            let map: [(BuildingKind, [String])] = [
                (.farma, ["farm", "pole"]), (.sypka, ["sypk", "sklad"]), (.palisada, ["hradb", "palisad", "zed"]),
                (.trziste, ["trh", "trzist"]), (.kaple, ["kapl", "chram", "svatyn"]), (.kasarna, ["kasar"]),
                (.ranhojicstvi, ["ranhoj", "lazaret", "lecit"]), (.straznaVez, ["vez", "hlidk"]),
            ]
            build = map.first { $0.1.contains { f.contains($0) } }?.0
        }
        var used: [String] = []
        for item in state.hero.items {
            // kmen slova (+ střídání ů/o: hůl → holí)
            let words = CzechText.fold(item.name).split(separator: " ").filter { $0.count >= 3 }
            let stems = words.flatMap { w -> [String] in
                let p = String(w.prefix(4))
                return [p, p.replacingOccurrences(of: "u", with: "o")]
            }
            if stems.contains(where: { f.range(of: "\\b" + $0, options: .regularExpression) != nil }) { used.append(item.name) }
        }
        let risky: Set<ActionCategory> = [.combat, .stealth, .magic]
        let difficulty: Difficulty
        switch category {
        case .rest, .build: difficulty = .trivial
        case .other: difficulty = .easy
        case .combat: difficulty = .normal
        default: difficulty = state.phase == 3 ? .hard : .normal
        }
        let risk: Risk = category == .combat ? .medium : (risky.contains(category) || category == .explore || category == .travel ? .low : .none)
        return ActionIntent(summary: String(text.prefix(80)), category: category, stat: category.defaultStat,
                            difficulty: difficulty, risk: risk, itemsUsed: used, build: build)
    }

    static let lines: [Outcome: [String]] = [
        .critSuccess: ["Všechno do sebe zapadne s děsivou přesností. Osud se dnes usmívá – a to se v tomhle kraji nestává často.",
                       "Na okamžik jako by tě vedla cizí ruka. Výsledek předčí i tvé nejodvážnější naděje."],
        .success: ["Podaří se to. Srdce ti buší, ale ruce zůstávají pevné.",
                   "Dokážeš to – ne bez námahy, ale čistě. Svět kolem na chvíli ztichne."],
        .partial: ["Napůl se to povede. Něco však zaskřípe a cena za úspěch tě ještě dožene.",
                   "Dosáhneš svého jen zčásti. Ve tmě zůstává cosi nedořešeného."],
        .fail: ["Nevyjde to. Chyba je malá, ale v tomhle světě stačí i malá chyba.",
                "Pokus selže a ozvěna tvého nezdaru se nese dál, než by sis přál(a)."],
        .critFail: ["Všechno se zvrtne. Bolest, zmatek a pach krve – tohle si budeš pamatovat dlouho.",
                    "Katastrofa. Jako by se proti tobě spikla sama země."],
        .auto: ["Uděláš to bez potíží. Čas plyne a kraj kolem tebe dýchá svým pomalým, nepřátelským dechem.",
                "Chvíli se nic neděje. Jen vítr, kouř a vzdálené kokrhání krkavců."],
        .impossible: ["Tohle v tomto světě nejde. Realita se tvému záměru vysměje a ty jen ztrácíš drahocenný čas."],
    ]

    public static func narrate(state: inout GameState, resolution r: Resolution) -> NarratorOutput {
        var text = state.pick(lines[r.roll.outcome] ?? lines[.auto]!)
        if let b = r.build { text = (b.started ? "Dáš pokyn ke stavbě: \(b.kind.czechName). " : "Stavba \(b.kind.czechName.lowercased()) nezačne – \(b.reason) ") + text }
        if let a = r.arrival { text = "Karavana dorazí do místa \(a.stop.name). \(a.text) " + text }
        if r.mandatory.hp < 0 { text += " Rána pálí a krev ti stéká po paži." }
        if r.mandatory.hp > 0 && r.intent.category != .rest { text += " Bolest na chvíli poleví." }
        if state.hero.stress >= 70 { text += " A ty stíny… hýbou se, nebo se ti to jen zdá?" }
        if state.chance(35), let w = weatherLine[state.weather] { text += " " + w }
        text += " Co uděláš teď?"
        var out = NarratorOutput(narration: text, proposed: r.mandatory)
        if [.success, .critSuccess].contains(r.roll.outcome) && r.intent.category == .explore && state.chance(30) {
            out.itemsGained = [(state.pick(["Zrezivělý klíč", "Lahvička lektvaru", "Stříbrná mince s lebkou", "Kus mapy"]), .treasure)]
            if out.itemsGained[0].0 == "Lahvička lektvaru" { out.itemsGained[0].1 = .consumable }
            if out.itemsGained[0].0 == "Zrezivělý klíč" { out.itemsGained[0].1 = .key }
        }
        if let a = r.arrival { out.location = a.stop.name; out.scene = a.stop.scene }
        if r.intent.category == .social && [.success, .critSuccess, .partial].contains(r.roll.outcome) && state.chance(60) {
            let p = state.pick(people)
            out.npc = (p.0, p.1, r.roll.outcome == .partial ? .neutral : .friend)
        }
        if r.contractEligible, let c = state.contract {
            let f = CzechText.fold(r.intent.summary)
            let stems = CzechText.fold(c.title).split(separator: " ").filter { $0.count >= 5 }.map { String($0.prefix(5)) }
            if f.contains("zakazk") || stems.contains(where: { f.contains($0) }) {
                out.contractDone = true
                out.narration = out.narration.replacingOccurrences(of: " Co uděláš teď?", with: "") + " Zakázka je splněna – \(c.giver) bude spokojen. Co uděláš teď?"
            }
        }
        if r.losesQuest {
            out.narration = out.narration.replacingOccurrences(of: " Co uděláš teď?", with: "") + " A pak je pozdě. Cíl výpravy je nenávratně ztracen."
        } else if r.completesQuest {
            out.narration = out.narration.replacingOccurrences(of: " Co uděláš teď?", with: "") + " Poslední překážka padá – cíl výpravy je splněn."
        }
        return out
    }

    static let weatherLine: [Weather: String] = [
        .dest: "Déšť ti stéká za límec a bláto čvachtá pod nohama.",
        .mlha: "Mlha polyká zvuky i tvary – každý stín může být cokoli.",
        .bourka: "Nad hlavou práskne hrom a vichr rve plášť.",
        .snih: "Sníh tlumí kroky a mráz zalézá pod kůži.",
        .mraz: "Mráz štípe do tváří, dech se mění v páru.",
        .jasno: "Slunce na chvíli prorazí šeď, ale nehřeje.",
        .zatazeno: "Šedé nebe visí nízko jako víko rakve.",
    ]

    static let people: [(String, String)] = [
        ("Stará Jitka", "kořenářka"), ("Matěj Jednooký", "převozník"), ("Bratr Kliment", "potulný mnich"),
        ("Ilsa", "lovkyně"), ("Vojtěch z Brodu", "kupec"), ("Hubert", "hostinský"), ("Dorota", "vdova po strážném"),
        ("Šimon Kulhavý", "zvěd"), ("Agáta", "kovářka"), ("Lukáš Rudovous", "vysloužilý voják"),
    ]

    public static func intro(state: GameState, hook: String?) -> String {
        let h = state.hero
        switch state.mode {
        case .quest:
            return "Vítej v kraji, kde slunce vychází neochotně a noc nikdy úplně neodchází, \(h.name). \(hook ?? "") Stojíš na prahu místa zvaného \(state.location). Tvůj cíl: \(state.quest?.objective ?? "přežít"). Vzduch páchne rzí a mokrou hlínou. Co uděláš?"
        case .campaign:
            return "Město \(state.settlement.name) hoří za vašimi zády, \(h.name). Čtyřiadvacet přeživších, pár vozů a slib, že někde za horami leží Údolí Úsvitu. Zásoby nevydrží věčně a v lesích už někdo sleduje vaše stopy. Co uděláš?"
        case .realm, .endless:
            return "Vítej v osadě \(state.settlement.name), \(h.name). Pár desítek duší, jedna farma, rozpadlá palisáda a divočina, která se každou noc přibližuje. Lidé k tobě vzhlížejí – a čekají, jestli je dovedeš přes zimu. Co uděláš?"
        }
    }

    public static func epilogue(state: GameState) -> String {
        let h = state.hero
        switch state.end {
        case .death: return "Píseň o \(h.name) se zpívá potichu, aby ji neslyšeli mrtví. Padl(a) tam, kde jiní utekli – a to se v tomhle kraji počítá."
        case .victory: return "\(h.name) dokázal(a), co mnozí pokládali za nemožné. U ohňů se o tom ještě dlouho bude mluvit – a pokaždé o trochu hrdinštěji."
        case .defeat: return "Píseň o \(h.name) je krátká a hořká: přišel(a), zaváhal(a), ztratil(a). Ale kraj si pamatuje i ty, kteří prohráli – a někdy se vracejí."
        case .ruin: return "Z \(state.settlement.name) zbyly jen ohořelé trámy a vrány. Jméno \(h.name) si pamatuje už jen vítr."
        default: return "Výprava skončila dřív, než se naplnil její cíl. Ale \(h.name) přežil(a) – a kdo přežije, může to zkusit znovu."
        }
    }
}
