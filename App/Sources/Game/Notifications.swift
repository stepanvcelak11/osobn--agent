import Foundation
import UserNotifications
import RealmCore

/// Lokální oznámení pro Živý simulátor (hrozby, dokončené stavby, nový den). Nic neodchází z telefonu.
enum RealmNotifications {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "notify.realm") as? Bool ?? true }

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func reschedule(for state: GameState) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let prefix = "realm.\(state.id)."
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        guard enabled, state.mode.hasSettlement, !state.isOver else { return }
        for n in Simulation.plannedNotifications(state, now: Date()).prefix(40) {
            let content = UNMutableNotificationContent()
            content.title = n.title
            content.body = n.body
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: n.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: prefix + n.id, content: content, trigger: trigger))
        }
    }

    static func cancel(gameId: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("realm.\(gameId).") })
    }
}
