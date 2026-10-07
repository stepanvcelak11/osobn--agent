import Foundation

// Uložené hry ze starších verzí: chybějící pole dostanou výchozí hodnotu místo chyby načtení.

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, _ fallback: @autoclosure () -> T) -> T {
        if let v = try? decodeIfPresent(T.self, forKey: key) { return v }
        return fallback()
    }
}

extension Hero {
    enum CodingKeys: String, CodingKey {
        case name, feminine, background, attributes, hp, stress, items, xp, level, statUse, awakeHours, conditions, traits, abilities
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try c.decode(String.self, forKey: .name),
                  feminine: c.value(.feminine, false),
                  background: try c.decode(String.self, forKey: .background),
                  attributes: try c.decode([Attribute: Int].self, forKey: .attributes),
                  hp: try c.decode(Int.self, forKey: .hp),
                  stress: try c.decode(Int.self, forKey: .stress),
                  items: c.value(.items, []))
        xp = c.value(.xp, 0)
        level = c.value(.level, 1)
        statUse = c.value(.statUse, [:])
        awakeHours = c.value(.awakeHours, 0)
        conditions = c.value(.conditions, [])
        traits = c.value(.traits, [])
        abilities = c.value(.abilities, [])
    }
}

extension QuestInfo {
    enum CodingKeys: String, CodingKey { case objective, steps, progress, setbacks, maxSetbacks, stages }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(objective: try c.decode(String.self, forKey: .objective), steps: c.value(.steps, 3),
                  stages: c.value(.stages, []))
        progress = c.value(.progress, 0)
        setbacks = c.value(.setbacks, 0)
        maxSetbacks = c.value(.maxSetbacks, 4)
    }
}

extension GameState {
    enum CodingKeys: String, CodingKey {
        case id, version, mode, hero, settlement, journey, quest, threats, location, scene, turn, day, phase
        case worldTime, lastRealTime, lastTickAt, rngState, log, chronicle, achievements, end, epilogue
        case createdAt, updatedAt, stats, weather, weatherDay, characters, contract, recentContracts, premise, memory, authorsNote
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let settlement = try c.decode(Settlement.self, forKey: .settlement)
        self.init(mode: try c.decode(GameMode.self, forKey: .mode),
                  hero: try c.decode(Hero.self, forKey: .hero),
                  settlement: settlement,
                  location: c.value(.location, settlement.name),
                  scene: c.value(.scene, SceneKind.town),
                  rngState: c.value(.rngState, UInt64(0x9E3779B97F4A7C15)))
        id = try c.decode(String.self, forKey: .id)
        version = c.value(.version, 1)
        journey = c.value(.journey, nil)
        quest = c.value(.quest, nil)
        threats = c.value(.threats, [])
        turn = c.value(.turn, 0)
        day = c.value(.day, 1)
        phase = c.value(.phase, 0)
        let created: Date = c.value(.createdAt, Date())
        createdAt = created
        updatedAt = c.value(.updatedAt, created)
        worldTime = c.value(.worldTime, updatedAt)
        lastRealTime = c.value(.lastRealTime, updatedAt)
        lastTickAt = c.value(.lastTickAt, worldTime)
        log = c.value(.log, [])
        chronicle = c.value(.chronicle, [])
        achievements = c.value(.achievements, [])
        end = c.value(.end, nil)
        epilogue = c.value(.epilogue, nil)
        stats = c.value(.stats, [:])
        weather = c.value(.weather, Weather.zatazeno)
        weatherDay = c.value(.weatherDay, day)
        characters = c.value(.characters, [])
        contract = c.value(.contract, nil)
        recentContracts = c.value(.recentContracts, [])
        premise = c.value(.premise, "")
        memory = c.value(.memory, "")
        authorsNote = c.value(.authorsNote, "")
    }
}
