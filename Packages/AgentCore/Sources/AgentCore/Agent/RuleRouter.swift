import Foundation

/// Výsledek pravidel (rychlá cesta bez modelu).
public enum RuleResult: Equatable, Sendable {
    /// Jistý nástroj.
    case tool(ToolCall)
    /// Chybí údaj – zeptat se a čekat na doplnění.
    case clarify(question: String, pending: PendingIntent)
}

/// Rozpracovaný požadavek, kterému chybí jeden údaj (typicky čas).
public struct PendingIntent: Equatable, Sendable {
    public enum Missing: String, Sendable { case when, title, duration }
    public var tool: String
    public var args: [String: String]
    public var missing: Missing
}

/// Pevná pravidla pro běžné české fráze. Co nepozná s jistotou, nechá na modelu.
public struct RuleRouter: Sendable {
    public var calendar: Calendar
    public var now: Date

    public init(calendar: Calendar, now: Date) { self.calendar = calendar; self.now = now }

    var parser: CzechTimeParser { CzechTimeParser(calendar: calendar, now: now) }

    static let reminderTrigger = #"\b(pripomen(?:\s+mi)?|upozorni\s+me|nezapomen\s+mi\s+pripomenout|(?:nastav|vytvor|pridej|udelej)(?:\s+mi)?\s+pripominku)\b|^\s*pripominka\b"#
    static let notePrefix = #"^\s*(?:(?:prosim\s+)?(?:poznamenej(?:\s+si)?|zapis(?:\s+si)?|zaznamenej(?:\s+si)?|uloz(?:\s+si)?(?:\s+poznamku)?|zapamatuj\s+si|nova\s+poznamka|poznamka))\s*[:,\-–]?\s*"#
    static let taskPrefix = #"^\s*(?:(?:prosim\s+)?(?:pridej(?:\s+si)?(?:\s+(?:do\s+)?(?:ukol[uy]?|ukolu))|novy\s+ukol|ukol|todo|to-do))\s*[:,\-–]?\s*"#
    static let completePrefix = #"^\s*(?:hotovo|splneno|dokonceno|odskrtni|oznac\s+(?:jako\s+)?(?:hotove|splnene|hotovy|splneny))\s*[:,\-–]?\s*"#
    static let undoPhrases: Set<String> = ["zpet", "vrat to", "vrat zpet", "vrat to zpet", "vrat posledni akci", "odvolej",
                                           "zrus posledni akci", "zrus to", "vrat to prosim", "zpet prosim", "undo"]

