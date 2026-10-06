import Foundation

/// Výsledek rozpoznání času v české větě.
public struct ParsedTime: Equatable, Sendable {
    /// Vyřešené datum a čas (u opakování první výskyt).
    public var date: Date?
    /// Uživatel zadal den (dnes, zítra, 15. 10., v pondělí…).
    public var hasDate: Bool = false
    /// Uživatel zadal čas (v 8, o půl osmé, za hodinu…).
    public var hasTime: Bool = false
    public var recurrence: Recurrence?
    /// Co jsme si domysleli (zobrazí se v kartě, aby to uživatel mohl opravit).
    public var assumptions: [String] = []
    /// Rozsahy v původním textu, které tvoří časový výraz.
    public var ranges: [Range<String.Index>] = []

    public var isEmpty: Bool { !hasDate && !hasTime && recurrence == nil }
}

/// Deterministický parser českých časových výrazů.
/// Model nikdy nepočítá data sám – předá text („zítra v 8“) a čas spočítá tento kód.
public struct CzechTimeParser: Sendable {
    public var calendar: Calendar
    public var now: Date
    /// Výchozí hodina, když je zadán jen den.
    public var defaultHour: Int = 9
    /// Režim budíku: „v 6“ = 6:00 ráno (žádný posun na odpoledne), jinak nejbližší budoucí výskyt.
    public var alarmMode: Bool = false

    public init(calendar: Calendar = CzechFormat.calendar(), now: Date = Date(), defaultHour: Int = 9, alarmMode: Bool = false) {
        self.calendar = calendar
        self.now = now
        self.defaultHour = defaultHour
        self.alarmMode = alarmMode
    }

    // MARK: - Slovníky

    static let dayPattern = "pondeli|pondelky|utery|stred[uay]|ctvrt(?:ek|ky|ka)|pat(?:ek|ky|ku)|sobot[uya]|nedel[ei]"
    static func weekdayNumber(_ s: String) -> Int? {
        if s.hasPrefix("pondel") { return 1 }
        if s.hasPrefix("uter") { return 2 }
        if s.hasPrefix("stred") { return 3 }
        if s.hasPrefix("ctvrt") { return 4 }
        if s.hasPrefix("pat") { return 5 }
        if s.hasPrefix("sobot") { return 6 }
        if s.hasPrefix("nedel") { return 7 }
        return nil
    }
    static let months = ["ledna", "unora", "brezna", "dubna", "kvetna", "cervna",
                         "cervence", "srpna", "zari", "rijna", "listopadu", "prosince"]
    static let cardinal: [String: Int] = [
        "jedna": 1, "jednu": 1, "jeden": 1, "dve": 2, "dva": 2, "tri": 3, "ctyri": 4, "pet": 5, "sest": 6,
        "sedm": 7, "osm": 8, "devet": 9, "deset": 10, "jedenact": 11, "dvanact": 12,
        "trinact": 13, "ctrnact": 14, "patnact": 15, "sestnact": 16, "sedmnact": 17, "osmnact": 18,
        "devatenact": 19, "dvacet": 20, "tricet": 30, "ctyricet": 40, "padesat": 50,
    ]
    static let ordinalGenitive: [String: Int] = [
        "jedne": 1, "druhe": 2, "treti": 3, "ctvrte": 4, "pate": 5, "seste": 6, "sedme": 7,
        "osme": 8, "devate": 9, "desate": 10, "jedenacte": 11, "dvanacte": 12,
    ]
    static let hourWords = "jednu|jedna|dve|tri|ctyri|pet|sest|sedm|osm|devet|deset|jedenact|dvanact"
    static let ordinalWords = "jedne|druhe|treti|ctvrte|pate|seste|sedme|osme|devate|desate|jedenacte|dvanacte"
    static let numberWords = "jednu|jeden|jedna|dve|dva|tri|ctyri|pet|sest|sedm|osm|devet|deset|patnact|dvacet|tricet|ctyricet|padesat|pul|ctvrt"

