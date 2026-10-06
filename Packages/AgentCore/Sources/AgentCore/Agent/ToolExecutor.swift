import Foundation

public struct AgentSettings: Codable, Equatable, Sendable {
    /// Vyžadovat potvrzení i u vytváření (výchozí: jen mazání a hromadné změny).
    public var confirmAllWrites: Bool = false
    /// Hodina, když je zadán jen den.
    public var defaultHour: Int = 9
    /// Výchozí upozornění před událostí (minuty).
    public var eventAlertMinutes: Int = 15
    /// Kolik zpráv historie posílat modelu.
    public var historyMessages: Int = 6
    public init() {}
}

/// Výsledek provedení nástroje.
public struct ToolOutcome: Sendable {
    /// Záznam akce (u zapisujících nástrojů) – UI z něj vykreslí kartu.
    public var action: ActionRecord?
    /// Výsledek pro model (data).
    public var resultForModel: String
    /// Hotová odpověď pro uživatele (pokud není potřeba model).
    public var replyText: String?
    /// Je potřeba se uživatele doptat.
    public var clarification: String?
    public var isRead: Bool = false
}

public protocol NoteSearching: AnyObject {
    func search(_ query: String, limit: Int) async throws -> [(note: Note, score: Double)]
}

/// Provádí nástroje nad daty. Pravidla bezpečnosti jsou vynucena ZDE v kódu, ne v promptu:
/// mazání vždy čeká na potvrzení uživatelem a nástroje sahají jen na data aplikace.
public final class ToolExecutor: @unchecked Sendable {
    public let store: DataStore
    public let refs: RefRegistry
    public var calendar: Calendar
    public var clock: () -> Date
    public var settings: AgentSettings
    public weak var searcher: NoteSearching?

    public init(store: DataStore, refs: RefRegistry, calendar: Calendar, settings: AgentSettings = AgentSettings(),
                clock: @escaping () -> Date = Date.init) {
        self.store = store; self.refs = refs; self.calendar = calendar; self.settings = settings; self.clock = clock
    }

    var parser: CzechTimeParser { CzechTimeParser(calendar: calendar, now: clock(), defaultHour: settings.defaultHour) }

    // MARK: - Provedení

    public func execute(_ call: ToolCall, source: String) async throws -> ToolOutcome {
        guard let spec = Tools.spec(call.name) else {
            return clarify("Tomuhle nerozumím. Můžeš to říct jinak?")
        }
        for p in spec.params where p.required && p.type != .integer {
            if call.args.nonEmptyString(p.name) == nil {
                return clarify(missingQuestion(tool: spec.name, param: p.name))
            }
        }
        switch spec.name {
        case Tools.createNote.name: return try createNote(call, source: source)
        case Tools.createTask.name: return try createTask(call, source: source)
        case Tools.createReminder.name: return try createReminder(call, source: source)
        case Tools.createEvent.name: return try createEvent(call, source: source)
        case Tools.completeTask.name: return try completeTask(call, source: source)
        case Tools.updateItem.name: return try updateItem(call, source: source)
        case Tools.deleteItem.name: return try deleteItem(call, source: source)
        case Tools.listAgenda.name:
            let range = AgendaRange(rawValue: call.args.nonEmptyString("range") ?? "today") ?? .today
            let text = try OverviewBuilder(store: store, calendar: calendar, now: clock()).agendaText(range, refs: refs)
            return ToolOutcome(action: nil, resultForModel: text, replyText: text, clarification: nil, isRead: true)
        case Tools.listTasks.name:
            let done = call.args.nonEmptyString("status") == "done"
            let text = try OverviewBuilder(store: store, calendar: calendar, now: clock()).tasksText(done: done, refs: refs)
            return ToolOutcome(action: nil, resultForModel: text, replyText: text, clarification: nil, isRead: true)
        case Tools.searchNotes.name: return try await searchNotes(call)
        case Tools.undoLast.name:
            guard let undone = try undoLast() else {
                return ToolOutcome(action: nil, resultForModel: "Není co vracet.", replyText: "Není co vracet.", clarification: nil)
            }
            return ToolOutcome(action: undone, resultForModel: "Vráceno: \(undone.summary)", replyText: "Vráceno zpět: \(undone.summary)", clarification: nil)
        default:
            return clarify("Tomuhle nerozumím.")
        }
    }

    private func clarify(_ q: String) -> ToolOutcome {
        ToolOutcome(action: nil, resultForModel: "Chybí údaj: \(q)", replyText: nil, clarification: q)
    }

