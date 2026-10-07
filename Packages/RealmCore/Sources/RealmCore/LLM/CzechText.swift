import Foundation

/// Pomocné funkce pro práci s českým textem.
public enum CzechText {
    /// Malá písmena bez diakritiky. Zachovává počet znaků (Character), aby šlo mapovat rozsahy zpět.
    public static func fold(_ text: String) -> String {
        var out = String()
        out.reserveCapacity(text.count)
        for ch in text {
            let lower = String(ch).lowercased()
            let folded = lower.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "cs_CZ"))
            if folded.count == 1 { out.append(contentsOf: folded) }
            else if lower.count == 1 { out.append(contentsOf: lower) }
            else { out.append(ch) }
        }
        return out
    }

    /// Převede NSRange ve složeném textu na rozsah v původním textu.
    static func originalRange(_ ns: NSRange, folded: String, original: String) -> Range<String.Index>? {
        guard let r = Range(ns, in: folded) else { return nil }
        let lo = folded.distance(from: folded.startIndex, to: r.lowerBound)
        let hi = folded.distance(from: folded.startIndex, to: r.upperBound)
        guard hi <= original.count else { return nil }
        let a = original.index(original.startIndex, offsetBy: lo)
        let b = original.index(original.startIndex, offsetBy: hi)
        return a..<b
    }

    public static func collapseSpaces(_ s: String) -> String {
        s.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// První písmeno velké.
    public static func capitalizeFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return String(f).uppercased() + s.dropFirst()
    }

    /// Odstraní interpunkci a výplňová slova na okrajích („ať“, „že“, „mi“, „prosím“, dvojtečka…).
    public static func trimFillers(_ s: String, fillers: Set<String>) -> String {
        var words = s.split(separator: " ").map(String.init)
        func norm(_ w: String) -> String {
            fold(w).trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        }
        while let f = words.first, fillers.contains(norm(f)) || norm(f).isEmpty { words.removeFirst() }
        while let l = words.last, fillers.contains(norm(l)) || norm(l).isEmpty { words.removeLast() }
        var out = words.joined(separator: " ")
        out = out.trimmingCharacters(in: CharacterSet(charactersIn: " ,:;-–.!?\"„“"))
        return out
    }

    /// Jednoduchá podobnost pro hledání podle názvu (podíl společných slov).
    public static func similarity(_ a: String, _ b: String) -> Double {
        let wa = Set(fold(a).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count > 1 })
        let wb = Set(fold(b).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count > 1 })
        guard !wa.isEmpty, !wb.isEmpty else { return 0 }
        // Porovnání kmenů (prvních 4 znaků) kvůli skloňování: doktor/doktorovi
        func stems(_ s: Set<String>) -> Set<String> { Set(s.map { String($0.prefix(max(4, $0.count - 3))) }) }
        let sa = stems(wa), sb = stems(wb)
        let inter = sa.intersection(sb).count
        return Double(inter) / Double(min(sa.count, sb.count))
    }
}
