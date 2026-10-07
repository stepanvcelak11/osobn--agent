import Foundation

/// Kostra příběhu: cíl a úkoly po řadě. První úkol je vždy klidný (zjistit, co se děje) – hráč se k problému dostává postupně.
public struct Tale: Equatable, Sendable {
    public var title: String
    public var goal: String
    /// Kde hrdina na začátku je a jak se o problému dozví (ve 2. osobě).
    public var opening: String
    public var stages: [String]
}

public enum Tales {
    public static let quests: [Tale] = [
        Tale(title: "Kovář v zajetí", goal: "Osvoboď kováře Radima z rukou lapků",
             opening: "Sedíš v hospodě ve vsi Lipnice. Vesničané si šeptají, že kováře Radima odvlekli lapkové a jeho dcera shání pomoc.",
             stages: ["Vyptej se ve vsi, co se stalo s kovářem", "Najdi tábor lapků v lese", "Dostaň kováře z tábora živého"]),
        Tale(title: "Šedá vlčice", goal: "Zbav kraj Šedé vlčice, která trhá stáda",
             opening: "Přicházíš k salaši na horské pastvině. Pastýři jsou vystrašení – v noci zase zmizely ovce.",
             stages: ["Zjisti od pastýřů, kde vlčice útočí", "Vystopuj doupě vlčice", "Postav se Šedé vlčici"]),
        Tale(title: "Mlha nad klášterem", goal: "Zjisti, proč z vypáleného kláštera stoupá mlha, a zastav ji",
             opening: "Docházíš do městečka pod kopcem s vypáleným klášterem. Lidé zavírají okenice a mluví o mlze, ve které mizí poutníci.",
             stages: ["Vyptej se lidí, co o mlze a klášteře vědí", "Najdi cestu do sklepení pod klášterem", "Zastav zdroj mlhy"]),
        Tale(title: "Otrávená studna", goal: "Najdi, kdo otrávil studnu v Hlubočanech",
             opening: "Přicházíš do vesnice Hlubočany, kde polovina lidí leží v horečce. Kořenářka tvrdí, že za to může voda ze studny.",
             stages: ["Zjisti, kdo onemocněl a co měli nemocní společného", "Najdi stopy toho, kdo studnu otrávil", "Dopadni travíře"]),
        Tale(title: "Ukradená korouhev", goal: "Získej zpět rodovou korouhev hraběte z Vranova",
             opening: "Jsi hostem na hradě Vranov. Hrabě zuří: noční lupiči ukradli rodovou korouhev a za tři dny má přijet král.",
             stages: ["Prozkoumej, kudy se lupiči dostali na hrad", "Vystopuj, kam korouhev odnesli", "Získej korouhev zpět"]),
        Tale(title: "Prsten z hrobky", goal: "Najdi prsten krále Oldřicha v zapomenuté hrobce",
             opening: "V krčmě si k tobě přisedne starý učenec. Tvrdí, že zná cestu k hrobce krále Oldřicha, a za jeho prsten nabízí velkou odměnu.",
             stages: ["Zjisti od učence, co o hrobce ví", "Najdi vchod do hrobky", "Získej prsten a dostaň se z hrobky živý"]),
    ]

    static let campaignMiddle = [
        "Převeď karavanu přes rozvodněný brod",
        "Projdi s lidmi Vlčím hvozdem",
        "Najdi bezpečnou cestu bažinami",
        "Vyjednej průchod přes území loupeživého barona",
        "Přečkej noc v opuštěné pevnosti",
        "Dostaň vozy přes zasněžený průsmyk",
    ]

    public static let endlessPool = [
        "Urovnej spor dvou mocných rodů",
        "Zažeň bandity z obchodní cesty",
        "Prozkoumej ruiny za řekou",
        "Uzavři spojenectví se sousedním panstvím",
        "Zastav nemoc, která se šíří osadou",
        "Postav kamenné hradby",
        "Odhal zrádce v radě",
        "Získej přízeň putovních kupců",
        "Ochraň úrodu před suchem",
        "Ubraň hranice před vojskem z hor",
        "Najdi nový zdroj železa",
        "Usmiř lesní lid",
    ]

    /// Příběh pro nový začátek. Vlastní téma od hráče má vždy přednost.
    public static func make(mode: GameMode, place: String, premise: String, story: inout Story) -> Tale {
        let p = premise.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .quest:
            if !p.isEmpty { return custom(p) }
            return story.pick(quests)
        case .campaign:
            var middle = campaignMiddle
            var picked: [String] = []
            for _ in 0..<3 { picked.append(middle.remove(at: story.random(0...(middle.count - 1)))) }
            return Tale(title: "Cesta do Údolí Úsvitu",
                        goal: "Doveď karavanu přeživších z padlého města \(place) do Údolí Úsvitu",
                        opening: "Město \(place) padlo. Stojíš na náměstí mezi vozy a vystrašenými lidmi, kteří čekají, že je povedeš pryč." + (p.isEmpty ? "" : " " + p),
                        stages: ["Připrav karavanu k odchodu a vyveď lidi z města"] + picked + ["Doveď lidi do Údolí Úsvitu"])
        case .realm:
            return Tale(title: "Osada \(place)", goal: "Proměň osadu \(place) v prosperující město",
                        opening: "Právě přijíždíš do osady \(place) na okraji divočiny. Od dnešního dne jí vládneš. Na návsi čeká rychtář a hrstka nedůvěřivých lidí." + (p.isEmpty ? "" : " " + p),
                        stages: ["Seznam se s osadou a zjisti, co ji nejvíc trápí", "Zajisti osadě dost jídla na zimu",
                                 "Postav ochranu proti nájezdníkům", "Získej obchodníky nebo spojence", "Ubraň osadu před velkým nájezdem"])
        case .endless:
            return Tale(title: "Říše \(place)", goal: "Rozšiř osadu \(place) v mocnou říši",
                        opening: "Od včerejška vládneš osadě \(place). Ráno vycházíš na náves, kde už čekají první prosebníci." + (p.isEmpty ? "" : " " + p),
                        stages: ["Seznam se s osadou a jejími lidmi", story.pick(endlessPool)])
        }
    }

    /// Výprava podle tématu hráče.
    public static func custom(_ premise: String) -> Tale {
        var title = premise
        if let dot = title.firstIndex(where: { ".!?\n".contains($0) }) { title = String(title[..<dot]) }
        if title.count > 40 { title = String(title.prefix(38)).trimmingCharacters(in: .whitespaces) + "…" }
        return Tale(title: title, goal: premise,
                    opening: "Právě se začínáš dozvídat, co se děje: \(premise)",
                    stages: ["Zjisti víc o tom, co se děje", "Najdi cestu k jádru problému", "Vyřeš to a dotáhni příběh do konce"])
    }

    /// Nekonečná říše: po splnění úkolu přibude další (jiný než posledních pár).
    public static func nextEndless(_ story: inout Story) -> String {
        let recent = Set(story.stages.suffix(6))
        let options = endlessPool.filter { !recent.contains($0) }
        return story.pick(options.isEmpty ? endlessPool : options)
    }
}
