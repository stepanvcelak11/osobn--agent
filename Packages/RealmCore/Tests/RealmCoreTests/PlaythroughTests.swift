import XCTest
@testable import RealmCore

/// Celé hry se záložním vypravěčem – hra nesmí spadnout a musí jít dohrát.
final class PlaythroughTests: XCTestCase {
    let actions = ["Prohledám okolí", "Zaútočím mečem na nejbližšího nepřítele", "Promluvím s místními",
                   "Odpočinu si u ohně", "Plížím se kolem stráží", "Vyrazíme dál", "Postavím farmu", "Postavím sýpku",
                   "Použiju brašnu léčivých bylin", "Obchoduji na trhu"]

    func play(_ mode: GameMode, seed: UInt64, turns: Int) async throws -> GameState {
        var s = GameEngine.newGame(NewGameSetup(mode: mode, heroName: "Test", cityName: "Mlhov", backgroundId: "bylinkar", seed: seed)).state
        let engine = GameEngine(model: nil)
        s = await engine.intro(s, hook: nil)
        var now = Date()
        for i in 0..<turns where !s.isOver {
            let a = actions[(i * 7 + Int(seed % 5)) % actions.count]
            s = try await engine.playTurn(s, input: a, now: now).state
            if mode == .realm { now = now.addingTimeInterval(3 * 3600) }
        }
        return s
    }

    func testManyGames() async throws {
        var ends: [String: Int] = [:]
        for mode in GameMode.allCases {
            for seed in UInt64(1)...UInt64(30) {
                let s = try await play(mode, seed: seed, turns: mode == .quest ? 20 : 60)
                ends["\(mode.rawValue):\(s.end?.rawValue ?? "running")", default: 0] += 1
                XCTAssertTrue((0...100).contains(s.hero.hp))
                XCTAssertGreaterThanOrEqual(s.settlement.gold, 0)
                XCTAssertGreaterThanOrEqual(s.settlement.food, 0)
                if mode == .quest { XCTAssertTrue(s.isOver) }
                if seed <= 3 { print("STAV", mode.rawValue, "tah", s.turn, "den", s.day, "hp", s.hero.hp, "stres", s.hero.stress, "lidi", s.settlement.population, "jídlo", s.settlement.foodPercent, "zlato", s.settlement.gold, "stavby", s.settlement.buildings.mapValues { $0 }, "j", s.journey?.index ?? -1) }
            }
        }
        print("KONCE:", ends.sorted { $0.key < $1.key })
    }
}

extension PlaythroughTests {
    /// Rozumná strategie (cestovat často) musí karavanu většinou dovést do cíle.
    func testCampaignIsWinnable() async throws {
        var wins = 0
        for seed in UInt64(1)...UInt64(30) {
            var s = GameEngine.newGame(NewGameSetup(mode: .campaign, heroName: "T", cityName: "M", backgroundId: "zoldner", seed: seed)).state
            let engine = GameEngine(model: nil)
            for i in 0..<40 where !s.isOver {
                s = try await engine.playTurn(s, input: i % 2 == 0 ? "Vyrazíme dál" : "Prohledám okolí a hledám jídlo").state
            }
            if s.end == .victory { wins += 1 }
        }
        print("VÝHRY karavany:", wins)
        XCTAssertGreaterThan(wins, 12)
    }
}
