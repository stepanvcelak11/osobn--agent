import Foundation

/// Pravidlo opakování (podmnožina iCalendar RRULE, kterou umíme vyjádřit česky).
public struct Recurrence: Codable, Equatable, Sendable {
    public enum Frequency: String, Codable, Sendable { case daily, weekly, monthly, yearly }

    public var frequency: Frequency
    /// Každý n-tý den/týden/měsíc/rok.
    public var interval: Int
    /// ISO dny v týdnu 1 = pondělí … 7 = neděle (jen pro weekly).
    public var weekdays: [Int]
    /// Den v měsíci (monthly), u yearly i měsíc.
    public var monthDay: Int?
    public var month: Int?
    public var hour: Int
    public var minute: Int
    public var until: Date?

    public init(frequency: Frequency, interval: Int = 1, weekdays: [Int] = [], monthDay: Int? = nil,
                month: Int? = nil, hour: Int, minute: Int, until: Date? = nil) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = Array(Set(weekdays)).sorted()
        self.monthDay = monthDay
        self.month = month
        self.hour = hour
        self.minute = minute
        self.until = until
    }

    /// Další výskyt striktně po `after`. `anchor` = první výskyt (pro interval > 1).
    public func nextOccurrence(after: Date, anchor: Date, calendar cal: Calendar) -> Date? {
        let start = max(after, anchor.addingTimeInterval(-1))
        var day = cal.startOfDay(for: start)
        // Hledáme maximálně ~4 roky dopředu (u yearly 29. 2. apod.).
        for _ in 0..<(366 * 4 + 2) {
            if let candidate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day),
               candidate > start, matches(day: day, anchor: anchor, calendar: cal) {
                if let until, candidate > until { return nil }
                return candidate
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { return nil }
            day = next
        }
        return nil
    }

    /// Výskyty v intervalu [from, to], nejvýše `limit`.
    public func occurrences(from: Date, to: Date, anchor: Date, calendar: Calendar, limit: Int = 100) -> [Date] {
        var result: [Date] = []
        var cursor = from.addingTimeInterval(-1)
        while result.count < limit, let next = nextOccurrence(after: cursor, anchor: anchor, calendar: calendar), next <= to {
            result.append(next)
            cursor = next
        }
        return result
    }

    private func matches(day: Date, anchor: Date, calendar cal: Calendar) -> Bool {
        let anchorDay = cal.startOfDay(for: anchor)
        switch frequency {
        case .daily:
            guard interval > 1 else { return true }
            let diff = cal.dateComponents([.day], from: anchorDay, to: day).day ?? 0
            return diff >= 0 && diff % interval == 0
        case .weekly:
            let wd = Recurrence.isoWeekday(day, calendar: cal)
            let days = weekdays.isEmpty ? [Recurrence.isoWeekday(anchor, calendar: cal)] : weekdays
            guard days.contains(wd) else { return false }
            guard interval > 1 else { return true }
            let weeks = Recurrence.weeksBetween(anchorDay, day, calendar: cal)
            return weeks >= 0 && weeks % interval == 0
        case .monthly:
            let target = monthDay ?? cal.component(.day, from: anchor)
            let comps = cal.dateComponents([.year, .month, .day], from: day)
            let range = cal.range(of: .day, in: .month, for: day)!
            // 31. v kratším měsíci → poslední den měsíce.
            let effective = min(target, range.count)
            guard comps.day == effective else { return false }
            guard interval > 1 else { return true }
            let a = cal.dateComponents([.year, .month], from: anchorDay)
            let months = (comps.year! - a.year!) * 12 + (comps.month! - a.month!)
            return months >= 0 && months % interval == 0
        case .yearly:
            let targetDay = monthDay ?? cal.component(.day, from: anchor)
            let targetMonth = month ?? cal.component(.month, from: anchor)
            let comps = cal.dateComponents([.year, .month, .day], from: day)
            guard comps.month == targetMonth, comps.day == targetDay else { return false }
            guard interval > 1 else { return true }
            let years = comps.year! - cal.component(.year, from: anchorDay)
            return years >= 0 && years % interval == 0
        }
    }

    public static func isoWeekday(_ date: Date, calendar: Calendar) -> Int {
        let w = calendar.component(.weekday, from: date) // 1 = neděle
        return w == 1 ? 7 : w - 1
    }

    static func weeksBetween(_ a: Date, _ b: Date, calendar cal: Calendar) -> Int {
        // Počet týdnů mezi pondělky obou týdnů.
        func monday(_ d: Date) -> Date {
            let wd = isoWeekday(d, calendar: cal)
            return cal.date(byAdding: .day, value: -(wd - 1), to: cal.startOfDay(for: d))!
        }
        let days = cal.dateComponents([.day], from: monday(a), to: monday(b)).day ?? 0
        return Int((Double(days) / 7).rounded())
    }

    // MARK: - Popis česky

    public var czechDescription: String {
        let time = CzechFormat.time(hour: hour, minute: minute)
        let at = CzechFormat.atPreposition(hour: hour) + " " + time
        switch frequency {
        case .daily:
            if interval == 1 { return "každý den \(at)" }
            if interval == 2 { return "obden \(at)" }
            return "každé \(interval) \(CzechFormat.plural(interval, "den", "dny", "dní")) \(at)"
        case .weekly:
            let days = weekdays.sorted()
            if days == [1, 2, 3, 4, 5] && interval == 1 { return "každý pracovní den \(at)" }
            if days == [6, 7] && interval == 1 { return "o víkendech \(at)" }
            if days == [1, 2, 3, 4, 5, 6, 7] && interval == 1 { return "každý den \(at)" }
            let list = days.isEmpty ? "" : CzechFormat.weekdayListAccusative(days)
            let prefix: String
            if let first = days.first { prefix = CzechFormat.everyAccusative(weekday: first) } else { prefix = "každý týden" }
            if interval == 2 { return "každý druhý týden: \(list) \(at)" }
            if interval > 2 { return "každý \(interval). týden: \(list) \(at)" }
            return "\(prefix) \(list) \(at)".replacingOccurrences(of: "  ", with: " ")
        case .monthly:
            let d = monthDay.map { "\($0)." } ?? ""
            if interval == 1 { return "každý měsíc \(d) \(at)" }
            return "každé \(interval) měsíce \(d) \(at)"
        case .yearly:
            let d = monthDay.map { "\($0)." } ?? ""
            let m = month.map { CzechFormat.monthGenitive[$0 - 1] } ?? ""
            return "každý rok \(d) \(m) \(at)".replacingOccurrences(of: "  ", with: " ")
        }
    }
}
