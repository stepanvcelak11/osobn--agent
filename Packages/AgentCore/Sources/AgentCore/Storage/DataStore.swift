import Foundation

/// Přístup k datům aplikace. Vše leží v šifrované databázi SQLCipher.
public final class DataStore: @unchecked Sendable {
    public let db: Database
    /// Volá se po každé změně dat (UI, přeplánování notifikací).
    public var onChange: (() -> Void)?

    public init(database: Database) throws {
        self.db = database
        try Schema.migrate(database)
    }

    /// Otevře šifrovanou databázi v souboru.
    public static func open(path: String, key: Data) throws -> DataStore {
        try DataStore(database: Database(path: path, key: key))
    }

    /// Pro testy: šifrovaná databáze v paměti.
    public static func inMemory() throws -> DataStore {
        try DataStore(database: Database(path: ":memory:", key: Data((0..<32).map { _ in UInt8.random(in: 0...255) })))
    }

    func changed() { onChange?() }

    // MARK: - Poznámky

    public func insert(_ n: Note) throws {
        try db.execute("INSERT INTO notes (id, title, body, created_at, updated_at, deleted_at) VALUES (?,?,?,?,?,?)",
                       [n.id, n.title, n.body, n.createdAt, n.updatedAt, n.deletedAt])
        changed()
    }

    public func update(_ n: Note) throws {
        try db.execute("UPDATE notes SET title=?, body=?, updated_at=?, deleted_at=? WHERE id=?",
                       [n.title, n.body, n.updatedAt, n.deletedAt, n.id])
        changed()
    }

    public func note(id: String) throws -> Note? {
        try db.query("SELECT * FROM notes WHERE id=?", [id]).first.map(Self.note(from:))
    }

    public func notes(limit: Int = 200, includeDeleted: Bool = false) throws -> [Note] {
        let w = includeDeleted ? "" : "WHERE deleted_at IS NULL"
        return try db.query("SELECT * FROM notes \(w) ORDER BY updated_at DESC LIMIT ?", [limit]).map(Self.note(from:))
    }

    /// Fulltextové hledání (bez ohledu na diakritiku).
    public func searchNotes(_ query: String, limit: Int = 20) throws -> [Note] {
        let terms = CzechText.fold(query)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
        guard !terms.isEmpty else { return [] }
        // Prefixové hledání každého slova, spojené OR – kvůli skloňování.
        let match = terms.map { "\"\(String($0.prefix(max(3, $0.count - 2))))\"*" }.joined(separator: " OR ")
        let rows = try db.query("""
            SELECT notes.* FROM notes_fts JOIN notes ON notes.rowid = notes_fts.rowid
            WHERE notes_fts MATCH ? AND notes.deleted_at IS NULL
            ORDER BY bm25(notes_fts) LIMIT ?
            """, [match, limit])
        return rows.map(Self.note(from:))
    }

    static func note(from r: Row) -> Note {
        Note(id: r.string("id")!, title: r.string("title") ?? "", body: r.string("body") ?? "",
             createdAt: r.date("created_at")!, updatedAt: r.date("updated_at"), deletedAt: r.date("deleted_at"))
    }

    // MARK: - Úkoly

    public func insert(_ t: TaskItem) throws {
        try db.execute("""
            INSERT INTO tasks (id, title, details, due_at, due_has_time, done_at, priority, created_at, updated_at, deleted_at)
            VALUES (?,?,?,?,?,?,?,?,?,?)
            """, [t.id, t.title, t.details, t.dueAt, t.dueHasTime, t.doneAt, t.priority, t.createdAt, t.updatedAt, t.deletedAt])
        changed()
    }

    public func update(_ t: TaskItem) throws {
        try db.execute("""
            UPDATE tasks SET title=?, details=?, due_at=?, due_has_time=?, done_at=?, priority=?, updated_at=?, deleted_at=? WHERE id=?
            """, [t.title, t.details, t.dueAt, t.dueHasTime, t.doneAt, t.priority, t.updatedAt, t.deletedAt, t.id])
        changed()
    }

