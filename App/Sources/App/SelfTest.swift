#if DEBUG
import Foundation
import SwiftUI
import RealmCore

/// Samotest aplikace v simulátoru (CI): odehraje hry ve všech módech přes skutečné GameSession,
/// vyzkouší režimy psaní, Znovu, Vrátit, paměť, uložení a načtení. Výsledek zapíše do Documents/selftest.txt.
@MainActor
enum SelfTest {
    static var requested: Bool { Demo.mode == "selftest" }

    static func run(_ app: AppModel) async {
        var log: [String] = []
        var failures: [String] = []
        func check(_ ok: Bool, _ what: String) { if !ok { failures.append(what) } }

        func waitIdle(_ s: GameSession, _ what: String) async {
            var n = 0
            // nejdřív počkat, až se tah rozjede, pak až doběhne
            try? await Task.sleep(nanoseconds: 50_000_000)
            while (s.isBusy || s.pendingAction != nil) && n < 600 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                n += 1
            }
            check(n < 600, "\(what): zaseknuto")
            s.diceOverlay = nil
        }

        let actions: [(String, InputMode)] = [
            ("Rozhlédnu se kolem a hledám stopy", .act),
            ("Kdo je tam? Ukaž se!", .say),
            ("Z mlhy vystoupí stará žena s lucernou.", .story),
            ("", .proceed),
            ("Použiju schopnost a zaútočím", .act),
            ("Postavím farmu", .act),
            ("Vyrazíme dál", .act),
            ("Celou noc spím", .act),
        ]

        for (i, mode) in GameMode.allCases.enumerated() {
            let bg = Catalog.backgrounds[(i * 3) % Catalog.backgrounds.count]
            let setup = NewGameSetup(mode: mode, heroName: "Test \(i)", cityName: "Zkouškov", backgroundId: bg.id,
                                     feminine: i % 2 == 0, seed: UInt64(1000 + i), premise: "Samotest.",
                                     traits: [Traits.all[i].id, Traits.all[i + 4].id], bonusPoints: [.duvtip: 2])
            app.startNewGame(setup)
            guard let s = app.session else { failures.append("\(mode): žádná relace"); continue }
            await waitIdle(s, "\(mode) úvod")
            check(!s.state.log.isEmpty, "\(mode): chybí úvod")
            s.setMemory("Bratr Ondřej má jizvu.", note: "víc hororu")
            for (text, im) in actions where !s.state.isOver {
                let before = s.state.turn
                s.send(text, mode: im)
                await waitIdle(s, "\(mode) \(im)")
                check(s.state.turn == before + 1 || s.state.isOver, "\(mode) \(im): tah neproběhl (\(s.error ?? "-"))")
                check(s.state.violations().isEmpty, "\(mode): neplatný stav \(s.state.violations())")
            }
            if !s.state.isOver {
                let turn = s.state.turn
                s.retry()
                await waitIdle(s, "\(mode) znovu")
                check(s.state.turn == turn, "\(mode): Znovu změnilo počet tahů")
                s.undo()
                check(s.state.turn == turn - 1, "\(mode): Vrátit nefunguje")
            }
            if mode.hasSettlement { s.setLiveWorld(false) }
            s.refreshSimulation()
            let id = s.state.id, turn = s.state.turn
            app.closeSession()
            if let loaded = try? app.store.load(id) {
                check(loaded.turn == turn, "\(mode): po načtení jiný tah")
                check(loaded.memory == "Bratr Ondřej má jizvu.", "\(mode): paměť se neuložila")
                check(loaded.hero.abilities.count == 1 && loaded.hero.traits.count == 2, "\(mode): postava se neuložila")
                if mode.hasSettlement { check(!loaded.liveWorld, "\(mode): zastavení času se neuložilo") }
            } else { failures.append("\(mode): nejde načíst") }
            app.open(id)
            if let s2 = app.session { await waitIdle(s2, "\(mode) znovuotevření"); app.closeSession() }
            log.append("\(mode.rawValue): \(turn) tahů OK")
        }
        // Více rozehraných her najednou
        app.refreshSaves()
        check(app.saves.filter { $0.end == nil }.count >= 3, "rozehrané hry: \(app.saves.count)")
        // Konec hry a epilog
        app.startNewGame(NewGameSetup(mode: .quest, heroName: "Smrtelník", cityName: "", backgroundId: "zoldner", seed: 7))
        if let s = app.session {
            await waitIdle(s, "konec úvod")
            s.abandon()
            await waitIdle(s, "epilog")
            check(s.state.isOver && !(s.state.epilogue ?? "").isEmpty, "epilog chybí")
            app.closeSession()
        }
        for sv in app.saves { app.delete(sv.id) }

        let result = (failures.isEmpty ? "SELFTEST OK\n" : "SELFTEST FAIL\n" + failures.joined(separator: "\n") + "\n") + log.joined(separator: "\n")
        print(result)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("selftest.txt")
        try? result.write(to: url, atomically: true, encoding: .utf8)
    }
}
#endif
