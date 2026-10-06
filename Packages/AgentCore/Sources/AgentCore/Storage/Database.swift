import Foundation
import CSQLCipher

/// Hodnota pro vazbu parametrů / čtení sloupců.
public enum SQLValue: Equatable, Sendable {
    case null
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)
}

public protocol SQLConvertible { var sqlValue: SQLValue { get } }
extension Int: SQLConvertible { public var sqlValue: SQLValue { .int(Int64(self)) } }
extension Int64: SQLConvertible { public var sqlValue: SQLValue { .int(self) } }
extension Double: SQLConvertible { public var sqlValue: SQLValue { .double(self) } }
extension String: SQLConvertible { public var sqlValue: SQLValue { .text(self) } }
extension Data: SQLConvertible { public var sqlValue: SQLValue { .blob(self) } }
extension Bool: SQLConvertible { public var sqlValue: SQLValue { .int(self ? 1 : 0) } }
extension Date: SQLConvertible { public var sqlValue: SQLValue { .double(timeIntervalSince1970) } }
extension SQLValue: SQLConvertible { public var sqlValue: SQLValue { self } }
extension Optional: SQLConvertible where Wrapped: SQLConvertible {
    public var sqlValue: SQLValue {
        switch self {
        case .none: return .null
        case .some(let v): return v.sqlValue
        }
    }
}

public struct Row: Sendable {
    let columns: [String: SQLValue]

    public subscript(_ name: String) -> SQLValue { columns[name] ?? .null }

    public func string(_ name: String) -> String? {
        switch self[name] {
        case .text(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        default: return nil
        }
    }
    public func int(_ name: String) -> Int? {
        switch self[name] {
        case .int(let i): return Int(i)
        case .double(let d): return Int(d)
        case .text(let s): return Int(s)
        default: return nil
        }
    }
    public func double(_ name: String) -> Double? {
        switch self[name] {
        case .int(let i): return Double(i)
        case .double(let d): return d
        default: return nil
        }
    }
    public func date(_ name: String) -> Date? { double(name).map { Date(timeIntervalSince1970: $0) } }
    public func bool(_ name: String) -> Bool { (int(name) ?? 0) != 0 }
    public func data(_ name: String) -> Data? {
        if case .blob(let d) = self[name] { return d }
        return nil
    }
}

public enum DatabaseError: Error, CustomStringConvertible {
    case open(String)
    case wrongKeyOrCorrupted
    case cipherUnavailable
    case prepare(String)
    case step(String)
    case closed

    public var description: String {
        switch self {
        case .open(let m): return "Nelze otevřít databázi: \(m)"
        case .wrongKeyOrCorrupted: return "Špatný klíč nebo poškozená databáze"
        case .cipherUnavailable: return "Šifrování SQLCipher není dostupné"
        case .prepare(let m): return "Chyba SQL: \(m)"
        case .step(let m): return "Chyba SQL: \(m)"
        case .closed: return "Databáze je zavřená"
        }
    }
}

private let SQLITE_TRANSIENT_PTR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Tenká obálka nad SQLCipher. Všechny operace jsou serializované zámkem.
/// Klíč je 32 B náhodných dat (raw key → žádné PBKDF2, klíč už je plně náhodný).
public final class Database: @unchecked Sendable {
    private var handle: OpaquePointer?
    private let lock = NSRecursiveLock()
    public let path: String

    /// Otevře (nebo vytvoří) šifrovanou databázi. `path == ":memory:"` pro testy.
    public init(path: String, key: Data) throws {
        precondition(key.count == 32, "Klíč databáze musí mít 32 bajtů")
        self.path = path
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(path, &db, flags, nil)
        guard rc == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "kód \(rc)"
            if let db { sqlite3_close_v2(db) }
            throw DatabaseError.open(msg)
        }
        handle = db

        // Raw klíč ve tvaru x'HEX' – SQLCipher ho použije přímo jako AES-256 klíč.
        var hex = "x'" + key.map { String(format: "%02X", $0) }.joined() + "'"
        defer { hex = String(repeating: "0", count: hex.count) }
        let keyRC = hex.withCString { ptr in
            sqlite3_key(db, ptr, Int32(strlen(ptr)))
        }
        guard keyRC == SQLITE_OK else { close(); throw DatabaseError.cipherUnavailable }

        // Ověř, že je skutečně aktivní SQLCipher (ne obyčejné SQLite).
        guard let version = try? scalarString("PRAGMA cipher_version"), !version.isEmpty else {
            close(); throw DatabaseError.cipherUnavailable
        }
        // Ověř klíč – čtení schématu selže při špatném klíči.
        do {
            _ = try query("SELECT count(*) AS c FROM sqlite_master")
        } catch {
            close(); throw DatabaseError.wrongKeyOrCorrupted
        }
        try execute("PRAGMA cipher_memory_security = ON")
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA secure_delete = ON")
        try execute("PRAGMA journal_mode = DELETE")
        try execute("PRAGMA temp_store = MEMORY")
    }

    deinit { close() }

    public var isOpen: Bool { lock.lock(); defer { lock.unlock() }; return handle != nil }

    public func close() {
        lock.lock(); defer { lock.unlock() }
        if let h = handle { sqlite3_close_v2(h) }
        handle = nil
    }

