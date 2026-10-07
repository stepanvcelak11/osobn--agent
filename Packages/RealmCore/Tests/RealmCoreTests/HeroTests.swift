import XCTest
@testable import RealmCore

/// Tvorba postavy: původy, schopnosti, povaha, volné body.
final class HeroTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func hero(_ bg: String, traits: [String] = [], bonus: [Attribute: Int] = [:], mode: GameMode = .quest) -> GameState {
        GameEngine.newGame(NewGameSetup(mode: mode, heroName: "Ráchel", cityName: "Vranov", backgroundId: bg, feminine: true,
                                        seed: 7, traits: traits, bonusPoints: bonus), now: t0).state
    }

    func testEveryOriginIsDistinctAndBalanced() {
        XCTAssertGreaterThanOrEqual(Catalog.backgrounds.count, 11)
        XCTAssertEqual(Set(Catalog.backgrounds.map(\.id)).count, Catalog.backgrounds.count)
        XCTAssertEqual(Set(Catalog.backgrounds.map(\.ability.name)).count, Catalog.backgrounds.count)
        for bg in Catalog.backgrounds {
            XCTAssertEqual(bg.attributes.values.reduce(0, +), 4, bg.id)
            XCTAssertFalse(bg.items.isEmpty, bg.id)
            let s = hero(bg.id)
            XCTAssertEqual(s.hero.abilities.count, 1)
            XCTAssertEqual(s.hero.abilities[0].usesLeft, 2)
        }
    }

    func testFreePointsAndTraits() {
        let s = hero("kupec", traits: ["silak", "odvazny", "nocni"], bonus: [.sila: 2, .charisma: 5])
        XCTAssertEqual(s.hero.traits, ["silak", "odvazny"], "nejvýš dvě vlastnosti")
        XCTAssertEqual(s.hero.score(.sila), 3, "2 volné body + Silák")
        XCTAssertEqual(s.hero.score(.charisma), 3, "volné body už došly")
        // strop při tvorbě: Žoldnéř má Sílu 3, víc než 4 z bodů nedostane
        let z = hero("zoldner", bonus: [.sila: 2])
        XCTAssertEqual(z.hero.score(.sila), 4)
        XCTAssertEqual(Catalog.validTraits(["xyz", "silak", "silak"]), ["silak"])
        XCTAssertTrue(Prompts.stateBlock(s).contains("Povaha: Silák, Odvážný"))
        XCTAssertTrue(Prompts.stateBlock(s).contains("Obchodní nos"))
    }

    func testAbilityGivesBonusAndIsSpent() {
        var s = hero("zoldner")
        let base = Rules.resolve(state: &s, intent: ActionIntent(summary: "útok", category: .combat))
        var s2 = hero("zoldner")
        let boosted = Rules.resolve(state: &s2, intent: ActionIntent(summary: "útok", category: .combat, itemsUsed: ["Bojový řev"]))
        XCTAssertEqual(boosted.roll.modifier - base.roll.modifier, 4)
        XCTAssertEqual(boosted.usedAbilities, ["bojovy_rev"])
        XCTAssertTrue(boosted.missingItems.isEmpty, "schopnost není chybějící předmět")
        var st = GameEngine.apply(state: s2, action: "x", resolution: boosted,
                                  output: NarratorOutput(narration: "Řev.", proposed: boosted.mandatory), now: t0).state
        XCTAssertEqual(st.hero.abilities[0].usesLeft, 1)
        st.hero.abilities[0].usesLeft = 0
        let empty = Rules.resolve(state: &st, intent: ActionIntent(summary: "útok", category: .combat, itemsUsed: ["bojovy rev"]))
        XCTAssertTrue(empty.usedAbilities.isEmpty)
        XCTAssertTrue(empty.notes.contains { $0.contains("vyčerpaná") })
        // spánek schopnost obnoví
        let rest = Rules.resolve(state: &st, intent: ActionIntent(summary: "spím", category: .rest, difficulty: .trivial, risk: .none))
        let after = GameEngine.apply(state: st, action: "spím", resolution: rest, output: NarratorOutput(narration: "Spíš.", proposed: rest.mandatory), now: t0).state
        XCTAssertEqual(after.hero.abilities[0].usesLeft, 2)
    }

    func testHealingAbility() {
        var s = hero("bylinkar")
        s.hero.hp = 40
        s.hero.conditions = [Condition(kind: .krvaceni, until: t0.addingTimeInterval(36000))]
        let r = Rules.resolve(state: &s, intent: ActionIntent(summary: "léčím se", category: .craft, difficulty: .trivial, risk: .none, itemsUsed: ["Léčivé ruce"]))
        XCTAssertEqual(r.mandatory.hp, 25)
        XCTAssertTrue(r.cures.contains(.krvaceni))
        // záložní vypravěč pozná schopnost v textu
        XCTAssertTrue(Fallback.interpret("Použiju léčivé ruce na ránu", state: s).itemsUsed.contains("Léčivé ruce"))
    }

    func testTraitEffects() {
        // Noční pták: v noci bonus místo postihu
        var owl = hero("lovec", traits: ["nocni"]); owl.phase = 3
        var plain = hero("lovec"); plain.phase = 3
        let a = Rules.resolve(state: &owl, intent: ActionIntent(summary: "x", category: .combat))
        let b = Rules.resolve(state: &plain, intent: ActionIntent(summary: "x", category: .combat))
        XCTAssertEqual(a.roll.modifier - b.roll.modifier, 2)
        // Železná vůle: stres nezhoršuje hody
        var iron = hero("lovec", traits: ["zelezna_vule"]); iron.hero.stress = 95
        var weak = hero("lovec"); weak.hero.stress = 95
        let c = Rules.resolve(state: &iron, intent: ActionIntent(summary: "x", category: .explore))
        let d = Rules.resolve(state: &weak, intent: ActionIntent(summary: "x", category: .explore))
        XCTAssertEqual(c.roll.modifier - d.roll.modifier, 3)
        // Nespavec: později unavený
        var ns = hero("lovec", traits: ["nespavec"]); ns.hero.awakeHours = 20
        XCTAssertTrue(World.conditions(ns.hero, at: t0).isEmpty)
        ns.hero.awakeHours = 41
        XCTAssertEqual(World.conditions(ns.hero, at: t0), [.vycerpani])
        // Šťastlivec: přirozená 1 je vzácnější
        var lucky = 0, unlucky = 0
        for seed in 1...400 as ClosedRange<UInt64> {
            var l = GameEngine.newGame(NewGameSetup(mode: .quest, heroName: "A", cityName: "", backgroundId: "lovec", seed: seed, traits: ["stastlivec"]), now: t0).state
            var u = GameEngine.newGame(NewGameSetup(mode: .quest, heroName: "A", cityName: "", backgroundId: "lovec", seed: seed), now: t0).state
            if Rules.resolve(state: &l, intent: ActionIntent(summary: "x", category: .combat)).roll.die == 1 { lucky += 1 }
            if Rules.resolve(state: &u, intent: ActionIntent(summary: "x", category: .combat)).roll.die == 1 { unlucky += 1 }
        }
        XCTAssertLessThan(lucky, unlucky)
        // Odvážný: méně stresu z boje
        var brave = hero("zoldner", traits: ["odvazny"]), coward = hero("zoldner")
        let e = Rules.resolve(state: &brave, intent: ActionIntent(summary: "x", category: .combat, difficulty: .trivial))
        let f = Rules.resolve(state: &coward, intent: ActionIntent(summary: "x", category: .combat, difficulty: .trivial))
        XCTAssertLessThan(e.mandatory.stress, f.mandatory.stress)
    }

    func testOldHeroWithoutAbilitiesLoads() throws {
        let s = hero("zoldner")
        var json = try JSONSerialization.jsonObject(with: SaveStore.encoder.encode(s)) as! [String: Any]
        var h = json["hero"] as! [String: Any]
        h.removeValue(forKey: "traits"); h.removeValue(forKey: "abilities")
        json["hero"] = h
        let back = try SaveStore.decoder.decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(back.hero.abilities.isEmpty)
        XCTAssertTrue(back.hero.traits.isEmpty)
    }
}

