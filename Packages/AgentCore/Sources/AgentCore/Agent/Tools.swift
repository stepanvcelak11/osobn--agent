import Foundation

public enum ParamType: Equatable, Sendable {
    case string
    case integer
    case enumeration([String])
}

public struct ToolParam: Equatable, Sendable {
    public var name: String
    public var type: ParamType
    public var required: Bool
    public var description: String
}

public enum ToolKind: Sendable {
    /// Jen čte data.
    case read
    /// Vytváří nebo mění data (provede se, lze vrátit).
    case write
    /// Mazání / hromadné změny – vždy čeká na potvrzení uživatele.
    case destructive
}

public struct ToolSpec: Equatable, Sendable {
    public var name: String
    public var description: String
    public var params: [ToolParam]
    public var kind: ToolKind

    public static func == (a: ToolSpec, b: ToolSpec) -> Bool { a.name == b.name }
}

/// Všechny nástroje agenta. Agent nemá přístup k ničemu mimo vlastní data aplikace.
public enum Tools {
    public static let createNote = ToolSpec(
        name: "create_note",
        description: "Uloží poznámku (myšlenku, informaci, text k zapamatování).",
        params: [
            .init(name: "text", type: .string, required: true, description: "obsah poznámky"),
            .init(name: "title", type: .string, required: false, description: "krátký název"),
        ], kind: .write)

    public static let createTask = ToolSpec(
        name: "create_task",
        description: "Vytvoří úkol (něco, co má uživatel udělat). Termín je nepovinný.",
        params: [
            .init(name: "title", type: .string, required: true, description: "co udělat, krátce"),
            .init(name: "due", type: .string, required: false, description: "termín česky, např. „do pátku“, „zítra“"),
            .init(name: "priority", type: .enumeration(["normal", "high"]), required: false, description: "priorita"),
        ], kind: .write)

    public static let createReminder = ToolSpec(
        name: "create_reminder",
        description: "Naplánuje připomínku s notifikací v daný čas, případně opakovanou.",
        params: [
            .init(name: "title", type: .string, required: true, description: "co připomenout"),
            .init(name: "when", type: .string, required: true, description: "kdy, česky jak řekl uživatel, např. „zítra v 8“, „každé pondělí v 7“"),
        ], kind: .write)

    public static let createEvent = ToolSpec(
        name: "create_event",
        description: "Vytvoří událost v kalendáři (schůzka, návštěva, akce).",
        params: [
            .init(name: "title", type: .string, required: true, description: "název události"),
            .init(name: "start", type: .string, required: true, description: "začátek česky, např. „ve čtvrtek ve 14“"),
            .init(name: "duration_minutes", type: .integer, required: false, description: "délka v minutách"),
            .init(name: "location", type: .string, required: false, description: "místo"),
        ], kind: .write)

    public static let completeTask = ToolSpec(
        name: "complete_task",
        description: "Označí úkol jako splněný.",
        params: [
            .init(name: "ref", type: .string, required: true, description: "odkaz na úkol (např. U2) nebo jeho název"),
        ], kind: .write)

    public static let updateItem = ToolSpec(
        name: "update_item",
        description: "Upraví existující položku (název, čas, text).",
        params: [
            .init(name: "ref", type: .string, required: true, description: "odkaz na položku (N1, U2, K3, P4)"),
            .init(name: "title", type: .string, required: false, description: "nový název"),
            .init(name: "when", type: .string, required: false, description: "nový čas / termín česky"),
            .init(name: "text", type: .string, required: false, description: "nový text poznámky"),
        ], kind: .write)

    public static let deleteItem = ToolSpec(
        name: "delete_item",
        description: "Smaže položku. Uživatel to vždy musí potvrdit.",
        params: [
            .init(name: "ref", type: .string, required: true, description: "odkaz na položku (N1, U2, K3, P4)"),
        ], kind: .destructive)

    public static let listAgenda = ToolSpec(
        name: "list_agenda",
        description: "Vypíše události, připomínky a úkoly s termínem v daném období.",
        params: [
            .init(name: "range", type: .enumeration(["today", "tomorrow", "week", "next_week", "overdue"]),
                  required: true, description: "období"),
        ], kind: .read)

    public static let listTasks = ToolSpec(
        name: "list_tasks",
        description: "Vypíše úkoly.",
        params: [
            .init(name: "status", type: .enumeration(["open", "done"]), required: true, description: "nesplněné / splněné"),
        ], kind: .read)

    public static let searchNotes = ToolSpec(
        name: "search_notes",
        description: "Hledá v poznámkách podle významu i slov.",
        params: [
            .init(name: "query", type: .string, required: true, description: "co hledat"),
        ], kind: .read)

    public static let undoLast = ToolSpec(
        name: "undo_last",
        description: "Vrátí zpět poslední akci agenta.",
        params: [], kind: .write)

    public static let all: [ToolSpec] = [
        createNote, createTask, createReminder, createEvent, completeTask, updateItem, deleteItem,
        listAgenda, listTasks, searchNotes, undoLast,
    ]

    /// Nástroje pro rychlé zachycení – jen zařazení myšlenky.
    public static let capture: [ToolSpec] = [createNote, createTask, createReminder]

    public static func spec(_ name: String) -> ToolSpec? { all.first { $0.name == name } }
}

public struct ToolCall: Equatable, Sendable {
    public var name: String
    public var args: JSONValue
    public init(name: String, args: JSONValue) { self.name = name; self.args = args }
    public init(_ name: String, _ args: [String: String]) {
        self.name = name
        self.args = .object(args.mapValues { .string($0) })
    }
}