    enum PartOfDay: String { case rano, dopoledne, poledne, odpoledne, vecer, noc
        var defaultHour: Int {
            switch self { case .rano: return 8; case .dopoledne: return 10; case .poledne: return 12
            case .odpoledne: return 15; case .vecer: return 19; case .noc: return 22 }
        }
    }

    // MARK: - Mezivýsledky

    private struct Scan {
        var folded: String
        var consumed: [NSRange] = []
        var ranges: [NSRange] = []

        mutating func take(_ r: NSRange) { consumed.append(r); ranges.append(r) }
        func overlaps(_ r: NSRange) -> Bool { consumed.contains { NSIntersectionRange($0, r).length > 0 } }
    }

    private enum DaySpec {
        case offsetDays(Int)
        case absolute(year: Int?, month: Int, day: Int)
        case weekday(Int, mode: WeekdayMode)
        case nextWeek
        case weekend
    }
    private enum WeekdayMode { case upcoming, nextWeek, thisWeek }

    // MARK: - Hlavní funkce

    public func parse(_ text: String) -> ParsedTime? {
        let folded = CzechText.fold(text)
        var scan = Scan(folded: folded)
        var result = ParsedTime()

        var daySpec: DaySpec?
        var hour: Int?
        var minute: Int = 0
        var hourIsLoose = false          // „v 8“, „ve tři“ – může jít o dopoledne i večer
        var partOfDay: PartOfDay?
        var absoluteDateTime: Date?      // „za 2 hodiny“
        var midnightNextDay = false
        var recurrence: Recurrence?
        var recurrencePart: PartOfDay?

        // 1) Opakování (musí být první – obsahuje názvy dnů).
        if let (rec, part) = scanRecurrence(&scan) {
            recurrence = rec
            recurrencePart = part
        }

        // 2) ISO datum (2026-10-07 08:00)
        for m in matches(#"\b(\d{4})-(\d{1,2})-(\d{1,2})(?:[ t](\d{1,2}):(\d{2}))?\b"#, in: scan) {
            guard !scan.overlaps(m.range) else { continue }
            let y = int(m, 1, scan), mo = int(m, 2, scan), d = int(m, 3, scan)
            guard let y, let mo, let d, (1...12).contains(mo), (1...31).contains(d) else { continue }
            daySpec = .absolute(year: y, month: mo, day: d)
            if let h = int(m, 4, scan), let mi = int(m, 5, scan), h < 24, mi < 60 { hour = h; minute = mi }
            scan.take(m.range)
            break
        }

        // 3) Datum se jménem měsíce (15. října 2026)
        if daySpec == nil {
            let p = #"\b(\d{1,2})\.?\s*("# + CzechTimeParser.months.joined(separator: "|") + #")(?:\s+(\d{4}))?\b"#
            for m in matches(p, in: scan) where !scan.overlaps(m.range) {
                guard let d = int(m, 1, scan), let ms = str(m, 2, scan),
                      let mo = CzechTimeParser.months.firstIndex(of: ms) else { continue }
                daySpec = .absolute(year: int(m, 3, scan), month: mo + 1, day: d)
                scan.take(m.range)
                break
            }
        }

        // 4) Číselné datum (15. 10. / 15.10.2026)
        if daySpec == nil {
            for m in matches(#"\b(\d{1,2})\.\s?(\d{1,2})\.(?:\s?(\d{4}))?"#, in: scan) where !scan.overlaps(m.range) {
                guard let d = int(m, 1, scan), let mo = int(m, 2, scan), (1...31).contains(d), (1...12).contains(mo) else { continue }
                daySpec = .absolute(year: int(m, 3, scan), month: mo, day: d)
                scan.take(m.range)
                break
            }
        }

        // 5) Posun „za 2 hodiny“, „za týden“, „za chvíli“
        let offsetPattern = #"\bza\s+(?:(\d+|"# + CzechTimeParser.numberWords + #")\s+)?(minutu|minuty|minut|min|hodinu|hodiny|hodin|hod|h|den|dny|dni|dnu|tyden|tydny|tydnu|mesic|mesice|mesicu|rok|roky|let)\b"#
        for m in matches(offsetPattern, in: scan) where !scan.overlaps(m.range) {
            let numStr = str(m, 1, scan)
            var amount: Double = 1
            if let numStr {
                if let n = Int(numStr) { amount = Double(n) }
                else if numStr == "pul" { amount = 0.5 }
                else if numStr == "ctvrt" { amount = 0.25 }
                else if let n = CzechTimeParser.cardinal[numStr] { amount = Double(n) }
            }
            let unit = str(m, 2, scan) ?? ""
            if unit.hasPrefix("min") {
                absoluteDateTime = now.addingTimeInterval(amount * 60)
            } else if unit.hasPrefix("h") {
                absoluteDateTime = now.addingTimeInterval(amount * 3600)
            } else if unit.hasPrefix("d") {
                daySpec = .offsetDays(Int(amount))
            } else if unit.hasPrefix("tyd") {
                daySpec = .offsetDays(Int(amount * 7))
            } else if unit.hasPrefix("mes") {
                if let d = calendar.date(byAdding: .month, value: Int(amount), to: now) {
                    let c = calendar.dateComponents([.year, .month, .day], from: d)
                    daySpec = .absolute(year: c.year, month: c.month!, day: c.day!)
                }
            } else {
                if let d = calendar.date(byAdding: .year, value: Int(amount), to: now) {
                    let c = calendar.dateComponents([.year, .month, .day], from: d)
                    daySpec = .absolute(year: c.year, month: c.month!, day: c.day!)
                }
            }
            scan.take(m.range)
            break
        }
        for m in matches(#"\bza\s+chvil[iu]\b"#, in: scan) where !scan.overlaps(m.range) {
            absoluteDateTime = now.addingTimeInterval(15 * 60)
            result.assumptions.append("„za chvíli“ = za 15 minut")
            scan.take(m.range)
            break
        }

        // 6) Relativní dny
        if daySpec == nil {
            for m in matches(#"\b(dnes|dneska|dnesni|dnesek|zitra|zitrejsi|zitrek|pozitri|popozitri)\b"#, in: scan) where !scan.overlaps(m.range) {
                let w = str(m, 1, scan) ?? ""
                switch w {
                case "zitra", "zitrejsi", "zitrek": daySpec = .offsetDays(1)
                case "pozitri": daySpec = .offsetDays(2)
                case "popozitri": daySpec = .offsetDays(3)
                default: daySpec = .offsetDays(0)
                }
                scan.take(m.range)
                break
            }
        }

        // 7) Příští týden / víkend / den v týdnu
        if daySpec == nil {
            for m in matches(#"\b(?:(?:v|ve|na|do)\s+)?(?:(pristi|tento|toto|tuto|tenhle|tuhle|tohle)\s+)?(?:(?:v|ve|na)\s+)?("# + CzechTimeParser.dayPattern + #")\b"#, in: scan) where !scan.overlaps(m.range) {
                guard let dayStr = str(m, 2, scan), let wd = CzechTimeParser.weekdayNumber(dayStr) else { continue }
                let modifier = str(m, 1, scan)
                let mode: WeekdayMode = modifier == "pristi" ? .nextWeek : (modifier == nil ? .upcoming : .thisWeek)
                daySpec = .weekday(wd, mode: mode)
                scan.take(m.range)
                break
            }
        }
        if daySpec == nil {
            for m in matches(#"\b(?:pristi\s+tyden|v\s+pristim\s+tydnu)\b"#, in: scan) where !scan.overlaps(m.range) {
                daySpec = .nextWeek
                scan.take(m.range)
                break
            }
        }
        if daySpec == nil {
            for m in matches(#"\b(?:o|na|tento|tenhle|pristi)?\s*vikend[u]?\b"#, in: scan) where !scan.overlaps(m.range) {
                daySpec = .weekend
                scan.take(m.range)
                break
            }
        }

        // 8) Čas
        // tři čtvrtě na osm
        for m in matches(#"\b(?:(?:v|ve|o|na|kolem|okolo)\s+)?tri\s*ctvrte\s+na\s+("# + CzechTimeParser.hourWords + #"|\d{1,2})\b"#, in: scan) where !scan.overlaps(m.range) {
            if let n = hourValue(str(m, 1, scan)) { hour = n - 1; minute = 45; hourIsLoose = true; scan.take(m.range) }
            break
        }
        if hour == nil {
            for m in matches(#"\b(?:(?:v|ve|o|na|kolem|okolo)\s+)?ctvrt\s+na\s+("# + CzechTimeParser.hourWords + #"|\d{1,2})\b"#, in: scan) where !scan.overlaps(m.range) {
                if let n = hourValue(str(m, 1, scan)) { hour = n - 1; minute = 15; hourIsLoose = true; scan.take(m.range) }
                break
            }
        }
        if hour == nil {
            for m in matches(#"\b(?:(?:v|ve|o|na|kolem|okolo)\s+)?pul\s+("# + CzechTimeParser.ordinalWords + #")\b"#, in: scan) where !scan.overlaps(m.range) {
                if let w = str(m, 1, scan), let n = CzechTimeParser.ordinalGenitive[w] { hour = n - 1; minute = 30; hourIsLoose = true; scan.take(m.range) }
                break
            }
        }
        if hour == nil {
            // 8:30, 8.30, v 8:30 h
            for m in matches(#"\b(?:(?:v|ve|o|na|od|kolem|okolo|cca)\s+)?(\d{1,2})[:.](\d{2})\b(?:\s*(?:h|hod|hodin)\b)?(?!\s*\.?\s*\d)"#, in: scan) where !scan.overlaps(m.range) {
                guard let h = int(m, 1, scan), let mi = int(m, 2, scan), h < 24, mi < 60 else { continue }
                hour = h; minute = mi; hourIsLoose = false
                scan.take(m.range)
                break
            }
        }
        if hour == nil {
            // v 8, ve 14 h, kolem 9 hodin
            for m in matches(#"\b(?:v|ve|o|na|kolem|okolo|od|cca)\s+(\d{1,2})\b(?:\s*(h|hod|hodin|hodiny)\b)?(?!\s*[.:]\s*\d)(?!\s*(?:minut|min|dni|dny|den|krat|lidi|osob|kus))"#, in: scan) where !scan.overlaps(m.range) {
                guard let h = int(m, 1, scan), h <= 24 else { continue }
                hour = h == 24 ? 0 : h; minute = 0; hourIsLoose = h <= 12
                scan.take(m.range)
                break
            }
        }
        if hour == nil {
            // 8 hodin (bez předložky)
            for m in matches(#"\b(\d{1,2})\s*(?:h|hod|hodin|hodiny)\b"#, in: scan) where !scan.overlaps(m.range) {
                guard let h = int(m, 1, scan), h < 24 else { continue }
                hour = h; minute = 0; hourIsLoose = h <= 12
                scan.take(m.range)
                break
            }
        }
        if hour == nil {
            // ve tři, v osm hodin
            for m in matches(#"\b(?:v|ve|o|na|kolem|okolo)\s+("# + CzechTimeParser.hourWords + #")(?:\s+(?:hodin|hodiny|hod))?\b"#, in: scan) where !scan.overlaps(m.range) {
                if let w = str(m, 1, scan), let n = CzechTimeParser.cardinal[w] { hour = n; minute = 0; hourIsLoose = true; scan.take(m.range) }
                break
            }
        }
        if hour == nil {
            for m in matches(#"\b(?:v|o|na|kolem)?\s*(poledne|pulnoc|pulnoci)\b"#, in: scan) where !scan.overlaps(m.range) {
                let w = str(m, 1, scan) ?? ""
                if w == "poledne" { hour = 12; minute = 0 } else { hour = 0; minute = 0; midnightNextDay = true }
                scan.take(m.range)
                break
            }
        }
        // Část dne
        for m in matches(#"\b(rano|rana|dopoledne|odpoledne|vecer|vecera|v\s+noci|noc|v\s+poledne)\b"#, in: scan) where !scan.overlaps(m.range) {
            let w = (str(m, 1, scan) ?? "").replacingOccurrences(of: "v ", with: "").replacingOccurrences(of: "  ", with: " ")
            switch w {
            case "rano", "rana": partOfDay = .rano
            case "dopoledne": partOfDay = .dopoledne
            case "odpoledne": partOfDay = .odpoledne
            case "vecer", "vecera": partOfDay = .vecer
            case "noci", "noc": partOfDay = .noc
            case "poledne": partOfDay = .poledne
            default: break
            }
            if partOfDay != nil { scan.take(m.range) }
            break
        }

        if daySpec == nil && hour == nil && partOfDay == nil && absoluteDateTime == nil && recurrence == nil {
            return nil
        }

        result.ranges = scan.ranges.compactMap { CzechText.originalRange($0, folded: folded, original: text) }

        // --- Opakování ---
        if var rec = recurrence {
            let part = partOfDay ?? recurrencePart
            if let hour {
                rec.hour = adjustHour(hour, part: part, loose: hourIsLoose)
                rec.minute = minute
            } else if let part {
                rec.hour = part.defaultHour; rec.minute = 0
                result.assumptions.append("čas \(CzechFormat.time(hour: rec.hour, minute: 0)) (\(part.rawValue))")
            } else {
                rec.hour = defaultHour; rec.minute = 0
                result.assumptions.append("čas nebyl zadán – použito \(CzechFormat.time(hour: defaultHour, minute: 0))")
            }
            if rec.frequency == .monthly && rec.monthDay == nil, case .absolute(_, _, let d)? = daySpec { rec.monthDay = d }
            let startDay = daySpec.map { resolveDay($0) } ?? calendar.startOfDay(for: now)
            let anchorBase = calendar.date(bySettingHour: rec.hour, minute: rec.minute, second: 0, of: startDay) ?? now
            if rec.frequency == .monthly && rec.monthDay == nil { rec.monthDay = calendar.component(.day, from: anchorBase) }
            if rec.frequency == .yearly {
                if rec.monthDay == nil { rec.monthDay = calendar.component(.day, from: anchorBase) }
                if rec.month == nil { rec.month = calendar.component(.month, from: anchorBase) }
            }
            let searchFrom = max(now, anchorBase.addingTimeInterval(-1))
            let first = rec.nextOccurrence(after: searchFrom, anchor: anchorBase, calendar: calendar)
            result.recurrence = rec
            result.date = first
            result.hasTime = hour != nil || part != nil
            result.hasDate = daySpec != nil
            return result
        }

        // --- Absolutní posun („za 2 hodiny“) ---
        if let abs = absoluteDateTime {
            result.date = abs
            result.hasDate = true
            result.hasTime = true
            return result
        }

        // --- Den + čas ---
        var day: Date
        var dayExplicit = false
        if let spec = daySpec {
            day = resolveDay(spec)
            dayExplicit = true
            result.hasDate = true
        } else {
            day = calendar.startOfDay(for: now)
        }
        if midnightNextDay { day = calendar.date(byAdding: .day, value: 1, to: day) ?? day }

        let isToday = calendar.isDate(day, inSameDayAs: now)
        if var h = hour {
            result.hasTime = true
            let adjusted = adjustHour(h, part: partOfDay, loose: hourIsLoose)
            if adjusted != h {
                if partOfDay == nil { result.assumptions.append("\(CzechFormat.time(hour: adjusted, minute: minute)) (odpoledne)") }
                h = adjusted
            } else if !alarmMode && hourIsLoose && partOfDay == nil && h >= 7 && h <= 11 && (isToday || !dayExplicit) {
                // „v 8“ dnes, ale 8:00 už bylo → nejspíš večer
                let candidate = calendar.date(bySettingHour: h, minute: minute, second: 0, of: day)!
                let evening = calendar.date(bySettingHour: h + 12, minute: minute, second: 0, of: day)!
                if candidate <= now && evening > now {
                    h += 12
                    result.assumptions.append("\(CzechFormat.time(hour: h, minute: minute)) (ráno už bylo)")
                }
            }
            var date = calendar.date(bySettingHour: h, minute: minute, second: 0, of: day)!
            if !dayExplicit && date <= now {
                date = calendar.date(byAdding: .day, value: 1, to: date)!
                result.assumptions.append("zítra (dnes už ten čas byl)")
            }
            result.date = date
        } else if let part = partOfDay {
            result.hasTime = true
            var date = calendar.date(bySettingHour: part.defaultHour, minute: 0, second: 0, of: day)!
            if !dayExplicit && date <= now { date = calendar.date(byAdding: .day, value: 1, to: date)! }
            result.date = date
            result.assumptions.append("\(part.rawValue) = \(CzechFormat.time(hour: part.defaultHour, minute: 0))")
        } else {
            result.hasTime = false
            result.date = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: day)
        }
        return result
    }

    /// Text bez časového výrazu (např. pro název připomínky).
    public func remainder(of text: String, removing ranges: [Range<String.Index>]) -> String {
        var s = text
        for r in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            // Rozsahy jsou z `text`; převedeme přes offsety (text se nemění, dokud mažeme odzadu).
            let lo = text.distance(from: text.startIndex, to: r.lowerBound)
            let hi = text.distance(from: text.startIndex, to: r.upperBound)
            let a = s.index(s.startIndex, offsetBy: lo), b = s.index(s.startIndex, offsetBy: hi)
            s.replaceSubrange(a..<b, with: " ")
        }
        return CzechText.collapseSpaces(s)
    }

    // MARK: - Pomocné

    private func adjustHour(_ h: Int, part: PartOfDay?, loose: Bool) -> Int {
        if let part {
            switch part {
            case .odpoledne, .vecer: return h < 12 ? h + 12 : h
            case .noc: return (h >= 7 && h < 12) ? h + 12 : (h == 12 ? 0 : h)
            case .rano, .dopoledne: return h == 12 ? 12 : h
            case .poledne: return h
            }
        }
        // „ve tři“ bez upřesnění = 15:00 (1–6 hodin běžně znamená odpoledne)
        if loose && !alarmMode && h >= 1 && h <= 6 { return h + 12 }
        return h
    }

    private func hourValue(_ s: String?) -> Int? {
        guard let s else { return nil }
        if let n = Int(s), (1...24).contains(n) { return n }
        return CzechTimeParser.cardinal[s]
    }

    private func resolveDay(_ spec: DaySpec) -> Date {
        let today = calendar.startOfDay(for: now)
        switch spec {
        case .offsetDays(let n):
            return calendar.date(byAdding: .day, value: n, to: today)!
        case .absolute(let year, let month, let day):
            let y = year ?? calendar.component(.year, from: now)
            var c = DateComponents(year: y, month: month, day: day)
            var d = calendar.date(from: c) ?? today
            if year == nil && d < today {
                c.year = y + 1
                d = calendar.date(from: c) ?? d
            }
            return calendar.startOfDay(for: d)
        case .weekday(let wd, let mode):
            let todayWd = Recurrence.isoWeekday(today, calendar: calendar)
            let monday = calendar.date(byAdding: .day, value: -(todayWd - 1), to: today)!
            switch mode {
            case .upcoming:
                var diff = wd - todayWd
                if diff <= 0 { diff += 7 }
                return calendar.date(byAdding: .day, value: diff, to: today)!
            case .nextWeek:
                return calendar.date(byAdding: .day, value: 7 + wd - 1, to: monday)!
            case .thisWeek:
                let d = calendar.date(byAdding: .day, value: wd - 1, to: monday)!
                return d < today ? calendar.date(byAdding: .day, value: 7, to: d)! : d
            }
        case .nextWeek:
            let todayWd = Recurrence.isoWeekday(today, calendar: calendar)
            return calendar.date(byAdding: .day, value: 8 - todayWd, to: today)!
        case .weekend:
            let todayWd = Recurrence.isoWeekday(today, calendar: calendar)
            if todayWd == 6 { return today }
            if todayWd == 7 { return calendar.date(byAdding: .day, value: 6, to: today)! }
            return calendar.date(byAdding: .day, value: 6 - todayWd, to: today)!
        }
    }

    private func scanRecurrence(_ scan: inout Scan) -> (Recurrence, PartOfDay?)? {
        let every = #"kazd(?:y|e|ou|eho|ym|ych)"#
        // Dny v týdnu: „každé pondělí a čtvrtek“, „každý týden v pondělí“
        let day = CzechTimeParser.dayPattern
        let weeklyPattern = #"\b"# + every + #"\s+(?:(druhy|druhe|treti)\s+)?(?:tyden\s+)?(?:(?:v|ve)\s+)?((?:"# + day + #")(?:\s*(?:,|a|i)\s*(?:(?:v|ve|"# + every + #")\s+)?(?:"# + day + #"))*)\b"#
        for m in matches(weeklyPattern, in: scan) where !scan.overlaps(m.range) {
            guard let list = str(m, 2, scan) else { continue }
            let days = matches(day, in: Scan(folded: list)).compactMap { mm -> Int? in
                let s = (list as NSString).substring(with: mm.range)
                return CzechTimeParser.weekdayNumber(s)
            }
            guard !days.isEmpty else { continue }
            let interval = intervalWord(str(m, 1, scan))
            scan.take(m.range)
            return (Recurrence(frequency: .weekly, interval: interval, weekdays: days, hour: defaultHour, minute: 0), nil)
        }
        // Množné číslo bez „každý“: „v pondělky a čtvrtky“, „po pátcích“
        for m in matches(#"\b(?:v|ve|o)\s+(pondelky|utery|stredy|ctvrtky|patky|soboty|nedele)(?:\s*(?:,|a)\s*(pondelky|utery|stredy|ctvrtky|patky|soboty|nedele))*\b"#, in: scan) where !scan.overlaps(m.range) {
            let s = (scan.folded as NSString).substring(with: m.range)
            let days = matches(#"pondelky|utery|stredy|ctvrtky|patky|soboty|nedele"#, in: Scan(folded: s)).compactMap {
                CzechTimeParser.weekdayNumber((s as NSString).substring(with: $0.range))
            }
            guard !days.isEmpty else { continue }
            scan.take(m.range)
            return (Recurrence(frequency: .weekly, weekdays: days, hour: defaultHour, minute: 0), nil)
        }
        // Pracovní dny / víkendy
        for m in matches(#"\b(?:"# + every + #"\s+(?:pracovni|vsedni)\s+den|(?:ve|v)\s+(?:vsedni|pracovni)\s+dny|(?:ve|v)\s+(?:vsedni|pracovni)ch\s+dnech|pres\s+tyden)\b"#, in: scan) where !scan.overlaps(m.range) {
            scan.take(m.range)
            return (Recurrence(frequency: .weekly, weekdays: [1, 2, 3, 4, 5], hour: defaultHour, minute: 0), nil)
        }
        for m in matches(#"\b(?:o\s+vikendech|"# + every + #"\s+vikend)\b"#, in: scan) where !scan.overlaps(m.range) {
            scan.take(m.range)
            return (Recurrence(frequency: .weekly, weekdays: [6, 7], hour: defaultHour, minute: 0), nil)
        }
        // Každé ráno / každý večer
        for m in matches(#"\b"# + every + #"\s+(rano|dopoledne|odpoledne|vecer|noc)\b"#, in: scan) where !scan.overlaps(m.range) {
            let part = PartOfDay(rawValue: str(m, 1, scan) ?? "")
            scan.take(m.range)
            return (Recurrence(frequency: .daily, hour: part?.defaultHour ?? defaultHour, minute: 0), part)
        }
        // Denně / každý den / obden / každé 3 dny
        for m in matches(#"\b(?:"# + every + #"\s+(\d+)\s+(?:dny|dni|dnu)|obden|"# + every + #"\s+druhy\s+den)\b"#, in: scan) where !scan.overlaps(m.range) {
            let n = int(m, 1, scan) ?? 2
            scan.take(m.range)
            return (Recurrence(frequency: .daily, interval: n, hour: defaultHour, minute: 0), nil)
        }
        for m in matches(#"\b(?:"# + every + #"\s+den|denne|kazdodenne)\b"#, in: scan) where !scan.overlaps(m.range) {
            scan.take(m.range)
            return (Recurrence(frequency: .daily, hour: defaultHour, minute: 0), nil)
        }
        // Týdně (bez dne) – den podle data
        for m in matches(#"\b(?:"# + every + #"\s+(?:(druhy|druhe)\s+)?tyden|tydne|jednou\s+tydne)\b"#, in: scan) where !scan.overlaps(m.range) {
            let interval = intervalWord(str(m, 1, scan))
            scan.take(m.range)
            return (Recurrence(frequency: .weekly, interval: interval, hour: defaultHour, minute: 0), nil)
        }
        // Měsíčně: „každého 5.“, „každý měsíc 15.“, „každý 1. den v měsíci“
        for m in matches(#"\b(?:"# + every + #"\s+(?:mesic\s+)?(\d{1,2})\.(?:\s*(?:den\s+)?(?:v\s+mesici|dne|v\s+mesici))?|"# + every + #"\s+mesic|mesicne|jednou\s+mesicne)"#, in: scan) where !scan.overlaps(m.range) {
            let d = int(m, 1, scan)
            scan.take(m.range)
            return (Recurrence(frequency: .monthly, monthDay: d, hour: defaultHour, minute: 0), nil)
        }
        for m in matches(#"\b(?:"# + every + #"\s+rok|rocne|jednou\s+rocne)\b"#, in: scan) where !scan.overlaps(m.range) {
            scan.take(m.range)
            return (Recurrence(frequency: .yearly, hour: defaultHour, minute: 0), nil)
        }
        return nil
    }

    private func intervalWord(_ s: String?) -> Int {
        switch s {
        case "druhy", "druhe": return 2
        case "treti": return 3
        default: return 1
        }
    }

    private func matches(_ pattern: String, in scan: Scan) -> [NSTextCheckingResult] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            assertionFailure("Neplatný regex: \(pattern)")
            return []
        }
        return re.matches(in: scan.folded, range: NSRange(location: 0, length: (scan.folded as NSString).length))
    }

    private func str(_ m: NSTextCheckingResult, _ i: Int, _ scan: Scan) -> String? {
        guard i < m.numberOfRanges else { return nil }
        let r = m.range(at: i)
        guard r.location != NSNotFound else { return nil }
        return (scan.folded as NSString).substring(with: r)
    }

    private func int(_ m: NSTextCheckingResult, _ i: Int, _ scan: Scan) -> Int? {
        str(m, i, scan).flatMap { Int($0) }
    }
}
