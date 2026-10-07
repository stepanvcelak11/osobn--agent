import Foundation

/// Kostky jen u riskantních činů. Otázky, rozhovory a běžné činy se nehází – vypravěč je prostě vypráví.
/// Vlastnosti postavy mění šanci: válečník spíš vyhraje souboj, bard spíš někoho přemluví.
public enum Dice {
    /// Cílové číslo na k20 (bez bonusu je šance asi 50 %).
    public static let target = 11
    /// Bezhlavé činy jsou těžší.
    public static let recklessTarget = 15

    static let rules: [(Attribute, [String])] = [
        // pořadí je důležité: střelba a kouzla před obecným bojem
        (.obratnost, ["vystrel", "strelim", "strilim", "zamirim", "napnu luk", "sipem", "hodim nuz", "hodim dyku"]),
        (.duvtip, ["kouzl", "zaklin", "carodej", "rituál", "ritual", "sesl", "magi", "vyvolam", "zarikav"]),
        (.sila, ["zautoc", "utocim", "bojuj", "seknu", "bodnu", "udeřím", "uderim", "zabij", "porazim", "zapas", "tasim",
                 "rozsekn", "srazim", "kopnu", "praštim", "prastim", "vyrazim dvere", "vylomim", "vypacim", "zvednu", "odvalim", "prorazim"]),
        (.obratnost, ["plizim", "pliz", "proplizim", "potichu", "nepozorovane", "ukradnu", "kradu", "schovam", "skryju", "odemknu",
                      "pakl", "vysplham", "splham", "preskocim", "skocim", "uteku", "utecu", "utikam", "uhnu", "proklouznu", "vylezu"]),
        (.charisma, ["presvedc", "premluv", "ukecam", "zalzu", "lzu", "obalamut", "vyhroz", "zastras", "smlouv", "uplatim", "okouzl", "svedu", "vyjednam"]),
        (.duvtip, ["stopuj", "vystopuj", "stopy", "patram", "pátrám", "prohledam", "zkoumam", "rozlustim", "vylecim", "osetrim", "lecim"]),
    ]

    static let reckless = ["holyma ruk", "na vsechn", "sam proti", "bez rozmysl", "skocim do propast", "naslepo", "bez zbrane", "vsechny zabij"]

    /// Otázka na okolí („Kde jsem?“) – odpovídá se popisem, nehází se.
    public static func isQuestion(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix("?") { return true }
        let f = CzechText.fold(t)
        let starts = ["kde ", "kdo ", "kolik ", "proc ", "kam ", "odkud ", "co je ", "co vidim", "co se ", "jak to ", "jaky je ", "jaka je ", "je tu ", "je tady "]
        return starts.contains { f.hasPrefix($0) }
    }

    /// Kterou vlastností se čin zkouší (nil = bez hodu).
    public static func attribute(for text: String, input: InputMode) -> Attribute? {
        guard input == .act || input == .say else { return nil }
        let f = CzechText.fold(text)
        if input == .act && isQuestion(text) { return nil }
        if input == .say {
            // Řeč se hází jen při přesvědčování, lhaní a vyhrožování.
            return rules.first { $0.0 == .charisma }!.1.contains { f.contains(CzechText.fold($0)) } ? .charisma : nil
        }
        for (attr, words) in rules where words.contains(where: { f.contains(CzechText.fold($0)) }) { return attr }
        return nil
    }

    public static func isReckless(_ text: String) -> Bool {
        let f = CzechText.fold(text)
        return reckless.contains { f.contains($0) }
    }

    /// Hod k20 + 2× vlastnost proti cílovému číslu.
    public static func roll(_ attr: Attribute, hero: Hero, reckless: Bool, story: inout Story) -> Roll {
        let die = story.random(1...20)
        let bonus = hero.score(attr) * 2
        let t = reckless ? recklessTarget : target
        let total = die + bonus
        let outcome: Outcome
        if die == 20 { outcome = .critSuccess }
        else if die == 1 { outcome = .critFail }
        else if total >= t + 6 { outcome = .critSuccess }
        else if total >= t { outcome = .success }
        else if total >= t - 3 { outcome = .partial }
        else if total <= t - 9 { outcome = .critFail }
        else { outcome = .fail }
        return Roll(attribute: attr, die: die, bonus: bonus, target: t, outcome: outcome)
    }

    /// Šance na úspěch (aspoň „napůl“) v procentech – pro nápovědu u postavy.
    public static func chance(score: Int, target: Int = Dice.target) -> Int {
        var ok = 0
        for die in 1...20 {
            if die == 20 { ok += 1; continue }
            if die == 1 { continue }
            if die + score * 2 >= target - 3 { ok += 1 }
        }
        return ok * 5
    }
}
