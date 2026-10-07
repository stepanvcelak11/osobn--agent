import Foundation
import EventKit
import UIKit
import AgentCore

/// Propojení s Kalendářem a Připomínkami Apple (EventKit) a s Poznámkami Apple přes Zkratky.
/// Vše je volitelné a ve výchozím stavu VYPNUTÉ. Zdrojem pravdy zůstává šifrovaná databáze aplikace;
/// do Apple aplikací se zapisuje kopie (události, připomínky, úkoly) a změny/smazání/„Zpět“ se propisují.
/// Notifikace dál posílá jen tato aplikace (kopie v Apple aplikacích jsou bez upozornění, aby nechodily dvakrát).
final class AppleIntegration: ObservableObject, @unchecked Sendable {
    static let systemEvent = "ek.event"
    static let systemReminder = "ek.reminder"

    let eventStore = EKEventStore()
    @Published private(set) var version = 0
    private let queue = DispatchQueue(label: "cz.osobniagent.eventkit")

    // MARK: - Nastavení (UserDefaults – jen přepínače a ID kalendářů, žádná data)

    private let d = UserDefaults.standard
    var calendarSyncOn: Bool { get { d.bool(forKey: "ek.cal.on") } set { d.set(newValue, forKey: "ek.cal.on"); bump() } }
    var calendarReadOn: Bool { get { d.bool(forKey: "ek.cal.read") } set { d.set(newValue, forKey: "ek.cal.read"); bump() } }
    var calendarId: String? { get { d.string(forKey: "ek.cal.id") } set { d.set(newValue, forKey: "ek.cal.id"); bump() } }
    var remindersSyncOn: Bool { get { d.bool(forKey: "ek.rem.on") } set { d.set(newValue, forKey: "ek.rem.on"); bump() } }
    var tasksSyncOn: Bool { get { d.bool(forKey: "ek.tasks.on") } set { d.set(newValue, forKey: "ek.tasks.on"); bump() } }
    var reminderListId: String? { get { d.string(forKey: "ek.rem.id") } set { d.set(newValue, forKey: "ek.rem.id"); bump() } }
    var notesShortcutName: String { get { d.string(forKey: "notes.shortcut") ?? "Uložit do Poznámek" } set { d.set(newValue, forKey: "notes.shortcut"); bump() } }

    private func bump() { DispatchQueue.main.async { self.version += 1 } }

    // MARK: - Oprávnění