    private func missingQuestion(tool: String, param: String) -> String {
        switch (tool, param) {
        case ("create_reminder", "when"): return "Kdy ti to mám připomenout?"
        case ("create_reminder", "title"): return "Co ti mám připomenout?"
        case ("create_event", "start"): return "Kdy ta událost začíná?"
        case ("create_note", "text"): return "Co mám zapsat?"
        case ("create_task", "title"): return "Jaký úkol mám přidat?"
        case (_, "ref"): return "Kterou položku myslíš?"
        default: return "Můžeš to upřesnit?"
        }
    }

    /// Uloží akci – podle pravidel ji rovnou provede, nebo nechá čekat na potvrzení.
    private func record(tool: String, args: JSONValue, summary: String, entity: EntityRef, before: JSONValue?,
                        after: JSONValue?, source: String, notes: [String], forcePending: Bool) throws -> ActionRecord {
        let pending = forcePending || settings.confirmAllWrites
        var a = ActionRecord(createdAt: clock(), tool: tool, args: args, status: .pending, summary: summary,
                             entity: entity, before: before, after: after, source: source, notes: notes)
        try store.db.transaction {
            if !pending { try apply(&a) }
            try store.insert(a)
        }
        _ = refs.short(for: entity)
        return a
    }

    private func apply(_ a: inout ActionRecord) throws {
        guard let entity = a.entity else { return }
        if let after = a.after {
            try store.restore(after, kind: entity.kind)
        } else {
            try store.softDelete(entity, at: clock())
        }
        a.status = .applied
    }

    private func writeOutcome(_ a: ActionRecord) -> ToolOutcome {
        let status = a.status == .pending ? "čeká na potvrzení uživatelem" : "provedeno"
        let ref = a.entity.map { refs.short(for: $0) } ?? ""
        var text = "\(a.summary) – \(status)"
        if !ref.isEmpty { text += " [\(ref)]" }
        let reply = a.status == .pending ? "Potvrď prosím: \(a.summary)" : a.summary
        return ToolOutcome(action: a, resultForModel: text, replyText: reply, clarification: nil)
    }

    // MARK: - Vytváření

    private func cleanTitle(_ s: String) -> String {
        let fillers: Set<String> = ["mi", "me", "mne", "prosim", "at", "abych", "ze", "si", "mam", "pripomen", "pripomenout",
                                    "pripominku", "nastav", "upozorni", "nezapomen", "na", "to", "a", "aby", "jsem", "se", "mel", "mela"]
        return CzechText.capitalizeFirst(CzechText.trimFillers(CzechText.collapseSpaces(s), fillers: fillers))
    }

    private func createNote(_ call: ToolCall, source: String) throws -> ToolOutcome {
        let text = call.args.nonEmptyString("text")!
        var title = call.args.nonEmptyString("title") ?? ""
        if title.isEmpty {
            let words = text.split(separator: " ").prefix(7).joined(separator: " ")
            title = words.count < text.count ? words + "…" : ""
        }
        let now = clock()
        let note = Note(title: title, body: text, createdAt: now)
        let summary = "Poznámka: " + note.displayTitle
        let a = try record(tool: call.name, args: call.args, summary: summary, entity: EntityRef(kind: .note, id: note.id),
                           before: nil, after: JSONValue.from(note), source: source, notes: [], forcePending: false)
        return writeOutcome(a)
    }

    private func createTask(_ call: ToolCall, source: String) throws -> ToolOutcome {
        var title = cleanTitle(call.args.nonEmptyString("title")!)
        var notes: [String] = []
        var due: Date?
        var dueHasTime = false
        if let dueText = call.args.nonEmptyString("due") {
            if let p = parser.parse(dueText), let d = p.date {
                due = d; dueHasTime = p.hasTime
                notes += p.assumptions
            } else {
                notes.append("termín „\(dueText)“ se nepodařilo rozpoznat – úkol je bez termínu")
            }
        } else if let p = parser.parse(title), let d = p.date, p.recurrence == nil {
            // Termín schovaný v názvu („zaplatit nájem do pátku“)
            due = d; dueHasTime = p.hasTime
            title = cleanTitle(parser.remainder(of: title, removing: p.ranges).replacingOccurrences(of: " do", with: ""))
            notes += p.assumptions
        }
        if title.isEmpty { return clarify("Jaký úkol mám přidat?") }
        let priority = call.args.nonEmptyString("priority") == "high" ? 1 : 0
        let task = TaskItem(title: title, dueAt: due, dueHasTime: dueHasTime, priority: priority, createdAt: clock())
        var summary = "Úkol: \(title)"
        if let due { summary += " – termín " + CzechFormat.relativeDateTime(due, now: clock(), calendar: calendar, hasTime: dueHasTime) }
        let a = try record(tool: call.name, args: call.args, summary: summary, entity: EntityRef(kind: .task, id: task.id),
                           before: nil, after: JSONValue.from(task), source: source, notes: notes, forcePending: false)
        return writeOutcome(a)
    }

