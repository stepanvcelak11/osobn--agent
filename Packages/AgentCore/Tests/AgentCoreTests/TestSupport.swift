import Foundation
@testable import AgentCore

enum TS {
    static let tz = TimeZone(identifier: "Europe/Prague")!
    static let cal = CzechFormat.calendar(timeZone: tz)

    /// Úterý 6. 10. 2026 10:00 (Praha)
    static let now = date(2026, 10, 6, 10, 0)

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi))!
    }

    static func fmt(_ d: Date?) -> String {
        guard let d else { return "nil" }
        return CzechFormat.machine(d, calendar: cal)
    }

    static func parser(_ now: Date = now) -> CzechTimeParser {
        CzechTimeParser(calendar: cal, now: now)
    }
}
