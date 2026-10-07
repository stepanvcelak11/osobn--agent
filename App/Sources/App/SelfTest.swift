#if DEBUG
import Foundation
import SwiftUI
import RealmCore

/// Samotest aplikace v simulátoru (CI): odehraje příběhy ve všech módech přes skutečné GameSession,
/// vyzkouší způsoby tahu, Znovu, Vrátit, paměť, uložení, načtení a konec hry. Výsledek zapíše do Documents/selftest.txt.
@MainActor
enum SelfTest {
    static var requested: Bool { Demo.mode == "selftest" }

    static func run(_ app: AppModel) async {
        var log: [String] = []
        var failures: [String] = []
        func check(_ ok: Bool, _ what: String) { if !ok { failures.append(what) } }

        func waitIdle(_ s: GameSession, _ what: String) async {
            var n = 0
            try? await Task.sleep(nanoseconds: 50_000_000)
            while (s.isBusy || s.pendingAction != nil) && n < 600 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                n += 1
            }
            check(n < 600, "\(what): zaseknuto")
        }

        let actions: [(String, InputMode)] = [
            ("Kde to jsem?", .act),
            ("Rozhlédnu se kolem", .act),
            ("Dobrý den, hledám rychtáře", .say),
            ("Z mlhy vystoupí stará žena s lucernou.", .story),
            ("", .proceed),
            ("Zaútočím na lapka", .act),
            ("Přesvědčím ho, ať mi pomůže", .say),
        ]

        for (i, mode) in GameMode.allCases.enumerated() {
            let k = HeroClass.all[i % HeroClass.all.count]
            app.startNewGame(NewStory(mode: mode, heroName: "Test \(i)", classId: k.id, feminine: i % 2 == 0, place: "Zkouškov",
                                      premise: i == 0 ? "Drak unesl princeznu." : "", seed: UInt64(1000 + i)))
            guard let s = app.session else { failures.append("\(mode): žádná relace"); continue }
            await waitIdle(s, "\(mode) úvod")
            check(s.story.log.contains { $0.kind == .narration }, "\(mode): chybí úvod")
            check(!s.story.log.contains { $0.kind == .event }, "\(mode): úvod nemá dávat nápovědy")
            if i == 0 { check(s.story.goal == "Drak unesl princeznu.", "vlastní téma se nepoužilo") }
            s.setMemory("Bratr Ondřej má jizvu.", note: "víc hororu")
            for (text, im) in actions where !s.story.isOver {
                let before = s.story.turns
                s.send(text, mode: im)
                await waitIdle(s, "\(mode) \(im)")
                check(s.story.turns == before + 1 || s.story.isOver, "\(mode) \(im): tah neproběhl (\(s.error ?? "-"))")
            }
            if !s.story.isOver {
                let turns = s.story.turns
                s.retry()
                await waitIdle(s, "\(mode) znovu")
                check(s.story.turns == turns, "\(mode): Znovu změnilo počet tahů")
                s.undo()
                check(s.story.turns == turns - 1, "\(mode): Vrátit nefunguje")
            }
            let id = s.story.id, turns = s.story.turns
            app.closeSession()
            if let loaded = try? app.store.load(id) {
                check(loaded.turns == turns, "\(mode): po načtení jiný tah")
                check(loaded.memory == "Bratr Ondřej má jizvu.", "\(mode): paměť se neuložila")
                check(loaded.hero.classId == k.id, "\(mode): postava se neuložila")
            } else { failures.append("\(mode): nejde načíst") }
            app.open(id)
            if let s2 = app.session { await waitIdle(s2, "\(mode) znovuotevření"); app.closeSession() }
            log.append("\(mode.rawValue): \(turns) tahů OK")
        }
        app.refreshSaves()
        check(app.running.count >= 3, "rozehrané hry: \(app.saves.count)")
        // Konec hry a epilog
        app.startNewGame(NewStory(mode: .quest, heroName: "Konec", classId: "bard", feminine: false, seed: 7))
        if let s = app.session {
            await waitIdle(s, "konec úvod")
            s.abandon()
            await waitIdle(s, "epilog")
            check(s.story.isOver && !(s.story.epilogue ?? "").isEmpty, "epilog chybí")
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