    private func createReminder(_ call: ToolCall, source: String) throws -> ToolOutcome {
        var title = cleanTitle(call.args.nonEmptyString("title")!)
        let whenText = call.args.nonEmptyString("when")!
        guard let p = parser.parse(whenText), let date = p.date else {
            return clarify("Nerozumím času „\(whenText)“. Kdy ti to mám připomenout?")
        }
        // Model občas nechá čas i v názvu – odstraníme ho.
        if let inTitle = parser.parse(title), !inTitle.ranges.isEmpty {
            let rest = cleanTitle(parser.remainder(of: title, removing: inTitle.ranges))
            if !rest.isEmpty { title = rest }
        }
        let now = clock()
        if p.recurrence == nil && date <= now {
            return clarify("Čas \(CzechFormat.relativeDateTime(date, now: now, calendar: calendar)) už byl. Kdy ti to mám připomenout?")
        }
        var notes = p.assumptions
        if !p.hasTime && p.recurrence == nil {
            notes.append("čas nebyl zadán – nastaveno \(CzechFormat.atTime(date, calendar: calendar))")
        }
        let rem = Reminder(title: title, dueAt: date, recurrence: p.recurrence, createdAt: now)
        let whenDesc = p.recurrence?.czechDescription ?? CzechFormat.relativeDateTime(date, now: now, calendar: calendar)
        let summary = "Připomínka: \(title) – \(whenDesc)"
        let a = try record(tool: call.name, args: call.args, summary: summary, entity: EntityRef(kind: .reminder, id: rem.id),
                           before: nil, after: JSONValue.from(rem), source: source, notes: notes, forcePending: false)
        return writeOutcome(a)
    }

    private func createEvent(_ call: ToolCall, source: String) throws -> ToolOutcome {
        let title = cleanTitle(call.args.nonEmptyString("title")!)
        let startText = call.args.nonEmptyString("start")!
        guard let p = parser.parse(startText), let start = p.date else {
            return clarify("Nerozumím času „\(startText)“. Kdy událost začíná?")
        }
        let duration = call.args["duration_minutes"]?.intValue ?? 60
        let allDay = !p.hasTime
        let end: Date? = allDay ? nil : start.addingTimeInterval(Double(max(5, min(duration, 24 * 60))) * 60)
        let event = Event(title: title, startAt: allDay ? calendar.startOfDay(for: start) : start, endAt: end, allDay: allDay,
                          location: call.args.nonEmptyString("location") ?? "",
                          alertMinutes: allDay ? nil : settings.eventAlertMinutes, createdAt: clock())
        var notes = p.assumptions
        if allDay { notes.append("bez času – celodenní událost") }
        let summary = "Událost: \(title) – " + CzechFormat.relativeDateTime(event.startAt, now: clock(), calendar: calendar, hasTime: !allDay)
        let a = try record(tool: call.name, args: call.args, summary: summary, entity: EntityRef(kind: .event, id: event.id),
                           before: nil, after: JSONValue.from(event), source: source, notes: notes, forcePending: false)
        return writeOutcome(a)
    }

    // MARK: - Úpravy

    enum Resolution { case found(EntityRef), ambiguous([String]), notFound }

    /// Najde položku podle krátkého odkazu nebo názvu.
    func resolve(_ text: String, kinds: [EntityKind]) throws -> Resolution {
        if let r = refs.resolve(text), kinds.contains(r.kind), try store.exists(r) { return .found(r) }
        var candidates: [(EntityRef, String, Double)] = []
        for kind in kinds {
            let items: [(String, String)]
            switch kind {
            case .task: items = try store.tasks(.open).map { ($0.id, $0.title) }
            case .reminder: items = try store.activeReminders().map { ($0.id, $0.title) }
            case .event: items = try store.events(from: clock().addingTimeInterval(-86400 * 2), to: clock().addingTimeInterval(86400 * 60)).map { ($0.id, $0.title) }
            case .note: items = try store.notes(limit: 300).map { ($0.id, $0.displayTitle) }
            }
            for (id, title) in items {
                let s = CzechText.similarity(text, title)
                if s >= 0.5 { candidates.append((EntityRef(kind: kind, id: id), title, s)) }
            }
        }
        guard let best = candidates.max(by: { $0.2 < $1.2 }) else { return .notFound }
        let top = candidates.filter { $0.2 >= best.2 - 0.001 }
        if top.count == 1 { return .found(best.0) }
        return .ambiguous(top.prefix(5).map { "\($0.1) [\(refs.short(for: $0.0))]" })
    }

