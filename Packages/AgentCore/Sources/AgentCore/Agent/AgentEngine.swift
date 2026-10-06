import Foundation

public enum AgentMode: Sendable { case chat, capture }

/// Události během zpracování (pro průběžné zobrazení v UI).
public enum AgentProgress: Sendable {
    case thinking(String)
    case partialAnswer(String)
}

/// Výsledek jednoho kola konverzace.
public struct AgentReply: Sendable {
    /// Text odpovědi (může být prázdný, když mluví jen karta akce).
    public var text: String
    /// Akce provedené / navržené v tomto kole (karty).
    public var actions: [ActionRecord]
    /// Agent se ptá na doplnění.
    public var isQuestion: Bool
    /// Kdo odpověděl: "pravidla" / "model" / "systém".
    public var source: String
    public var stats: [GenerationStats]
}

/// Mozek aplikace: nejdřív pevná pravidla, pak lokální model s nástroji.
public final class AgentEngine: @unchecked Sendable {
    public let store: DataStore
    public let executor: ToolExecutor
    public let refs: RefRegistry
    public var model: LanguageModel?
    public var calendar: Calendar { didSet { executor.calendar = calendar } }
    public var clock: () -> Date { didSet { executor.clock = clock } }
    public var settings: AgentSettings { didSet { executor.settings = settings } }
    /// Použít pravidla (vypíná se v benchmarku modelu).
    public var useRules = true
    public let maxSteps = 4

    private var pending: PendingIntent?
    private let lock = NSLock()

    public init(store: DataStore, model: LanguageModel?, calendar: Calendar = CzechFormat.calendar(),
                settings: AgentSettings = AgentSettings(), clock: @escaping () -> Date = Date.init) {
        self.store = store
        self.refs = RefRegistry()
        self.model = model
        self.calendar = calendar
        self.clock = clock
        self.settings = settings
        self.executor = ToolExecutor(store: store, refs: refs, calendar: calendar, settings: settings, clock: clock)
    }

    var router: RuleRouter { RuleRouter(calendar: calendar, now: clock()) }

