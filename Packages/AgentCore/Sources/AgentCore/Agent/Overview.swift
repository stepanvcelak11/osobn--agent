import Foundation

public enum AgendaRange: String, Sendable, CaseIterable {
    case today, tomorrow, week, nextWeek = "next_week", overdue

    public var czechTitle: String {
        switch self {
        case .today: return "Dnes"
        case .tomorrow: return "Zítra"
        case .week: return "Příštích 7 dní"
        case .nextWeek: return "Příští týden"
        case .overdue: return "Po termínu"
        }
    }
}

public struct AgendaItem: Identifiable, Equatable, Sendable {
    public var id: String { "\(ref.kind.rawValue)-\(ref.id)-\(date.map { Int($0.timeIntervalSince1970) } ?? 0)" }
    public var ref: EntityRef
    public var title: String
    public var date: Date?
    public var endDate: Date?
    public var hasTime: Bool
    public var isOverdue: Bool
    public var recurrenceText: String?
    public var location: String?
    /// Odkud položka pochází, když není z aplikace (např. „Kalendář Apple“).
    public var source: String? = nil

    public var isExternal: Bool { source != nil }
}

/// Událost z jiné aplikace (Kalendář Apple) – jen ke čtení.
public struct ExternalAgendaItem: Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date?
    public var allDay: Bool
    public var location: String?
    public var source: String
    public init(id: String, title: String, start: Date, end: Date?, allDay: Bool, location: String?, source: String) {
        self.id = id; self.title = title; self.start = start; self.end = end; self.allDay = allDay; self.location = location; self.source = source
    }

    var agendaItem: AgendaItem {
        AgendaItem(ref: EntityRef(kind: .event, id: "ext:" + id), title: title, date: start, endDate: end, hasTime: !allDay,
                   isOverdue: false, recurrenceText: nil, location: location, source: source)
    }
}

public struct DayOverview: Sendable {
    public var date: Date
    /// Probíhající událost.
    public var current: AgendaItem?
    /// Nejbližší budoucí věc (událost / připomínka / úkol s časem).
    public var next: AgendaItem?
    public var todayItems: [AgendaItem]
    public var overdueTasks: [AgendaItem]
    public var openTasks: [TaskItem]
    public var upcoming: [AgendaItem]
    public var recentNotes: [Note]
}

/// Sestavuje přehledy z dat – deterministicky, bez modelu.
public struct OverviewBuilder {
    public let store: DataStore
    public let calendar: Calendar
    public let now: Date

    /// Události z Kalendáře Apple (jen když to uživatel povolí).
    public var external: (@Sendable (Date, Date) -> [ExternalAgendaItem])?

    public init(store: DataStore, calendar: Calendar, now: Date = Date(),
                external: (@Sendable (Date, Date) -> [ExternalAgendaItem])? = nil) {
        self.store = store; self.calendar = calendar; self.now = now; self.external = external
    }

    public func interval(_ range: AgendaRange) -> (Date, Date) {
        let today = calendar.startOfDay(for: now)
        switch range {
        case .today: return (today, calendar.date(byAdding: .day, value: 1, to: today)!)
        case .tomorrow:
            let t = calendar.date(byAdding: .day, value: 1, to: today)!
            return (t, calendar.date(byAdding: .day, value: 1, to: t)!)
        case .week: return (today, calendar.date(byAdding: .day, value: 8, to: today)!)
        case .nextWeek:
            let wd = Recurrence.isoWeekday(today, calendar: calendar)
            let mon = calendar.date(byAdding: .day, value: 8 - wd, to: today)!
            return (mon, calendar.date(byAdding: .day, value: 7, to: mon)!)
        case .overdue: return (Date.distantPast, now)
        }
    }