    private func resolutionFailure(_ r: Resolution, what: String) -> ToolOutcome {
        switch r {
        case .ambiguous(let list): return clarify("Odpovídá víc položek: \(list.joined(separator: ", ")). Kterou myslíš?")
        default: return clarify("Tohle se nepodařilo najít (\(what)). Jak se to jmenuje?")
        }
    }

    private func completeTask(_ call: ToolCall, source: String) throws -> ToolOutcome {
        let r = try resolve(call.args.nonEmptyString("ref")!, kinds: [.task])
        guard case .found(let ref) = r, var task = try store.task(id: ref.id) else { return resolutionFailure(r, what: "takový úkol") }
        let before = JSONValue.from(task)
        task.doneAt = clock(); task.updatedAt = clock()
        let a = try record(tool: call.name, args: call.args, summary: "Splněno: \(task.title)", entity: ref, before: before,
                           after: JSONValue.from(task), source: source, notes: [], forcePending: false)
        return writeOutcome(a)
    }

    private func updateItem(_ call: ToolCall, source: String) throws -> ToolOutcome {
        let r = try resolve(call.args.nonEmptyString("ref")!, kinds: [.task, .reminder, .event, .note])
        guard case .found(let ref) = r, let before = try store.snapshot(ref) else { return resolutionFailure(r, what: "takovou položku") }
        let newTitle = call.args.nonEmptyString("title").map(cleanTitle)
        let whenText = call.args.nonEmptyString("when")
        let newText = call.args.nonEmptyString("text")
        var parsed: ParsedTime?
        if let whenText {
            guard let p = parser.parse(whenText), p.date != nil else { return clarify("Nerozumím času „\(whenText)“.") }
            parsed = p
        }
        let now = clock()
        var after: JSONValue
        var summary: String
        switch ref.kind {
        case .note:
            guard var n = before.decode(Note.self) else { return clarify("Položku nelze upravit.") }
            if let newTitle { n.title = newTitle }
            if let newText { n.body = newText }
            n.updatedAt = now
            after = JSONValue.from(n); summary = "Upravena poznámka: \(n.displayTitle)"
        case .task:
            guard var t = before.decode(TaskItem.self) else { return clarify("Položku nelze upravit.") }
            if let newTitle { t.title = newTitle }
            if let p = parsed { t.dueAt = p.date; t.dueHasTime = p.hasTime }
            if let newText { t.details = newText }
            t.updatedAt = now
            after = JSONValue.from(t); summary = "Upraven úkol: \(t.title)"
        case .reminder:
            guard var rem = before.decode(Reminder.self) else { return clarify("Položku nelze upravit.") }
            if let newTitle { rem.title = newTitle }
            if let p = parsed { rem.dueAt = p.date!; rem.recurrence = p.recurrence; rem.doneAt = nil }
            rem.updatedAt = now
            after = JSONValue.from(rem)
            summary = "Upravena připomínka: \(rem.title) – " + (rem.recurrence?.czechDescription ?? CzechFormat.relativeDateTime(rem.dueAt, now: now, calendar: calendar))
        case .event:
            guard var e = before.decode(Event.self) else { return clarify("Položku nelze upravit.") }
            if let newTitle { e.title = newTitle }
            if let p = parsed, let d = p.date {
                let dur = e.endAt.map { $0.timeIntervalSince(e.startAt) } ?? 3600
                e.startAt = d; e.endAt = d.addingTimeInterval(dur); e.allDay = !p.hasTime
            }
            if let newText { e.details = newText }
            e.updatedAt = now
            after = JSONValue.from(e)
            summary = "Upravena událost: \(e.title) – " + CzechFormat.relativeDateTime(e.startAt, now: now, calendar: calendar, hasTime: !e.allDay)
        }
        let a = try record(tool: call.name, args: call.args, summary: summary, entity: ref, before: before, after: after,
                           source: source, notes: parsed?.assumptions ?? [], forcePending: false)
        return writeOutcome(a)
    }

