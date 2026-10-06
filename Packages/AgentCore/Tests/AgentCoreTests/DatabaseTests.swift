import XCTest
@testable import AgentCore

final class DatabaseTests: XCTestCase {
    func tmpPath() -> String {
        NSTemporaryDirectory() + "agent-test-\(UUID().uuidString).db"
    }

    func testCipherIsActive() throws {
        let v = Database.cipherVersionString
        XCTAssertNotNil(v)
        XCTAssertFalse(v!.isEmpty)
    }

    func testFileIsEncryptedOnDisk() throws {
        let path = tmpPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let key = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let store = try DataStore.open(path: path, key: key)
        try store.insert(Note(title: "Tajný projekt", body: "UNIKATNI_RETEZEC_123 obsah poznámky"))
        store.db.close()

        let raw = try Data(contentsOf: URL(fileURLWithPath: path))
        XCTAssertGreaterThan(raw.count, 0)
        // Žádný čitelný obsah ani hlavička SQLite.
        XCTAssertNil(raw.range(of: Data("UNIKATNI_RETEZEC_123".utf8)))
        XCTAssertNil(raw.range(of: Data("SQLite format 3".utf8)))
        XCTAssertNil(raw.range(of: Data("notes".utf8)))
    }

    func testWrongKeyFails() throws {
        let path = tmpPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let key = Data(repeating: 7, count: 32)
        let store = try DataStore.open(path: path, key: key)
        try store.insert(Note(title: "a", body: "b"))
        store.db.close()

        XCTAssertThrowsError(try DataStore.open(path: path, key: Data(repeating: 8, count: 32)))
        let reopened = try DataStore.open(path: path, key: key)
        XCTAssertEqual(try reopened.notes().count, 1)
    }

    func testRekey() throws {
        let path = tmpPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let k1 = Data(repeating: 1, count: 32), k2 = Data(repeating: 2, count: 32)
        let s = try DataStore.open(path: path, key: k1)
        try s.insert(Note(title: "x", body: "y"))
        try s.db.rekey(k2)
        s.db.close()
        XCTAssertThrowsError(try DataStore.open(path: path, key: k1))
        XCTAssertEqual(try DataStore.open(path: path, key: k2).notes().count, 1)
    }

    func testCrudAndFTS() throws {
        let s = try DataStore.inMemory()
        try s.insert(Note(title: "Projekt Zahrada", body: "Koupit semínka rajčat a zalít záhony."))
        try s.insert(Note(title: "Nákup", body: "mléko, chléb"))
        // Hledání bez diakritiky a se skloňováním
        XCTAssertEqual(try s.searchNotes("rajcata").first?.title, "Projekt Zahrada")
        XCTAssertEqual(try s.searchNotes("zahradě").first?.title, "Projekt Zahrada")
        XCTAssertEqual(try s.searchNotes("chleba").first?.title, "Nákup")

        let t = TaskItem(title: "Zavolat doktorovi", dueAt: TS.now)
        try s.insert(t)
        XCTAssertEqual(try s.tasks(.open).count, 1)
        var done = t; done.doneAt = Date()
        try s.update(done)
        XCTAssertEqual(try s.tasks(.open).count, 0)
        XCTAssertEqual(try s.tasks(.done).count, 1)

        let ref = EntityRef(kind: .task, id: t.id)
        let snap = try s.snapshot(ref)!
        try s.softDelete(ref)
        XCTAssertEqual(try s.tasks(.all).count, 0)
        XCTAssertEqual(try s.deletedItems().count, 1)
        try s.restore(snap, kind: .task)
        XCTAssertEqual(try s.tasks(.all).count, 1)
        XCTAssertEqual(try s.task(id: t.id)?.title, "Zavolat doktorovi")
    }

    func testReminderOccurrences() throws {
        let s = try DataStore.inMemory()
        let rec = Recurrence(frequency: .weekly, weekdays: [1, 4], hour: 7, minute: 0)
        let first = TS.date(2026, 10, 8, 7, 0) // čt
        try s.insert(Reminder(title: "Cvičení", dueAt: first, recurrence: rec))
        try s.insert(Reminder(title: "Jednorázová", dueAt: TS.date(2026, 10, 7, 8, 0)))
        let occ = try s.reminderOccurrences(from: TS.now, to: TS.date(2026, 10, 20), calendar: TS.cal)
        XCTAssertEqual(occ.map { TS.fmt($0.date) }, [
            "2026-10-07 08:00", "2026-10-08 07:00", "2026-10-12 07:00", "2026-10-15 07:00", "2026-10-19 07:00",
        ])
    }

    func testEmbeddingsRoundTrip() throws {
        let s = try DataStore.inMemory()
        let ref = EntityRef(kind: .note, id: "n1")
        try s.upsertEmbedding(ref, model: "m", vector: [0.5, -1, 2], contentHash: "h")
        let e = try s.embeddings(model: "m")
        XCTAssertEqual(e.first?.vector, [0.5, -1, 2])
    }

    func testActionsAndSettings() throws {
        let s = try DataStore.inMemory()
        let a = ActionRecord(tool: "create_note", args: .object(["text": .string("x")]), status: .applied,
                             summary: "Poznámka", entity: EntityRef(kind: .note, id: "1"), before: nil, source: "rules")
        try s.insert(a)
        XCTAssertEqual(try s.lastAppliedAction()?.id, a.id)
        try s.setSetting("k", "v")
        XCTAssertEqual(try s.setting("k"), "v")
        try s.setSetting("k", nil)
        XCTAssertNil(try s.setting("k"))
    }
}
