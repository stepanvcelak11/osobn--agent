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
    public enum Missing: String, Sendable { case when, title }
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

    static let reminderTrigger = #"\b(pripomen(?:\s+mi)?|pripomenout|pripominku|pripominka|upozorni\s+me|upozorni|nezapomen\s+mi\s+pripomenout)\b"#
    static let notePrefix = #"^\s*(?:(?:prosim\s+)?(?:poznamenej(?:\s+si)?|zapis(?:\s+si)?|zaznamenej(?:\s+si)?|uloz(?:\s+si)?(?:\s+poznamku)?|zapamatuj\s+si|nova\s+poznamka|poznamka))\s*[:,\-–]?\s*"#
    static let taskPrefix = #"^\s*(?:(?:prosim\s+)?(?:pridej(?:\s+si)?(?:\s+(?:do\s+)?(?:ukol[uy]?|ukolu))|novy\s+ukol|ukol|todo|to-do|musim))\s*[:,\-–]?\s*"#
    static let completePrefix = #"^\s*(?:hotovo|splneno|dokonceno|odskrtni|oznac\s+(?:jako\s+)?(?:hotove|splnene|hotovy|splneny))\s*[:,\-–]?\s*"#
    static let undoPhrases: Set<String> = ["zpet", "vrat to", "vrat zpet", "vrat to zpet", "vrat posledni akci", "odvolej",
                                           "zrus posledni akci", "zrus to", "vrat to prosim", "zpet prosim", "undo"]

    public func route(_ input: String) -> RuleResult? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let f = CzechText.fold(text).trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))

        if Self.undoPhrases.contains(f) { return .tool(ToolCall(name: "undo_last", args: .object([:]))) }

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
            guard let p = parser.parse(answer), !p.isEmpty else { return nil }
            args["when"] = answer
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

    // MARK: - Pomocné

    private func agendaRange(_ f: String) -> AgendaRange? {
        let asks = matches(#"\b(co|jaky|jake|kolik)\b.*\b(mam|me\s+ceka|ceka\s+me|cekaji|deje|program|plan|naplanovano|v\s+planu)\b|^(?:dnesni|zitrejsi|tydenni)\s+(?:program|plan|prehled)|^(?:prehled|program|agenda)\b"#, f)
        guard asks, !matches(#"\bukol"#, f) || matches(#"\b(dnes|zitra|tyden)"#, f) else { return nil }
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
