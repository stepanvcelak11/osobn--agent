import SwiftUI
import AgentCore

/// Formulář pro úpravu / vytvoření položky. Vrací nový snapshot entity.
struct EntityEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    var ref: EntityRef
    var snapshot: JSONValue
    var isNew: Bool = false
    var onSave: (JSONValue, String) -> Void

    // Společná pole
    @State private var title = ""
    @State private var body_ = ""
    @State private var date = Date()
    @State private var endDate = Date()
    @State private var hasDate = false
    @State private var hasTime = true
    @State private var allDay = false
    @State private var location = ""
    @State private var alertMinutes = 15
    @State private var important = false
    @State private var repeatMode: RepeatMode = .none
    @State private var weekdays: Set<Int> = []
    @State private var loaded = false

    enum RepeatMode: String, CaseIterable, Identifiable {
        case none, daily, weekdays, weekly, monthly, yearly
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none: return "Neopakovat"
            case .daily: return "Každý den"
            case .weekdays: return "Pracovní dny"
            case .weekly: return "Vybrané dny v týdnu"
            case .monthly: return "Každý měsíc"
            case .yearly: return "Každý rok"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                switch ref.kind {
                case .note: noteForm
                case .task: taskForm
                case .event: eventForm
                case .reminder: reminderForm
                }
            }
            .navigationTitle(isNew ? "Nová \(ref.kind.czechName.lowercased())".replacingOccurrences(of: "Nová úkol", with: "Nový úkol") : "Upravit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložit") { save() }
                        .disabled(ref.kind == .note ? (title + body_).trimmingCharacters(in: .whitespaces).isEmpty
                                                    : title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .environment(\.locale, Locale(identifier: "cs_CZ"))
    }

    // MARK: - Formuláře

    private var noteForm: some View {
        Section {
            TextField("Název (nepovinný)", text: $title)
            TextEditor(text: $body_).frame(minHeight: 220)
        }
    }

    private var taskForm: some View {
        Group {
            Section { TextField("Co udělat", text: $title) }
            Section {
                Toggle("Termín", isOn: $hasDate.animation())
                if hasDate {
                    Toggle("Včetně času", isOn: $hasTime)
                    DatePicker("Kdy", selection: $date, displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                }
                Toggle("Důležité", isOn: $important)
            }
            Section("Poznámka") { TextEditor(text: $body_).frame(minHeight: 90) }
        }
    }

    private var eventForm: some View {
        Group {
            Section { TextField("Název", text: $title); TextField("Místo", text: $location) }
            Section {
                Toggle("Celý den", isOn: $allDay.animation())
                DatePicker("Začátek", selection: $date, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                if !allDay {
                    DatePicker("Konec", selection: $endDate, in: date..., displayedComponents: [.date, .hourAndMinute])
                    Picker("Upozornit", selection: $alertMinutes) {
                        Text("Neupozorňovat").tag(-1)
                        Text("V čas začátku").tag(0)
                        Text("5 min předem").tag(5)
                        Text("15 min předem").tag(15)
                        Text("30 min předem").tag(30)
                        Text("1 h předem").tag(60)
                        Text("1 den předem").tag(1440)
                    }
                }
            }
            Section("Poznámka") { TextEditor(text: $body_).frame(minHeight: 80) }
        }
    }

    private var reminderForm: some View {
        Group {
            Section { TextField("Co připomenout", text: $title) }
            Section {
                DatePicker(repeatMode == .none ? "Kdy" : "Poprvé", selection: $date, displayedComponents: [.date, .hourAndMinute])
                Picker("Opakování", selection: $repeatMode) {
                    ForEach(RepeatMode.allCases) { Text($0.title).tag($0) }
                }
                if repeatMode == .weekly {
                    HStack {
                        ForEach(1...7, id: \.self) { d in
                            let on = weekdays.contains(d)
                            Button(CzechFormat.weekdayShort[d - 1]) {
                                if on { weekdays.remove(d) } else { weekdays.insert(d) }
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(on ? Theme.accent : Color(.tertiarySystemFill), in: Circle())
                            .foregroundStyle(on ? .white : .primary)
                            .buttonStyle(.plain)
                            .accessibilityLabel(CzechFormat.weekdayNominative[d - 1])
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
            }
        }
    }

    // MARK: - Načtení a uložení

    private func load() {
        guard !loaded else { return }
        loaded = true
        let cal = CzechFormat.calendar()
        switch ref.kind {
        case .note:
            if let n = snapshot.decode(Note.self) { title = n.title; body_ = n.body }
        case .task:
            if let t = snapshot.decode(TaskItem.self) {
                title = t.title; body_ = t.details; important = t.priority > 0
                hasDate = t.dueAt != nil; hasTime = t.dueHasTime
                date = t.dueAt ?? cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date().addingTimeInterval(86400))!
            }
        case .event:
            if let e = snapshot.decode(Event.self) {
                title = e.title; body_ = e.details; location = e.location; allDay = e.allDay
                date = e.startAt; endDate = e.endAt ?? e.startAt.addingTimeInterval(3600)
                alertMinutes = e.alertMinutes ?? -1
            }
        case .reminder:
            if let r = snapshot.decode(Reminder.self) {
                title = r.title; date = r.dueAt
                if let rec = r.recurrence {
                    switch rec.frequency {
                    case .daily: repeatMode = .daily
                    case .weekly:
                        if rec.weekdays == [1, 2, 3, 4, 5] { repeatMode = .weekdays } else { repeatMode = .weekly; weekdays = Set(rec.weekdays) }
                    case .monthly: repeatMode = .monthly
                    case .yearly: repeatMode = .yearly
                    }
                }
            }
        }
    }

    private func save() {
        let now = Date()
        let cal = CzechFormat.calendar()
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        switch ref.kind {
        case .note:
            var n = snapshot.decode(Note.self) ?? Note(id: ref.id, title: "", body: "")
            n.title = t; n.body = body_; n.updatedAt = now
            onSave(JSONValue.from(n), (isNew ? "Nová poznámka: " : "Upravena poznámka: ") + n.displayTitle)
        case .task:
            var x = snapshot.decode(TaskItem.self) ?? TaskItem(id: ref.id, title: t)
            x.title = t; x.details = body_; x.priority = important ? 1 : 0
            x.dueAt = hasDate ? (hasTime ? date : cal.date(bySettingHour: 9, minute: 0, second: 0, of: date)) : nil
            x.dueHasTime = hasDate && hasTime
            x.updatedAt = now
            onSave(JSONValue.from(x), (isNew ? "Nový úkol: " : "Upraven úkol: ") + t)
        case .event:
            var e = snapshot.decode(Event.self) ?? Event(id: ref.id, title: t, startAt: date)
            e.title = t; e.details = body_; e.location = location; e.allDay = allDay
            e.startAt = allDay ? cal.startOfDay(for: date) : date
            e.endAt = allDay ? nil : max(endDate, date.addingTimeInterval(300))
            e.alertMinutes = (allDay || alertMinutes < 0) ? nil : alertMinutes
            e.updatedAt = now
            onSave(JSONValue.from(e), (isNew ? "Nová událost: " : "Upravena událost: ") + t)
        case .reminder:
            var r = snapshot.decode(Reminder.self) ?? Reminder(id: ref.id, title: t, dueAt: date)
            r.title = t; r.dueAt = date; r.doneAt = nil; r.updatedAt = now
            let h = cal.component(.hour, from: date), m = cal.component(.minute, from: date)
            switch repeatMode {
            case .none: r.recurrence = nil
            case .daily: r.recurrence = Recurrence(frequency: .daily, hour: h, minute: m)
            case .weekdays: r.recurrence = Recurrence(frequency: .weekly, weekdays: [1, 2, 3, 4, 5], hour: h, minute: m)
            case .weekly:
                let days = weekdays.isEmpty ? [Recurrence.isoWeekday(date, calendar: cal)] : Array(weekdays)
                r.recurrence = Recurrence(frequency: .weekly, weekdays: days, hour: h, minute: m)
            case .monthly: r.recurrence = Recurrence(frequency: .monthly, monthDay: cal.component(.day, from: date), hour: h, minute: m)
            case .yearly: r.recurrence = Recurrence(frequency: .yearly, monthDay: cal.component(.day, from: date),
                                                    month: cal.component(.month, from: date), hour: h, minute: m)
            }
            onSave(JSONValue.from(r), (isNew ? "Nová připomínka: " : "Upravena připomínka: ") + t)
        }
        dismiss()
    }
}
