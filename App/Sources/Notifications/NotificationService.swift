import Foundation
import UserNotifications
import AgentCore

/// Lokální notifikace. iOS je doručí i při zavřené aplikaci a v úsporném režimu – plánuje je systém.
/// Obsah je ve výchozím stavu obecný; podrobnosti až po odemčení aplikace.
@MainActor
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    @Published private(set) var authorized: Bool = false
    /// Notifikace, na kterou uživatel klepl (po odemčení se otevře přehled/chat).
    @Published var openedFromNotification: String?

    private let center = UNUserNotificationCenter.current()
    static let categoryReminder = "OA_REMINDER"
    static let categorySummary = "OA_SUMMARY"
    static let actionSnooze10 = "OA_SNOOZE_10"
    static let actionSnooze60 = "OA_SNOOZE_60"
    private let managedPrefixes = ["rem-", "evt-", "tsk-"]

    func configure() {
        center.delegate = self
        let snooze10 = UNNotificationAction(identifier: Self.actionSnooze10, title: "Odložit o 10 minut", options: [])
        let snooze60 = UNNotificationAction(identifier: Self.actionSnooze60, title: "Odložit o hodinu", options: [])
        let reminder = UNNotificationCategory(identifier: Self.categoryReminder, actions: [snooze10, snooze60], intentIdentifiers: [],
                                              hiddenPreviewsBodyPlaceholder: "Připomínka", options: [])
        let summary = UNNotificationCategory(identifier: Self.categorySummary, actions: [], intentIdentifiers: [],
                                             hiddenPreviewsBodyPlaceholder: "Přehled dne", options: [])
        center.setNotificationCategories([reminder, summary])
        Task { await refreshAuthorization() }
    }

    func refreshAuthorization() async {
        let s = await center.notificationSettings()
        authorized = s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorization()
    }

    var showContent: Bool {
        get { UserDefaults.standard.bool(forKey: "notif.showContent") }
        set { UserDefaults.standard.set(newValue, forKey: "notif.showContent") }
    }

    /// Přeplánuje všechny notifikace podle dat (volá se po každé změně, když je aplikace odemčená).
    func reschedule(store: DataStore, calendar: Calendar) async {
        let planner = NotificationPlanner(calendar: calendar, now: Date(), showContent: showContent)
        guard let plan = try? planner.plan(store: store) else { return }
        let pending = await center.pendingNotificationRequests()
        let wanted = Set(plan.map(\.id))
        let stale = pending.map(\.identifier).filter { id in managedPrefixes.contains { id.hasPrefix($0) } && !wanted.contains(id) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        let existing = Set(pending.map(\.identifier))
        for p in plan {
            // Obsah se může změnit (např. zapnutí zobrazování názvů) – přeplánujeme vždy.
            if existing.contains(p.id) { center.removePendingNotificationRequests(withIdentifiers: [p.id]) }
            let content = UNMutableNotificationContent()
            content.title = p.title
            content.body = p.body
            content.sound = .default
            content.categoryIdentifier = Self.categoryReminder
            content.interruptionLevel = .active
            content.threadIdentifier = "osobni-agent"
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: p.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: p.id, content: content, trigger: trigger))
        }
        await scheduleSummaries()
    }

    // MARK: - Ranní / večerní přehled

    struct SummarySettings {
        var morningEnabled: Bool
        var morningMinutes: Int   // minuty od půlnoci
        var eveningEnabled: Bool
        var eveningMinutes: Int
    }

    var summarySettings: SummarySettings {
        get {
            let d = UserDefaults.standard
            return SummarySettings(morningEnabled: d.object(forKey: "sum.morning.on") as? Bool ?? true,
                                   morningMinutes: d.object(forKey: "sum.morning.min") as? Int ?? 7 * 60 + 30,
                                   eveningEnabled: d.object(forKey: "sum.evening.on") as? Bool ?? false,
                                   eveningMinutes: d.object(forKey: "sum.evening.min") as? Int ?? 21 * 60)
        }
        set {
            let d = UserDefaults.standard
            d.set(newValue.morningEnabled, forKey: "sum.morning.on"); d.set(newValue.morningMinutes, forKey: "sum.morning.min")
            d.set(newValue.eveningEnabled, forKey: "sum.evening.on"); d.set(newValue.eveningMinutes, forKey: "sum.evening.min")
        }
    }

    func scheduleSummaries() async {
        center.removePendingNotificationRequests(withIdentifiers: ["sum-morning", "sum-evening"])
        let s = summarySettings
        if s.morningEnabled {
            await addDaily(id: "sum-morning", minutes: s.morningMinutes, title: "Dobré ráno", body: "Tvůj přehled dne je připravený.")
        }
        if s.eveningEnabled {
            await addDaily(id: "sum-evening", minutes: s.eveningMinutes, title: "Večerní shrnutí", body: "Podívej se, co bylo dnes a co tě čeká zítra.")
        }
    }

    private func addDaily(id: String, minutes: Int, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categorySummary
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func removeAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Delegát

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let req = response.notification.request
        switch response.actionIdentifier {
        case Self.actionSnooze10, Self.actionSnooze60:
            // Odložení bez přístupu k databázi – zkopíruje se obsah notifikace.
            let minutes = response.actionIdentifier == Self.actionSnooze10 ? 10 : 60
            guard let content = req.content.mutableCopy() as? UNMutableNotificationContent else { return }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "snooze-\(UUID().uuidString)", content: content, trigger: trigger))
        default:
            let id = req.identifier
            await MainActor.run { self.openedFromNotification = id }
        }
    }
}
