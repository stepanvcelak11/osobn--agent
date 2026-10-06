import Foundation

/// Délky v češtině: „10 minut“, „hodinu a půl“, „1,5 hodiny“, „90 sekund“, „půl hodiny“, „5 min“, „2:30“.
public enum CzechDuration {
    static let numberWords: [String: Double] = [
        "jednu": 1, "jedna": 1, "jeden": 1, "dve": 2, "dva": 2, "tri": 3, "ctyri": 4, "pet": 5, "sest": 6, "sedm": 7,
        "osm": 8, "devet": 9, "deset": 10, "jedenact": 11, "dvanact": 12, "patnact": 15, "dvacet": 20, "tricet": 30,
        "ctyricet": 40, "padesat": 50, "sedesat": 60, "devadesat": 90, "pul": 0.5, "ctvrt": 0.25,
    ]

    /// Vrací sekundy, nebo nil.
    public static func parse(_ text: String) -> TimeInterval? {
        let f = CzechText.fold(text).replacingOccurrences(of: ",", with: ".")
        let num = #"(\d+(?:\.\d+)?|jednu|jedna|jeden|dve|dva|tri|ctyri|pet|sest|sedm|osm|devet|deset|jedenact|dvanact|patnact|dvacet|tricet|ctyricet|padesat|sedesat|devadesat|pul|ctvrt)"#
        let unit = #"(hodin[uy]?|hod|h|minut[uy]?|min|m|sekund[uy]?|sek|s|vterin[uy]?)"#
        guard let re = try? NSRegularExpression(pattern: #"(?:\b"# + num + #"\s*)?"# + unit + #"\b"#) else { return nil }
        var total: TimeInterval = 0
        var found = false
        let ns = f as NSString
        for m in re.matches(in: f, range: NSRange(location: 0, length: ns.length)) {
            let unitStr = ns.substring(with: m.range(at: 2))
            var amount: Double = 1
            if m.range(at: 1).location != NSNotFound {
                let n = ns.substring(with: m.range(at: 1))
                guard let v = Double(n) ?? numberWords[n] else { continue }
                amount = v
            } else {
                // Samotná jednotka bez čísla („hodinu“, „minutu“) = 1; zkratky bez čísla ignorujeme.
                guard unitStr.count > 3 else { continue }
            }
            let mult: Double = unitStr.hasPrefix("h") ? 3600 : (unitStr.hasPrefix("m") ? 60 : 1)
            total += amount * mult
            found = true
        }
        // „a půl“ za jednotkou: „hodinu a půl“, „5 minut a půl“
        if found, f.range(of: #"\ba\s+pul\b"#, options: .regularExpression) != nil {
            if f.range(of: #"hodin\w*\s+a\s+pul"#, options: .regularExpression) != nil { total += 1800 }
            else if f.range(of: #"minut\w*\s+a\s+pul"#, options: .regularExpression) != nil { total += 30 }
        }
        if !found, let m = f.range(of: #"\b(\d{1,2}):(\d{2})\b"#, options: .regularExpression) {
            let parts = f[m].split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 { return parts[0] * 60 + parts[1] }   // mm:ss
        }
        return found && total > 0 ? total : nil
    }

    /// „10 min“, „1 h 30 min“, „45 s“
    public static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) h") }
        if m > 0 { parts.append("\(m) min") }
        if sec > 0 && h == 0 { parts.append("\(sec) s") }
        return parts.isEmpty ? "0 s" : parts.joined(separator: " ")
    }

    /// Ciferník „01:05:09“ / „05:09“.
    public static func clock(_ seconds: TimeInterval, tenths: Bool = false) -> String {
        let total = max(0, seconds)
        let t = Int((total * 10).rounded(tenths ? .toNearestOrAwayFromZero : .down))
        let s = t / 10
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        func p(_ v: Int) -> String { v < 10 ? "0\(v)" : "\(v)" }
        var out = h > 0 ? "\(h):\(p(m)):\(p(sec))" : "\(p(m)):\(p(sec))"
        if tenths { out += "," + String(t % 10) }
        return out
    }
}
