#if DEBUG
import Foundation
import RealmCore

/// Ukázkové stavy pro snímky obrazovky v simulátoru (jen ladicí sestavení; spouští se proměnnou PR_DEMO).
enum Demo {
    static var mode: String? { ProcessInfo.processInfo.environment["PR_DEMO"] }
    static var sheet: String? { ProcessInfo.processInfo.environment["PR_SHEET"] }

    static func state(_ name: String) -> GameState? {
        let now = Date()
        switch name {
        case "game-quest", "gameover":
            var s = GameEngine.newGame(NewGameSetup(mode: .quest, heroName: "Ráchel", cityName: "Vranov", backgroundId: "stinochod", feminine: true, seed: 11), now: now).state
            s.log = [
                LogEntry(kind: .narration, text: "Vítej v kraji, kde slunce vychází neochotně, Ráchel. Před tebou se z mlhy noří vypálený klášter sv. Havla a pod ním zeje vchod do kobky. Z hlubin stoupá šedá mlha, která páchne rzí a mokrou hlínou. Někde dole cosi tiše škrábe o kámen. Co uděláš?"),
                LogEntry(kind: .player, text: "Potichu se proplížím ke vchodu a poslouchám"),
                LogEntry(kind: .narration, text: "Kroky tlumíš o mech mezi kameny. U vchodu se zastavíš – škrábání utichne a místo něj uslyšíš dech. Pomalý, chrčivý, jako by patřil něčemu velkému, co spí. Na schodu se zaleskne rezavý klíč.",
                         roll: RollInfo(die: 14, modifier: 3, dc: 12, stat: .obratnost, outcome: .success),
                         delta: StatDelta(stress: 3), itemsAdded: ["Rezavý klíč"], hours: 0.25),
                { var e = LogEntry(kind: .player, text: "Je tam někdo? Ukaž se, nebo tam hodím oheň!"); e.input = .say; e.day = 1; return e }(),
                LogEntry(kind: .narration, text: "Z hlubiny se ozve chraplavý smích. „Oheň? Tady dole hoří jen mlha, děvče,“ zašeptá hlas, který zní jako stará Jitka z tržiště. Pak ticho – a škrábání se vrátí, blíž než předtím.",
                         delta: StatDelta(stress: 4), hours: 0.25),
                { var e = LogEntry(kind: .player, text: "Seberu klíč a hodím kouřovou bombu dolů do tmy"); e.day = 2; return e }(),
                LogEntry(kind: .narration, text: "Bomba se rozprskne o schody a kobku zaplní štiplavý dým. Něco dole zařve a vyrazí proti tobě – drápy tě zasáhnou do ramene dřív, než stihneš uskočit. Bolest je ostrá, ale stvůra v dýmu tápe.",
                         roll: RollInfo(die: 6, modifier: 4, dc: 12, stat: .obratnost, outcome: .partial),
                         delta: StatDelta(hp: -9, stress: 7), itemsRemoved: ["Kouřová bomba"], hours: 0.25),
            ]
            s.turn = 2
            s.quest?.progress = 1
            s.hero.hp = 91; s.hero.stress = 20
            s.hero.items.append(Item(name: "Rezavý klíč", kind: .key))
            s.log.append(LogEntry(kind: .event, text: "🩸 Krvácíš. Ošetři ránu, než tě oslabí."))
            s.log.append(LogEntry(kind: .event, text: "⭐ Úroveň 2! Obratnost +1 – učíš se tím, co děláš. Zdraví +20, stres −15."))
            s.location = "Les u kláštera sv. Havla"
            s.scene = .forest
            s.phase = 3
            s.day = 2
            s.weather = .mlha
            s.hero.level = 2; s.hero.xp = 95
            s.hero.conditions = [Condition(kind: .krvaceni, until: s.worldTime.addingTimeInterval(8 * 3600))]
            s.hero.awakeHours = 19
            s.characters = [NPC(name: "Stará Jitka", role: "kořenářka", attitude: .neutral, lastSeen: 2)]
            if name == "gameover" {
                s.end = .victory
                s.turn = 7
                s.quest?.progress = 3
                s.achievements = ["vitez_vyprava", "osud", "prvni_krev"]
                s.epilogue = "Říká se, že Ráchel ze slumů Vranova sestoupila do kobky, odkud se nikdo nevrátil, a vynesla Srdce mlhy v holých dlaních. Mlha od té doby nad klášterem nestoupá – a děti si hrají na stínochodku, která se nebála tmy."
            }
            return s
        case "game-realm", "game-endless":
            var s = GameEngine.newGame(NewGameSetup(mode: name == "game-endless" ? .endless : .realm, heroName: "Ota", cityName: "Černá Lhota", backgroundId: "rytir", seed: 5), now: now).state
            s.log = [
                LogEntry(kind: .narration, text: "Vítej v osadě Černá Lhota, Oto. Pár desítek duší, jedna farma a rozpadlá palisáda. Lidé k tobě vzhlížejí a čekají, jestli je dovedeš přes zimu."),
                LogEntry(kind: .event, text: "🌅 Úsvit 2. dne. Jídlo +5, zlato +8; přibyli 2 obyvatelé.", delta: StatDelta(pop: 2, gold: 8, food: 5)),
                LogEntry(kind: .event, text: "⚠️ Hrozba: Lapkové z Vlčího lesa (lapkové) – udeří za 31 h. Připrav osadu, nebo jednej."),
                LogEntry(kind: .player, text: "Postavím hradby"),
                LogEntry(kind: .narration, text: "Svoláš muže na návsi. Kladiva tlučou do pozdní noci a z lesa se ozývá odpověď – vytí, které nepatří vlkům. Někdo tvrdí, že mezi stromy viděl světla. Šepot se šíří od chalupy k chalupě.", delta: StatDelta(gold: -60)),
                LogEntry(kind: .event, text: "🔨 Stavba zahájena: Hradby – hotovo za 10 h."),
            ]
            s.settlement.population = 34; s.settlement.gold = 41; s.settlement.food = 64
            s.settlement.construction = [Construction(kind: .palisada, finishAt: s.worldTime.addingTimeInterval(6 * 3600))]
            s.threats = [Threat(kind: .bandits, title: "Lapkové z Vlčího lesa", strength: 24, deadline: s.worldTime.addingTimeInterval(31 * 3600))]
            s.hero.stress = 78; s.hero.hp = 64
            s.day = 2; s.turn = 4
            s.scene = .town
            s.weather = name == "game-endless" ? .snih : .dest
            if name == "game-endless" { s.day = 64; s.settlement.population = 118; s.settlement.buildings = [.farma: 3, .sypka: 2, .palisada: 1, .trziste: 1] }
            s.hero.level = 3; s.hero.xp = 190
            s.contract = Contract(title: "Najdi mlynářovu dceru, která se ztratila v lese", giver: "mlynář Kuba", categories: [.explore, .combat, .social],
                                  reward: Reward(gold: 30, morale: 8), deadline: s.worldTime.addingTimeInterval(40 * 3600))
            s.characters = [NPC(name: "Mlynář Kuba", role: "mlynář", attitude: .friend, lastSeen: 3),
                            NPC(name: "Banda Jednookého Matěje", role: "lapkové", attitude: .hostile, lastSeen: 2),
                            NPC(name: "Bratr Kliment", role: "potulný mnich", attitude: .neutral, lastSeen: 1)]
            s.log.insert(LogEntry(kind: .event, text: "📜 Zakázka: Najdi mlynářovu dceru, která se ztratila v lese (zadává mlynář Kuba). Odměna: 30 zlata, +8 morálka. Čas: 40 h."), at: 3)
            return s
        case "game-campaign":
            var s = GameEngine.newGame(NewGameSetup(mode: .campaign, heroName: "Matěj", cityName: "Popelín", backgroundId: "zoldner", seed: 8), now: now).state
            s.journey?.index = 3
            s.location = s.journey!.current.name
            s.scene = s.journey!.current.scene
            s.log = [
                LogEntry(kind: .player, text: "Vyrazíme dál"),
                LogEntry(kind: .narration, text: "Vozy vrzají v blátě a koně funí. Když dorazíte k \(s.location), z křoví vyletí šípy. Lapkové! Tví žoldáci je zaženou, ale dva lidé zůstanou ležet v trávě a kus nákladu je pryč.",
                         roll: RollInfo(die: 11, modifier: 1, dc: 12, stat: .obratnost, outcome: .partial),
                         delta: StatDelta(pop: -2, gold: -10, food: -19, morale: -8, stress: 10), hours: 24),
            ]
            s.settlement.population = 22; s.settlement.food = 38; s.settlement.morale = 48
            s.turn = 9; s.day = 2; s.phase = 2
            s.weather = .bourka
            s.premise = "Vedu karavanu, ale v jednom z vozů se skrývá zrádce, který posílá zprávy lapkům."
            s.memory = "Vítek, syn vdovy Hedviky, nosí na krku rodinný amulet se sokolem."
            s.authorsNote = "Ponurá atmosféra, víc dialogů, krátké úderné věty."
            s.log.append({ var e = LogEntry(kind: .player, text: "Karavana se ukryje v rokli a přečká bouři. Vdova Hedvika pláče pro syna."); e.input = .story; e.day = 3; return e }())
            s.log.append(LogEntry(kind: .narration, text: "Vozy stáhnete do rokle a plachty přivážete ke skalám. Bouře řve celou noc. Hedvika sedí u ohně a hledí do tmy, kde naposledy viděla syna – a ráno ti podá jeho rozbitou píšťalku, kterou našla v blátě.", hours: 0.25))
            return s
        default:
            return nil
        }
    }
}
#endif