    public func task(id: String) throws -> TaskItem? {
        try db.query("SELECT * FROM tasks WHERE id=?", [id]).first.map(Self.task(from:))
    }

    public enum TaskFilter: String, Sendable { case open, done, all }

    public func tasks(_ filter: TaskFilter = .open, limit: Int = 500) throws -> [TaskItem] {
        let w: String
        switch filter {
        case .open: w = "deleted_at IS NULL AND done_at IS NULL"
        case .done: w = "deleted_at IS NULL AND done_at IS NOT NULL"
        case .all: w = "deleted_at IS NULL"
        }
        // Nejdřív s termínem (podle termínu), pak bez termínu (nejnovější).
        return try db.query("""
            SELECT * FROM tasks WHERE \(w)
            ORDER BY CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, due_at ASC, priority DESC, created_at DESC LIMIT ?
            """, [limit]).map(Self.task(from:))
    }

    static func task(from r: Row) -> TaskItem {
        TaskItem(id: r.string("id")!, title: r.string("title") ?? "", details: r.string("details") ?? "",
                 dueAt: r.date("due_at"), dueHasTime: r.bool("due_has_time"), doneAt: r.date("done_at"),
                 priority: r.int("priority") ?? 0, createdAt: r.date("created_at")!, updatedAt: r.date("updated_at"),
                 deletedAt: r.date("deleted_at"))
    }

    // MARK: - Události

    public func insert(_ e: Event) throws {
        try db.execute("""
            INSERT INTO events (id, title, start_at, end_at, all_day, location, details, alert_minutes, created_at, updated_at, deleted_at)
            VALUES (?,?,?,?,?,?,?,?,?,?,?)
            """, [e.id, e.title, e.startAt, e.endAt, e.allDay, e.location, e.details, e.alertMinutes, e.createdAt, e.updatedAt, e.deletedAt])
        changed()
    }

    public func update(_ e: Event) throws {
        try db.execute("""
            UPDATE events SET title=?, start_at=?, end_at=?, all_day=?, location=?, details=?, alert_minutes=?, updated_at=?, deleted_at=? WHERE id=?
            """, [e.title, e.startAt, e.endAt, e.allDay, e.location, e.details, e.alertMinutes, e.updatedAt, e.deletedAt, e.id])
        changed()
    }

    public func event(id: String) throws -> Event? {
        try db.query("SELECT * FROM events WHERE id=?", [id]).first.map(Self.event(from:))
    }

    /// Události, které zasahují do intervalu [from, to).
    public func events(from: Date, to: Date) throws -> [Event] {
        try db.query("""
            SELECT * FROM events WHERE deleted_at IS NULL
            AND start_at < ? AND COALESCE(end_at, start_at + 3600) > ?
            ORDER BY start_at ASC
            """, [to, from]).map(Self.event(from:))
    }

    public func allEvents(limit: Int = 500) throws -> [Event] {
        try db.query("SELECT * FROM events WHERE deleted_at IS NULL ORDER BY start_at DESC LIMIT ?", [limit]).map(Self.event(from:))
    }

    static func event(from r: Row) -> Event {
        Event(id: r.string("id")!, title: r.string("title") ?? "", startAt: r.date("start_at")!, endAt: r.date("end_at"),
              allDay: r.bool("all_day"), location: r.string("location") ?? "", details: r.string("details") ?? "",
              alertMinutes: r.int("alert_minutes"), createdAt: r.date("created_at")!, updatedAt: r.date("updated_at"),
              deletedAt: r.date("deleted_at"))
    }

    // MARK: - Připomínky

    public func insert(_ rem: Reminder) throws {
        try db.execute("""
            INSERT INTO reminders (id, title, due_at, recurrence, done_at, created_at, updated_at, deleted_at)
            VALUES (?,?,?,?,?,?,?,?)
            """, [rem.id, rem.title, rem.dueAt, Self.encodeRecurrence(rem.recurrence), rem.doneAt, rem.createdAt, rem.updatedAt, rem.deletedAt])
        changed()
    }

