import Foundation

public enum EntityKind: String, Codable, Sendable, CaseIterable {
    case note, task, event, reminder

    public var czechName: String {
        switch self {
        case .note: return "Poznámka"
        case .task: return "Úkol"
        case .event: return "Událost"
        case .reminder: return "Připomínka"
        }
    }
    /// Prefix krátkého odkazu, který vidí model (N1, U2, K3, P4).
    public var refPrefix: String {
        switch self {
        case .note: return "N"
        case .task: return "U"
        case .event: return "K"
        case .reminder: return "P"
        }
    }
    var table: String {
        switch self {
        case .note: return "notes"
        case .task: return "tasks"
        case .event: return "events"
        case .reminder: return "reminders"
        }
    }
}

public struct EntityRef: Hashable, Codable, Sendable {
    public var kind: EntityKind
    public var id: String
    public init(kind: EntityKind, id: String) { self.kind = kind; self.id = id }
}

public struct Note: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: String = UUID().uuidString, title: String, body: String,
                createdAt: Date = Date(), updatedAt: Date? = nil, deletedAt: Date? = nil) {
        self.id = id; self.title = title; self.body = body
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.deletedAt = deletedAt
    }

    /// Titulek pro zobrazení – když chybí, vezme se začátek textu.
    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        let firstLine = body.split(separator: "\n").first.map(String.init) ?? body
        return firstLine.count > 60 ? String(firstLine.prefix(60)) + "…" : firstLine
    }
}

public struct TaskItem: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var title: String
    public var details: String
    public var dueAt: Date?
    public var dueHasTime: Bool
    public var doneAt: Date?
    public var priority: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: String = UUID().uuidString, title: String, details: String = "", dueAt: Date? = nil,
                dueHasTime: Bool = false, doneAt: Date? = nil, priority: Int = 0,
                createdAt: Date = Date(), updatedAt: Date? = nil, deletedAt: Date? = nil) {
        self.id = id; self.title = title; self.details = details; self.dueAt = dueAt
        self.dueHasTime = dueHasTime; self.doneAt = doneAt; self.priority = priority
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.deletedAt = deletedAt
    }
    public var isDone: Bool { doneAt != nil }
}

public struct Event: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var title: String
    public var startAt: Date
    public var endAt: Date?
    public var allDay: Bool
    public var location: String
    public var details: String
    /// Kolik minut předem upozornit (nil = neupozorňovat).
    public var alertMinutes: Int?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: String = UUID().uuidString, title: String, startAt: Date, endAt: Date? = nil,
                allDay: Bool = false, location: String = "", details: String = "", alertMinutes: Int? = 15,
                createdAt: Date = Date(), updatedAt: Date? = nil, deletedAt: Date? = nil) {
        self.id = id; self.title = title; self.startAt = startAt; self.endAt = endAt; self.allDay = allDay
        self.location = location; self.details = details; self.alertMinutes = alertMinutes
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.deletedAt = deletedAt
    }
}

public struct Reminder: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var title: String
    /// První (u opakování kotevní) výskyt.
    public var dueAt: Date
    public var recurrence: Recurrence?
    public var doneAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(id: String = UUID().uuidString, title: String, dueAt: Date, recurrence: Recurrence? = nil,
                doneAt: Date? = nil, createdAt: Date = Date(), updatedAt: Date? = nil, deletedAt: Date? = nil) {
        self.id = id; self.title = title; self.dueAt = dueAt; self.recurrence = recurrence; self.doneAt = doneAt
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt; self.deletedAt = deletedAt
    }

    /// Nejbližší výskyt v čase >= `date` (u jednorázové jen pokud ještě nenastal a není hotová).
    public func nextOccurrence(onOrAfter date: Date, calendar: Calendar) -> Date? {
        if let r = recurrence {
            if dueAt >= date { return dueAt }
            return r.nextOccurrence(after: date.addingTimeInterval(-1), anchor: dueAt, calendar: calendar)
        }
        guard doneAt == nil else { return nil }
        return dueAt >= date ? dueAt : nil
    }
}

public enum ChatRole: String, Codable, Sendable { case user, assistant, action, system }

public struct ChatMessage: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var role: ChatRole
    public var text: String
    public var actionId: String?
    public var createdAt: Date
    public init(id: String = UUID().uuidString, role: ChatRole, text: String, actionId: String? = nil, createdAt: Date = Date()) {
        self.id = id; self.role = role; self.text = text; self.actionId = actionId; self.createdAt = createdAt
    }
}

public enum ActionStatus: String, Codable, Sendable {
    /// Provedeno (lze vrátit).
    case applied
    /// Čeká na potvrzení uživatelem.
    case pending
    /// Vráceno zpět.
    case undone
    /// Zamítnuto uživatelem.
    case rejected
}

/// Záznam v deníku akcí agenta – umožňuje „Zpět“ a potvrzování.
public struct ActionRecord: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var createdAt: Date
    public var tool: String
    public var args: JSONValue
    public var status: ActionStatus
    public var summary: String
    public var entity: EntityRef?
    /// Stav entity před změnou (nil = entita vznikla touto akcí).
    public var before: JSONValue?
    public var source: String

    public init(id: String = UUID().uuidString, createdAt: Date = Date(), tool: String, args: JSONValue,
                status: ActionStatus, summary: String, entity: EntityRef?, before: JSONValue?, source: String) {
        self.id = id; self.createdAt = createdAt; self.tool = tool; self.args = args; self.status = status
        self.summary = summary; self.entity = entity; self.before = before; self.source = source
    }
}
