import XCTest
@testable import AgentCore

final class SecurityTests: XCTestCase {
    let pw = "správné-heslo-42"

    func testArgon2KnownVector() throws {
        // Referenční vektor z PHC (argon2id, v=19, m=32, t=3, p=4, pwd=0x01*32, salt=0x02*16) – zde jen ověříme determinismus
        let k1 = try KDF.argon2id(password: "heslo", salt: Data(repeating: 2, count: 16), params: .fastForTests)
        let k2 = try KDF.argon2id(password: "heslo", salt: Data(repeating: 2, count: 16), params: .fastForTests)
        let k3 = try KDF.argon2id(password: "heslo", salt: Data(repeating: 3, count: 16), params: .fastForTests)
        XCTAssertEqual(k1.withUnsafeBytes { Data($0) }, k2.withUnsafeBytes { Data($0) })
        XCTAssertNotEqual(k1.withUnsafeBytes { Data($0) }, k3.withUnsafeBytes { Data($0) })
    }

    func testBackupRoundTripAndTamper() throws {
        let plain = Data((0..<(2_500_000)).map { UInt8($0 % 251) }) // 3 bloky
        let enc = try BackupCrypto.encrypt(plain, password: pw, params: .fastForTests)
        XCTAssertNil(enc.range(of: plain.prefix(64)))
        XCTAssertEqual(try BackupCrypto.decrypt(enc, password: pw), plain)

        XCTAssertThrowsError(try BackupCrypto.decrypt(enc, password: "spatne-heslo-42")) {
            XCTAssertEqual($0 as? CryptoError, .wrongPasswordOrCorrupted)
        }
        // Změna jednoho bajtu
        var tampered = enc
        tampered[tampered.count - 100] ^= 0x01
        XCTAssertThrowsError(try BackupCrypto.decrypt(tampered, password: pw))
        // Useknutí posledního bloku
        let firstChunkEnd = 49 + 4 + (1 << 20) + 16
        // (u prvního bloku nejde odlišit od špatného hesla – podstatné je, že se odmítne)
        XCTAssertThrowsError(try BackupCrypto.decrypt(enc.prefix(firstChunkEnd), password: pw))
        // Useknutí uprostřed bloku
        XCTAssertThrowsError(try BackupCrypto.decrypt(enc.prefix(enc.count - 10), password: pw)) {
            XCTAssertEqual($0 as? CryptoError, .truncated)
        }
        // Cizí soubor
        XCTAssertThrowsError(try BackupCrypto.decrypt(Data("ahoj".utf8), password: pw))
        // Slabé heslo
        XCTAssertThrowsError(try BackupCrypto.encrypt(plain, password: "kratke", params: .fastForTests))
    }

    func testEmptyBackup() throws {
        let enc = try BackupCrypto.encrypt(Data(), password: pw, params: .fastForTests)
        XCTAssertEqual(try BackupCrypto.decrypt(enc, password: pw), Data())
    }

    func testFullBackupRestore() throws {
        let s = try DataStore.inMemory()
        try s.insert(Note(title: "Tajné", body: "TAJNY_OBSAH_XYZ"))
        try s.insert(TaskItem(title: "Úkol", dueAt: TS.now))
        try s.insert(Reminder(title: "R", dueAt: TS.now, recurrence: Recurrence(frequency: .daily, hour: 8, minute: 0)))
        try s.insert(Event(title: "E", startAt: TS.now))
        try s.append(ChatMessage(role: .user, text: "ahoj"))
        try s.setSetting("x", "y")
        let blob = try BackupService.export(store: s, password: pw, params: .fastForTests)
        XCTAssertNil(blob.range(of: Data("TAJNY_OBSAH_XYZ".utf8)), "záloha nesmí obsahovat čitelný text")

        let target = try DataStore.inMemory()
        try target.insert(Note(title: "Přepíše se", body: ""))
        let payload = try BackupService.open(blob, password: pw)
        try BackupService.restore(payload, into: target)
        XCTAssertEqual(try target.notes().map(\.body), ["TAJNY_OBSAH_XYZ"])
        XCTAssertEqual(try target.tasks().count, 1)
        XCTAssertEqual(try target.activeReminders().first?.recurrence?.hour, 8)
        XCTAssertEqual(try target.setting("x"), "y")
        XCTAssertEqual(try target.recentMessages().count, 1)
    }

