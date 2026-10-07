import XCTest
@testable import RealmCore

/// Prvky inspirované AI Dungeon: Čin / Řeč / Příběh / Pokračuj, Znovu, paměť a poznámka k vyprávění.
final class StoryModeTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func newState(_ mode: GameMode = .campaign, premise: String = "") -> GameState {
        GameEngine.newGame(NewGameSetup(mode: mode, heroName: "Ráchel", cityName: "Vranov", backgroundId: "zoldner",
                                        feminine: true, seed: 7, premise: premise), now: t0).state
    }

    let greedy = #"{"narration":"Najdeš truhlu plnou zlata a meč králů.","hp":0,"stress":0,"gold":80,"food":40,"pop":3,"defense":5,"morale":10,"items_gained":[{"name":"Meč králů","kind":"artifact"}],"items_lost":[],"location":"Brod","scene":"river","chronicle":"Poklad.","npc":null,"contract_done":true}"#

    func testStoryModeSkipsJudgeAndGrantsNothing() async throws {
        let s = newState()
        let model = ScriptedModel([greedy])
        let r = try await GameEngine(model: model).playTurn(s, input: "Najdu truhlu plnou zlata", mode: .story, now: t0)
        XCTAssertEqual(model.prompts.count, 1, "příběh jde rovnou k vypravěči")
        XCTAssertTrue(model.prompts[0].contains("Hráč vypráví, co se stane"))
        XCTAssertEqual(r.roll.outcome, .auto)
        XCTAssertLessThanOrEqual(r.delta.gold, 0)
        XCTAssertLessThanOrEqual(r.delta.pop, 0)
        XCTAssertTrue(r.itemsAdded.isEmpty)
        XCTAssertEqual(r.state.log.last { $0.kind == .player }?.input, .story)
        XCTAssertEqual(r.state.log.last { $0.kind == .narration }?.text, "Najdeš truhlu plnou zlata a meč králů.")
    }

    func testProceedLetsWorldAct() async throws {
        let s = newState(.quest)
        let model = ScriptedModel([#"{"narration":"Ze tmy se ozvou kroky.","hp":0,"stress":2,"gold":0,"items_gained":[],"items_lost":[],"location":"Kobka","scene":"dungeon","chronicle":"Kroky.","npc":null}"#])
        let r = try await GameEngine(model: model).playTurn(s, input: "", mode: .proceed, now: t0)
        XCTAssertTrue(model.prompts[0].contains("Pokračuj v příběhu"))
        XCTAssertEqual(r.state.worldTime.timeIntervalSince(s.worldTime), 3600, accuracy: 1)
        XCTAssertEqual(r.state.log.last { $0.kind == .player }?.input, .proceed)
        // bez modelu vypráví záložní vypravěč
        let fb = try await GameEngine(model: nil).playTurn(s, input: "", mode: .proceed, now: t0)
        XCTAssertFalse(fb.state.log.last { $0.kind == .narration }!.text.isEmpty)
        await XCTAssertThrowsAsync { try await GameEngine(model: nil).playTurn(s, input: "  ", mode: .act, now: self.t0) }
    }

    func testSayIsSpeech() async throws {
        let s = newState()
        let interp = #"{"intent":"Přemlouvá stráž","category":"social","stat":"charisma","difficulty":"normal","risk":"low","items_used":[],"duration":"moment"}"#
        let model = ScriptedModel([interp, greedy])
        let r = try await GameEngine(model: model).playTurn(s, input: "Pusťte nás, nesu zprávu pro kastelána", mode: .say, now: t0)
        XCTAssertTrue(model.prompts[0].contains("Hrdina říká nahlas: „Pusťte nás"))
        XCTAssertTrue(model.prompts[1].contains("Hrdina mluví"))
        XCTAssertEqual(r.state.log.last { $0.kind == .player }?.input, .say)
        // v historii dalšího tahu zůstane jako řeč
        XCTAssertTrue(GameEngine.historyPairs(r.state).last!.0.contains("říká nahlas"))
        // bez modelu: řeč = jednání
        let fb = try await GameEngine(model: nil).playTurn(s, input: "Dobrý den", mode: .say, now: t0)
        XCTAssertEqual(fb.roll.stat, .charisma)
    }

    func testRetryKeepsTheSameDice() async throws {
        let s = newState(.quest)
        let a = try await GameEngine(model: nil).playTurn(s, input: "Zaútočím mečem na stráž", now: t0)
        let b = try await GameEngine(model: nil).playTurn(s, input: "Zaútočím mečem na stráž", variation: 3, now: t0)
        XCTAssertEqual(a.roll, b.roll, "Znovu = jiné vyprávění, ne nový hod")
    }

    func testMemoryNoteAndPremiseReachTheNarrator() async throws {
        var s = newState(premise: "Hrdinka hledá ztraceného bratra Ondřeje.")
        XCTAssertEqual(s.premise, "Hrdinka hledá ztraceného bratra Ondřeje.")
        s.memory = "Bratr má jizvu přes oko."
        s.authorsNote = "Víc černého humoru."
        XCTAssertTrue(Prompts.stateBlock(s).contains("bratra Ondřeje"))
        XCTAssertTrue(Prompts.stateBlock(s).contains("jizvu přes oko"))
        XCTAssertTrue(Prompts.introTask(state: s, hook: nil).contains("černého humoru"))
        let model = ScriptedModel([greedy])
        _ = try await GameEngine(model: model).playTurn(s, input: "Jedeme dál", mode: .story, now: t0)
        XCTAssertTrue(model.prompts[0].contains("<data>\nVíc černého humoru.\n</data>"))
    }
}

func XCTAssertThrowsAsync(_ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do { try await body(); XCTFail("očekávána chyba", file: file, line: line) } catch {}
}

final class PausedWorldTests: XCTestCase {
    func testPausedSettlementWaitsForPlayer() {
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        var live = GameEngine.newGame(NewGameSetup(mode: .endless, heroName: "A", cityName: "B", backgroundId: "kupec", seed: 4), now: t0).state
        var paused = GameEngine.newGame(NewGameSetup(mode: .endless, heroName: "A", cityName: "B", backgroundId: "kupec", seed: 4, liveWorld: false), now: t0).state
        let week = t0.addingTimeInterval(7 * 86400)
        Simulation.syncRealTime(&live, now: week)
        Simulation.syncRealTime(&paused, now: week)
        XCTAssertGreaterThan(live.worldTime, t0.addingTimeInterval(2 * 86400))
        XCTAssertEqual(paused.worldTime, t0, "zastavená hra čeká")
        XCTAssertEqual(paused.lastRealTime, week)
        XCTAssertTrue(Simulation.plannedNotifications(paused, now: week).isEmpty)
        // a po návratu běží dál jen herní čas tahů
        paused.liveWorld = true
        Simulation.syncRealTime(&paused, now: week.addingTimeInterval(30))
        XCTAssertEqual(paused.worldTime, t0)
    }
}
