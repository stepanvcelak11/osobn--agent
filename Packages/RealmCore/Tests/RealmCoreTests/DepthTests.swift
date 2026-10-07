import XCTest
@testable import RealmCore

/// Hloubka hry: úrovně, stavy, počasí, postavy, zakázky, etapy výprav, kompatibilita uložených her.
final class DepthTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func newState(_ mode: GameMode, bg: String = "zoldner", seed: UInt64 = 7) -> GameState {
        GameEngine.newGame(NewGameSetup(mode: mode, heroName: "Ráchel", cityName: "Vranov", backgroundId: bg, feminine: true, seed: seed), now: t0).state
    }

    func apply(_ s: GameState, _ res: Resolution, _ o: NarratorOutput? = nil) -> TurnResult {
        GameEngine.apply(state: s, action: "x", resolution: res, output: o ?? NarratorOutput(narration: "…", proposed: res.mandatory), now: t0)
    }

    func testOldSaveStillLoads() throws {
        // Uložená hra z verze 2.0 (bez úrovní, stavů, počasí, postav a zakázek).
        let s = newState(.realm)
        var json = try JSONSerialization.jsonObject(with: SaveStore.encoder.encode(s)) as! [String: Any]
        for k in ["weather", "weatherDay", "characters", "contract", "recentContracts", "premise", "memory", "authorsNote"] { json.removeValue(forKey: k) }
        var hero = json["hero"] as! [String: Any]
        for k in ["xp", "level", "statUse", "awakeHours", "conditions"] { hero.removeValue(forKey: k) }
        json["hero"] = hero
        let data = try JSONSerialization.data(withJSONObject: json)
        let back = try SaveStore.decoder.decode(GameState.self, from: data)
        XCTAssertEqual(back.hero.level, 1)
        XCTAssertEqual(back.hero.xp, 0)
        XCTAssertTrue(back.characters.isEmpty)
        XCTAssertEqual(back.settlement, s.settlement)
        XCTAssertEqual(back.worldTime, s.worldTime)
        // a nový formát projde tam i zpět beze ztrát
        var full = s
        full.hero.xp = 70; full.hero.level = 2; full.hero.conditions = [Condition(kind: .krvaceni, until: t0)]
        full.characters = [NPC(name: "Hubert", role: "hostinský", attitude: .friend, lastSeen: 3)]
        full.contract = Contract(title: "T", giver: "G", categories: [.social], reward: Reward(gold: 5), deadline: t0)
        let again = try SaveStore.decoder.decode(GameState.self, from: SaveStore.encoder.encode(full))
        XCTAssertEqual(again, full)
    }

    func testLevelUpRaisesMostUsedAttribute() {
        var s = newState(.quest, bg: "stinochod")
        s.hero.statUse = ["duvtip": 5, "obratnost": 1]
        let before = s.hero.score(.duvtip)
        s.hero.xp = World.xpForLevel(2) - 10
        s.hero.hp = 50
        var res = Rules.resolve(state: &s, intent: ActionIntent(summary: "x", category: .explore))
        res.roll.outcome = .success
        res.mandatory = StatDelta()
        let r = apply(s, res)
        XCTAssertEqual(r.state.hero.level, 2)
        XCTAssertEqual(r.state.hero.score(.duvtip), before + 1)
        XCTAssertEqual(r.state.hero.hp, 70)
        XCTAssertTrue(r.state.log.contains { $0.text.hasPrefix("⭐ Úroveň 2") })
        XCTAssertEqual(World.xpForLevel(1), 0)
        XCTAssertEqual(World.xpForLevel(2), 60)
        XCTAssertEqual(World.xpForLevel(3), 160)
    }

    func testBleedingWeakensUntilTreated() {
        var s = newState(.quest)
        s.hero.items.removeAll { $0.kind == .armor }
        var res = Rules.resolve(state: &s, intent: ActionIntent(summary: "x", category: .combat, risk: .high))
        res.roll.outcome = .critFail
        res.newConditions = [.krvaceni]
        res.mandatory = StatDelta(hp: -10)
        var st = apply(s, res).state
        XCTAssertTrue(World.conditions(st.hero, at: st.worldTime).contains(.krvaceni))
        // další tah: krvácení bere zdraví a dává postih
        let next = Rules.resolve(state: &st, intent: ActionIntent(summary: "rozhlédnu se", category: .explore, difficulty: .trivial, risk: .none))
        XCTAssertEqual(next.mandatory.hp, -2)
        // odpočinek ránu ošetří
        let rest = Rules.resolve(state: &st, intent: ActionIntent(summary: "spím", category: .rest, difficulty: .trivial, risk: .none))
        XCTAssertTrue(rest.cures.contains(.krvaceni))
        let after = apply(st, rest).state
        XCTAssertFalse(after.hero.conditions.contains { $0.kind == .krvaceni })
        XCTAssertEqual(after.hero.awakeHours, 0)
    }

    func testHealingItemCuresBleeding() {
        var s = newState(.quest, bg: "bylinkar")
        s.hero.conditions = [Condition(kind: .krvaceni, until: t0.addingTimeInterval(36000))]
        let res = Rules.resolve(state: &s, intent: ActionIntent(summary: "obvážu se", category: .craft, difficulty: .trivial, risk: .none, itemsUsed: ["Brašna léčivých bylin"]))
        XCTAssertGreaterThan(res.mandatory.hp, 0)
        XCTAssertTrue(res.cures.contains(.krvaceni))
    }

    func testFatigueFromLongDays() {
        var s = newState(.quest)
        s.hero.awakeHours = 17
        var res = Rules.resolve(state: &s, intent: ActionIntent(summary: "x", category: .explore, difficulty: .trivial, duration: .hours))
        res.mandatory = StatDelta()
        let st = apply(s, res).state
        XCTAssertEqual(st.hero.awakeHours, 21)
        XCTAssertTrue(World.conditions(st.hero, at: st.worldTime).contains(.unava))
        var tired = st
        tired.hero.awakeHours = 31
        let r = Rules.resolve(state: &tired, intent: ActionIntent(summary: "x", category: .explore, difficulty: .trivial))
        XCTAssertGreaterThanOrEqual(r.mandatory.stress, 3)
        XCTAssertEqual(ConditionKind.vycerpani.rollModifier, -2)
    }

    func testSeasonsAndWeather() {
        XCTAssertEqual(World.season(day: 1), .jaro)
        XCTAssertEqual(World.season(day: 21), .leto)
        XCTAssertEqual(World.season(day: 41), .podzim)
        XCTAssertEqual(World.season(day: 61), .zima)
        XCTAssertEqual(World.season(day: 81), .jaro)
        XCTAssertEqual(World.year(day: 81), 2)
        // v zimě nikdy nebouří, v létě nesněží
        var s = newState(.endless)
        var seen = Set<Weather>()
        for d in 61...80 { s.day = d; World.updateWeather(&s); seen.insert(s.weather) }
        XCTAssertFalse(seen.contains(.bourka))
        XCTAssertTrue(seen.contains(.snih) || seen.contains(.mraz))
        seen = []
        for d in 21...40 { s.day = d; World.updateWeather(&s); seen.insert(s.weather) }
        XCTAssertFalse(seen.contains(.snih))
        XCTAssertTrue(s.log.contains { $0.text.contains("léto") })
        // počasí mění hody
        XCTAssertEqual(Weather.mlha.modifier(.stealth), 2)
        XCTAssertEqual(Weather.bourka.modifier(.travel), -2)
        // zima je v osadě hladová
        var summer = newState(.endless), winter = newState(.endless)
        summer.createdAt = t0.addingTimeInterval(-25 * 86400)
        winter.createdAt = t0.addingTimeInterval(-65 * 86400)
        for var g in [summer, winter] {
            g.settlement.food = 100
            Simulation.advance(&g, to: t0.addingTimeInterval(86400))
            if g.createdAt == summer.createdAt { summer = g } else { winter = g }
        }
        XCTAssertGreaterThan(summer.settlement.food, winter.settlement.food)
    }

    func testStormSlowsCaravan() {
        var s = newState(.campaign)
        s.weather = .bourka; s.weatherDay = s.day
        let res = Rules.resolve(state: &s, intent: ActionIntent(summary: "jedeme", category: .travel, difficulty: .trivial, duration: .day))
        XCTAssertEqual(res.hours, 36, accuracy: 0.1)
    }

    func testCharactersAreRemembered() {
        var s = newState(.quest)
        var res = Rules.resolve(state: &s, intent: ActionIntent(summary: "x", category: .social, difficulty: .trivial))
        res.mandatory = StatDelta()
        var o = NarratorOutput(narration: "Hostinský se usměje.", proposed: StatDelta())
        o.npc = ("Hubert", "hostinský", .friend)
        var st = apply(s, res, o).state
        XCTAssertEqual(st.characters.first?.name, "Hubert")
        // stejné jméno = stejná postava, postoj se mění
        o.npc = ("hubert", "", .hostile)
        st = apply(st, res, o).state
        XCTAssertEqual(st.characters.count, 1)
        XCTAssertEqual(st.characters[0].attitude, .hostile)
        XCTAssertEqual(st.characters[0].meetings, 2)
        // hrdina sám ani „nikdo“ se nezapisují
        o.npc = ("Ráchel", "hrdinka", .friend)
        st = apply(st, res, o).state
        o.npc = ("nikdo", "x", .neutral)
        st = apply(st, res, o).state
        XCTAssertEqual(st.characters.count, 1)
        XCTAssertTrue(Prompts.stateBlock(st).contains("Hubert (hostinský, nepřítel)"))
        // paměť má strop
        for i in 0..<20 { World.meet(&st, name: "Poutník \(i)", role: "poutník", attitude: .neutral) }
        XCTAssertEqual(st.characters.count, World.maxCharacters)
    }

    func testContractCompletedOnlyWithSuccess() {
        var s = newState(.realm)
        s.contract = Contract(title: "Rozsuď spor dvou rodů", giver: "stařešina", categories: [.social],
                              reward: Reward(gold: 30, morale: 10), deadline: t0.addingTimeInterval(48 * 3600))
        let gold = s.settlement.gold
        var res = Rules.resolve(state: &s, intent: ActionIntent(summary: "rozsoudím spor", category: .social))
        res.roll.outcome = .success
        res.contractEligible = true
        res.mandatory = StatDelta()
        var o = NarratorOutput(narration: "Rody si podají ruce.", proposed: StatDelta())
        o.contractDone = true
        let st = apply(s, res, o).state
        XCTAssertNil(st.contract)
        XCTAssertGreaterThanOrEqual(st.settlement.gold, gold + 30)
        XCTAssertEqual(st.stats["contracts_done"], 1)
        // vypravěč nemůže zakázku „splnit“ při neúspěchu
        var s2 = s
        let fail = Rules.resolve(state: &s2, intent: ActionIntent(summary: "x", category: .combat, difficulty: .extreme))
        if fail.roll.outcome != .success && fail.roll.outcome != .critSuccess { XCTAssertFalse(fail.contractEligible) }
        var res3 = res
        res3.contractEligible = false
        XCTAssertNotNil(apply(s, res3, o).state.contract)
    }

    func testContractsOfferedAndExpire() {
        var s = newState(.endless)
        s.settlement.food = 180
        Simulation.advance(&s, to: t0.addingTimeInterval(8 * 86400))
        XCTAssertTrue(s.log.contains { $0.text.hasPrefix("📜 Zakázka") })
        // propadlá zakázka stojí morálku
        var e = newState(.endless)
        e.contract = Contract(title: "T", giver: "G", categories: [.social], reward: Reward(gold: 5), deadline: t0.addingTimeInterval(3600))
        let m = e.settlement.morale
        Simulation.advance(&e, to: t0.addingTimeInterval(2 * 3600))
        XCTAssertNil(e.contract)
        XCTAssertEqual(e.settlement.morale, m - 5)
        XCTAssertTrue(Prompts.stateBlock(s).contains("ZAKÁZKA") == (s.contract != nil))
    }

    func testQuestStagesAdvance() {
        var s = newState(.quest)
        let q = s.quest!
        XCTAssertEqual(q.stages.count, Catalog.questSteps)
        XCTAssertEqual(q.currentStage, q.stages[0])
        XCTAssertTrue(Prompts.stateBlock(s).contains(q.stages[0]))
        var res = Rules.resolve(state: &s, intent: ActionIntent(summary: "x", category: .explore))
        res.roll.outcome = .success; res.questGain = 1; res.mandatory = StatDelta()
        let st = apply(s, res).state
        XCTAssertEqual(st.quest?.currentStage, q.stages[1])
        XCTAssertTrue(Prompts.narratorTask(state: s, resolution: res).contains(q.stages[1]))
    }

    func testSettlementRankUpCelebrates() {
        var s = newState(.endless)
        s.settlement.population = 50
        var res = Rules.resolve(state: &s, intent: ActionIntent(summary: "x", category: .other, difficulty: .trivial))
        res.mandatory = StatDelta()
        let st = apply(s, res).state
        XCTAssertTrue(st.log.contains { $0.text.contains("povýšila: Ves") })
        // podruhé se neslaví
        let again = apply(st, res).state
        XCTAssertEqual(again.log.filter { $0.text.contains("povýšila") }.count, 1)
    }

    func testNarratorParsesNewFields() throws {
        let raw = #"{"narration":"Kovářka kývne.","hp":0,"stress":0,"gold":0,"food":0,"pop":0,"defense":0,"morale":0,"items_gained":[],"items_lost":[],"location":"Kovárna","scene":"town","chronicle":"Dohoda.","npc":{"name":"Agáta","role":"kovářka","attitude":"friend"},"contract_done":true,"resolve_threat":false}"#
        let o = try XCTUnwrap(NarratorOutput.parse(XCTUnwrap(JSONTools.parseObject(raw)), mandatory: StatDelta()))
        XCTAssertEqual(o.npc?.name, "Agáta")
        XCTAssertEqual(o.npc?.attitude, .friend)
        XCTAssertTrue(o.contractDone)
        let nul = #"{"narration":"Ticho.","hp":0,"stress":0,"gold":0,"items_gained":[],"items_lost":[],"location":"Les","scene":"forest","chronicle":"Nic.","npc":null}"#
        XCTAssertNil(try XCTUnwrap(NarratorOutput.parse(XCTUnwrap(JSONTools.parseObject(nul)), mandatory: StatDelta())).npc)
    }
}
