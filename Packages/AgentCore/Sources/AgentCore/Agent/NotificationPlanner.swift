import Foundation

/// Lokální notifikace k naplánování (iOS jich drží max. 64 na aplikaci).
public struct PlannedNotification: Equatable, Sendable {
    public var id: String
    public var fireDate: Date
    public var entity: EntityRef
    public var title: String
    public var body: String
}

/// Spočítá, které notifikace mají být naplánované. Obsah je ve výchozím stavu obecný (bez citlivých dat).
public struct NotificationPlanner {
    public var calendar: Calendar
    public var now: Date
    /// Zobrazit název připomínky v notifikaci (iOS ho na zamčené obrazovce stejně skryje, pokud je nastaveno „Náhledy: Po odemknutí“).
    public var showContent: Bool
    public var maxCount: Int = 60
    public var horizonDays: Int = 60

    public init(calendar: Calendar, now: Date, showContent: Bool) {
        self.calendar = calendar; self.now = now; self.showContent = showContent
    }

    public func plan(store: DataStore) throws -> [PlannedNotification] {
        let to = now.addingTimeInterval(Double(horizonDays) * 86400)
        var out: [PlannedNotification] = []
        for (r, d) in try store.reminderOccurrences(from: now.addingTimeInterval(1), to: to, calendar: calendar) {
            let ref = EntityRef(kind: .reminder, id: r.id)
            out.append(PlannedNotification(
                id: "rem-\(r.id)-\(Int(d.timeIntervalSince1970))", fireDate: d, entity: ref,
                title: showContent ? r.title : "Připomínka",
                body: showContent ? (r.recurrence?.czechDescription ?? CzechFormat.relativeDateTime(d, now: now, calendar: calendar))
                                  : "Otevři aplikaci pro podrobnosti."))
        }
        for e in try store.events(from: now, to: to) {
            guard let mins = e.alertMinutes, !e.allDay else { continue }
            let fire = e.startAt.addingTimeInterval(-Double(mins) * 60)
            guard fire > now else { continue }
            out.append(PlannedNotification(
                id: "evt-\(e.id)-\(Int(e.startAt.timeIntervalSince1970))", fireDate: fire, entity: EntityRef(kind: .event, id: e.id),
                title: showContent ? e.title : "Událost",
                body: showContent ? "Začíná \(CzechFormat.atTime(e.startAt, calendar: calendar))" + (e.location.isEmpty ? "" : " – \(e.location)")
                                  : "Za \(mins) min. Otevři aplikaci pro podrobnosti."))
        }
        for t in try store.tasks(.open) {
            guard let due = t.dueAt, t.dueHasTime, due > now, due < to else { continue }
            out.append(PlannedNotification(
                id: "tsk-\(t.id)-\(Int(due.timeIntervalSince1970))", fireDate: due, entity: EntityRef(kind: .task, id: t.id),
                title: showContent ? t.title : "Úkol", body: showContent ? "Termín úkolu" : "Otevři aplikaci pro podrobnosti."))
        }
        return Array(out.sorted { $0.fireDate < $1.fireDate }.prefix(maxCount))
    }
}
