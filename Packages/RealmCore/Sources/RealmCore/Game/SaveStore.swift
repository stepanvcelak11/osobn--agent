import Foundation

/// Ukládání příběhů do JSON souborů (jeden soubor = jedna hra) se zálohou předchozí verze.
/// Hry ze starší verze 2 se při načtení převedou (jméno, postava, mód a celý deník zůstanou).
public final class SaveStore: @unchecked Sendable {
    public let directory: URL
    private let lock = NSLock()

    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func url(_ id: String) -> URL { directory.appendingPathComponent("\(id).json") }
    func backupURL(_ id: String) -> URL { directory.appendingPathComponent("\(id).json.bak") }

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

    public func save(_ story: Story) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try Self.encoder.encode(story)
        let target = url(story.id)
        let fm = FileManager.default
        if fm.fileExists(atPath: target.path), (try? Self.decode(Data(contentsOf: target))) != nil {
            try? fm.removeItem(at: backupURL(story.id))
            try? fm.copyItem(at: target, to: backupURL(story.id))
        }
        try data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    public func load(_ id: String) throws -> Story {
        if let data = try? Data(contentsOf: url(id)), let s = try? Self.decode(data) { return s }
        let data = try Data(contentsOf: backupURL(id))
        return try Self.decode(data)
    }

    public func delete(_ id: String) {
        try? FileManager.default.removeItem(at: url(id))
        try? FileManager.default.removeItem(at: backupURL(id))
    }

    public func list() -> [SaveSummary] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? load($0.deletingPathExtension().lastPathComponent) }
            .map(SaveSummary.init)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    static func decode(_ data: Data) throws -> Story {
        if let s = try? decoder.decode(Story.self, from: data) { return s }
        return try decoder.decode(LegacyGame.self, from: data).story
    }
}

/// Uložená hra z verze 2 – jen to, co má smysl převzít.
struct LegacyGame: Decodable {
    struct LHero: Decodable { var name: String; var background: String?; var feminine: Bool? }
    struct LEntry: Decodable { var kind: String; var text: String; var input: InputMode? }
    struct LQuest: Decodable { var objective: String; var stages: [String]?; var progress: Int? }
    struct LSettlement: Decodable { var name: String? }

    var id: String
    var mode: GameMode
    var hero: LHero
    var log: [LEntry]
    var createdAt: Date?
    var updatedAt: Date?
    var quest: LQuest?
    var settlement: LSettlement?
    var end: String?
    var epilogue: String?
    var memory: String?
    var authorsNote: String?
    var premise: String?

    var story: Story {
        let place = settlement?.name ?? "Vranov"
        let hero = Hero(name: self.hero.name, classId: HeroClass.fromLegacy(self.hero.background ?? ""), feminine: self.hero.feminine ?? false)
        var s = Story(id: id, now: createdAt ?? Date(), mode: mode, hero: hero, place: place, premise: premise ?? "",
                      title: "", goal: "", opening: "", stages: [], rng: UInt64(abs(id.hashValue)) | 1)
        if let q = quest {
            let tale = Tales.quests.first { $0.goal == q.objective } ?? Tales.custom(q.objective)
            s.title = tale.title; s.goal = q.objective; s.opening = tale.opening; s.stages = q.stages ?? tale.stages
            s.stage = min(q.progress ?? 0, s.stages.count)
        } else {
            let tale = Tales.make(mode: mode, place: place, premise: "", story: &s)
            s.title = tale.title; s.goal = tale.goal; s.opening = tale.opening; s.stages = tale.stages
        }
        s.updatedAt = updatedAt ?? s.createdAt
        s.log = log.compactMap { e in
            switch e.kind {
            case "player": return Entry(kind: .player, text: e.text, input: e.input)
            case "narration": return Entry(kind: .narration, text: e.text)
            default: return nil
            }
        }
        s.turns = s.log.filter { $0.kind == .player }.count
        s.memory = memory ?? ""
        s.note = authorsNote ?? ""
        switch end {
        case nil: break
        case "victory": s.end = .victory
        case "abandoned": s.end = .abandoned
        default: s.end = .defeat
        }
        s.epilogue = epilogue
        return s
    }
}
