import Foundation

/// Jednoduchý vypravěč bez modelu – hraje, dokud se jazykový model stahuje nebo když selže.
public enum Fallback {
    public static func intro(_ s: Story) -> String {
        "\(s.opening) Co uděláš?"
    }

    public static func turn(_ s: Story, text: String, mode: InputMode, roll: Roll?, question: Bool, defeat: Bool) -> String {
        if defeat {
            return "Tohle už nejde zachránit. Všechno, oč ses snažil\(s.hero.feminine ? "a" : ""), se ti rozpadá pod rukama a příběh končí."
        }
        if question { return "Rozhlížíš se kolem. Všechno je tak, jak to bylo před chvílí. Co uděláš?" }
        switch mode {
        case .story:
            let t = text.trimmingCharacters(in: .whitespaces)
            return (t.hasSuffix(".") || t.hasSuffix("!") ? t : t + ".") + " Co uděláš teď?"
        case .proceed:
            return "Chvíli se nic neděje. Pak zaslechneš blížící se kroky a tlumené hlasy."
        case .say:
            if let r = roll { return r.outcome.isSuccess ? "Tvá slova zaberou. Posluchač pomalu přikývne." : "Tvá slova vyzní naprázdno. Posluchač se zamračí." }
            return "Tvá slova chvíli visí ve vzduchu. Pak ti někdo odpoví."
        case .act:
            guard let r = roll else { return "Uděláš, co sis umínil\(s.hero.feminine ? "a" : ""). Zatím se nic zvláštního nestane." }
            switch r.outcome {
            case .critSuccess: return "Povede se ti to dokonale – lépe, než jsi doufal\(s.hero.feminine ? "a" : "")."
            case .success: return "Povede se ti to. Můžeš pokračovat."
            case .partial: return "Povede se to jen napůl a stojí tě to víc sil, než jsi čekal\(s.hero.feminine ? "a" : "")."
            case .fail: return "Nevyjde to. Situace se zhoršuje."
            case .critFail: return "Dopadne to velmi špatně. Tohle tě bude mrzet."
            }
        }
    }

    public static func epilogue(_ s: Story) -> String {
        let who = "\(s.hero.name), \(s.hero.className.lowercased())"
        switch s.end {
        case .victory: return "O tom, jak \(who) dokázal\(s.hero.feminine ? "a" : ""), co jiní nedokázali, se bude zpívat ještě dlouho."
        case .defeat: return "O tom, jak \(who) neuspěl\(s.hero.feminine ? "a" : ""), se mluví potichu. Ale i prohra je kus legendy."
        default: return "Příběh, který \(who) začal\(s.hero.feminine ? "a" : ""), zůstal nedopovězen. Možná ho jednou někdo dokončí."
        }
    }
}
