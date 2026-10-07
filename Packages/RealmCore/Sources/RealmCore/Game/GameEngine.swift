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
    public var contractDone = false
    /// Postava, se kterou hrdina jednal (paměť světa).
    public var npc: (name: String, role: String, attitude: Attitude)?

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
        o.contractDone = v["contract_done"]?.boolValue ?? false
        if let n = v["npc"], let name = n.nonEmptyString("name") {
            o.npc = (name, n.nonEmptyString("role") ?? "", n["attitude"]?.stringValue.flatMap(Attitude.init(rawValue:)) ?? .neutral)
        }
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
    /// Pojistka proti zaseknutí: nejdelší doba generování (bez zpracování promptu). Pak se použije, co je hotové,
    /// nebo záložní vypravěč.
    public var interpretLimit: TimeInterval = 35
    public var narrateLimit: TimeInterval = 100

    /// Vrací false (= přestat), když tah zrušil hráč nebo vypršel čas.
    static func keepGoing(since start: Date, limit: TimeInterval) -> Bool {
        !Task.isCancelled && Date().timeIntervalSince(start) < limit
    }

    public init(model: LanguageModel?) { self.model = model }

    // MARK: Nová hra

    public static func newGame(_ setup: NewGameSetup, now: Date = Date()) -> (state: GameState, hook: String?) {
        let bg = Catalog.background(setup.backgroundId)
        let heroName = CzechText.collapseSpaces(PromptSanitizer.clean(setup.heroName)).trimmingCharacters(in: .whitespaces)
        var city = CzechText.collapseSpaces(PromptSanitizer.clean(setup.cityName)).trimmingCharacters(in: .whitespaces)
        if city.isEmpty { city = Catalog.defaultCityNames[Int(setup.seed % UInt64(Catalog.defaultCityNames.count))] }
        var hero = Hero(name: heroName.isEmpty ? "Bezejmenný" : String(heroName.prefix(30)), feminine: setup.feminine,
                        background: bg.id,
                        attributes: Catalog.startAttributes(background: bg, bonus: setup.bonusPoints, traits: setup.traits),
                        hp: 100, stress: Catalog.startStress(setup.mode),
                        items: bg.items.map { var i = $0; i.id = UUID().uuidString; return i })
        hero.traits = Catalog.validTraits(setup.traits)
        hero.abilities = [bg.ability]
        let settlement = Catalog.startSettlement(mode: setup.mode, name: String(city.prefix(30)), bonusGold: bg.bonusGold)
        var s = GameState(mode: setup.mode, hero: hero, settlement: settlement, location: settlement.name, scene: .town,
                          rngState: setup.seed)
        let start = World.whole(now)
        s.createdAt = start; s.updatedAt = now; s.lastTickAt = start; s.worldTime = start; s.lastRealTime = now
        var hook: String?
        switch setup.mode {
        case .quest:
            let q = s.pick(Catalog.quests)
            s.quest = QuestInfo(objective: q.objective, steps: Catalog.questSteps, stages: q.stages)
            s.location = q.location; s.scene = q.scene; hook = q.hook
        case .campaign:
            let middle = Array(s.shuffled(Catalog.campaignWaypoints).prefix(Catalog.campaignMiddleStops))
            s.journey = Journey(stops: [Stop(name: "Trosky města \(settlement.name)", scene: .ruins)] + middle + [Catalog.campaignDestination], index: 0)
            s.location = s.journey!.current.name; s.scene = .ruins
        case .realm, .endless:
            s.scene = .town
            s.phase = Simulation.phase(for: now)
        }
        s.stats["start_pop"] = settlement.population
        s.stats["min_hp"] = 100
        s.liveWorld = setup.liveWorld
        s.premise = String(CzechText.collapseSpaces(PromptSanitizer.clean(setup.premise)).trimmingCharacters(in: .whitespacesAndNewlines).prefix(400))
        World.updateWeather(&s)
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
                                                   onToken: { [limit = narrateLimit, started = Date()] in streamer.feed($0); return Self.keepGoing(since: started, limit: limit) }) {
                text = Self.narration(from: out.text)
            }
        }
        let final = text ?? Fallback.intro(state: s, hook: hook)
        onText(final)
        var first = LogEntry(kind: .narration, text: final)
        first.day = s.day
        s.log.append(first)
        if let q = s.quest { s.chronicle.append("Výprava začala: \(q.objective).") }
        else if s.mode == .campaign { s.chronicle.append("Karavana opustila trosky města \(s.settlement.name).") }
        else { s.chronicle.append("\(s.hero.name) \(s.hero.feminine ? "se ujala" : "se ujal") vlády nad osadou \(s.settlement.name).") }
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
        let junk = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "[]`*#\"{}"))
        var s = CzechText.collapseSpaces(PromptSanitizer.clean(t)).trimmingCharacters(in: junk)
        while let f = s.first, ".,;:–-".contains(f) { s = String(s.dropFirst()).trimmingCharacters(in: junk) }
        return scrubStats(s)
    }

    /// Vypravěč nemá jmenovat čísla statistik („stres stoupá o 2“) – ty ukazuje panel. Takové věty vypustíme.
    static func scrubStats(_ text: String) -> String {
        let stat = "(stres|zdrav|zásob|zasob|morál|moral|životy|hp)"
        let pattern = "(?i)" + stat + "[^.!?]{0,40}\\d|\\d+\\s?%|\\d[^.!?]{0,12}" + stat
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        var sentences: [String] = []
        var cur = ""
        for ch in text {
            cur.append(ch)
            if ".!?…".contains(ch) { sentences.append(cur); cur = "" }
        }
        if !cur.isEmpty { sentences.append(cur) }
        let kept = sentences.filter { s in re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) == nil }
        guard !kept.isEmpty, kept.count < sentences.count else { return text }
        return kept.joined().trimmingCharacters(in: .whitespaces)
    }

    // MARK: Prompt s historií

    /// Dvojice (tah hráče, vyprávění) z deníku – úvod se počítá jako odpověď na „Začni hru.“
    static func historyPairs(_ s: GameState) -> [(String, String)] {
        var pairs: [(String, String)] = []
        var pendingUser: String? = "Začni hru."
        for e in s.log {
            switch e.kind {
            case .player: pendingUser = Prompts.playerLine(e.text, e.input ?? .act)
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

    /// - Parameters:
    ///   - mode: čin, řeč, příběh nebo „pokračuj“ (jako v AI Dungeon).
    ///   - variation: jiná hodnota = jiné vyprávění téhož tahu („Znovu“); hod kostkou zůstává stejný.
    public func playTurn(_ state: GameState, input: String, mode inputMode: InputMode = .act, variation: UInt32 = 0,
                         now: Date = Date(),
                         onEvent: @escaping @Sendable (TurnEvent) -> Void = { _ in }) async throws -> TurnResult {
        guard !state.isOver else { throw GameError.gameOver }
        var action = String(CzechText.collapseSpaces(input.replacingOccurrences(of: "\n", with: " "))
            .trimmingCharacters(in: .whitespaces).prefix(400))
        if inputMode == .proceed { action = "Pokračuj" }
        guard !action.isEmpty else { throw GameError.emptyInput }
        let seed = 42 &+ variation &* 7919
        let direct = inputMode == .story || inputMode == .proceed

        var s = state
        var events: [LogEntry] = []
        if s.mode.hasSettlement {
            events = Simulation.syncRealTime(&s, now: now).entries
        }
        // 1) Posouzení
        onEvent(.interpreting)
        var usedModel = false
        var intent: ActionIntent?
        var genStats: GenerationStats?
        let ctx = model?.contextLength ?? 4096
        let interpTask = Prompts.interpreterTask(state: s, action: Prompts.playerLine(action, inputMode), now: now)
        var interpMessages: [PromptMessage] = []
        var interpRaw = ""
        if let model, !direct {
            interpMessages = messages(s, current: interpTask, budget: ctx - 1000)
            let prompt = model.template.render(interpMessages)
            var io = GenerationOptions(maxTokens: 140, temperature: 0.2, topP: 0.9, grammar: Grammars.interpreter(mode: s.mode))
            io.seed = seed
            let started = Date(), limit = interpretLimit
            if let out = try? await model.generate(prompt: prompt, options: io,
                                                   onToken: { _ in Self.keepGoing(since: started, limit: limit) }),
               let v = JSONTools.parseObject(out.text) {
                intent = ActionIntent.parse(v, fallbackText: action)
                interpRaw = JSONTools.firstObject(out.text) ?? out.text
                usedModel = true
                genStats = out.stats
            }
        }
        try Task.checkCancellation()
        var finalIntent = intent ?? Fallback.interpret(action, state: s)
        if direct {
            // Příběh a „pokračuj“: bez posouzení a bez hodu, jen plyne čas.
            finalIntent = ActionIntent(summary: String(action.prefix(80)), category: .other, stat: nil, difficulty: .trivial,
                                       risk: .none, duration: inputMode == .proceed ? .hour : .moment)
        } else if inputMode == .say && intent == nil {
            finalIntent.category = .social; finalIntent.stat = .charisma
        }

        // 2) Pravidla
        var res = Rules.resolve(state: &s, intent: finalIntent, now: now)
        res.input = inputMode
        onEvent(.rolled(res.roll, res.intent))

        // 3) Vyprávění
        var output: NarratorOutput?
        if let model {
            let narrTask = Prompts.narratorTask(state: s, resolution: res)
            var m: [PromptMessage]
            if direct {
                m = messages(s, current: Prompts.directTask(state: s, action: action, mode: inputMode, now: now) + "\n\n" + narrTask, budget: ctx - 700)
            } else {
                m = interpMessages.isEmpty ? messages(s, current: interpTask, budget: ctx - 900) : interpMessages
                m.append(.init(.assistant, interpRaw.isEmpty ? "{}" : interpRaw))
                m.append(.init(.user, narrTask))
            }
            let prompt = model.template.render(m)
            let streamer = FieldStreamer(field: "narration") { onEvent(.narrating($0)) }
            var no = GenerationOptions(maxTokens: 560, temperature: 0.72, topP: 0.92, grammar: Grammars.narrator(mode: s.mode))
            no.seed = seed
            let started = Date(), limit = narrateLimit
            if let out = try? await model.generate(prompt: prompt, options: no,
                                                   onToken: { streamer.feed($0); return Self.keepGoing(since: started, limit: limit) }) {
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
        var o = o
        if r.input == .story || r.input == .proceed {
            // Hráč může psát příběh, ale ne si přidělovat odměny.
            d.gold = min(d.gold, 0); d.food = min(d.food, 0); d.pop = min(d.pop, 0)
            d.defense = min(d.defense, 0); d.morale = min(d.morale, 0); d.hp = min(d.hp, r.mandatory.hp)
            o.itemsGained = []
            o.contractDone = false
            o.resolveThreat = false
        }

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
        let finder = r.intent.category == .explore && [.success, .critSuccess].contains(outcome) && s.hero.has("hledac") ? 1 : 0
        for (raw, kind) in o.itemsGained.prefix(Rules.allowedNewItems(outcome) + finder) {
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
            st.construction.append(Construction(kind: b.kind, finishAt: s.worldTime.addingTimeInterval(b.kind.buildHours * 3600)))
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
        var threatXP = 0
        if s.mode.hasSettlement, o.resolveThreat, !s.threats.isEmpty {
            s.threats.sort { $0.deadline < $1.deadline }
            if outcome == .success || outcome == .critSuccess {
                let t = s.threats.removeFirst()
                threatXP = 25
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

        // Postavy
        if let n = o.npc { World.meet(&s, name: n.name, role: n.role, attitude: n.attitude) }

        // Stavy hrdiny
        for c in r.cures {
            if let i = s.hero.conditions.firstIndex(where: { $0.kind == c }) {
                s.hero.conditions.remove(at: i)
                extra.append(LogEntry(kind: .event, text: c == .krvaceni ? "🩹 Rána je ošetřená a přestala krvácet." : "🌿 Horečka ustoupila."))
            }
        }
        for c in r.newConditions where !r.cures.contains(c) {
            let hours: Double = c == .krvaceni ? 12 : (c == .horecka ? 48 : 6)
            if World.addCondition(&s, c, hours: hours + r.hours), !c.isGood {
                extra.append(LogEntry(kind: .event, text: c == .krvaceni ? "🩸 Krvácíš. Ošetři ránu, než tě oslabí." : "🤒 Chytil\(s.hero.feminine ? "a" : "") jsi horečku."))
            }
        }
        for id in r.usedAbilities {
            if let i = s.hero.abilities.firstIndex(where: { $0.id == id }) { s.hero.abilities[i].usesLeft = max(0, s.hero.abilities[i].usesLeft - 1) }
        }
        if r.intent.category == .rest && r.hours >= 6 { s.hero.awakeHours = 0; s.hero.refreshAbilities() }
        else if r.hours >= 20 { s.hero.awakeHours = max(s.hero.awakeHours, 14) }
        else { s.hero.awakeHours += r.hours }
        if let st = r.roll.stat, r.roll.outcome != .auto && r.roll.outcome != .impossible {
            s.hero.statUse[st.rawValue, default: 0] += 1
        }

        // Zakázka
        var xp = World.xp(for: outcome)
        if let c = s.contract, r.contractEligible, o.contractDone {
            s.contract = nil
            let rw = c.reward
            s.settlement.gold += rw.gold
            if s.mode != .quest {
                s.settlement.food = min(s.settlement.foodCapacity, s.settlement.food + rw.food)
                s.settlement.population += rw.pop
                s.settlement.defense += rw.defense
                s.settlement.morale = min(100, s.settlement.morale + rw.morale)
            }
            s.stats["contracts_done", default: 0] += 1
            xp += 40
            extra.append(LogEntry(kind: .event, text: "✅ Zakázka splněna: \(c.title). Odměna: \(rw.text).", delta: rw.delta))
        }
        if r.questGain > 0 { xp += 20 * r.questGain }
        if r.arrival != nil { xp += 20 }

        // Čas
        s.turn += 1
        if let q = s.quest, r.questGain > 0 {
            s.quest?.progress = min(q.steps, q.progress + r.questGain)
        }
        if let q = s.quest, r.questSetback > 0 {
            s.quest?.setbacks = min(q.maxSetbacks, q.setbacks + r.questSetback)
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
        } else if s.mode == .quest && r.losesQuest {
            s.end = .defeat
        } else if s.mode == .quest && r.completesQuest {
            s.end = .victory
        } else if s.mode != .quest && s.settlement.morale <= 0 {
            s.end = .defeat
            extra.append(LogEntry(kind: .event, text: s.mode == .campaign ? "⚔️ Vzpoura! Lidé ztratili víru a karavana se rozpadla." : "⚔️ Povstání! Lid tě svrhl a vyhnal z osady."))
        } else if s.mode == .campaign, r.arrival?.isDestination == true {
            s.end = .victory
        }

        // Deník
        var playerEntry = LogEntry(kind: .player, text: action)
        playerEntry.day = s.day
        playerEntry.input = r.input == .act ? nil : r.input
        var narrEntry = LogEntry(kind: .narration, text: o.narration, roll: r.roll.outcome == .auto ? nil : r.roll,
                                 delta: d.isZero ? nil : d, itemsAdded: added, itemsRemoved: removed, hours: r.hours)
        narrEntry.day = s.day
        s.log.append(playerEntry)
        s.log.append(narrEntry)
        s.log.append(contentsOf: extra)

        // Čin zabere herní čas (minuty až dny); v osadě mezitím běží život
        s.worldTime = World.whole(s.worldTime.addingTimeInterval(r.hours * 3600))
        s.phase = Simulation.phase(for: s.worldTime)
        s.day = max(1, Simulation.daysBetween(s.createdAt, s.worldTime) + 1)
        World.updateWeather(&s)
        s.hero.conditions.removeAll { $0.until <= s.worldTime }
        if s.day > (playerEntry.day ?? s.day) { s.hero.refreshAbilities() }
        if s.mode == .campaign && s.end == nil {
            if let e = World.expireContract(&s) { s.log.append(e) }
            if r.arrival != nil && !(r.arrival?.isDestination ?? false) && s.chance(55), let e = World.offerContract(&s, at: s.worldTime) {
                s.log.append(e)
            }
        }
        if s.end == nil { s.log.append(contentsOf: World.gainXP(&s, xp + threatXP)) }
        if s.mode.hasSettlement && s.end == nil {
            Simulation.advance(&s, to: s.worldTime)
            if s.end == nil { s.log.append(contentsOf: World.checkRank(&s)) }
            if s.mode == .realm && s.end == nil && Catalog.realmGoalMet(s.settlement) {
                s.end = .victory
                s.log.append(LogEntry(kind: .event, text: "🏰 \(s.settlement.name) se stala městem! Cíl vlády je splněn."))
            }
        }
        if s.log.count > 500 { s.log.removeFirst(s.log.count - 500) }

        let fixed = s.repair()
        if !fixed.isEmpty { s.stats["repairs", default: 0] += 1; s.stats["repair_" + (fixed.first ?? "?").prefix(20), default: 0] += 1 }
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
                                                   onToken: { [limit = narrateLimit, started = Date()] in streamer.feed($0); return Self.keepGoing(since: started, limit: limit) }) {
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