/// Rozhodnutí modelu (jediný JSON objekt na výstupu).
public enum AgentDecision: Equatable, Sendable {
    case answer(String)
    case ask(String)
    case tool(ToolCall)

    public static func parse(_ text: String) -> AgentDecision? {
        // Model může přidat text kolem – vezmeme první vyvážený JSON objekt.
        guard let json = extractFirstJSONObject(text), let v = JSONValue.parse(json) else { return nil }
        switch v["type"]?.stringValue {
        case "answer": return .answer(v["text"]?.stringValue ?? "")
        case "ask": return .ask(v["text"]?.stringValue ?? "")
        case "tool":
            guard let name = v["name"]?.stringValue else { return nil }
            return .tool(ToolCall(name: name, args: v["args"] ?? .object([:])))
        default: return nil
        }
    }

    public var json: String {
        switch self {
        case .answer(let t): return JSONValue.object(["type": .string("answer"), "text": .string(t)]).compactJSON(order: ["type", "text"])
        case .ask(let t): return JSONValue.object(["type": .string("ask"), "text": .string(t)]).compactJSON(order: ["type", "text"])
        case .tool(let c):
            return "{\"type\":\"tool\",\"name\":\"\(c.name)\",\"args\":\(c.args.compactJSON(order: Tools.spec(c.name)?.params.map(\.name) ?? []))}"
        }
    }

    static func extractFirstJSONObject(_ s: String) -> String? {
        guard let start = s.firstIndex(of: "{") else { return nil }
        var depth = 0, inString = false, escape = false
        var i = start
        while i < s.endIndex {
            let c = s[i]
            if inString {
                if escape { escape = false }
                else if c == "\\" { escape = true }
                else if c == "\"" { inString = false }
            } else {
                if c == "\"" { inString = true }
                else if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 { return String(s[start...i]) }
                }
            }
            i = s.index(after: i)
        }
        return nil
    }
}

extension JSONValue {
    /// Kompaktní JSON se zadaným pořadím klíčů (pro konzistentní ukázky v promptu).
    func compactJSON(order: [String]) -> String {
        guard case .object(let o) = self else { return jsonString }
        let keys = order.filter { o[$0] != nil } + o.keys.filter { !order.contains($0) }.sorted()
        return "{" + keys.map { "\(JSONValue.string($0).jsonString):\(o[$0]!.jsonString)" }.joined(separator: ",") + "}"
    }
}

/// Generátor gramatiky GBNF pro llama.cpp – model pak MUSÍ vrátit platný JSON ve správném tvaru.
public enum GrammarBuilder {
    public static func agentGrammar(tools: [ToolSpec], allowAnswer: Bool = true, allowAsk: Bool = true) -> String {
        var rules: [String] = []
        var rootAlts: [String] = []
        if allowAnswer { rootAlts.append("answer") }
        if allowAsk { rootAlts.append("ask") }
        if !tools.isEmpty { rootAlts.append("toolcall") }
        rules.append("root ::= " + rootAlts.joined(separator: " | "))
        rules.append(#"answer ::= "{\"type\":\"answer\",\"text\":" str "}""#)
        rules.append(#"ask ::= "{\"type\":\"ask\",\"text\":" str "}""#)
        if !tools.isEmpty {
            rules.append("toolcall ::= " + tools.map { "t-" + ruleName($0.name) }.joined(separator: " | "))
            for t in tools {
                rules.append("t-\(ruleName(t.name)) ::= " + #""{\"type\":\"tool\",\"name\":\"\#(t.name)\",\"args\":" "# + argsRule(t) + #" "}""#)
            }
        }
        rules.append(#"str ::= "\"" chr* "\"""#)
        rules.append(#"chr ::= [^"\\\x00-\x1F] | "\\" (["\\/bfnrt] | "u" [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F])"#)
        rules.append(#"int ::= "-"? [0-9] [0-9]? [0-9]? [0-9]? [0-9]?"#)
        return rules.joined(separator: "\n") + "\n"
    }

    /// Gramatika jen pro volnou odpověď (shrnutí apod.).
    public static var answerOnly: String { agentGrammar(tools: [], allowAnswer: true, allowAsk: false) }

    static func ruleName(_ s: String) -> String { s.replacingOccurrences(of: "_", with: "-") }

    static func argsRule(_ t: ToolSpec) -> String {
        let required = t.params.filter(\.required)
        let optional = t.params.filter { !$0.required }
        if required.isEmpty && optional.isEmpty { return #""{}""# }
        var parts: [String] = []
        var first = true
        for p in required {
            parts.append(#"""# + (first ? "{" : ",") + #"\"\#(p.name)\":" "# + valueRule(p.type))
            first = false
        }
        if first {
            // Jen nepovinné parametry – první bez čárky (zjednodušeně: celý objekt nebo prázdný)
            let p = optional[0]
            parts.append(#"("{\"\#(p.name)\":" "# + valueRule(p.type) + #" | "{")"#)
            for p in optional.dropFirst() { parts.append(#"(",\"\#(p.name)\":" "# + valueRule(p.type) + ")?") }
        } else {
            for p in optional { parts.append(#"(",\"\#(p.name)\":" "# + valueRule(p.type) + ")?") }
        }
        parts.append(#""}""#)
        return parts.joined(separator: " ")
    }

    static func valueRule(_ t: ParamType) -> String {
        switch t {
        case .string: return "str"
        case .integer: return "int"
        case .enumeration(let vals): return "(" + vals.map { #""\"\#($0)\"""# }.joined(separator: " | ") + ")"
        }
    }
}