    /// Zpracuje vstup uživatele. Uloží zprávy do historie.
    public func handle(_ input: String, mode: AgentMode = .chat,
                       progress: (@Sendable (AgentProgress) -> Void)? = nil) async -> AgentReply {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return AgentReply(text: "", actions: [], isQuestion: false, source: "systém", stats: []) }
        try? store.append(ChatMessage(role: .user, text: text, createdAt: clock()))
        let reply: AgentReply
        do {
            reply = try await process(text, mode: mode, progress: progress)
        } catch {
            reply = AgentReply(text: "Něco se pokazilo: \(error)", actions: [], isQuestion: false, source: "systém", stats: [])
        }
        persist(reply)
        return reply
    }

    private func persist(_ reply: AgentReply) {
        let now = clock()
        for (i, a) in reply.actions.enumerated() {
            try? store.append(ChatMessage(role: .action, text: a.summary, actionId: a.id, createdAt: now.addingTimeInterval(Double(i) * 0.001)))
        }
        if !reply.text.isEmpty {
            try? store.append(ChatMessage(role: .assistant, text: reply.text, createdAt: now.addingTimeInterval(0.01)))
        }
    }

    private func process(_ text: String, mode: AgentMode, progress: (@Sendable (AgentProgress) -> Void)?) async throws -> AgentReply {
        // 1) Doplnění rozpracovaného požadavku
        if useRules, let p = takePending() {
            if let r = router.complete(p, with: text) {
                return try await run(rule: r)
            }
            // Odpověď nepasuje – pokračujeme normálně.
        }

        // 2) Pevná pravidla
        if useRules {
            if mode == .capture {
                if case .tool(let call)? = router.route(text), Tools.capture.contains(where: { $0.name == call.name }) {
                    return try await run(rule: .tool(call))
                }
                if model == nil {
                    return try await run(rule: .tool(router.classifyCapture(text)))
                }
            } else if let r = router.route(text) {
                return try await run(rule: r)
            }
        }

        // 3) Model
        guard let model else {
            if mode == .capture { return try await run(rule: .tool(router.classifyCapture(text))) }
            return AgentReply(text: """
                Jazykový model zatím není načtený, takže rozumím jen základním příkazům, např.:
                • „zítra v 8 mi připomeň zavolat doktorovi“
                • „poznamenej si …“ / „přidej úkol …“
                • „co mám dnes?“ / „jaké mám úkoly?“
                Model nahraješ v Nastavení → Modely.
                """, actions: [], isQuestion: false, source: "systém", stats: [])
        }
        return try await runModel(text, model: model, mode: mode, progress: progress)
    }

    private func takePending() -> PendingIntent? {
        lock.lock(); defer { lock.unlock() }
        let p = pending
        pending = nil
        return p
    }

    private func setPending(_ p: PendingIntent?) {
        lock.lock(); pending = p; lock.unlock()
    }

    private func run(rule: RuleResult) async throws -> AgentReply {
        switch rule {
        case .clarify(let q, let p):
            setPending(p)
            return AgentReply(text: q, actions: [], isQuestion: true, source: "pravidla", stats: [])
        case .tool(let call):
            let out = try await executor.execute(call, source: "pravidla")
            if let q = out.clarification {
                if call.name == "create_reminder", var args = call.args.objectValue?.compactMapValues({ $0.stringValue }) {
                    args["when"] = nil
                    setPending(PendingIntent(tool: call.name, args: args, missing: .when))
                }
                return AgentReply(text: q, actions: [], isQuestion: true, source: "pravidla", stats: [])
            }
            let text = out.action == nil ? (out.replyText ?? "") : ""
            return AgentReply(text: text, actions: out.action.map { [$0] } ?? [], isQuestion: false, source: "pravidla", stats: [])
        }
    }

    // MARK: - Model

    /// Historie pro model (posledních N zpráv, bez aktuální).
    func historyMessages() -> [PromptMessage] {
        let limit = settings.historyMessages
        guard limit > 0, let msgs = try? store.recentMessages(limit: limit + 1) else { return [] }
        var out: [PromptMessage] = []
        for m in msgs.dropLast() { // poslední je aktuální vstup
            switch m.role {
            case .user: out.append(PromptMessage(.user, PromptSanitizer.clean(m.text)))
            case .assistant: out.append(PromptMessage(.assistant, AgentDecision.answer(PromptSanitizer.clean(m.text)).json))
            case .action: out.append(PromptMessage(.assistant, AgentDecision.answer("[Akce] " + PromptSanitizer.clean(m.text)).json))
            case .system: break
            }
        }
        // Šablony vyžadují střídání rolí – sloučíme po sobě jdoucí asistentské zprávy.
        var merged: [PromptMessage] = []
        for m in out {
            if let last = merged.last, last.role == m.role {
                if m.role == .user { merged[merged.count - 1].content += "\n" + m.content }
                else { merged[merged.count - 1] = m }
            } else { merged.append(m) }
        }
        if merged.first?.role == .assistant { merged.removeFirst() }
        if merged.last?.role == .user { merged.removeLast() }
        return merged
    }

    private func runModel(_ text: String, model: LanguageModel, mode: AgentMode,
                          progress: (@Sendable (AgentProgress) -> Void)?) async throws -> AgentReply {
        let tools = mode == .capture ? Tools.capture : Tools.all
        let system = PromptMessage(.system, Prompts.system(now: clock(), calendar: calendar, tools: tools, capture: mode == .capture))
        let userMessage = PromptMessage(.user, PromptSanitizer.clean(text))
        var history = historyMessages()
        // Historie se ořízne odzadu, aby se vše vešlo do kontextu modelu (s rezervou na odpověď a výsledky nástrojů).
        let budget = model.contextLength - 400 - 900
        while !history.isEmpty && model.countTokens(model.template.render([system] + history + [userMessage])) > budget {
            history.removeFirst(min(2, history.count))
        }
        var messages: [PromptMessage] = [system] + history + [userMessage]
        let grammar = GrammarBuilder.agentGrammar(tools: tools, allowAnswer: mode != .capture, allowAsk: true)

        var actions: [ActionRecord] = []
        var stats: [GenerationStats] = []
        var lastCall: ToolCall?
        var lastReadResult: String?

        for step in 0..<maxSteps {
            progress?(.thinking(step == 0 ? "Přemýšlím…" : "Zpracovávám výsledek…"))
            let prompt = model.template.render(messages)
            let streamer = AnswerStreamer { partial in progress?(.partialAnswer(partial)) }
            let (out, st) = try await model.generate(prompt: prompt, options: GenerationOptions(maxTokens: 400, grammar: grammar)) { piece in
                streamer.feed(piece)
                return true
            }
            stats.append(st)
            guard let decision = AgentDecision.parse(out) else {
                // Model vrátil nesmysl – použijeme poslední výsledek nebo omluvu.
                let fallback = lastReadResult ?? (actions.isEmpty ? "Promiň, tomu nerozumím. Zkus to prosím říct jinak." : "")
                return AgentReply(text: fallback, actions: actions, isQuestion: false, source: "model", stats: stats)
            }
            switch decision {
            case .answer(let a):
                return AgentReply(text: a, actions: actions, isQuestion: false, source: "model", stats: stats)
            case .ask(let q):
                return AgentReply(text: q, actions: actions, isQuestion: true, source: "model", stats: stats)
            case .tool(let call):
                if call == lastCall {
                    // Zacyklení – ukončíme.
                    return AgentReply(text: lastReadResult ?? "", actions: actions, isQuestion: false, source: "model", stats: stats)
                }
                lastCall = call
                let outcome = try await executor.execute(call, source: "model")
                if let q = outcome.clarification {
                    return AgentReply(text: q, actions: actions, isQuestion: true, source: "model", stats: stats)
                }
                if let a = outcome.action { actions.append(a) }
                if outcome.isRead { lastReadResult = outcome.replyText }
                if mode == .capture {
                    return AgentReply(text: "", actions: actions, isQuestion: false, source: "model", stats: stats)
                }
                messages.append(PromptMessage(.assistant, decision.json))
                var result = outcome.resultForModel
                if result.count > 3000 { result = String(result.prefix(3000)) + "\n…(zkráceno)" }
                messages.append(PromptMessage(.user, Prompts.toolResult(name: call.name, result: result)))
            }
        }
        return AgentReply(text: lastReadResult ?? "", actions: actions, isQuestion: false, source: "model", stats: stats)
    }

    // MARK: - Shrnutí dne

    /// Shrnutí dne – deterministický základ, případně přeformulovaný modelem.
    public func summary(evening: Bool, useModel: Bool = true,
                        progress: (@Sendable (AgentProgress) -> Void)? = nil) async -> String {
        let builder = OverviewBuilder(store: store, calendar: calendar, now: clock())
        let base = (try? builder.deterministicSummary(evening: evening)) ?? ""
        guard useModel, let model else { return base }
        var data = (try? builder.agendaText(.today, refs: nil)) ?? ""
        if evening { data += "\n\n" + ((try? builder.agendaText(.tomorrow, refs: nil)) ?? "") }
        data += "\n\n" + ((try? builder.tasksText(done: false, refs: nil)) ?? "")
        let messages = [
            PromptMessage(.system, Prompts.summarySystem(now: clock(), calendar: calendar, evening: evening)),
            PromptMessage(.user, PromptSanitizer.wrapData(data)),
        ]
        let streamer = AnswerStreamer { partial in progress?(.partialAnswer(partial)) }
        guard let (out, _) = try? await model.generate(prompt: model.template.render(messages),
                                                       options: GenerationOptions(maxTokens: 220, temperature: 0.4, grammar: GrammarBuilder.answerOnly),
                                                       onToken: { streamer.feed($0); return true }),
              case .answer(let text)? = AgentDecision.parse(out), !text.isEmpty else { return base }
        return text
    }

    /// Zahodí rozpracovaný dotaz (např. když uživatel odejde z chatu).
    public func clearPending() { setPending(nil) }
}

