import Foundation
import SwiftUI
import UserNotifications
import AgentCore
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Budíky, odpočty a stopky.
/// - iOS 26+: AlarmKit – skutečné budíky Apple (zvoní i v tichém režimu, na zamčené obrazovce a v Dynamic Islandu).
/// - Starší iOS: lokální notifikace se zvukem (tichý režim nepřebijí).
/// Volá se z agenta (mimo hlavní vlákno) i z UI – stav je chráněný zámkem, UI se obnovuje přes `version`.
final class AppClockService: ObservableObject, ClockService, @unchecked Sendable {
    @Published private(set) var version = 0
    private let lock = NSRecursiveLock()
    private var _registry: [ClockAlarm] = []
    private var _stopwatch = StopwatchState()
    private(set) var alarmKitAuthorized = false

    var registry: [ClockAlarm] { lock.lock(); defer { lock.unlock() }; return _registry }
    var stopwatchState: StopwatchState { lock.lock(); defer { lock.unlock() }; return _stopwatch }

    private func bump() { DispatchQueue.main.async { self.version += 1 } }

    private let registryKey = "clock.registry"
    private let stopwatchKey = "clock.stopwatch"

    /// Je k dispozici AlarmKit (iOS 26+)?
    var usesAlarmKit: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    init() {
        if let d = UserDefaults.standard.data(forKey: registryKey),
           let list = try? JSONDecoder.withDates.decode([ClockAlarm].self, from: d) { _registry = list }
        if let d = UserDefaults.standard.data(forKey: stopwatchKey),
           let s = try? JSONDecoder.withDates.decode(StopwatchState.self, from: d) { _stopwatch = s }
        prune()
        if #available(iOS 26.0, *) {
            alarmKitAuthorized = AlarmManager.shared.authorizationState == .authorized
            Task { [weak self] in
                for await alarms in AlarmManager.shared.alarmUpdates {
                    self?.reconcile(alarmIds: Set(alarms.map { $0.id.uuidString }))
                }
            }
        }
    }

    // MARK: - Registr (jen popisky a časy, žádná citlivá data)

    private func save() {
        if let d = try? JSONEncoder.withDates.encode(registry) { UserDefaults.standard.set(d, forKey: registryKey) }
        bump()
    }

    /// Odstraní proběhlé jednorázové budíky a odpočty.
    func prune() {
        let now = Date()
        lock.lock()
        let before = _registry.count
        _registry.removeAll { a in
            a.weekdays.isEmpty && (a.fireDate.map { $0.addingTimeInterval(60) < now } ?? false)
        }
        let changed = _registry.count != before
        lock.unlock()
        if changed { save() }
    }

    private func reconcile(alarmIds: Set<String>) {
        lock.lock()
        let before = _registry.count
        _registry.removeAll { !alarmIds.contains($0.id) }
        let changed = _registry.count != before
        lock.unlock()
        if changed { save() }
    }

    private func add(_ a: ClockAlarm) {
        lock.lock(); _registry.append(a); lock.unlock()
        save()
    }

    // MARK: - ClockService

    func requestAuthorizationIfNeeded() async throws {
        if #available(iOS 26.0, *) {
            switch AlarmManager.shared.authorizationState {
            case .authorized: alarmKitAuthorized = true
            case .denied: throw ClockError.notAuthorized
            default:
                let s = try await AlarmManager.shared.requestAuthorization()
                alarmKitAuthorized = s == .authorized
                guard alarmKitAuthorized else { throw ClockError.notAuthorized }
            }
        } else {
            await NotificationService.shared.requestAuthorization()
        }
    }

    func scheduleAlarm(label: String, date: Date, weekdays: [Int], hour: Int, minute: Int) async throws -> ClockAlarm {
        try await requestAuthorizationIfNeeded()
        let id = UUID()
        var alarm = ClockAlarm(id: id.uuidString, kind: .alarm, label: label, fireDate: date, weekdays: weekdays, hour: hour, minute: minute)
        if #available(iOS 26.0, *) {
            let schedule: Alarm.Schedule
            if weekdays.isEmpty {
                schedule = .fixed(date)
            } else {
                let days = weekdays.compactMap(Self.localeWeekday)
                schedule = .relative(.init(time: .init(hour: hour, minute: minute), repeats: .weekly(days)))
            }
            let attrs = AlarmAttributes<OAAlarmMetadata>(
                presentation: Self.presentation(title: label, snooze: true),
                metadata: OAAlarmMetadata(label: label, isTimer: false),
                tintColor: Color(red: 0.37, green: 0.79, blue: 0.75))
            // Odložení (snooze) o 9 minut
            let config = AlarmManager.AlarmConfiguration<OAAlarmMetadata>(
                countdownDuration: .init(preAlert: nil, postAlert: 9 * 60), schedule: schedule, attributes: attrs)
            _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
        } else {
            try await scheduleNotificationAlarm(alarm)
        }
        if !weekdays.isEmpty {
            alarm.fireDate = Recurrence(frequency: .weekly, weekdays: weekdays, hour: hour, minute: minute)
                .nextOccurrence(after: Date(), anchor: Date(), calendar: CzechFormat.calendar()) ?? date
        }
        add(alarm)
        return alarm
    }

    func startTimer(label: String, duration: TimeInterval) async throws -> ClockAlarm {
        try await requestAuthorizationIfNeeded()
        let id = UUID()
        let alarm = ClockAlarm(id: id.uuidString, kind: .timer, label: label, fireDate: Date().addingTimeInterval(duration), duration: duration)
        if #available(iOS 26.0, *) {
            let attrs = AlarmAttributes<OAAlarmMetadata>(
                presentation: Self.presentation(title: label, snooze: false, countdown: true),
                metadata: OAAlarmMetadata(label: label, isTimer: true),
                tintColor: Color(red: 0.37, green: 0.79, blue: 0.75))
            let config = AlarmManager.AlarmConfiguration<OAAlarmMetadata>.timer(duration: duration, attributes: attrs)
            _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
        } else {
            let content = UNMutableNotificationContent()
            content.title = label
            content.body = "Odpočet \(CzechDuration.format(duration)) skončil."
            content.sound = .default
            content.interruptionLevel = .active
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, duration), repeats: false)
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "clk-\(alarm.id)", content: content, trigger: trigger))
        }
        add(alarm)
        return alarm
    }

    func cancel(id: String) throws {
        if #available(iOS 26.0, *), let uuid = UUID(uuidString: id) {
            try? AlarmManager.shared.cancel(id: uuid)
        }
        let center = UNUserNotificationCenter.current()
        let ids = ["clk-\(id)"] + (1...7).map { "clk-\(id)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
        lock.lock(); _registry.removeAll { $0.id == id }; lock.unlock()
        save()
    }

    func activeAlarms() -> [ClockAlarm] {
        prune()
        return registry.sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }
    }

    func stopwatch(_ action: StopwatchAction) -> StopwatchState {
        lock.lock()
        _stopwatch.apply(action, now: Date())
        let st = _stopwatch
        lock.unlock()
        if let d = try? JSONEncoder.withDates.encode(st) { UserDefaults.standard.set(d, forKey: stopwatchKey) }
        bump()
        return st
    }

    // MARK: - AlarmKit pomocné

    @available(iOS 26.0, *)
    static func presentation(title: String, snooze: Bool, countdown: Bool = false) -> AlarmPresentation {
        let snoozeButton = AlarmButton(text: "Odložit", textColor: .white, systemImageName: "zzz")
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title),
                                            secondaryButton: snooze ? snoozeButton : nil,
                                            secondaryButtonBehavior: snooze ? .countdown : nil)
        } else {
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title),
                                            stopButton: AlarmButton(text: "Vypnout", textColor: .white, systemImageName: "stop.circle"),
                                            secondaryButton: snooze ? snoozeButton : nil,
                                            secondaryButtonBehavior: snooze ? .countdown : nil)
        }
        let countdownPresentation = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: countdown ? title : "Odloženo"),
            pauseButton: AlarmButton(text: "Pauza", textColor: .white, systemImageName: "pause.fill"))
        let paused = AlarmPresentation.Paused(
            title: "Pozastaveno",
            resumeButton: AlarmButton(text: "Pokračovat", textColor: .white, systemImageName: "play.fill"))
        return AlarmPresentation(alert: alert, countdown: countdownPresentation, paused: paused)
    }

    @available(iOS 26.0, *)
    static func localeWeekday(_ iso: Int) -> Locale.Weekday? {
        switch iso {
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        case 7: return .sunday
        default: return nil
        }
    }

    // MARK: - Náhrada pro iOS < 26 (notifikace)

    private func scheduleNotificationAlarm(_ a: ClockAlarm) async throws {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = a.label
        content.body = "Budík"
        content.sound = .default
        content.interruptionLevel = .active
        content.categoryIdentifier = NotificationService.categoryReminder
        if a.weekdays.isEmpty, let d = a.fireDate {
            let comps = CzechFormat.calendar().dateComponents([.year, .month, .day, .hour, .minute], from: d)
            try await center.add(UNNotificationRequest(identifier: "clk-\(a.id)", content: content,
                                                       trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        } else {
            for wd in a.weekdays {
                // UNCalendar: 1 = neděle
                let comps = DateComponents(hour: a.hour, minute: a.minute, weekday: wd == 7 ? 1 : wd + 1)
                try await center.add(UNNotificationRequest(identifier: "clk-\(a.id)-\(wd)", content: content,
                                                           trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
            }
        }
    }
}