    public func route(_ input: String) -> RuleResult? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let f = CzechText.fold(text).trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))

        if Self.undoPhrases.contains(f) { return .tool(ToolCall(name: "undo_last", args: .object([:]))) }

        if let r = routeClock(text, f) { return r }

        // Připomínky
        if matches(Self.reminderTrigger, f) {
            let p = parser.parse(text)
            var title = text
            var whenText: String?
            if let p, !p.isEmpty {
                title = parser.remainder(of: text, removing: p.ranges)
                whenText = joinedRanges(text, p.ranges)
            }
            title = cleanReminderTitle(title)
            if title.isEmpty {
                return .clarify(question: "Co ti mám připomenout?",
                                pending: PendingIntent(tool: "create_reminder", args: ["when": whenText ?? ""], missing: .title))
            }
            guard let whenText, !whenText.isEmpty else {
                return .clarify(question: "Kdy ti mám připomenout „\(title)“?",
                                pending: PendingIntent(tool: "create_reminder", args: ["title": title], missing: .when))
            }
            return .tool(ToolCall("create_reminder", ["title": title, "when": whenText]))
        }

        // Poznámky
        if let rest = stripPrefix(Self.notePrefix, text: text, folded: f) {
            guard !rest.isEmpty else {
                return .clarify(question: "Co mám zapsat?", pending: PendingIntent(tool: "create_note", args: [:], missing: .title))
            }
            return .tool(ToolCall("create_note", ["text": CzechText.capitalizeFirst(rest)]))
        }

        // Úkoly
        if let rest = stripPrefix(Self.taskPrefix, text: text, folded: f) {
            guard !rest.isEmpty else {
                return .clarify(question: "Jaký úkol mám přidat?", pending: PendingIntent(tool: "create_task", args: [:], missing: .title))
            }
            var args = ["title": rest]
            if let p = parser.parse(rest), p.date != nil, p.recurrence == nil {
                args["title"] = parser.remainder(of: rest, removing: p.ranges)
                    .replacingOccurrences(of: #"\s+do$"#, with: "", options: .regularExpression)
                args["due"] = joinedRanges(rest, p.ranges)
            }
            return .tool(ToolCall("create_task", args))
        }

        // Splnění úkolu
        if let rest = stripPrefix(Self.completePrefix, text: text, folded: f), !rest.isEmpty {
            return .tool(ToolCall("complete_task", ["ref": rest]))
        }

        // Přehled / agenda
        if let range = agendaRange(f) { return .tool(ToolCall("list_agenda", ["range": range.rawValue])) }
        if matches(#"^(?:jake|ktere|co)\s+(?:mam\s+)?(?:nesplnene\s+)?ukoly|^(?:seznam|vypis|ukaz)\s+ukol|nesplnene\s+ukoly|co\s+mam\s+(?:udelat|resit|na\s+praci)"#, f) {
            return .tool(ToolCall("list_tasks", ["status": "open"]))
        }
        return nil
    }

    /// Doplnění rozpracovaného požadavku odpovědí uživatele.
    public func complete(_ pending: PendingIntent, with answer: String) -> RuleResult? {
        var args = pending.args
        switch pending.missing {
        case .when:
            let alarm = pending.tool == "set_alarm"
            guard let p = CzechTimeParser(calendar: calendar, now: now, alarmMode: alarm).parse(answer), !p.isEmpty else { return nil }
            args["when"] = answer
        case .duration:
            guard CzechDuration.parse(answer) != nil else { return nil }
            args["duration"] = answer
        case .title:
            let t = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            if pending.tool == "create_note" { args["text"] = t } else { args["title"] = t }
            if pending.tool == "create_reminder", (args["when"] ?? "").isEmpty {
                return .clarify(question: "Kdy ti to mám připomenout?",
                                pending: PendingIntent(tool: pending.tool, args: args, missing: .when))
            }
        }
        return .tool(ToolCall(pending.tool, args))
    }

    /// Rychlé zachycení: rozhodne poznámka / úkol / připomínka bez modelu.
    public func classifyCapture(_ input: String) -> ToolCall {
        if case .tool(let call)? = route(input), Tools.capture.contains(where: { $0.name == call.name }) { return call }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let f = CzechText.fold(text)
        let p = parser.parse(text)
        let taskVerbs = #"\b(koupit|nakoupit|zavolat|zaplatit|objednat|poslat|napsat|vyridit|udelat|opravit|vyzvednout|zarezervovat|domluvit|zkontrolovat|odevzdat|prinest|vratit|uklidit|pripravit|musim|nezapomenout|nezapomen|potrebuju|potrebuji|mam\s+(?:udelat|zavolat|koupit|zaplatit|poslat|napsat))\b"#
        let isTask = matches(taskVerbs, f)
        if let p, !p.isEmpty {
            let rest = parser.remainder(of: text, removing: p.ranges)
            let when = joinedRanges(text, p.ranges)
            if p.hasTime || p.recurrence != nil { return ToolCall("create_reminder", ["title": rest, "when": when]) }
            if isTask { return ToolCall("create_task", ["title": rest, "due": when]) }
        }
        if isTask { return ToolCall("create_task", ["title": text]) }
        return ToolCall("create_note", ["text": CzechText.capitalizeFirst(text)])
    }

    // MARK: - Budíky, minutky, stopky

    private func routeClock(_ text: String, _ f: String) -> RuleResult? {
        let isQuestion = text.hasSuffix("?")
        // Stopky
        if matches(#"\bstopk"#, f) {
            let action: String
            if matches(#"\b(zastav\w*|stop|pauz\w*)\b"#, f) { action = "stop" }
            else if matches(#"\b(vynuluj|nuluj|reset|vymaz)"#, f) { action = "reset" }
            else if matches(#"\b(mezicas|kolo)\b"#, f) { action = "lap" }
            else if isQuestion || matches(#"\b(kolik|stav|jak\s+dlouho|ukaz)\b"#, f) { action = "status" }
            else { action = "start" }
            return .tool(ToolCall("stopwatch", ["action": action]))
        }
        // Zrušení
        if matches(#"^(?:prosim\s+)?(?:zrus|vypni|smaz|odstran|zastav)\w*\s+(?:mi\s+)?(?:vsechny\s+|ten\s+|tu\s+)?(?:budik|minutk|casovac|odpoc)"#, f) {
            return .tool(ToolCall("cancel_alarm", ["which": text]))
        }
        // Přehled
        if matches(#"^(?:jake|ktere|kolik|mam)\s+(?:mam\s+)?(?:nastavene\s+|nastaveny\s+)?(?:budik|minutk|casovac|odpoc)"#, f) {
            let kind = matches(#"budik"#, f) ? "alarm" : (matches(#"minutk|casovac|odpoc"#, f) ? "timer" : "all")
            return .tool(ToolCall("list_alarms", ["kind": kind]))
        }
        guard !isQuestion else { return nil }
        let timerWord = matches(#"\b(minutk\w*|casovac\w*|odpocet|odpocitavani|odpocitej|timer)\b"#, f)
            || matches(#"^(?:zazvon|pipni|ozvi)\w*\s+(?:mi\s+)?za\b"#, f)
            || matches(#"\bbudik\w*\s+za\b"#, f)
        if timerWord, CzechDuration.parse(text) != nil {
            var args = ["duration": text]
            let label = clockLabel(text, extraFillers: ["za"])
            if !label.isEmpty { args["label"] = label }
            else if matches(#"\bbudik"#, f) { args["label"] = "Budík" }
            return .tool(ToolCall("set_timer", args))
        }
        if timerWord {
            return .clarify(question: "Na jak dlouho mám odpočet nastavit?",
                            pending: PendingIntent(tool: "set_timer", args: [:], missing: .duration))
        }
        if matches(#"\b(budik\w*|vzbud\w*|probud\w*|buzeni)\b"#, f) {
            let p = CzechTimeParser(calendar: calendar, now: now, defaultHour: 7, alarmMode: true)
            if let parsed = p.parse(text), parsed.hasTime || parsed.recurrence != nil {
                var args = ["when": joinedRanges(text, parsed.ranges)]
                let label = clockLabel(p.remainder(of: text, removing: parsed.ranges), extraFillers: [])
                if !label.isEmpty { args["label"] = label }
                return .tool(ToolCall("set_alarm", args))
            }
            return .clarify(question: "Na kolik hodin mám budík nastavit?",
                            pending: PendingIntent(tool: "set_alarm", args: [:], missing: .when))
        }
        return nil
    }

    /// Popisek budíku / minutky – text bez spouštěcích a výplňových slov a bez délky.
    private func clockLabel(_ text: String, extraFillers: Set<String>) -> String {
        var t = text.replacingOccurrences(
            of: #"(?i)\b(\d+(?:[.,]\d+)?|jednu|jednou|dvě|dve|tři|tri|čtyři|ctyri|pět|pet|deset|patnáct|patnact|dvacet|třicet|tricet|půl|pul|čtvrt|ctvrt)?\s*(hodin[uy]?|hod|minut[uy]?|min|sekund[uy]?|sek|vteřin[uy]?|vterin[uy]?)\b(\s+a\s+(půl|pul))?"#,
            with: " ", options: .regularExpression)
        t = CzechText.collapseSpaces(t)
        let fillers = Set<String>(["nastav", "nastavit", "spust", "zapni", "dej", "mi", "me", "na", "prosim", "minutku", "minutka",
                                    "casovac", "odpocet", "odpocitej", "timer", "zazvon", "pipni", "ozvi", "se", "budik", "budika",
                                    "vzbud", "probud", "a", "s", "popiskem", "nazvem", "buzeni", "novy", "chci"]).union(extraFillers)
        // Výplňová slova odebereme ze začátku; zbytek je popisek (např. „na těstoviny“ → „Těstoviny“).
        var words = t.split(separator: " ").map(String.init)
        while let w = words.first, fillers.contains(CzechText.fold(w).trimmingCharacters(in: .punctuationCharacters)) { words.removeFirst() }
        while let w = words.last, fillers.contains(CzechText.fold(w).trimmingCharacters(in: .punctuationCharacters)) { words.removeLast() }
        return CzechText.capitalizeFirst(words.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " ,.:;-")))
    }

    // MARK: - Pomocné

    private func agendaRange(_ f: String) -> AgendaRange? {
        let asks = matches(#"\b(co|jaky|jake|kolik|mam)\b.*\b(mam|me\s+ceka|ceka\s+me|cekaji|deje|program|plan|naplanovano|naplanovaneho|v\s+planu)\b|^(?:dnesni|zitrejsi|tydenni)\s+(?:program|plan|prehled)|^(?:prehled|program|agenda)\b"#, f)
        // Jen krátké dotazy, které míří na čas nebo program (ne „co mám vařit k večeři?“)
        let words = f.split(whereSeparator: { $0 == " " }).count
        let timeOrPlan = matches(#"\b(dnes|dneska|zitra|pozitri|tyden|tydnu|po\s+terminu|ceka|cekaji|program|plan|naplanovan\w*|agenda|prehled)\b"#, f)
        guard asks, timeOrPlan, words <= 8, !matches(#"\bukol"#, f) || matches(#"\b(dnes|zitra|tyden)"#, f) else { return nil }
        if matches(#"\bpo\s+terminu\b|\bzmeskan|\bprosvihl"#, f) { return .overdue }
        if matches(#"\bpristi\s+tyden|\bpristim\s+tydnu"#, f) { return .nextWeek }
        if matches(#"\b(tento\s+tyden|tenhle\s+tyden|tomto\s+tydnu|tyden|tydnu|pristich\s+dnech|nejblizsich\s+dnech)\b"#, f) { return .week }
        if matches(#"\b(zitra|zitrejsi|zitrek)\b"#, f) { return .tomorrow }
        return .today
    }

    private func cleanReminderTitle(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"(?i)\b(připomeň|připomen|pripomen|připomenout|pripomenout|připomínku|pripominku|připomínka|pripominka|upozorni|nezapomeň|nezapomen)\b"#,
                                       with: " ", options: .regularExpression)
        t = CzechText.collapseSpaces(t)
        let fillers: Set<String> = ["mi", "me", "mne", "prosim", "at", "abych", "ze", "si", "mam", "nastav", "na", "to",
                                    "a", "aby", "jsem", "se", "mel", "mela", "musim"]
        return CzechText.capitalizeFirst(CzechText.trimFillers(t, fillers: fillers))
    }

    private func stripPrefix(_ pattern: String, text: String, folded: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: folded, range: NSRange(location: 0, length: (folded as NSString).length)),
              let r = CzechText.originalRange(m.range, folded: folded, original: text) else { return nil }
        return CzechText.collapseSpaces(String(text[r.upperBound...]))
    }

    private func matches(_ pattern: String, _ s: String) -> Bool {
        s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func joinedRanges(_ text: String, _ ranges: [Range<String.Index>]) -> String {
        ranges.sorted { $0.lowerBound < $1.lowerBound }.map { String(text[$0]) }.joined(separator: " ")
    }
}