/// Z průběžného výstupu `{"type":"answer","text":"…` vytahuje čitelný text pro UI.
final class AnswerStreamer: @unchecked Sendable {
    private var buffer = ""
    private let onText: (String) -> Void
    private let prefixes = [#"{"type":"answer","text":""#, #"{"type":"ask","text":""#]

    init(onText: @escaping (String) -> Void) { self.onText = onText }

    func feed(_ piece: String) {
        buffer += piece
        for p in prefixes where buffer.hasPrefix(p) {
            let rest = String(buffer.dropFirst(p.count))
            onText(Self.decodePartialJSONString(rest))
            return
        }
    }

    static func decodePartialJSONString(_ s: String) -> String {
        var out = ""
        var it = s.makeIterator()
        while let c = it.next() {
            if c == "\"" { break }
            if c == "\\" {
                guard let n = it.next() else { break }
                switch n {
                case "n": out.append("\n")
                case "t": out.append("\t")
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                case "/": out.append("/")
                case "u":
                    var hex = ""
                    for _ in 0..<4 { if let h = it.next() { hex.append(h) } }
                    if let v = UInt32(hex, radix: 16), let sc = Unicode.Scalar(v) { out.append(Character(sc)) }
                default: out.append(n)
                }
            } else { out.append(c) }
        }
        return out
    }
}