    public func items(_ range: AgendaRange) throws -> [AgendaItem] {
        if range == .overdue { return try overdueTasks() }
        let (from, to) = interval(range)
        var out: [AgendaItem] = []
        for e in try store.events(from: from, to: to) {
            out.append(AgendaItem(ref: EntityRef(kind: .event, id: e.id), title: e.title, date: e.startAt, endDate: e.endAt,
                                  hasTime: !e.allDay, isOverdue: false, recurrenceText: nil,
                                  location: e.location.isEmpty ? nil : e.location))
        }
        for (r, d) in try store.reminderOccurrences(from: from, to: to, calendar: calendar) {
            out.append(AgendaItem(ref: EntityRef(kind: .reminder, id: r.id), title: r.title, date: d, endDate: nil,
                                  hasTime: true, isOverdue: false, recurrenceText: r.recurrence?.czechDescription, location: nil))
        }
        for x in external?(from, to) ?? [] { out.append(x.agendaItem) }
        for t in try store.tasks(.open) {
            guard let due = t.dueAt, due >= from, due < to else { continue }
            out.append(AgendaItem(ref: EntityRef(kind: .task, id: t.id), title: t.title, date: due, endDate: nil,
                                  hasTime: t.dueHasTime, isOverdue: due < now && t.dueHasTime, recurrenceText: nil, location: nil))
        }
        return out.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    public func overdueTasks() throws -> [AgendaItem] {
        let today = calendar.startOfDay(for: now)
        return try store.tasks(.open).compactMap { t in
            guard let due = t.dueAt else { return nil }
            let overdue = t.dueHasTime ? due < now : due < today
            guard overdue else { return nil }
            return AgendaItem(ref: EntityRef(kind: .task, id: t.id), title: t.title, date: due, endDate: nil,
                              hasTime: t.dueHasTime, isOverdue: true, recurrenceText: nil, location: nil)
        }
    }

    public func overview() throws -> DayOverview {
        let todayItems = try items(.today)
        let current = todayItems.first { item in
            guard item.ref.kind == .event, item.hasTime, let s = item.date else { return false }
            let e = item.endDate ?? s.addingTimeInterval(3600)
            return s <= now && now < e
        }
        let (_, weekEnd) = interval(.week)
        let futureWindow = try store.events(from: now, to: weekEnd).map {
            AgendaItem(ref: EntityRef(kind: .event, id: $0.id), title: $0.title, date: $0.startAt, endDate: $0.endAt,
                       hasTime: !$0.allDay, isOverdue: false, recurrenceText: nil, location: $0.location.isEmpty ? nil : $0.location)
        } + (try store.reminderOccurrences(from: now, to: weekEnd, calendar: calendar)).map {
            AgendaItem(ref: EntityRef(kind: .reminder, id: $0.reminder.id), title: $0.reminder.title, date: $0.date, endDate: nil,
                       hasTime: true, isOverdue: false, recurrenceText: $0.reminder.recurrence?.czechDescription, location: nil)
        }
        let futureAll = futureWindow + (external?(now, weekEnd) ?? []).map(\.agendaItem)
        let next = futureAll.filter { ($0.date ?? .distantPast) > now && $0.hasTime }
            .min { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        let tomorrowStart = interval(.tomorrow).0
        let upcoming = try items(.week).filter { ($0.date ?? .distantPast) >= tomorrowStart }
        return DayOverview(date: now, current: current, next: next, todayItems: todayItems,
                           overdueTasks: try overdueTasks(), openTasks: try store.tasks(.open),
                           upcoming: upcoming, recentNotes: try store.notes(limit: 5))
    }

    // MARK: - Texty (pro model i přímou odpověď)

    public func line(_ item: AgendaItem, refs: RefRegistry?, withDay: Bool) -> String {
        var parts: [String] = []
        if let d = item.date {
            if withDay {
                parts.append(CzechFormat.relativeDateTime(d, now: now, calendar: calendar, hasTime: item.hasTime))
            } else if item.hasTime {
                var t = CzechFormat.time(d, calendar: calendar)
                if let e = item.endDate { t += "–" + CzechFormat.time(e, calendar: calendar) }
                parts.append(t)
            }
        }
        let kind: String
        switch item.ref.kind {
        case .event: kind = ""
        case .reminder: kind = "připomínka: "
        case .task: kind = "úkol: "
        case .note: kind = "poznámka: "
        }
        var s = "• " + (parts.isEmpty ? "" : parts.joined(separator: " ") + " – ") + kind + item.title
        if let loc = item.location { s += " (\(loc))" }
        if let r = item.recurrenceText { s += " [opakuje se \(r)]" }
        if let src = item.source { s += " (\(src))" }
        if item.isOverdue { s += " – po termínu" }
        if let refs, !item.isExternal { s += " [\(refs.short(for: item.ref))]" }
        return s
    }

    public func agendaText(_ range: AgendaRange, refs: RefRegistry?) throws -> String {
        let list = try items(range)
        let header: String
        switch range {
        case .today: header = "Dnes (\(CzechFormat.headerDate(now, calendar: calendar).lowercased()))"
        case .tomorrow: header = "Zítra (\(CzechFormat.headerDate(interval(.tomorrow).0, calendar: calendar).lowercased()))"
        default: header = range.czechTitle
        }
        if list.isEmpty {
            switch range {
            case .overdue: return "Nemáš žádné úkoly po termínu."
            case .today: return "\(header): nic naplánovaného."
            default: return "\(header): nic naplánovaného."
            }
        }
        let withDay = !(range == .today || range == .tomorrow)
        var out = "\(header):\n" + list.map { line($0, refs: refs, withDay: withDay) }.joined(separator: "\n")
        if range == .today {
            let overdue = try overdueTasks()
            if !overdue.isEmpty {
                out += "\nPo termínu:\n" + overdue.map { line($0, refs: refs, withDay: true) }.joined(separator: "\n")
            }
        }
        return out
    }

    public func tasksText(done: Bool, refs: RefRegistry?) throws -> String {
        let tasks = try store.tasks(done ? .done : .open, limit: 30)
        if tasks.isEmpty { return done ? "Žádné splněné úkoly." : "Nemáš žádné nesplněné úkoly. 🎉" }
        let lines = tasks.map { t -> String in
            var s = "• " + t.title
            if let d = t.dueAt { s += " – termín " + CzechFormat.relativeDateTime(d, now: now, calendar: calendar, hasTime: t.dueHasTime) }
            if t.priority > 0 { s += " (důležité)" }
            if let refs { s += " [\(refs.short(for: EntityRef(kind: .task, id: t.id)))]" }
            return s
        }
        let title = done ? "Splněné úkoly" : "Nesplněné úkoly (\(tasks.count))"
        return "\(title):\n" + lines.joined(separator: "\n")
    }

    /// Krátké shrnutí dne bez modelu.
    public func deterministicSummary(evening: Bool = false) throws -> String {
        let ov = try overview()
        let events = ov.todayItems.filter { $0.ref.kind == .event }
        let reminders = ov.todayItems.filter { $0.ref.kind == .reminder && ($0.date ?? .distantPast) > now }
        let tasksToday = ov.todayItems.filter { $0.ref.kind == .task }
        var parts: [String] = []
        if evening {
            let tomorrow = try items(.tomorrow)
            let doneToday = try store.tasks(.done).filter { t in t.doneAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false }
            parts.append("Dnes splněno: \(CzechFormat.count(doneToday.count, "úkol", "úkoly", "úkolů")).")
            if tomorrow.isEmpty { parts.append("Zítra zatím nic naplánovaného nemáš.") }
            else {
                parts.append("Zítra tě čeká \(CzechFormat.count(tomorrow.count, "věc", "věci", "věcí")), první \(CzechFormat.relativeDateTime(tomorrow[0].date!, now: now, calendar: calendar, hasTime: tomorrow[0].hasTime)): \(tomorrow[0].title).")
            }
        } else {
            var counts: [String] = []
            if !events.isEmpty { counts.append(CzechFormat.count(events.count, "událost", "události", "událostí")) }
            if !reminders.isEmpty { counts.append(CzechFormat.count(reminders.count, "připomínku", "připomínky", "připomínek")) }
            if !tasksToday.isEmpty { counts.append(CzechFormat.count(tasksToday.count, "úkol", "úkoly", "úkolů") + " s termínem") }
            parts.append(counts.isEmpty ? "Dnes nemáš nic naplánovaného." : "Dnes máš " + CzechFormat.joinedCzech(counts) + ".")
            if let n = ov.next, let d = n.date {
                parts.append("Nejbližší: \(n.title) \(CzechFormat.relativeDateTime(d, now: now, calendar: calendar)).")
            }
        }
        if !ov.overdueTasks.isEmpty {
            parts.append("Po termínu: \(CzechFormat.count(ov.overdueTasks.count, "úkol", "úkoly", "úkolů")).")
        }
        let open = ov.openTasks.count
        if open > 0 && !evening { parts.append("Celkem nesplněno: \(open).") }
        return parts.joined(separator: " ")
    }
}