final class NarrationQualityTests: XCTestCase {
    func testStatNumbersAreScrubbed() {
        let t = "Najdeš klíč. Tvá únava se projevuje, stres stoupá o 2. Zásoby se snížily o 10 %, což je rána. Za dveřmi něco zaškrábe."
        let c = GameEngine.clean(t)
        XCTAssertEqual(c, "Najdeš klíč. Za dveřmi něco zaškrábe.")
        XCTAssertEqual(GameEngine.clean("Seber tři zlaté mince a jdi."), "Seber tři zlaté mince a jdi.")
        XCTAssertEqual(GameEngine.clean("[Vítej v kraji.`]"), "Vítej v kraji.")
        XCTAssertEqual(GameEngine.clean(". Píseň o hrdince zní dál."), "Píseň o hrdince zní dál.")
    }

    func testEasyStepsDoNotAdvanceQuest() {
        var s = GameEngine.newGame(NewGameSetup(mode: .quest, heroName: "A", cityName: "", backgroundId: "lovec", seed: 3)).state
        for _ in 0..<30 {
            let r = Rules.resolve(state: &s, intent: ActionIntent(summary: "rozhlédnu se", category: .explore, difficulty: .easy))
            XCTAssertEqual(r.questGain, 0)
            let h = Rules.resolve(state: &s, intent: ActionIntent(summary: "útok", category: .combat, difficulty: .hard))
            XCTAssertLessThanOrEqual(h.questGain, 1)
        }
    }
}