    private func deleteItem(_ call: ToolCall, source: String) throws -> ToolOutcome {
        let r = try resolve(call.args.nonEmptyString("ref")!, kinds: [.task, .reminder, .event, .note])
        guard case .found(let ref) = r, let before = try store.snapshot(ref) else { return resolutionFailure(r, what: "takovou položku") }
        let title = before["title"]?.stringValue ?? ""
        let label = title.isEmpty ? ref.kind.czechName : "\(ref.kind.czechName.lowercased()) „\(title)“"
        // Mazání VŽDY čeká na potvrzení uživatelem – model ho nemůže provést sám.
        let a = try record(tool: call.name, args: call.args, summary: "Smazat \(label)", entity: ref, before: before,
                           after: nil, source: source, notes: [], forcePending: true)
        return writeOutcome(a)
    }

    // MARK: - Hledání

    private func searchNotes(_ call: ToolCall) async throws -> ToolOutcome {
        let q = call.args.nonEmptyString("query")!
        var results: [(Note, Double)] = []
        if let searcher { results = try await searcher.search(q, limit: 5) }
        else { results = try store.searchNotes(q, limit: 5).map { ($0, 1.0) } }
        if results.isEmpty {
            return ToolOutcome(action: nil, resultForModel: "Nic nenalezeno.", replyText: "V poznámkách není nic, co by odpovídalo.", clarification: nil, isRead: true)
        }
        let now = clock()
        let lines = results.map { (n, _) -> String in
            let snippet = n.body.count > 400 ? String(n.body.prefix(400)) + "…" : n.body
            let date = CzechFormat.relativeDay(n.updatedAt, now: now, calendar: calendar)
            return "[\(refs.short(for: EntityRef(kind: .note, id: n.id)))] \(n.displayTitle) (\(date)):\n\(snippet)"
        }
        let text = lines.joined(separator: "\n\n")
        let reply = "Nalezené poznámky:\n" + results.map { "• \($0.0.displayTitle)" }.joined(separator: "\n")
        return ToolOutcome(action: nil, resultForModel: text, replyText: reply, clarification: nil, isRead: true)
    }

    // MARK: - Potvrzení, zamítnutí, zpět

    @discardableResult
    public func confirm(actionId: String) throws -> ActionRecord {
        guard var a = try store.action(id: actionId) else { throw ExecutorError.notFound }
        guard a.status == .pending else { return a }
        try store.db.transaction {
            try apply(&a)
            try store.update(a)
        }
        return a
    }

    @discardableResult
    public func reject(actionId: String) throws -> ActionRecord {
        guard var a = try store.action(id: actionId) else { throw ExecutorError.notFound }
        guard a.status == .pending else { return a }
        a.status = .rejected
        try store.update(a)
        return a
    }

    @discardableResult
    public func undo(actionId: String) throws -> ActionRecord {
        guard var a = try store.action(id: actionId) else { throw ExecutorError.notFound }
        guard a.status == .applied, let entity = a.entity else { return a }
        try store.db.transaction {
            if let before = a.before {
                try store.restore(before, kind: entity.kind)
            } else {
                try store.hardDelete(entity)
            }
            a.status = .undone
            try store.update(a)
        }
        return a
    }

    public func undoLast() throws -> ActionRecord? {
        guard let last = try store.lastAppliedAction() else { return nil }
        return try undo(actionId: last.id)
    }

    /// Ruční úprava z karty („Upravit“) – zapíše se jako akce, aby šla vrátit.
    @discardableResult
    public func recordUserEdit(ref: EntityRef, after: JSONValue, summary: String) throws -> ActionRecord {
        let before = try store.snapshot(ref)
        var a = ActionRecord(createdAt: clock(), tool: "user_edit", args: .object([:]), status: .pending, summary: summary,
                             entity: ref, before: before, after: after, source: "uživatel")
        try store.db.transaction {
            try apply(&a)
            try store.insert(a)
        }
        return a
    }

    /// Úprava čekající akce před potvrzením (změní plánovaný stav).
    @discardableResult
    public func amendPending(actionId: String, after: JSONValue, summary: String) throws -> ActionRecord {
        guard var a = try store.action(id: actionId) else { throw ExecutorError.notFound }
        a.after = after
        a.summary = summary
        try store.update(a)
        return a
    }

    public enum ExecutorError: Error { case notFound }
}