    public static var cipherVersionString: String? {
        guard let db = try? Database(path: ":memory:", key: Data(repeating: 1, count: 32)) else { return nil }
        return try? db.scalarString("PRAGMA cipher_version")
    }

    public func cipherVersion() -> String? { try? scalarString("PRAGMA cipher_version") }

    /// Změna klíče (např. po obnově). Data se přešifrují.
    public func rekey(_ newKey: Data) throws {
        precondition(newKey.count == 32)
        lock.lock(); defer { lock.unlock() }
        guard let h = handle else { throw DatabaseError.closed }
        let hex = "x'" + newKey.map { String(format: "%02X", $0) }.joined() + "'"
        let rc = hex.withCString { sqlite3_rekey(h, $0, Int32(strlen($0))) }
        guard rc == SQLITE_OK else { throw DatabaseError.step(String(cString: sqlite3_errmsg(h))) }
    }

    // MARK: - Exec / Query

    public func execute(_ sql: String, _ params: [SQLConvertible] = []) throws {
        lock.lock(); defer { lock.unlock() }
        let stmt = try prepare(sql, params)
        defer { sqlite3_finalize(stmt) }
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            if rc == SQLITE_ROW { continue }
            throw DatabaseError.step(errorMessage)
        }
    }

    /// Spustí více příkazů oddělených středníkem (bez parametrů) – pro migrace.
    public func executeScript(_ sql: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard let h = handle else { throw DatabaseError.closed }
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(h, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "kód \(rc)"
            sqlite3_free(err)
            throw DatabaseError.step(msg)
        }
    }

    public func query(_ sql: String, _ params: [SQLConvertible] = []) throws -> [Row] {
        lock.lock(); defer { lock.unlock() }
        let stmt = try prepare(sql, params)
        defer { sqlite3_finalize(stmt) }
        var rows: [Row] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw DatabaseError.step(errorMessage) }
            var cols: [String: SQLValue] = [:]
            let n = sqlite3_column_count(stmt)
            for i in 0..<n {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER: cols[name] = .int(sqlite3_column_int64(stmt, i))
                case SQLITE_FLOAT: cols[name] = .double(sqlite3_column_double(stmt, i))
                case SQLITE_TEXT:
                    if let c = sqlite3_column_text(stmt, i) { cols[name] = .text(String(cString: c)) }
                    else { cols[name] = .null }
                case SQLITE_BLOB:
                    let len = Int(sqlite3_column_bytes(stmt, i))
                    if let p = sqlite3_column_blob(stmt, i), len > 0 { cols[name] = .blob(Data(bytes: p, count: len)) }
                    else { cols[name] = .blob(Data()) }
                default: cols[name] = .null
                }
            }
            rows.append(Row(columns: cols))
        }
        return rows
    }

    public func scalarString(_ sql: String, _ params: [SQLConvertible] = []) throws -> String? {
        lock.lock(); defer { lock.unlock() }
        let stmt = try prepare(sql, params)
        defer { sqlite3_finalize(stmt) }
        let rc = sqlite3_step(stmt)
        if rc == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) { return String(cString: c) }
        if rc == SQLITE_ROW || rc == SQLITE_DONE { return nil }
        throw DatabaseError.step(errorMessage)
    }

    public func scalarInt(_ sql: String, _ params: [SQLConvertible] = []) throws -> Int {
        let rows = try query(sql, params)
        guard let first = rows.first, let key = first.columns.keys.first else { return 0 }
        return first.int(key) ?? 0
    }

    public var changes: Int {
        lock.lock(); defer { lock.unlock() }
        guard let h = handle else { return 0 }
        return Int(sqlite3_changes(h))
    }

    /// Transakce – při chybě se vše vrátí.
    public func transaction<T>(_ body: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        try execute("SAVEPOINT tx")
        do {
            let result = try body()
            try execute("RELEASE tx")
            return result
        } catch {
            try? execute("ROLLBACK TO tx")
            try? execute("RELEASE tx")
            throw error
        }
    }

    // MARK: - Private

    private var errorMessage: String {
        guard let h = handle else { return "zavřeno" }
        return String(cString: sqlite3_errmsg(h))
    }

    private func prepare(_ sql: String, _ params: [SQLConvertible]) throws -> OpaquePointer {
        guard let h = handle else { throw DatabaseError.closed }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(h, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.prepare(errorMessage)
        }
        for (i, p) in params.enumerated() {
            let idx = Int32(i + 1)
            let rc: Int32
            switch p.sqlValue {
            case .null: rc = sqlite3_bind_null(stmt, idx)
            case .int(let v): rc = sqlite3_bind_int64(stmt, idx, v)
            case .double(let v): rc = sqlite3_bind_double(stmt, idx, v)
            case .text(let s): rc = sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT_PTR)
            case .blob(let d):
                if d.isEmpty {
                    rc = sqlite3_bind_zeroblob(stmt, idx, 0)
                } else {
                    rc = d.withUnsafeBytes { buf in
                        sqlite3_bind_blob(stmt, idx, buf.baseAddress, Int32(d.count), SQLITE_TRANSIENT_PTR)
                    }
                }
            }
            if rc != SQLITE_OK {
                sqlite3_finalize(stmt)
                throw DatabaseError.prepare(errorMessage)
            }
        }
        return stmt
    }
}
