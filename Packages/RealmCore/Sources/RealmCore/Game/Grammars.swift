import Foundation

/// GBNF gramatiky pro llama.cpp – model nemůže vrátit nic jiného než platný JSON v daném tvaru.
public enum Grammars {
    static let common = """
    ws ::= " "?
    char ::= [^"\\\\\\x7F\\x00-\\x1F] | "\\\\" (["\\\\/bfnrt] | "u" [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F])
    text ::= "\\"" char+ "\\""
    short ::= "\\"" char{1,90} "\\""
    name ::= "\\"" char{2,40} "\\""
    int ::= "-"? [0-9] [0-9]? [0-9]?
    bool ::= "true" | "false"
    names ::= "[" ws ( name ( "," ws name ){0,2} )? ws "]"
    """

    static func enumRule(_ name: String, _ values: [String]) -> String {
        "\(name) ::= " + values.map { "\"\\\"\($0)\\\"\"" }.joined(separator: " | ")
    }

    /// Krok 1: posouzení akce hráče.
    public static func interpreter(mode: GameMode) -> String {
        var root = #"root ::= "{" ws "\"intent\":" ws short "," ws "\"category\":" ws category "," ws "\"stat\":" ws stat "," ws "\"difficulty\":" ws difficulty "," ws "\"risk\":" ws risk "," ws "\"items_used\":" ws names"#
        if mode == .realm { root += #" "," ws "\"build\":" ws build"# }
        root += #" ws "}""#
        var cats = ActionCategory.allCases.map(\.rawValue)
        if mode != .realm { cats.removeAll { $0 == "build" } }
        if mode != .campaign { cats.removeAll { $0 == "travel" } }
        var rules = [root, common,
                     enumRule("category", cats),
                     enumRule("stat", Attribute.allCases.map(\.rawValue) + ["none"]),
                     enumRule("difficulty", Difficulty.allCases.map(\.rawValue)),
                     enumRule("risk", Risk.allCases.map(\.rawValue))]
        if mode == .realm { rules.append(enumRule("build", ["none"] + BuildingKind.allCases.map(\.rawValue))) }
        return rules.joined(separator: "\n") + "\n"
    }

    /// Krok 2: vyprávění + změny. Vyprávění je první pole, aby šlo plynule zobrazovat.
    public static func narrator(mode: GameMode) -> String {
        var root = #"root ::= "{\"narration\":" text "," ws "\"hp\":" ws int "," ws "\"stress\":" ws int "," ws "\"gold\":" ws int"#
        if mode != .quest {
            root += #" "," ws "\"food\":" ws int "," ws "\"pop\":" ws int "," ws "\"defense\":" ws int "," ws "\"morale\":" ws int"#
        }
        root += #" "," ws "\"items_gained\":" ws gained "," ws "\"items_lost\":" ws names "," ws "\"location\":" ws short "," ws "\"scene\":" ws scene "," ws "\"chronicle\":" ws short"#
        if mode == .quest { root += #" "," ws "\"objective_done\":" ws bool"# }
        if mode == .realm { root += #" "," ws "\"resolve_threat\":" ws bool"# }
        root += #" ws "}""#
        return [root, common,
                #"gained ::= "[" ws ( gitem ( "," ws gitem )? )? ws "]""#,
                #"gitem ::= "{" ws "\"name\":" ws name "," ws "\"kind\":" ws kind ws "}""#,
                enumRule("kind", ItemKind.allCases.map(\.rawValue)),
                enumRule("scene", SceneKind.allCases.map(\.rawValue))].joined(separator: "\n") + "\n"
    }

    /// Úvod a epilog – jen text.
    public static let story = [#"root ::= "{\"narration\":" text ws "}""#, common].joined(separator: "\n") + "\n"

    /// Všechny gramatiky (pro ověření parserem llama.cpp v CI).
    public static var all: [String: String] {
        var d: [String: String] = ["story": story]
        for m in GameMode.allCases {
            d["interpreter_\(m.rawValue)"] = interpreter(mode: m)
            d["narrator_\(m.rawValue)"] = narrator(mode: m)
        }
        return d
    }
}