    var calendarAuthorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    var remindersAuthorized: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }

    func requestCalendarAccess() async -> Bool {
        let ok = (try? await eventStore.requestFullAccessToEvents()) ?? false
        bump()
        return ok
    }

    func requestRemindersAccess() async -> Bool {
        let ok = (try? await eventStore.requestFullAccessToReminders()) ?? false
        bump()
        return ok
    }

    func writableCalendars() -> [EKCalendar] {
        guard calendarAuthorized else { return [] }
        return eventStore.calendars(for: .event).filter(\.allowsContentModifications).sorted { $0.title < $1.title }
    }

    func reminderLists() -> [EKCalendar] {
        guard remindersAuthorized else { return [] }
        return eventStore.calendars(for: .reminder).filter(\.allowsContentModifications).sorted { $0.title < $1.title }
    }

    private var targetCalendar: EKCalendar? {
        if let id = calendarId, let c = eventStore.calendar(withIdentifier: id), c.allowsContentModifications { return c }
        return eventStore.defaultCalendarForNewEvents
    }

    private var targetReminderList: EKCalendar? {
        if let id = reminderListId, let c = eventStore.calendar(withIdentifier: id), c.allowsContentModifications { return c }
        return eventStore.defaultCalendarForNewReminders()
    }

    // MARK: - Zrcadlení

    /// Zavolá se po každé změně položky v aplikaci.
    func entityChanged(_ ref: EntityRef, store: DataStore) {
        queue.async { [weak self] in self?.mirror(ref, store: store) }
    }

    private func mirror(_ ref: EntityRef, store: DataStore) {
        switch ref.kind {
        case .event:
            guard calendarSyncOn, calendarAuthorized else { return }
            mirrorEvent(ref, store: store)
        case .reminder:
            guard remindersSyncOn, remindersAuthorized else { return }
            mirrorReminder(ref, store: store)
        case .task:
            guard tasksSyncOn, remindersAuthorized else { return }
            mirrorReminder(ref, store: store)
        case .note:
            return
        }
    }

    private func mirrorEvent(_ ref: EntityRef, store: DataStore) {
        let existingId = try? store.externalId(ref, system: Self.systemEvent)
        let existing = existingId.flatMap { eventStore.event(withIdentifier: $0) }
        guard let e = try? store.event(id: ref.id), e.deletedAt == nil else {
            if let existing { try? eventStore.remove(existing, span: .thisEvent, commit: true) }
            try? store.setExternalId(nil, for: ref, system: Self.systemEvent)
            return
        }
        let ek = existing ?? EKEvent(eventStore: eventStore)
        if existing == nil { ek.calendar = targetCalendar }
        guard ek.calendar != nil else { return }
        ek.title = e.title
        ek.startDate = e.startAt
        ek.endDate = e.endAt ?? e.startAt.addingTimeInterval(e.allDay ? 86400 : 3600)
        ek.isAllDay = e.allDay
        ek.location = e.location.isEmpty ? nil : e.location
        ek.notes = e.details.isEmpty ? nil : e.details
        ek.alarms = nil   // upozornění posílá aplikace (obecný text na zamčené obrazovce)
        do {
            try eventStore.save(ek, span: .thisEvent, commit: true)
            try store.setExternalId(ek.eventIdentifier, for: ref, system: Self.systemEvent)
        } catch {}
    }

    private func mirrorReminder(_ ref: EntityRef, store: DataStore) {
        let existingId = try? store.externalId(ref, system: Self.systemReminder)
        let existing = existingId.flatMap { eventStore.calendarItem(withIdentifier: $0) as? EKReminder }
        let cal = CzechFormat.calendar()

        var title: String?
        var due: DateComponents?
        var completed = false
        var rule: EKRecurrenceRule?
        var priority = 0
        var notes: String?
        if ref.kind == .reminder, let r = try? store.reminder(id: ref.id), r.deletedAt == nil {
            title = r.title
            due = cal.dateComponents([.year, .month, .day, .hour, .minute], from: r.dueAt)
            completed = r.recurrence == nil && r.doneAt != nil
            rule = r.recurrence.map(Self.ekRule)
        } else if ref.kind == .task, let t = try? store.task(id: ref.id), t.deletedAt == nil {
            title = t.title
            if let d = t.dueAt { due = cal.dateComponents(t.dueHasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day], from: d) }
            completed = t.isDone
            priority = t.priority > 0 ? 1 : 0
            notes = t.details.isEmpty ? nil : t.details
        }
        guard let title else {
            if let existing { try? eventStore.remove(existing, commit: true) }
            try? store.setExternalId(nil, for: ref, system: Self.systemReminder)
            return
        }
        let rem = existing ?? EKReminder(eventStore: eventStore)
        if existing == nil { rem.calendar = targetReminderList }
        guard rem.calendar != nil else { return }
        rem.title = title
        rem.dueDateComponents = due
        rem.isCompleted = completed
        rem.priority = priority
        rem.notes = notes
        rem.recurrenceRules = rule.map { [$0] }
        rem.alarms = nil
        do {
            try eventStore.save(rem, commit: true)
            try store.setExternalId(rem.calendarItemIdentifier, for: ref, system: Self.systemReminder)
        } catch {}
    }

    static func ekRule(_ r: Recurrence) -> EKRecurrenceRule {
        switch r.frequency {
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: r.interval, end: nil)
        case .weekly:
            let days = r.weekdays.compactMap { EKWeekday(rawValue: $0 == 7 ? 1 : $0 + 1) }.map { EKRecurrenceDayOfWeek($0) }
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: r.interval, daysOfTheWeek: days.isEmpty ? nil : days,
                                    daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil,
                                    setPositions: nil, end: nil)
        case .monthly:
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: r.interval, daysOfTheWeek: nil,
                                    daysOfTheMonth: r.monthDay.map { [NSNumber(value: $0)] }, monthsOfTheYear: nil,
                                    weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
        case .yearly:
            return EKRecurrenceRule(recurrenceWith: .yearly, interval: r.interval, end: nil)
        }
    }

    /// Po zapnutí synchronizace zkopíruje budoucí události / aktivní připomínky / nesplněné úkoly.
    func syncAll(store: DataStore) {
        queue.async { [weak self] in
            guard let self else { return }
            let now = Date()
            if self.calendarSyncOn, self.calendarAuthorized {
                for e in (try? store.events(from: now.addingTimeInterval(-86400), to: now.addingTimeInterval(86400 * 365))) ?? [] {
                    self.mirrorEvent(EntityRef(kind: .event, id: e.id), store: store)
                }
            }
            if self.remindersSyncOn, self.remindersAuthorized {
                for r in (try? store.activeReminders()) ?? [] { self.mirrorReminder(EntityRef(kind: .reminder, id: r.id), store: store) }
            }
            if self.tasksSyncOn, self.remindersAuthorized {
                for t in (try? store.tasks(.open)) ?? [] { self.mirrorReminder(EntityRef(kind: .task, id: t.id), store: store) }
            }
        }
    }

    // MARK: - Čtení Kalendáře Apple (jen s povolením)

    /// Události z Kalendáře Apple (bez našich vlastních kopií).
    func externalEvents(from: Date, to: Date, store: DataStore) -> [ExternalAgendaItem] {
        guard calendarReadOn, calendarAuthorized else { return [] }
        let ours = (try? store.externalIds(system: Self.systemEvent)) ?? []
        let pred = eventStore.predicateForEvents(withStart: from, end: to, calendars: nil)
        return eventStore.events(matching: pred)
            .filter { !ours.contains($0.eventIdentifier ?? "") }
            .map { ev in
                ExternalAgendaItem(id: ev.eventIdentifier ?? UUID().uuidString, title: ev.title ?? "(bez názvu)",
                                   start: ev.startDate, end: ev.endDate, allDay: ev.isAllDay,
                                   location: (ev.location?.isEmpty ?? true) ? nil : ev.location,
                                   source: "Kalendář Apple")
            }
    }

    // MARK: - Poznámky Apple přes Zkratky

    /// Odešle text do Poznámek Apple pomocí zkratky uživatele. Aplikace se na chvíli přepne do Zkratek a vrátí se zpět.
    @MainActor
    func sendToAppleNotes(title: String, body: String) -> Bool {
        let text = title.isEmpty ? body : title + "\n\n" + body
        var c = URLComponents()
        c.scheme = "shortcuts"
        c.host = "x-callback-url"
        c.path = "/run-shortcut"
        c.queryItems = [
            URLQueryItem(name: "name", value: notesShortcutName),
            URLQueryItem(name: "input", value: "text"),
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "x-success", value: "osobniagent://returned"),
            URLQueryItem(name: "x-cancel", value: "osobniagent://returned"),
            URLQueryItem(name: "x-error", value: "osobniagent://returned"),
        ]
        guard let url = c.url else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
