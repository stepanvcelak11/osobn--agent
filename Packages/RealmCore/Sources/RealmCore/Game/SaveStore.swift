import Foundation

public struct SaveSummary: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var mode: GameMode
    public var heroName: String
    public var cityName: String
    public var turn: Int
    public var day: Int
    public var hp: Int
    public var end: GameEnd?
    public var updatedAt: Date
}

/// Uložené hry jako JSON soubory v Application Support (bez cloudu, bez sítě).
public final class SaveStore: @unchecked Sendable {
    public let directory: URL
    private let lock = NSLock()

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    func url(_ id: String) -> URL {
        let safe = id.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return directory.appendingPathComponent("\(safe).json")
    }

    public func save(_ state: GameState) throws {
        let data = try Self.encoder.encode(state)
        lock.lock(); defer { lock.unlock() }
        try data.write(to: url(state.id), options: [.atomic])
    }

    public func load(_ id: String) throws -> GameState {
        let data = try Data(contentsOf: url(id))
        return try Self.decoder.decode(GameState.self, from: data)
    }

    public func delete(_ id: String) {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: url(id))
    }

    public func list() -> [SaveSummary] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.compactMap { f -> SaveSummary? in
            guard let data = try? Data(contentsOf: f), let s = try? Self.decoder.decode(GameState.self, from: data) else { return nil }
            return SaveSummary(id: s.id, title: s.title, mode: s.mode, heroName: s.hero.name, cityName: s.settlement.name,
                               turn: s.turn, day: s.day, hp: s.hero.hp, end: s.end, updatedAt: s.updatedAt)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }
}