    public func update(_ rem: Reminder) throws {
        try db.execute("""
            UPDATE reminders SET title=?, due_at=?, recurrence=?, done_at=?, updated_at=?, deleted_at=? WHERE id=?
            """, [rem.title, rem.dueAt, Self.encodeRecurrence(rem.recurrence), rem.doneAt, rem.updatedAt, rem.deletedAt, rem.id])
        changed()
    }

    public func reminder(id: String) throws -> Reminder? {
        try db.query("SELECT * FROM reminders WHERE id=?", [id]).first.map(Self.reminder(from:))
    }

    /// Aktivní připomínky (nesmazané; jednorázové jen nesplněné).
    public func activeReminders() throws -> [Reminder] {
        try db.query("""
            SELECT * FROM reminders WHERE deleted_at IS NULL AND (done_at IS NULL OR recurrence IS NOT NULL)
            ORDER BY due_at ASC
            """).map(Self.reminder(from:))
    }

    /// Výskyty připomínek v intervalu (včetně opakovaných).
    public func reminderOccurrences(from: Date, to: Date, calendar: Calendar) throws -> [(reminder: Reminder, date: Date)] {
        var out: [(Reminder, Date)] = []
        for r in try activeReminders() {
            if let rec = r.recurrence {
                for d in rec.occurrences(from: from, to: to, anchor: r.dueAt, calendar: calendar, limit: 400) { out.append((r, d)) }
            } else if r.dueAt >= from && r.dueAt < to {
                out.append((r, r.dueAt))
            }
        }
        return out.sorted { $0.1 < $1.1 }
    }

    static func reminder(from r: Row) -> Reminder {
        Reminder(id: r.string("id")!, title: r.string("title") ?? "", dueAt: r.date("due_at")!,
                 recurrence: decodeRecurrence(r.string("recurrence")), doneAt: r.date("done_at"),
                 createdAt: r.date("created_at")!, updatedAt: r.date("updated_at"), deletedAt: r.date("deleted_at"))
    }

    static func encodeRecurrence(_ r: Recurrence?) -> String? {
        guard let r else { return nil }
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        enc.outputFormatting = .sortedKeys
        return (try? enc.encode(r)).map { String(decoding: $0, as: UTF8.self) }
    }

    static func decodeRecurrence(_ s: String?) -> Recurrence? {
        guard let s, let d = s.data(using: .utf8) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return try? dec.decode(Recurrence.self, from: d)
    }

    // MARK: - Obecné operace nad entitami (pro nástroje a „Zpět“)

    /// Aktuální stav entity jako JSON (pro uložení do deníku akcí).
    public func snapshot(_ ref: EntityRef) throws -> JSONValue? {
        switch ref.kind {
        case .note: return try note(id: ref.id).map { JSONValue.from($0) }
        case .task: return try task(id: ref.id).map { JSONValue.from($0) }
        case .event: return try event(id: ref.id).map { JSONValue.from($0) }
        case .reminder: return try reminder(id: ref.id).map { JSONValue.from($0) }
        }
    }

    /// Obnoví entitu ze snapshotu (vloží nebo přepíše).
    public func restore(_ snapshot: JSONValue, kind: EntityKind) throws {
        switch kind {
        case .note:
            guard let n = snapshot.decode(Note.self) else { return }
            if try note(id: n.id) != nil { try update(n) } else { try insert(n) }
        case .task:
            guard let t = snapshot.decode(TaskItem.self) else { return }
            if try task(id: t.id) != nil { try update(t) } else { try insert(t) }
        case .event:
            guard let e = snapshot.decode(Event.self) else { return }
            if try event(id: e.id) != nil { try update(e) } else { try insert(e) }
        case .reminder:
            guard let r = snapshot.decode(Reminder.self) else { return }
            if try reminder(id: r.id) != nil { try update(r) } else { try insert(r) }
        }
    }

