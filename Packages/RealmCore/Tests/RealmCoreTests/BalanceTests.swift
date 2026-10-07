import XCTest
@testable import RealmCore

/// Vyváženost: rozumný hráč má šanci vyhrát, lehkomyslný prohrává.
final class BalanceTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func realmAction(_ s: GameState, _ i: Int) -> String {
        let st = s.settlement
        if s.hero.hp < 40 || s.hero.awakeHours > 16 { return "Celou noc spím" }
        if let t = s.threats.min(by: { $0.deadline < $1.deadline }), t.deadline.timeIntervalSince(s.worldTime) < 30 * 3600 {
            return "Vycvičím domobranu a připravím obranu proti hrozbě"
        }
        if st.foodPercent < 45 { return st.count(.farma) < 4 && st.gold >= 40 ? "Postavím farmu" : "Prohledám les a lovím zvěř" }
        let order: [BuildingKind] = [.farma, .sypka, .palisada, .trziste, .farma, .kaple, .kasarna, .sypka, .farma]
        if st.construction.count < 2, let next = order.enumerated().first(where: { i, b in
            st.count(b) + st.construction.filter { $0.kind == b }.count < order.prefix(i + 1).filter { $0 == b }.count
        })?.element, st.gold >= next.goldCost {
            return "Postavím \(next.czechName.lowercased())"
        }
        return i % 2 == 0 ? "Obchoduji s kupci na trhu" : "Promluvím s lidmi a povzbudím je"
    }

    func testRealmIsWinnableWithGoodPlay() async throws {
        var wins = 0, lost = 0
        var turns: [Int] = []
        for seed in 1...20 as ClosedRange<UInt64> {
            var s = GameEngine.newGame(NewGameSetup(mode: .realm, heroName: "T", cityName: "M", backgroundId: "kovar", seed: seed), now: t0).state
            let engine = GameEngine(model: nil)
            var now = t0
            for i in 0..<600 where !s.isOver {
                now = now.addingTimeInterval(20)
                s = try await engine.playTurn(s, input: realmAction(s, i), now: now).state
            }
            if s.end == .victory { wins += 1; turns.append(s.turn) } else if s.isOver { lost += 1 }
            if seed <= 3 { print("REALM", seed, s.end?.rawValue ?? "běží", "tah", s.turn, "den", s.day, "lidi", s.settlement.population, "jídlo", s.settlement.foodPercent, "stavby", s.settlement.buildings) }
        }
        print("REALM výhry \(wins)/20, prohry \(lost), tahy \(turns.sorted())")
        XCTAssertGreaterThanOrEqual(wins, 14, "rozumná vláda má většinou vést k městu")
    }

    func testQuestSmartVsReckless() async throws {
        var smart = 0, reckless = 0
        for seed in 1...40 as ClosedRange<UInt64> {
            for careful in [true, false] {
                var s = GameEngine.newGame(NewGameSetup(mode: .quest, heroName: "T", cityName: "M", backgroundId: "zoldner", seed: seed), now: t0).state
                let engine = GameEngine(model: nil)
                for i in 0..<60 where !s.isOver {
                    let a: String
                    if careful {
                        a = s.hero.hp < 45 ? "Odpočinu si a ošetřím rány" : (i % 3 == 0 ? "Potichu se proplížím dál" : "Zaútočím mečem")
                    } else {
                        a = "Zaútočím holýma rukama na všechno, co se hýbe"
                    }
                    s = try await engine.playTurn(s, input: a, now: t0).state
                }
                if s.end == .victory { if careful { smart += 1 } else { reckless += 1 } }
            }
        }
        print("VÝPRAVA výhry: opatrný \(smart)/40, bezhlavý \(reckless)/40")
        XCTAssertGreaterThan(smart, reckless)
        XCTAssertGreaterThanOrEqual(smart, 20)
    }

    func testLazyRulerDoesNotWin() async throws {
        var wins = 0, lost = 0
        for seed in 1...10 as ClosedRange<UInt64> {
            var s = GameEngine.newGame(NewGameSetup(mode: .realm, heroName: "T", cityName: "M", backgroundId: "bard", seed: seed), now: t0).state
            let engine = GameEngine(model: nil)
            for _ in 0..<400 where !s.isOver {
                s = try await engine.playTurn(s, input: "Celý den se válím a piju víno", now: t0).state
            }
            if s.end == .victory { wins += 1 } else if s.isOver { lost += 1 }
        }
        print("LÍNÝ vládce: výhry \(wins), prohry \(lost)")
        XCTAssertEqual(wins, 0)
    }
}
