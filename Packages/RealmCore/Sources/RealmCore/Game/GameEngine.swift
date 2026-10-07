import Foundation

/// Výstup vypravěče (krok 2).
public struct NarratorOutput: Sendable {
    public var narration: String
    public var proposed: StatDelta
    public var itemsGained: [(String, ItemKind)] = []
    public var itemsLost: [String] = []
    public var location: String?
    public var scene: SceneKind?
    public var chronicle: String?
    public var objectiveDone = false
    public var resolveThreat = false

    public init(narration: String, proposed: StatDelta) {
        self.narration = narration; self.proposed = proposed
    }

    public static func parse(_ v: JSONValue, mandatory: StatDelta) -> NarratorOutput? {
        guard let text = v.nonEmptyString("narration") else { return nil }
        func n(_ k: String, _ def: Int) -> Int { v[k]?.intValue ?? def }
        var o = NarratorOutput(narration: text, proposed: StatDelta(
            pop: n("pop", mandatory.pop), gold: n("gold", mandatory.gold), food: n("food", mandatory.food),
            defense: n("defense", mandatory.defense), morale: n("morale", mandatory.morale),
            hp: n("hp", mandatory.hp), stress: n("stress", mandatory.stress)))
        o.itemsGained = (v["items_gained"]?.arrayValue ?? []).compactMap { g in
            guard let name = g.nonEmptyString("name") else { return nil }
            return (name, g["kind"]?.stringValue.flatMap(ItemKind.init(rawValue:)) ?? .treasure)
        }
        o.itemsLost = (v["items_lost"]?.arrayValue ?? []).compactMap { $0.stringValue }
        o.location = v.nonEmptyString("location")
        o.scene = v["scene"]?.stringValue.flatMap(SceneKind.init(rawValue:))
        o.chronicle = v.nonEmptyString("chronicle")
        o.objectiveDone = v["objective_done"]?.boolValue ?? false
        o.resolveThreat = v["resolve_threat"]?.boolValue ?? false
        return o
    }
}

public enum TurnEvent: Sendable {
    case interpreting
    case rolled(RollInfo, ActionIntent)
    case narrating(String)
}

public struct TurnResult: Sendable {
    public var state: GameState
    public var roll: RollInfo
    public var delta: StatDelta
    public var itemsAdded: [String]
    public var itemsRemoved: [String]
    public var newAchievements: [Achievement]
    public var usedModel: Bool
    public var stats: GenerationStats?
}

public enum GameError: Error, CustomStringConvertible {
    case emptyInput, gameOver
    public var description: String {
        switch self {
        case .emptyInput: return "Napiš, co hrdina udělá."
        case .gameOver: return "Hra skončila."
        }
    }
}

/// Herní engine: pravidla jsou deterministická, jazykový model jen posuzuje záměr a vypráví.
public final class GameEngine: @unchecked Sendable {
    public let model: LanguageModel?

    public init(model: LanguageModel?) { self.model = model }

    // MARK: Nová hra

    public static func newGame(_ setup: NewGameSetup, now: Date = Date()) -> (state: GameState, hook: String?) {
        let bg = Catalog.background(setup.backgroundId)
        let heroName = CzechText.collapseSpaces(PromptSanitizer.clean(setup.heroName)).trimmingCharacters(in: .whitespaces)
        var city = CzechText.collapseSpaces(PromptSanitizer.clean(setup.cityName)).trimmingCharacters(in: .whitespaces)
        if city.isEmpty { city = Catalog.defaultCityNames[Int(setup.seed % UInt64(Catalog.defaultCityNames.count))] }
        let hero = Hero(name: heroName.isEmpty ? "Bezejmenný" : String(heroName.prefix(30)), feminine: setup.feminine,
                        background: bg.id, attributes: bg.attributes, hp: 100, stress: Catalog.startStress(setup.mode),
                        items: bg.items.map { var i = $0; i.id = UUID().uuidString; return i })
        let settlement = Catalog.startSettlement(mode: setup.mode, name: String(city.prefix(30)), bonusGold: bg.bonusGold)
        var s = GameState(mode: setup.mode, hero: hero, settlement: settlement, location: settlement.name, scene: .town,
                          rngState: setup.seed)
        s.createdAt = now; s.updatedAt = now; s.lastTickAt = now
        var hook: String?
        switch setup.mode {
        case .quest:
            let q = s.pick(Catalog.quests)
            s.quest = QuestInfo(objective: q.objective, turnLimit: Catalog.questTurnLimit)
            s.location = q.location; s.scene = q.scene; hook = q.hook
        case .campaign:
            let middle = Array(s.shuffled(Catalog.campaignWaypoints).prefix(Catalog.campaignMiddleStops))
            s.journey = Journey(stops: [Stop(name: "Trosky města \(settlement.name)", scene: .ruins)] + middle + [Catalog.campaignDestination], index: 0)
            s.location = s.journey!.current.name; s.scene = .ruins
        case .realm:
            s.scene = .town
            s.actionPoints = Simulation.actionPointsPerDay
            s.actionPointsDay = Simulation.dayKey(now)
            s.phase = Simulation.phase(for: now)
        }
        s.stats["start_pop"] = settlement.population
        s.stats["min_hp"] = 100
        return (s, hook)
    }

