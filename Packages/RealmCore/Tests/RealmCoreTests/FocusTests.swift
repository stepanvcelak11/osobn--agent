import XCTest
@testable import RealmCore

/// Vypravěč reaguje na poslední tah a neprozrazuje, co má hrdina teprve zjistit.
final class FocusTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func quest() -> GameState {
        GameEngine.newGame(NewGameSetup(mode: .quest, heroName: "Ráchel", cityName: "", backgroundId: "zoldner",
                                        feminine: true, seed: 3), now: t0).state
    }

    let calm = #"{"narration":"Stojíš na kraji lesa, před tebou mýtnice.","hp":0,"stress":0,"gold":0,"items_gained":[],"items_lost":[],"location":"Kraj lesa","scene":"forest","chronicle":"Rozhlédnutí.","npc":null}"#

    func testQuestionDetection() {
        XCTAssertTrue(Fallback.isQuestion("Kde to vlastně stojím?"))
        XCTAssertTrue(Fallback.isQuestion("kde stojím"))
        XCTAssertTrue(Fallback.isQuestion("Co vidím kolem sebe"))
        XCTAssertFalse(Fallback.isQuestion("Zaútočím na lapky u brány"))
        XCTAssertFalse(Fallback.isQuestion("Plížím se k mýtnici a počítám stráže"))
    }

    func testQuestionNeverMovesTheQuest() async throws {
        let s = quest()
        // i když model tvrdí, že jde o těžký čin, který plní cíl
        let judge = #"{"intent":"ptá se","category":"explore","stat":"duvtip","difficulty":"hard","risk":"high","items_used":[],"duration":"hours","advances":true}"#
        for v in 0..<12 {
            let model = ScriptedModel([judge, calm])
            let r = try await GameEngine(model: model).playTurn(s, input: "Kde stojím?", variation: UInt32(v), now: t0)
            XCTAssertEqual(r.roll.outcome, .auto)
            XCTAssertEqual(r.state.quest?.progress, 0)
            XCTAssertEqual(r.state.quest?.setbacks, 0)
            XCTAssertGreaterThanOrEqual(r.delta.hp, 0)
            let narr = model.prompts.last!
            XCTAssertTrue(narr.contains("POSLEDNÍ TAH HRÁČE"))
            XCTAssertTrue(narr.contains("Hráč se ptá"))
            XCTAssertFalse(narr.contains("přiblížil k cíli"))
        }
    }

    func testSideActionDoesNotAdvanceQuest() {
        var s = quest()
        let i = ActionIntent.parse(.object(["category": .string("combat"), "difficulty": .string("hard"),
                                            "advances": .bool(false)]), fallbackText: "x")
        XCTAssertEqual(i.advancesGoal, false)
        var gains = 0, setbacks = 0
        for _ in 0..<60 {
            let r = Rules.resolve(state: &s, intent: i, now: t0)
            gains += r.questGain; setbacks += r.questSetback
        }
        XCTAssertEqual(gains + setbacks, 0)
        // čin, který cíl plní, ho posouvat může
        var on = i; on.advancesGoal = true
        var any = 0
        for _ in 0..<60 { let r = Rules.resolve(state: &s, intent: on, now: t0); any += r.questGain + r.questSetback }
        XCTAssertGreaterThan(any, 0)
    }

    func testPromptsGuardSecrets() {
        let s = quest()
        let stage = s.quest!.currentStage!
        XCTAssertTrue(Prompts.system(mode: .quest).contains("Neprozrazuj předem"))
        XCTAssertTrue(Prompts.stateBlock(s).contains("zatím neprozrazuj): \(stage)"))
        XCTAssertTrue(Prompts.introTask(state: s, hook: "h").contains("Neprozrazuj nic"))
        XCTAssertTrue(Prompts.interpreterTask(state: s, action: "x").contains("advances = true jen když"))
        XCTAssertTrue(Grammars.interpreter(mode: .quest).contains("advances"))
        XCTAssertFalse(Grammars.interpreter(mode: .realm).contains("advances"))
    }
}

/// Vyprávění bez čísel a bez useknutých vět; plynulý ukazatel průběhu.
final class NarrationFlowTests: XCTestCase {
    func testScrubsNumbersWrittenInWords() {
        let t = "Dýka tě škrábne do paže. Ztratíš sedm životních bodů a tvůj stres stoupne o dva body. Stín couvne do mlhy."
        XCTAssertEqual(GameEngine.scrubStats(t), "Dýka tě škrábne do paže. Stín couvne do mlhy.")
        let u = "Mlha houstne. Tvůj stres se zvýší. Ticho."
        XCTAssertEqual(GameEngine.scrubStats(u), "Mlha houstne. Ticho.")
        let ok = "Sedm stínů stojí u brány. Srdce ti buší."
        XCTAssertEqual(GameEngine.scrubStats(ok), ok)
    }

    func testTruncatedNarrationEndsWithWholeSentence() {
        let raw = #"{"narration":"Vstoupíš do krčmy a zápach piva tě udeří do nosu. Hostinský zvedne hlavu a mračí se. Pak pomalu sáhne pod pult, kde"#
        XCTAssertEqual(GameEngine.narration(from: raw), "Vstoupíš do krčmy a zápach piva tě udeří do nosu. Hostinský zvedne hlavu a mračí se.")
    }

    func testStreamerReportsWhenNarrationIsDone() {
        final class Box: @unchecked Sendable { var closed = 0; var text = "" }
        let b = Box()
        let f = FieldStreamer(field: "narration", onText: { b.text = $0 }, onClosed: { b.closed += 1 })
        for p in [#"{"narration":"Řekne: \"#, #""Stůj!\" a "#, #"zmizí."#] { f.feed(p) }
        XCTAssertEqual(b.closed, 0)
        f.feed(#"", "hp": 0"#)
        f.feed(#", "stress": 1"#)
        XCTAssertEqual(b.closed, 1)
        XCTAssertEqual(b.text, #"Řekne: "Stůj!" a zmizí."#)
    }

    func testTurnEmitsSettlingAfterNarration() async throws {
        let s = GameEngine.newGame(NewGameSetup(mode: .quest, heroName: "A", cityName: "", backgroundId: "zoldner", seed: 1)).state
        let judge = #"{"intent":"jde","category":"explore","stat":"duvtip","difficulty":"easy","risk":"low","items_used":[],"duration":"hour","advances":false}"#
        let narr = #"{"narration":"Jdeš dál chodbou.","hp":0,"stress":0,"gold":0,"items_gained":[],"items_lost":[],"location":"Chodba","scene":"dungeon","chronicle":"Chodba.","npc":null}"#
        final class Log: @unchecked Sendable { var events: [String] = [] }
        let log = Log()
        _ = try await GameEngine(model: ScriptedModel([judge, narr])).playTurn(s, input: "Jdu dál chodbou") { ev in
            switch ev {
            case .settling: log.events.append("settling")
            case .narrating: if log.events.last != "narrating" { log.events.append("narrating") }
            default: break
            }
        }
        XCTAssertEqual(Array(log.events.prefix(2)), ["narrating", "settling"])
    }
}