    func testKeyWrap() throws {
        let key = KDF.randomBytes(32)
        let blob = try KeyWrap.wrap(key, password: pw, params: .fastForTests)
        XCTAssertEqual(try KeyWrap.unwrap(blob, password: pw), key)
        XCTAssertThrowsError(try KeyWrap.unwrap(blob, password: "jine-heslo-123"))
    }

    func testModelVerifier() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "m-\(UUID().uuidString).gguf")
        try (Data("GGUF".utf8) + Data(repeating: 7, count: 1000)).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(ModelVerifier.checkMagic(url: url, kind: .llm))
        XCTAssertFalse(ModelVerifier.checkMagic(url: url, kind: .speech))
        let d = try ModelVerifier.digest(of: url)
        XCTAssertEqual(d.size, 1004)
        XCTAssertEqual(ModelVerifier.verdict(digest: d, fileName: "x.gguf", expected: nil), .unknown)
        XCTAssertEqual(ModelVerifier.verdict(digest: d, fileName: "x.gguf", expected: d.sha256.uppercased()), .verified("SHA-256"))
        if case .mismatch = ModelVerifier.verdict(digest: d, fileName: "x.gguf", expected: String(repeating: "0", count: 64)) {} else { XCTFail() }
        // Katalogový whisper model s jiným obsahem → nesoulad
        if case .mismatch = ModelVerifier.verdict(digest: d, fileName: "ggml-small.bin", expected: nil) {} else { XCTFail() }
    }

    func testPasswordPolicy() {
        XCTAssertFalse(PasswordPolicy.isAcceptable("abc"))
        XCTAssertFalse(PasswordPolicy.isAcceptable("aaaaaaaaaaaa"))
        XCTAssertFalse(PasswordPolicy.isAcceptable("1234567890"))
        XCTAssertTrue(PasswordPolicy.isAcceptable("kolo-strom-42"))
    }
}

final class FakeEmbedder: EmbeddingModel, @unchecked Sendable {
    let modelId = "fake"
    var calls = 0
    // Jednoduchý „bag of words“ přes složená slova – pro test stačí.
    func embed(_ text: String, isQuery: Bool) async throws -> [Float] {
        calls += 1
        var v = [Float](repeating: 0, count: 64)
        for w in CzechText.fold(text).split(whereSeparator: { !$0.isLetter }) where w.count > 2 {
            v[abs(String(w.prefix(4)).hashValue) % 64] += 1
        }
        return v
    }
}

final class SearchAndNotificationTests: XCTestCase {
    func testSemanticSearchAndRefresh() async throws {
        let s = try DataStore.inMemory()
        try s.insert(Note(title: "Dovolená", body: "Chorvatsko v srpnu, ubytování v Splitu"))
        try s.insert(Note(title: "Recept", body: "Guláš: cibule, maso, paprika"))
        let emb = FakeEmbedder()
        let search = SemanticSearch(store: s, embedder: emb)
        let first = try await search.refresh()
        XCTAssertEqual(first, 2)
        let second = try await search.refresh()
        XCTAssertEqual(second, 0, "nezměněné poznámky se nepřepočítávají")
        let r = try await search.search("ubytování chorvatsko", limit: 3)
        XCTAssertEqual(r.first?.note.title, "Dovolená")
        let r2 = try await search.search("gulas", limit: 3)
        XCTAssertEqual(r2.first?.note.title, "Recept")
    }

    func testNotificationPlannerGenericContent() throws {
        let s = try DataStore.inMemory()
        try s.insert(Reminder(title: "Tajná věc", dueAt: TS.date(2026, 10, 7, 8)))
        try s.insert(Reminder(title: "Denně", dueAt: TS.date(2026, 10, 6, 20), recurrence: Recurrence(frequency: .daily, hour: 20, minute: 0)))
        try s.insert(Event(title: "Porada", startAt: TS.date(2026, 10, 6, 14), endAt: TS.date(2026, 10, 6, 15), alertMinutes: 15))
        var p = NotificationPlanner(calendar: TS.cal, now: TS.now, showContent: false)
        let plan = try p.plan(store: s)
        XCTAssertEqual(plan.count, 60, "omezeno limitem")
        XCTAssertEqual(TS.fmt(plan[0].fireDate), "2026-10-06 13:45")
        XCTAssertFalse(plan.contains { $0.title.contains("Tajná") || $0.body.contains("Tajná") })
        p.showContent = true
        XCTAssertTrue(try p.plan(store: s).contains { $0.title == "Tajná věc" })
    }
}
