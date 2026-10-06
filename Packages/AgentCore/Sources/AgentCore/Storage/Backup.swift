import Foundation

/// Obsah zálohy (před zašifrováním). Vektory se nezálohují – po obnově se přepočítají.
public struct BackupPayload: Codable, Sendable {
    public var formatVersion: Int = 1
    public var createdAt: Date
    public var notes: [Note]
    public var tasks: [TaskItem]
    public var events: [Event]
    public var reminders: [Reminder]
    public var messages: [ChatMessage]
    public var settings: [String: String]

    public var counts: String {
        "\(notes.count) poznámek, \(tasks.count) úkolů, \(events.count) událostí, \(reminders.count) připomínek"
    }
}

public enum BackupService {
    /// Vytvoří zašifrovanou zálohu. Nešifrovaný obsah existuje jen v paměti.
    public static func export(store: DataStore, password: String, params: KDFParams = .standard, now: Date = Date()) throws -> Data {
        let payload = try snapshot(store: store, now: now)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        var json = try enc.encode(payload)
        defer { json.resetBytes(in: 0..<json.count) }
        return try BackupCrypto.encrypt(json, password: password, params: params)
    }

    public static func snapshot(store: DataStore, now: Date) throws -> BackupPayload {
        let notes = try store.db.query("SELECT * FROM notes").map(DataStore.note(from:))
        let tasks = try store.db.query("SELECT * FROM tasks").map(DataStore.task(from:))
        let events = try store.db.query("SELECT * FROM events").map(DataStore.event(from:))
        let reminders = try store.db.query("SELECT * FROM reminders").map(DataStore.reminder(from:))
        let messages = try store.recentMessages(limit: 100_000)
        var settings: [String: String] = [:]
        for r in try store.db.query("SELECT key, value FROM settings") {
            if let k = r.string("key"), let v = r.string("value") { settings[k] = v }
        }
        return BackupPayload(createdAt: now, notes: notes, tasks: tasks, events: events, reminders: reminders,
                             messages: messages, settings: settings)
    }

    /// Dešifruje a ověří zálohu (bez zápisu).
    public static func open(_ data: Data, password: String) throws -> BackupPayload {
        var json = try BackupCrypto.decrypt(data, password: password)
        defer { json.resetBytes(in: 0..<json.count) }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let payload = try? dec.decode(BackupPayload.self, from: json) else { throw CryptoError.badFormat }
        guard payload.formatVersion == 1 else { throw CryptoError.unsupportedVersion }
        return payload
    }

    /// Nahradí všechna data obsahem zálohy (v jedné transakci – při chybě se nic nezmění).
    public static func restore(_ p: BackupPayload, into store: DataStore) throws {
        try store.db.transaction {
            for t in ["notes", "tasks", "events", "reminders", "messages", "actions", "embeddings", "settings"] {
                try store.db.execute("DELETE FROM \(t)")
            }
            for n in p.notes { try store.insert(n) }
            for t in p.tasks { try store.insert(t) }
            for e in p.events { try store.insert(e) }
            for r in p.reminders { try store.insert(r) }
            for m in p.messages { try store.append(m) }
            for (k, v) in p.settings { try store.setSetting(k, v) }
        }
        store.changed()
    }
}
