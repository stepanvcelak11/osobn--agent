import Foundation

public struct Achievement: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let icon: String
}

public enum Achievements {
    public static let all: [Achievement] = [
        Achievement(id: "prvni_krev", title: "První krev", detail: "Vyhraj první boj.", icon: "drop.fill"),
        Achievement(id: "osud", title: "Osudový hod", detail: "Na kostce padne 20.", icon: "die.face.6.fill"),
        Achievement(id: "prokleti", title: "Prokletý hod", detail: "Na kostce padne 1.", icon: "moon.fill"),
        Achievement(id: "na_hrane", title: "Na hraně", detail: "Přežij se zdravím 10 nebo méně.", icon: "heart.slash"),
        Achievement(id: "zelezne_nervy", title: "Železné nervy", detail: "Sraz stres z 80+ pod 30.", icon: "brain"),
        Achievement(id: "sberatel", title: "Sběratel", detail: "Měj u sebe 8 předmětů.", icon: "bag.fill"),
        Achievement(id: "bohac", title: "Boháč", detail: "Nashromáždi 300 zlata.", icon: "dollarsign.circle.fill"),
        Achievement(id: "stavitel", title: "Stavitel", detail: "Dokonči 5 staveb.", icon: "hammer.fill"),
        Achievement(id: "mesto", title: "Rostoucí město", detail: "Dosáhni 80 obyvatel.", icon: "person.3.fill"),
        Achievement(id: "obrance", title: "Obránce", detail: "Odraž 3 hrozby.", icon: "shield.fill"),
        Achievement(id: "tyden", title: "Týden přežití", detail: "Veď osadu 7 dní.", icon: "calendar"),
        Achievement(id: "mesto_povstalo", title: "Město povstalo", detail: "Splň Vládu nad osadou.", icon: "building.columns.fill"),
        Achievement(id: "rise", title: "Říše roste", detail: "V Nekonečné říši dosáhni 200 obyvatel.", icon: "crown.fill"),
        Achievement(id: "vitez_vyprava", title: "Hrdina výpravy", detail: "Splň Rychlou výpravu.", icon: "flag.fill"),
        Achievement(id: "bleskovka", title: "Blesková výprava", detail: "Splň výpravu do 6 tahů.", icon: "bolt.fill"),
        Achievement(id: "vitez_karavana", title: "Údolí Úsvitu", detail: "Doveď karavanu do cíle.", icon: "sunrise.fill"),
        Achievement(id: "zkuseny", title: "Zkušený", detail: "Dosáhni 3. úrovně.", icon: "star.fill"),
        Achievement(id: "veteran", title: "Veterán", detail: "Dosáhni 5. úrovně.", icon: "star.circle.fill"),
        Achievement(id: "spolehlivy", title: "Spolehlivá ruka", detail: "Splň 3 zakázky.", icon: "checkmark.seal.fill"),
        Achievement(id: "zname_tvare", title: "Známá tvář", detail: "Poznej 5 postav.", icon: "person.2.fill"),
        Achievement(id: "zima", title: "Přežili jsme zimu", detail: "Doveď osadu do druhého jara.", icon: "snowflake"),
        Achievement(id: "bez_ztrat", title: "Nikdo nezůstal pozadu", detail: "Doveď karavanu bez ztráty jediného člověka.", icon: "hand.raised.fill"),
    ]

    public static func byId(_ id: String) -> Achievement? { all.first { $0.id == id } }

    /// Přidá nově splněné úspěchy do stavu a vrátí je.
    @discardableResult
    public static func evaluate(_ s: inout GameState) -> [Achievement] {
        var got: [String] = []
        func check(_ id: String, _ cond: Bool) { if cond && !s.achievements.contains(id) { got.append(id) } }
        let st = s.stats
        check("prvni_krev", (st["combats_won"] ?? 0) >= 1)
        check("osud", (st["nat20"] ?? 0) >= 1)
        check("prokleti", (st["nat1"] ?? 0) >= 1)
        check("na_hrane", s.hero.hp > 0 && s.hero.hp <= 10)
        check("zelezne_nervy", st["stress_peak"] == 1 && s.hero.stress < 30)
        check("sberatel", s.hero.items.count >= 8)
        check("bohac", s.settlement.gold >= 300)
        check("stavitel", (st["built"] ?? 0) >= 5)
        check("mesto", s.mode != .quest && s.settlement.population >= 80)
        check("obrance", (st["threats_repelled"] ?? 0) >= 3)
        check("tyden", s.mode.hasSettlement && (st["days"] ?? 0) >= 7)
        check("vitez_vyprava", s.mode == .quest && s.end == .victory)
        check("bleskovka", s.mode == .quest && s.end == .victory && s.turn <= 6)
        check("vitez_karavana", s.mode == .campaign && s.end == .victory)
        check("mesto_povstalo", s.mode == .realm && s.end == .victory)
        check("rise", s.mode == .endless && s.settlement.population >= 200)
        check("bez_ztrat", s.mode == .campaign && s.end == .victory && (st["pop_lost"] ?? 0) == 0)
        check("zkuseny", s.hero.level >= 3)
        check("veteran", s.hero.level >= 5)
        check("spolehlivy", (st["contracts_done"] ?? 0) >= 3)
        check("zname_tvare", s.characters.count >= 5)
        check("zima", s.mode.hasSettlement && s.day > World.seasonDays * 4)
        s.achievements.append(contentsOf: got)
        return got.compactMap(byId)
    }
}
