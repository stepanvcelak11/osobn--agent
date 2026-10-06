import Foundation

/// Budík nebo odpočet (časovač). Plánuje je systém (AlarmKit na iOS 26+, jinak notifikace).
public struct ClockAlarm: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case alarm, timer }
    public var id: String
    public var kind: Kind
    public var label: String
    /// Kdy zazvoní (u opakovaného budíku nejbližší výskyt).
    public var fireDate: Date?
    /// Délka odpočtu (časovač).
    public var duration: TimeInterval?
    /// Opakování budíku: ISO dny 1 = pondělí … 7 = neděle (prázdné = jednorázový).
    public var weekdays: [Int]
    public var hour: Int?
    public var minute: Int?

    public init(id: String = UUID().uuidString, kind: Kind, label: String, fireDate: Date?, duration: TimeInterval? = nil,
                weekdays: [Int] = [], hour: Int? = nil, minute: Int? = nil) {
        self.id = id; self.kind = kind; self.label = label; self.fireDate = fireDate; self.duration = duration
        self.weekdays = weekdays; self.hour = hour; self.minute = minute
    }

    public func describe(now: Date, calendar: Calendar) -> String {
        switch kind {
        case .timer:
            let d = CzechDuration.format(duration ?? 0)
            if let f = fireDate { return "Odpočet \(d) – zazvoní \(CzechFormat.atTime(f, calendar: calendar))" }
            return "Odpočet \(d)"
        case .alarm:
            if !weekdays.isEmpty, let h = hour, let m = minute {
                let rec = Recurrence(frequency: .weekly, weekdays: weekdays, hour: h, minute: m)
                return "Budík " + rec.czechDescription
            }
            if let f = fireDate { return "Budík " + CzechFormat.relativeDateTime(f, now: now, calendar: calendar) }
            return "Budík"
        }
    }
}

public enum StopwatchAction: String, Codable, Sendable, CaseIterable { case start, stop, reset, lap, status }

public struct StopwatchState: Codable, Equatable, Sendable {
    public var startedAt: Date?
    public var accumulated: TimeInterval = 0
    public var laps: [TimeInterval] = []
    public init() {}

    public var isRunning: Bool { startedAt != nil }
    public func elapsed(at now: Date) -> TimeInterval {
        accumulated + (startedAt.map { now.timeIntervalSince($0) } ?? 0)
    }

    public mutating func apply(_ action: StopwatchAction, now: Date) {
        switch action {
        case .start: if startedAt == nil { startedAt = now }
        case .stop:
            if let s = startedAt { accumulated += now.timeIntervalSince(s); startedAt = nil }
        case .reset: self = StopwatchState()
        case .lap: if isRunning { laps.append(elapsed(at: now)) }
        case .status: break
        }
    }
}

public enum ClockError: Error, CustomStringConvertible {
    case unavailable
    case notAuthorized
    case unsupportedRepeat
    case failed(String)

    public var description: String {
        switch self {
        case .unavailable: return "Budíky nejsou dostupné"
        case .notAuthorized: return "Aplikace nemá povolení nastavovat budíky (Nastavení iOS → Osobní agent → Budíky a časovače)."
        case .unsupportedRepeat: return "Budík umí opakování jen po dnech v týdnu (např. „každý pracovní den“)."
        case .failed(let m): return m
        }
    }
}

/// Implementuje aplikace (AlarmKit / notifikace). Jádro jen rozhoduje, co nastavit.
public protocol ClockService: AnyObject {
    func scheduleAlarm(label: String, date: Date, weekdays: [Int], hour: Int, minute: Int) async throws -> ClockAlarm
    func startTimer(label: String, duration: TimeInterval) async throws -> ClockAlarm
    func cancel(id: String) throws
    func activeAlarms() -> [ClockAlarm]
    func stopwatch(_ action: StopwatchAction) -> StopwatchState
}