    // MARK: Úvod

    public func intro(_ state: GameState, hook: String?, onText: @escaping @Sendable (String) -> Void = { _ in }) async -> GameState {
        var s = state
        var text: String?
        if let model {
            let prompt = model.template.render([.init(.system, Prompts.system(mode: s.mode)),
                                               .init(.user, Prompts.introTask(state: s, hook: hook))])
            let streamer = FieldStreamer(field: "narration", onText: onText)
            if let out = try? await model.generate(prompt: prompt,
                                                   options: GenerationOptions(maxTokens: 420, temperature: 0.85, topP: 0.95, grammar: Grammars.story),
                                                   onToken: { streamer.feed($0); return !Task.isCancelled }) {
                text = Self.narration(from: out.text)
            }
        }
        let final = text ?? Fallback.intro(state: s, hook: hook)
        onText(final)
        s.log.append(LogEntry(kind: .narration, text: final))
        if let q = s.quest { s.chronicle.append("Výprava začala: \(q.objective).") }
        else if s.mode == .campaign { s.chronicle.append("Karavana opustila trosky města \(s.settlement.name).") }
        else { s.chronicle.append("\(s.hero.name) se ujal(a) vlády nad osadou \(s.settlement.name).") }
        return s
    }

    static func narration(from raw: String) -> String? {
        if let v = JSONTools.parseObject(raw), let t = v.nonEmptyString("narration") { return clean(t) }
        let prefix = "{\"narration\":\""
        if let r = raw.range(of: prefix) {
            let t = JSONTools.decodePartialString(String(raw[r.upperBound...]))
            if t.count > 20 { return clean(t) }
        }
        return nil
    }

