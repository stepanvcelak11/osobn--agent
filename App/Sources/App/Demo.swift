#if DEBUG
import Foundation
import RealmCore

/// Ukázkové příběhy pro snímky obrazovky v simulátoru (jen ladicí sestavení; spouští se proměnnou PR_DEMO).
enum Demo {
    static var mode: String? { ProcessInfo.processInfo.environment["PR_DEMO"] }
    static var sheet: String? { ProcessInfo.processInfo.environment["PR_SHEET"] }
    static var step: Int? { ProcessInfo.processInfo.environment["PR_STEP"].flatMap(Int.init) }

    static func story(_ name: String) -> Story? {
        switch name {
        case "game-quest", "gameover":
            var s = StoryEngine.newStory(NewStory(mode: .quest, heroName: "Libuše", classId: "bard", feminine: true, seed: 3))
            s.title = "Kovář v zajetí"; s.goal = "Osvoboď kováře Radima z rukou lapků"
            s.log = [
                Entry(kind: .narration, text: "Sedíš u okna v hospodě ve vsi Lipnice a ladíš loutnu. U vedlejšího stolu si dva sedláci šeptají, že kováře Radima včera odvlekli lapkové. U výčepu stojí uplakaná dívka a prosí hostinského o pomoc."),
                Entry(kind: .player, text: "Přisednu si k dívce a zeptám se, co se stalo", input: .act),
                Entry(kind: .narration, text: "Dívka se jmenuje Anička a je kovářova dcera. Prý přišli za soumraku, čtyři muži v kožených kabátcích. Otce svázali a odvedli k lesu za mlýnem. Jeden z nich měl na tváři dlouhou jizvu."),
                Entry(kind: .player, text: "Neboj, já tvého otce najdu.", input: .say),
                Entry(kind: .narration, text: "Anička na tebe chvíli nedůvěřivě hledí. Pak přikývne a vytáhne z kapsy malý železný přívěsek. „Tohle mu dej, až ho najdeš. Pozná, že tě posílám já.“"),
                Entry(kind: .event, text: "✦ Příběh se posunul (1/3)"),
                Entry(kind: .player, text: "Přesvědčím hostinského, ať mi řekne, kde lapkové táboří", input: .act,
                      roll: Roll(attribute: .charisma, die: 9, bonus: 6, target: 11, outcome: .success)),
                Entry(kind: .narration, text: "Hostinský se ošívá, ale tvůj úsměv a pár veselých slov ho obměkčí. Nakloní se blíž a zašeptá, že lapkové kupují pivo u starého uhlíře na kraji lesa. Prý se vždycky vracejí k Černé skále."),
            ]
            s.stage = 1; s.turns = 3; s.turnsInStage = 1
            if name == "gameover" {
                s.end = .victory; s.stage = 3
                s.epilogue = "O bardce Libuši se v Lipnici zpívá dodnes. Prý vešla do tábora lapků jen s loutnou a odešla s kovářem Radimem. Jizvatý lapka od té doby v kraji nikdo neviděl."
            }
            return s
        case "game-realm", "game-endless":
            var s = StoryEngine.newStory(NewStory(mode: name == "game-realm" ? .realm : .endless, heroName: "Bořek", classId: "valecnik",
                                                  feminine: false, place: "Vranov", seed: 5))
            s.log = [
                Entry(kind: .narration, text: "Právě přijíždíš do osady Vranov na okraji divočiny. Na návsi čeká rychtář Matěj a hrstka nedůvěřivých lidí. Palisáda je na dvou místech prohnilá a sýpka zeje prázdnotou."),
                Entry(kind: .player, text: "Zeptám se rychtáře, co osadu nejvíc trápí", input: .act),
                Entry(kind: .narration, text: "Rychtář si odplivne. „Hlad, pane. Loni nám vlci roztrhali půlku ovcí a letos nepršelo.“ Ukáže k lesu, kde se nad stromy zvedá tenký sloupek dýmu. „A tamhle se usadili cizí uhlíři. Nikdo neví, kdo je poslal.“"),
            ]
            s.turns = 1; s.turnsInStage = 1
            return s
        case "game-campaign":
            var s = StoryEngine.newStory(NewStory(mode: .campaign, heroName: "Vlasta", classId: "lovec", feminine: true, place: "Kamenice", seed: 9))
            s.log = [
                Entry(kind: .narration, text: "Město Kamenice padlo. Stojíš na náměstí mezi vozy a vystrašenými lidmi. Za hradbami ještě doutnají střechy a vítr nese pach spáleniny."),
                Entry(kind: .player, text: "Vystopuju bezpečnou cestu z města", input: .act,
                      roll: Roll(attribute: .duvtip, die: 12, bonus: 2, target: 11, outcome: .success)),
                Entry(kind: .narration, text: "Mezi sutinami najdeš starou kupeckou cestu, kterou útočníci přehlédli. Vede kolem řeky k severní bráně. Lidé se za tebou tiše řadí a vozy se dávají do pohybu."),
            ]
            s.setbacks = 1; s.turns = 1
            return s
        default:
            return nil
        }
    }
}
#endif
