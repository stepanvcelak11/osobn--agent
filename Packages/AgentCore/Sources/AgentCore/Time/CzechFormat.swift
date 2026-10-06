import Foundation

/// České formátování dat a časů (24h, pondělí první den týdne) – nezávislé na systémových lokalizacích.
public enum CzechFormat {
    public static let weekdayNominative = ["pondělí", "úterý", "středa", "čtvrtek", "pátek", "sobota", "neděle"]
    public static let weekdayAccusative = ["pondělí", "úterý", "středu", "čtvrtek", "pátek", "sobotu", "neděli"]
    public static let weekdayShort = ["po", "út", "st", "čt", "pá", "so", "ne"]
    public static let monthGenitive = ["ledna", "února", "března", "dubna", "května", "června",
                                       "července", "srpna", "září", "října", "listopadu", "prosince"]
    public static let monthNominative = ["leden", "únor", "březen", "duben", "květen", "červen",
                                         "červenec", "srpen", "září", "říjen", "listopad", "prosinec"]

    /// Kalendář pro celou aplikaci: gregoriánský, pondělí první den, aktuální časová zóna.
    public static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        cal.locale = Locale(identifier: "cs_CZ")
        return cal
    }

    public static func time(hour: Int, minute: Int) -> String {
        "\(hour):" + (minute < 10 ? "0\(minute)" : "\(minute)")
    }

    public static func time(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return time(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    /// „v“ nebo „ve“ před hodinou (ve 2:00, ve 3:00, ve 4:00, ve 12:00, ve 13–14, ve 20–23).
    public static func atPreposition(hour: Int) -> String {
        [2, 3, 4, 12, 13, 14, 20, 21, 22, 23].contains(hour) ? "ve" : "v"
    }

    public static func atTime(_ date: Date, calendar: Calendar) -> String {
        let h = calendar.component(.hour, from: date)
        return atPreposition(hour: h) + " " + time(date, calendar: calendar)
    }

    /// „6. 10.“ nebo „6. 10. 2027“, pokud je jiný rok než `reference`.
    public static func shortDate(_ date: Date, reference: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.day, .month, .year], from: date)
        let y = calendar.component(.year, from: reference)
        var s = "\(c.day!). \(c.month!)."
        if c.year != y { s += " \(c.year!)" }
        return s
    }

    /// „6. října 2026“
    public static func longDate(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.day, .month, .year], from: date)
        return "\(c.day!). \(monthGenitive[c.month! - 1]) \(c.year!)"
    }

    public static func weekdayName(_ date: Date, calendar: Calendar) -> String {
        weekdayNominative[Recurrence.isoWeekday(date, calendar: calendar) - 1]
    }

    /// „Úterý 6. října“
    public static func headerDate(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.day, .month], from: date)
        let wd = weekdayName(date, calendar: calendar)
        return wd.prefix(1).uppercased() + wd.dropFirst() + " \(c.day!). \(monthGenitive[c.month! - 1])"
    }

    /// Relativní den: „dnes“, „zítra“, „pozítří“, „včera“, „v pondělí“ (do 6 dní), jinak datum.
    public static func relativeDay(_ date: Date, now: Date, calendar: Calendar) -> String {
        let d0 = calendar.startOfDay(for: now)
        let d1 = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: d0, to: d1).day ?? 0
        switch diff {
        case 0: return "dnes"
        case 1: return "zítra"
        case 2: return "pozítří"
        case -1: return "včera"
        case 3...6:
            let wd = Recurrence.isoWeekday(date, calendar: calendar)
            let prep = (wd == 3 || wd == 4) ? "ve" : "v"
            return "\(prep) \(weekdayAccusative[wd - 1]) \(shortDate(date, reference: now, calendar: calendar))"
        default:
            let wd = Recurrence.isoWeekday(date, calendar: calendar)
            return "\(weekdayShort[wd - 1]) \(shortDate(date, reference: now, calendar: calendar))"
        }
    }

    /// „zítra v 8:00“, „ve čtvrtek 8. 10. ve 14:30“
    public static func relativeDateTime(_ date: Date, now: Date, calendar: Calendar, hasTime: Bool = true) -> String {
        let day = relativeDay(date, now: now, calendar: calendar)
        return hasTime ? "\(day) \(atTime(date, calendar: calendar))" : day
    }

    /// „za 25 min“, „za 2 h“, „před 3 dny“
    public static func relativeInterval(_ date: Date, now: Date) -> String {
        let secs = date.timeIntervalSince(now)
        let past = secs < 0
        let m = Int((abs(secs) / 60).rounded())
        let text: String
        if m < 1 { return "teď" }
        else if m < 60 { text = "\(m) min" }
        else if m < 60 * 24 {
            let h = m / 60, rest = m % 60
            text = rest >= 10 && h < 5 ? "\(h) h \(rest) min" : "\(h) h"
        } else {
            let d = Int((Double(m) / 1440).rounded())
            text = past ? "\(d) \(plural(d, "dnem", "dny", "dny"))" : "\(d) \(plural(d, "den", "dny", "dní"))"
        }
        return past ? "před \(text)" : "za \(text)"
    }

    /// České množné číslo: 1 / 2–4 / 5+
    public static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let a = abs(n)
        if a == 1 { return one }
        if (2...4).contains(a) { return few }
        return many
    }

    public static func count(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        "\(n) \(plural(n, one, few, many))"
    }

    /// „každé“ / „každou“ / „každý“ podle rodu prvního dne.
    static func everyAccusative(weekday: Int) -> String {
        switch weekday {
        case 1, 2: return "každé"
        case 3, 6, 7: return "každou"
        default: return "každý"
        }
    }

    /// „pondělí a čtvrtek“, „pondělí, středu a pátek“
    static func weekdayListAccusative(_ days: [Int]) -> String {
        let names = days.map { weekdayAccusative[$0 - 1] }
        return joinedCzech(names)
    }

    public static func joinedCzech(_ items: [String]) -> String {
        if items.count <= 1 { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " a " + items.last!
    }

    /// ISO 8601 v místním čase bez zóny: 2026-10-07 08:00 – pro model.
    public static func machine(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        func p(_ v: Int?) -> String { let x = v ?? 0; return x < 10 ? "0\(x)" : "\(x)" }
        return "\(c.year!)-\(p(c.month))-\(p(c.day)) \(p(c.hour)):\(p(c.minute))"
    }
}