    static func clean(_ t: String) -> String {
        CzechText.collapseSpaces(PromptSanitizer.clean(t)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Prompt s historií

    /// Dvojice (tah hráče, vyprávění) z deníku – úvod se počítá jako odpověď na „Začni hru.“
    static func historyPairs(_ s: GameState) -> [(String, String)] {
        var pairs: [(String, String)] = []
        var pendingUser: String? = "Začni hru."
        for e in s.log {
            switch e.kind {
            case .player: pendingUser = e.text
            case .narration:
                if let u = pendingUser {
                    pairs.append((String(u.prefix(300)), String(e.text.prefix(600))))
                    pendingUser = nil
                }
            default: break
            }
        }
        return pairs
    }

    /// Okno historie se posouvá po čtyřech tazích, aby zůstal stabilní prefix pro KV cache.
    func messages(_ s: GameState, current: String, budget: Int) -> [PromptMessage] {
        let pairs = Self.historyPairs(s)
        var start = max(0, ((pairs.count - 4) / 4) * 4)
        while true {
            var m: [PromptMessage] = [.init(.system, Prompts.system(mode: s.mode))]
            for (u, a) in pairs[start...] {
                m.append(.init(.user, PromptSanitizer.wrapData(u)))
                m.append(.init(.assistant, a))
            }
            m.append(.init(.user, current))
            guard let model, start < pairs.count else { return m }
            if model.countTokens(model.template.render(m)) <= budget { return m }
            start = min(pairs.count, start + 2)
        }
    }

    // MARK: Tah

    public func playTurn(_ state: GameState, input: String, now: Date = Date(),
                         onEvent: @escaping @Sendable (TurnEvent) -> Void = { _ in }) async throws -> TurnResult {
        guard !state.isOver else { throw GameError.gameOver }
        let action = String(CzechText.collapseSpaces(input.replacingOccurrences(of: "\n", with: " "))
            .trimmingCharacters(in: .whitespaces).prefix(400))
        guard !action.isEmpty else { throw GameError.emptyInput }

        var s = state
        var events: [LogEntry] = []
        if s.mode == .realm {
            let report = Simulation.advance(&s, to: now)
            events = report.entries
        }
        // 1) Posouzení
        onEvent(.interpreting)
        var usedModel = false
        var intent: ActionIntent?
        var genStats: GenerationStats?
        let ctx = model?.contextLength ?? 4096
        let interpTask = Prompts.interpreterTask(state: s, action: action, now: now)
        var interpMessages: [PromptMessage] = []
        var interpRaw = ""
        if let model {
            interpMessages = messages(s, current: interpTask, budget: ctx - 1000)
            let prompt = model.template.render(interpMessages)
            if let out = try? await model.generate(prompt: prompt,
                                                   options: GenerationOptions(maxTokens: 140, temperature: 0.2, topP: 0.9,
                                                                              grammar: Grammars.interpreter(mode: s.mode)),
                                                   onToken: { _ in !Task.isCancelled }),
               let v = JSONTools.parseObject(out.text) {
                intent = ActionIntent.parse(v, fallbackText: action)
                interpRaw = JSONTools.firstObject(out.text) ?? out.text
                usedModel = true
                genStats = out.stats
            }
        }
        try Task.checkCancellation()
        let finalIntent = intent ?? Fallback.interpret(action, state: s)

        // 2) Pravidla
        let res = Rules.resolve(state: &s, intent: finalIntent, now: now)
        if res.exhausted {
            s.log.append(contentsOf: events)
            s.log.append(LogEntry(kind: .player, text: action))
            let msg = "Jsi vyčerpaný(á). Dnešní síly došly – nové přinese úsvit v \(Simulation.dawnHour):00. Zatím můžeš osadu jen pozorovat a mluvit s lidmi."
            s.log.append(LogEntry(kind: .system, text: msg))
            s.updatedAt = now
            return TurnResult(state: s, roll: res.roll, delta: StatDelta(), itemsAdded: [], itemsRemoved: [],
                              newAchievements: [], usedModel: usedModel, stats: genStats)
        }
        onEvent(.rolled(res.roll, res.intent))

        // 3) Vyprávění
        var output: NarratorOutput?
        if let model {
            let narrTask = Prompts.narratorTask(state: s, resolution: res)
            var m = interpMessages.isEmpty ? messages(s, current: interpTask, budget: ctx - 900) : interpMessages
            m.append(.init(.assistant, interpRaw.isEmpty ? "{}" : interpRaw))
            m.append(.init(.user, narrTask))
            let prompt = model.template.render(m)
            let streamer = FieldStreamer(field: "narration") { onEvent(.narrating($0)) }
            if let out = try? await model.generate(prompt: prompt,
                                                   options: GenerationOptions(maxTokens: 460, temperature: 0.8, topP: 0.95,
                                                                              grammar: Grammars.narrator(mode: s.mode)),
                                                   onToken: { streamer.feed($0); return !Task.isCancelled }) {
                if let v = JSONTools.parseObject(out.text), let o = NarratorOutput.parse(v, mandatory: res.mandatory) {
                    output = o
                } else if let t = Self.narration(from: out.text) {
                    output = NarratorOutput(narration: t, proposed: res.mandatory)
                }
                if output != nil { usedModel = true }
                if var g = genStats {
                    g.generatedTokens += out.stats.generatedTokens
                    g.generationSeconds += out.stats.generationSeconds
                    g.promptTokens += out.stats.promptTokens
                    g.cachedPromptTokens += out.stats.cachedPromptTokens
                    g.promptSeconds += out.stats.promptSeconds
                    genStats = g
                } else { genStats = out.stats }
            }
        }
        if Task.isCancelled && output == nil { throw CancellationError() }
        var narr = output ?? Fallback.narrate(state: &s, resolution: res)
        narr.narration = Self.clean(narr.narration)
        onEvent(.narrating(narr.narration))

        // 4) Použití výsledku
        s.log.append(contentsOf: events)
        var result = Self.apply(state: s, action: action, resolution: res, output: narr, now: now)
        result.usedModel = usedModel
        result.stats = genStats
        return result
    }

    /// Aplikuje výsledek tahu (čistá funkce – testovatelná bez modelu).
    public static func apply(state: GameState, action: String, resolution r: Resolution,
                             output o: NarratorOutput, now: Date) -> TurnResult {
        var s = state
        let outcome = r.roll.outcome
        var d = Rules.finalDelta(mode: s.mode, outcome: outcome, mandatory: r.mandatory, proposed: o.proposed, settlement: s.settlement)

        // Předměty: spotřebované
        var removed: [String] = []
        for used in r.usedItems where used.kind == .consumable {
            guard let idx = s.hero.items.firstIndex(where: { $0.id == used.id }) else { continue }
            let c = (s.hero.items[idx].charges ?? 1) - 1
            if c <= 0 { removed.append(s.hero.items[idx].name); s.hero.items.remove(at: idx) }
            else { s.hero.items[idx].charges = c }
        }
        // ztracené
        for name in o.itemsLost.prefix(2) {
            if let it = s.hero.item(named: name), let idx = s.hero.items.firstIndex(where: { $0.id == it.id }) {
                removed.append(it.name); s.hero.items.remove(at: idx)
            }
        }
        // nové
        var added: [String] = []
        for (raw, kind) in o.itemsGained.prefix(Rules.allowedNewItems(outcome)) {
            guard let name = Rules.cleanItemName(raw) else { continue }
            if removed.contains(where: { CzechText.fold($0) == CzechText.fold(name) }) { continue }
            if let idx = s.hero.items.firstIndex(where: { CzechText.fold($0.name) == CzechText.fold(name) }) {
                if s.hero.items[idx].kind == .consumable {
                    s.hero.items[idx].charges = (s.hero.items[idx].charges ?? 1) + 1
                    added.append(name)
                }
                continue
            }
            guard s.hero.items.count < Rules.maxItems else { break }
            s.hero.items.append(Item(name: name, kind: kind, charges: kind == .consumable ? 1 : nil))
            added.append(name)
        }

        // Statistiky
        s.hero.hp = max(0, min(100, s.hero.hp + d.hp))
        s.hero.stress = max(0, min(100, s.hero.stress + d.stress))
        var extra: [LogEntry] = []
        if s.hero.stress >= 100 && s.hero.hp > 0 {
            s.hero.hp = max(0, s.hero.hp - 10)
            s.hero.stress = 75
            d.hp -= 10
            extra.append(LogEntry(kind: .system, text: "Mysl se láme. Hrdina se na chvíli zhroutí – třes, pláč, krev z nosu. Zdraví −10."))
        }
        var st = s.settlement
        st.gold = max(0, st.gold + d.gold)
        if s.mode != .quest {
            st.population = max(0, st.population + d.pop)
            st.food = max(0, min(st.foodCapacity, st.food + d.food))
            st.defense = max(0, min(300, st.defense + d.defense))
            st.morale = max(0, min(100, st.morale + d.morale))
        }

        // Stavba
        if let b = r.build, b.started {
            st.construction.append(Construction(kind: b.kind, finishAt: now.addingTimeInterval(b.kind.buildHours * 3600)))
            extra.append(LogEntry(kind: .event, text: "🔨 Stavba zahájena: \(b.kind.czechName) – hotovo za \(Int(b.kind.buildHours)) h."))
        }
        s.settlement = st

        // Místo
        if let loc = o.location.map(clean), !loc.isEmpty { s.location = String(loc.prefix(50)) }
        if let sc = o.scene { s.scene = sc }
        if let a = r.arrival, var j = s.journey {
            j.index = min(j.stops.count - 1, j.index + 1)
            s.journey = j
            s.location = a.stop.name
            s.scene = a.stop.scene
            s.chronicle.append("Karavana dorazila: \(a.stop.name).")
        }

        // Hrozby (C)
        if s.mode == .realm, o.resolveThreat, !s.threats.isEmpty {
            s.threats.sort { $0.deadline < $1.deadline }
            if outcome == .success || outcome == .critSuccess {
                let t = s.threats.removeFirst()
                s.stats["threats_repelled", default: 0] += 1
                extra.append(LogEntry(kind: .event, text: "🛡️ Hrozba zažehnána: \(t.title)."))
            } else if outcome == .partial {
                s.threats[0].strength = s.threats[0].strength * 7 / 10
                extra.append(LogEntry(kind: .event, text: "Hrozba oslabena: \(s.threats[0].title)."))
            }
        }

        // Kronika
        if let c = o.chronicle.map(clean), !c.isEmpty {
            s.chronicle.append(String(c.prefix(120)))
            if s.chronicle.count > 60 { s.chronicle.removeFirst(s.chronicle.count - 60) }
        }

        // Čas
        s.turn += 1
        if s.mode != .realm {
            s.phase = (s.turn / 2) % 4
            s.day = s.turn / 8 + 1
        } else if Rules.costsActionPoint(r.intent) {
            s.actionPoints = max(0, s.actionPoints - 1)
        }

        // Počítadla
        if r.intent.category == .combat && [.success, .critSuccess].contains(outcome) { s.stats["combats_won", default: 0] += 1 }
        if r.roll.die == 20 { s.stats["nat20", default: 0] += 1 }
        if r.roll.die == 1 { s.stats["nat1", default: 0] += 1 }
        if d.pop < 0 { s.stats["pop_lost", default: 0] -= d.pop }
        s.stats["min_hp"] = min(s.stats["min_hp"] ?? 100, s.hero.hp)
        if s.hero.stress >= 80 { s.stats["stress_peak"] = 1 }

        // Konec hry
        if s.hero.hp <= 0 {
            s.end = .death
        } else if s.mode != .quest && s.settlement.population <= 0 {
            s.end = .ruin
        } else if s.mode == .quest {
            if o.objectiveDone && [.partial, .success, .critSuccess, .auto].contains(outcome) && s.turn >= 2 {
                s.end = .victory
            } else if let q = s.quest, s.turn >= q.turnLimit {
                s.end = .abandoned
                extra.append(LogEntry(kind: .system, text: "Čas vypršel. Výprava se nepodařila včas."))
            }
        } else if s.mode == .campaign, r.arrival?.isDestination == true {
            s.end = .victory
        }

        // Deník
        s.log.append(LogEntry(kind: .player, text: action))
        s.log.append(LogEntry(kind: .narration, text: o.narration, roll: r.roll.outcome == .auto ? nil : r.roll,
                              delta: d.isZero ? nil : d, itemsAdded: added, itemsRemoved: removed))
        s.log.append(contentsOf: extra)
        if s.log.count > 500 { s.log.removeFirst(s.log.count - 500) }

        let newAch = Achievements.evaluate(&s)
        s.updatedAt = now
        return TurnResult(state: s, roll: r.roll, delta: d, itemsAdded: added, itemsRemoved: removed,
                          newAchievements: newAch, usedModel: false, stats: nil)
    }

    // MARK: Epilog

    public func epilogue(_ state: GameState, onText: @escaping @Sendable (String) -> Void = { _ in }) async -> GameState {
        var s = state
        guard s.isOver, s.epilogue == nil else { return s }
        var text: String?
        if let model {
            let prompt = model.template.render([.init(.system, Prompts.system(mode: s.mode)),
                                               .init(.user, Prompts.epilogueTask(state: s))])
            let streamer = FieldStreamer(field: "narration", onText: onText)
            if let out = try? await model.generate(prompt: prompt,
                                                   options: GenerationOptions(maxTokens: 360, temperature: 0.85, topP: 0.95, grammar: Grammars.story),
                                                   onToken: { streamer.feed($0); return !Task.isCancelled }) {
                text = Self.narration(from: out.text)
            }
        }
        s.epilogue = text ?? Fallback.epilogue(state: s)
        onText(s.epilogue!)
        return s
    }

    /// Hráč ukončí hru sám (např. v Živém simulátoru).
    public static func abandon(_ state: GameState) -> GameState {
        var s = state
        if s.end == nil { s.end = .abandoned }
        return s
    }
}