    /// Měkké smazání (do koše).
    public func softDelete(_ ref: EntityRef, at date: Date = Date()) throws {
        try db.execute("UPDATE \(ref.kind.table) SET deleted_at=?, updated_at=? WHERE id=?", [date, date, ref.id])
        changed()
    }

    /// Trvalé smazání (vč. vektorů).
    public func hardDelete(_ ref: EntityRef) throws {
        try db.transaction {
            try db.execute("DELETE FROM \(ref.kind.table) WHERE id=?", [ref.id])
            try db.execute("DELETE FROM embeddings WHERE entity_kind=? AND entity_id=?", [ref.kind.rawValue, ref.id])
        }
        changed()
    }

    public func exists(_ ref: EntityRef) throws -> Bool {
        try db.scalarInt("SELECT count(*) AS c FROM \(ref.kind.table) WHERE id=? AND deleted_at IS NULL", [ref.id]) > 0
    }

    /// Položky v koši.
    public func deletedItems() throws -> [(ref: EntityRef, title: String, deletedAt: Date)] {
        var out: [(EntityRef, String, Date)] = []
        for kind in EntityKind.allCases {
            let rows = try db.query("SELECT id, title, deleted_at FROM \(kind.table) WHERE deleted_at IS NOT NULL ORDER BY deleted_at DESC")
            for r in rows {
                out.append((EntityRef(kind: kind, id: r.string("id")!), r.string("title") ?? "", r.date("deleted_at")!))
            }
        }
        return out.sorted { $0.2 > $1.2 }
    }

    /// Trvale vysype koš (položky smazané před `before`).
    @discardableResult
    public func purgeDeleted(before: Date) throws -> Int {
        var count = 0
        try db.transaction {
            for kind in EntityKind.allCases {
                let ids = try db.query("SELECT id FROM \(kind.table) WHERE deleted_at IS NOT NULL AND deleted_at < ?", [before])
                for r in ids {
                    try db.execute("DELETE FROM \(kind.table) WHERE id=?", [r.string("id")!])
                    try db.execute("DELETE FROM embeddings WHERE entity_kind=? AND entity_id=?", [kind.rawValue, r.string("id")!])
                    count += 1
                }
            }
        }
        if count > 0 { changed() }
        return count
    }

    // MARK: - Konverzace

    public func append(_ m: ChatMessage) throws {
        try db.execute("INSERT INTO messages (id, role, text, action_id, created_at) VALUES (?,?,?,?,?)",
                       [m.id, m.role.rawValue, m.text, m.actionId, m.createdAt])
    }

    public func recentMessages(limit: Int = 100) throws -> [ChatMessage] {
        let rows = try db.query("SELECT * FROM messages ORDER BY created_at DESC LIMIT ?", [limit])
        return rows.reversed().map { r in
            ChatMessage(id: r.string("id")!, role: ChatRole(rawValue: r.string("role") ?? "user") ?? .user,
                        text: r.string("text") ?? "", actionId: r.string("action_id"), createdAt: r.date("created_at")!)
        }
    }

    public func clearConversation() throws {
        try db.execute("DELETE FROM messages")
    }

    // MARK: - Deník akcí

    public func insert(_ a: ActionRecord) throws {
        try db.execute("""
            INSERT INTO actions (id, created_at, tool, args, status, summary, entity_kind, entity_id, before, source)
            VALUES (?,?,?,?,?,?,?,?,?,?)
            """, [a.id, a.createdAt, a.tool, a.args.jsonString, a.status.rawValue, a.summary,
                  a.entity?.kind.rawValue, a.entity?.id, a.before?.jsonString, a.source])
    }

    public func update(_ a: ActionRecord) throws {
        try db.execute("""
            UPDATE actions SET args=?, status=?, summary=?, entity_kind=?, entity_id=?, before=? WHERE id=?
            """, [a.args.jsonString, a.status.rawValue, a.summary, a.entity?.kind.rawValue, a.entity?.id, a.before?.jsonString, a.id])
    }

