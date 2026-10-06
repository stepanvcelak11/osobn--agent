import Foundation

/// Migrace schématu. Každá položka = jedna verze (PRAGMA user_version).
enum Schema {
    static let migrations: [String] = [
        // v1
        """
        CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL DEFAULT '',
            body TEXT NOT NULL DEFAULT '',
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL
        );
        CREATE INDEX notes_updated ON notes(updated_at);

        CREATE VIRTUAL TABLE notes_fts USING fts5(
            title, body, content='notes', content_rowid='rowid',
            tokenize = 'unicode61 remove_diacritics 2'
        );
        CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
            INSERT INTO notes_fts(rowid, title, body) VALUES (new.rowid, new.title, new.body);
        END;
        CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
            INSERT INTO notes_fts(notes_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.body);
        END;
        CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
            INSERT INTO notes_fts(notes_fts, rowid, title, body) VALUES ('delete', old.rowid, old.title, old.body);
            INSERT INTO notes_fts(rowid, title, body) VALUES (new.rowid, new.title, new.body);
        END;

        CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            details TEXT NOT NULL DEFAULT '',
            due_at REAL,
            due_has_time INTEGER NOT NULL DEFAULT 0,
            done_at REAL,
            priority INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL
        );
        CREATE INDEX tasks_due ON tasks(due_at);

        CREATE TABLE events (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            start_at REAL NOT NULL,
            end_at REAL,
            all_day INTEGER NOT NULL DEFAULT 0,
            location TEXT NOT NULL DEFAULT '',
            details TEXT NOT NULL DEFAULT '',
            alert_minutes INTEGER,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL
        );
        CREATE INDEX events_start ON events(start_at);

        CREATE TABLE reminders (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            due_at REAL NOT NULL,
            recurrence TEXT,
            done_at REAL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL
        );
        CREATE INDEX reminders_due ON reminders(due_at);

        CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            role TEXT NOT NULL,
            text TEXT NOT NULL,
            action_id TEXT,
            created_at REAL NOT NULL
        );
        CREATE INDEX messages_created ON messages(created_at);

        CREATE TABLE actions (
            id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            tool TEXT NOT NULL,
            args TEXT NOT NULL,
            status TEXT NOT NULL,
            summary TEXT NOT NULL,
            entity_kind TEXT,
            entity_id TEXT,
            before TEXT,
            source TEXT NOT NULL
        );
        CREATE INDEX actions_created ON actions(created_at);

        CREATE TABLE embeddings (
            entity_kind TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            model TEXT NOT NULL,
            dim INTEGER NOT NULL,
            vector BLOB NOT NULL,
            content_hash TEXT NOT NULL,
            PRIMARY KEY (entity_kind, entity_id, model)
        );

        CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """,
    ]

    static func migrate(_ db: Database) throws {
        let current = try db.scalarInt("PRAGMA user_version")
        guard current < migrations.count else { return }
        for v in current..<migrations.count {
            try db.transaction {
                try db.executeScript(migrations[v])
                try db.execute("PRAGMA user_version = \(v + 1)")
            }
        }
    }
}