    public func action(id: String) throws -> ActionRecord? {
        try db.query("SELECT * FROM actions WHERE id=?", [id]).first.map(Self.action(from:))
    }

    public func recentActions(limit: Int = 50) throws -> [ActionRecord] {
        try db.query("SELECT * FROM actions ORDER BY created_at DESC LIMIT ?", [limit]).map(Self.action(from:))
    }

    public func lastAppliedAction() throws -> ActionRecord? {
        try db.query("SELECT * FROM actions WHERE status='applied' ORDER BY created_at DESC LIMIT 1").first.map(Self.action(from:))
    }

    static func action(from r: Row) -> ActionRecord {
        var ref: EntityRef?
        if let k = r.string("entity_kind"), let kind = EntityKind(rawValue: k), let id = r.string("entity_id") {
            ref = EntityRef(kind: kind, id: id)
        }
        return ActionRecord(id: r.string("id")!, createdAt: r.date("created_at")!, tool: r.string("tool") ?? "",
                            args: JSONValue.parse(r.string("args") ?? "{}") ?? .object([:]),
                            status: ActionStatus(rawValue: r.string("status") ?? "applied") ?? .applied,
                            summary: r.string("summary") ?? "", entity: ref,
                            before: r.string("before").flatMap(JSONValue.parse), source: r.string("source") ?? "")
    }

    // MARK: - Vektory (sémantické hledání)

    public func upsertEmbedding(_ ref: EntityRef, model: String, vector: [Float], contentHash: String) throws {
        let data = vector.withUnsafeBufferPointer { Data(buffer: $0) }
        try db.execute("""
            INSERT INTO embeddings (entity_kind, entity_id, model, dim, vector, content_hash) VALUES (?,?,?,?,?,?)
            ON CONFLICT(entity_kind, entity_id, model) DO UPDATE SET dim=excluded.dim, vector=excluded.vector, content_hash=excluded.content_hash
            """, [ref.kind.rawValue, ref.id, model, vector.count, data, contentHash])
    }

    public func embeddings(model: String) throws -> [(ref: EntityRef, vector: [Float], contentHash: String)] {
        try db.query("SELECT * FROM embeddings WHERE model=?", [model]).compactMap { r in
            guard let kind = EntityKind(rawValue: r.string("entity_kind") ?? ""), let data = r.data("vector") else { return nil }
            let count = data.count / MemoryLayout<Float>.size
            let v: [Float] = data.withUnsafeBytes { raw in
                Array(UnsafeBufferPointer(start: raw.baseAddress!.assumingMemoryBound(to: Float.self), count: count))
            }
            return (EntityRef(kind: kind, id: r.string("entity_id")!), v, r.string("content_hash") ?? "")
        }
    }

    public func deleteEmbeddings(model: String? = nil) throws {
        if let model { try db.execute("DELETE FROM embeddings WHERE model=?", [model]) }
        else { try db.execute("DELETE FROM embeddings") }
    }

    // MARK: - Nastavení (citlivá nastavení patří sem, ne do UserDefaults)

    public func setting(_ key: String) throws -> String? {
        try db.scalarString("SELECT value FROM settings WHERE key=?", [key])
    }

    public func setSetting(_ key: String, _ value: String?) throws {
        if let value {
            try db.execute("INSERT INTO settings (key, value) VALUES (?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", [key, value])
        } else {
            try db.execute("DELETE FROM settings WHERE key=?", [key])
        }
    }

    // MARK: - Statistika

    public func counts() throws -> (notes: Int, tasks: Int, events: Int, reminders: Int) {
        (try db.scalarInt("SELECT count(*) AS c FROM notes WHERE deleted_at IS NULL"),
         try db.scalarInt("SELECT count(*) AS c FROM tasks WHERE deleted_at IS NULL"),
         try db.scalarInt("SELECT count(*) AS c FROM events WHERE deleted_at IS NULL"),
         try db.scalarInt("SELECT count(*) AS c FROM reminders WHERE deleted_at IS NULL"))
    }
}
