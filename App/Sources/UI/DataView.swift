import SwiftUI
import AgentCore

struct DataView: View {
    @EnvironmentObject var app: AppModel
    @State private var section: Section = .tasks
    @State private var tasks: [TaskItem] = []
    @State private var doneTasks: [TaskItem] = []
    @State private var events: [Event] = []
    @State private var reminders: [Reminder] = []
    @State private var notes: [Note] = []
    @State private var query = ""
    @State private var searchResults: [(note: Note, score: Double)]?
    @State private var editing: Target?
    @State private var confirmDelete: (ref: EntityRef, title: String)?
    @State private var showDone = false

    enum Section: String, CaseIterable, Identifiable {
        case tasks = "Úkoly", events = "Kalendář", reminders = "Připomínky", notes = "Poznámky"
        var id: String { rawValue }
        var kind: EntityKind {
            switch self { case .tasks: return .task; case .events: return .event; case .reminders: return .reminder; case .notes: return .note }
        }
    }

    struct Target: Identifiable { var id: String { ref.id }; var ref: EntityRef; var snapshot: JSONValue; var isNew: Bool }

    var body: some View {
        NavigationStack {
            List {
                Picker("Sekce", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                switch section {
                case .tasks: tasksList
                case .events: eventsList
                case .reminders: remindersList
                case .notes: notesList
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Moje data")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: section == .notes ? "Hledat v poznámkách (i podle významu)" : "Hledat")
            .onSubmit(of: .search) { Task { await runSearch() } }
            .onChange(of: query) { _, q in if q.isEmpty { searchResults = nil } }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { newItem() } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                        .accessibilityLabel("Přidat")
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { TrashView() } label: { Image(systemName: "trash") }.accessibilityLabel("Koš")
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: app.dataVersion) { _, _ in reload() }
        .sheet(item: $editing) { t in
            EntityEditSheet(ref: t.ref, snapshot: t.snapshot, isNew: t.isNew) { snap, summary in
                app.saveEdit(ref: t.ref, after: snap, summary: summary)
            }
        }
        .confirmationDialog("Opravdu smazat „\(confirmDelete?.title ?? "")“?",
                            isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Smazat", role: .destructive) {
                if let c = confirmDelete { app.delete(c.ref, title: c.title) }
                confirmDelete = nil
            }
        } message: { Text("Položka se přesune do koše, kde zůstane 30 dní.") }
    }

    private func reload() {
        guard let s = app.store else { return }
        tasks = (try? s.tasks(.open)) ?? []
        doneTasks = (try? s.tasks(.done, limit: 50)) ?? []
        let now = Date()
        events = ((try? s.events(from: now.addingTimeInterval(-86400 * 30), to: now.addingTimeInterval(86400 * 365))) ?? [])
        reminders = (try? s.activeReminders()) ?? []
        notes = (try? s.notes(limit: 500)) ?? []
    }

    private func matches(_ s: String) -> Bool {
        query.isEmpty || CzechText.fold(s).contains(CzechText.fold(query))
    }

    private func runSearch() async {
        guard section == .notes, !query.isEmpty, let search = app.semantic else { return }
        searchResults = try? await search.search(query, limit: 20)
    }

    private func newItem() {
        let id = UUID().uuidString
        let cal = app.calendar
        let next = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date().addingTimeInterval(86400))!
        let snap: JSONValue
        switch section {
        case .tasks: snap = JSONValue.from(TaskItem(id: id, title: ""))
        case .events: snap = JSONValue.from(Event(id: id, title: "", startAt: next, endAt: next.addingTimeInterval(3600)))
        case .reminders: snap = JSONValue.from(Reminder(id: id, title: "", dueAt: next))
        case .notes: snap = JSONValue.from(Note(id: id, title: "", body: ""))
        }
        editing = Target(ref: EntityRef(kind: section.kind, id: id), snapshot: snap, isNew: true)
    }

    private func edit(_ ref: EntityRef) {
        if let snap = try? app.store?.snapshot(ref) { editing = Target(ref: ref, snapshot: snap, isNew: false) }
    }

    private func deleteButton(_ ref: EntityRef, _ title: String) -> some View {
        Button(role: .destructive) { confirmDelete = (ref, title) } label: { Label("Smazat", systemImage: "trash") }
    }

    // MARK: - Seznamy

    @ViewBuilder private var tasksList: some View {
        let open = tasks.filter { matches($0.title) }
        SwiftUI.Section("Nesplněné (\(open.count))") {
            if open.isEmpty { EmptyHint(text: "Žádné nesplněné úkoly.") }
            ForEach(open) { t in
                TaskRow(task: t, now: Date())
                    .contentShape(Rectangle())
                    .onTapGesture { edit(EntityRef(kind: .task, id: t.id)) }
                    .swipeActions(edge: .trailing) { deleteButton(EntityRef(kind: .task, id: t.id), t.title) }
                    .swipeActions(edge: .leading) {
                        Button { app.toggleTask(t) } label: { Label("Hotovo", systemImage: "checkmark") }.tint(.green)
                    }
            }
        }
        SwiftUI.Section {
            DisclosureGroup("Splněné (\(doneTasks.count))", isExpanded: $showDone) {
                ForEach(doneTasks.filter { matches($0.title) }) { t in
                    TaskRow(task: t, now: Date())
                        .swipeActions { deleteButton(EntityRef(kind: .task, id: t.id), t.title) }
                }
            }
        }
    }

    private var eventGroups: [(day: Date, events: [Event])] {
        let cal = app.calendar
        let list = events.filter { matches($0.title + " " + $0.location) }
        let groups = Dictionary(grouping: list) { cal.startOfDay(for: $0.startAt) }
        return groups.keys.sorted().map { (day: $0, events: groups[$0] ?? []) }
    }

    @ViewBuilder private var eventsList: some View {
        let groups = eventGroups
        if groups.isEmpty { EmptyHint(text: "Žádné události. Řekni třeba „v pátek ve 14 schůzka s Petrem“.") }
        ForEach(groups, id: \.day) { g in
            SwiftUI.Section(dayTitle(g.day)) {
                ForEach(g.events) { e in eventRow(e) }
            }
        }
    }

    private func dayTitle(_ day: Date) -> String {
        CzechText.capitalizeFirst(CzechFormat.relativeDay(day, now: Date(), calendar: app.calendar))
    }

    private func eventSubtitle(_ e: Event) -> String {
        let cal = app.calendar
        var s = e.allDay ? "celý den" : CzechFormat.time(e.startAt, calendar: cal)
        if !e.allDay, let end = e.endAt { s += "–" + CzechFormat.time(end, calendar: cal) }
        if !e.location.isEmpty { s += " · " + e.location }
        return s
    }

    private func eventRow(_ e: Event) -> some View {
        HStack(spacing: 12) {
            KindBadge(kind: .event)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title)
                Text(eventSubtitle(e)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { edit(EntityRef(kind: .event, id: e.id)) }
        .swipeActions { deleteButton(EntityRef(kind: .event, id: e.id), e.title) }
    }

    @ViewBuilder private var remindersList: some View {
        let list = reminders.filter { matches($0.title) }
        let cal = app.calendar
        SwiftUI.Section {
            if list.isEmpty { EmptyHint(text: "Žádné připomínky.") }
            ForEach(list) { r in
                HStack(spacing: 12) {
                    KindBadge(kind: .reminder)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title)
                        if let rec = r.recurrence {
                            Label(rec.czechDescription, systemImage: "repeat").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text(CzechFormat.relativeDateTime(r.dueAt, now: Date(), calendar: cal))
                                .font(.caption).foregroundStyle(r.dueAt < Date() ? .red : .secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { edit(EntityRef(kind: .reminder, id: r.id)) }
                .swipeActions { deleteButton(EntityRef(kind: .reminder, id: r.id), r.title) }
            }
        }
    }

    @ViewBuilder private var notesList: some View {
        SwiftUI.Section {
            if let results = searchResults {
                if results.isEmpty { EmptyHint(text: "Nic nenalezeno.") }
                ForEach(results.map { $0.note }) { n in noteRow(n) }
            } else {
                let list = notes.filter { matches($0.title + " " + $0.body) }
                if list.isEmpty { EmptyHint(text: "Žádné poznámky.") }
                ForEach(list) { n in noteRow(n) }
            }
        } footer: {
            if section == .notes && !query.isEmpty && searchResults == nil {
                Text("Pro hledání podle významu stiskni Hledat na klávesnici.")
            }
        }
    }

    private func noteRow(_ n: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(n.displayTitle).font(.body.weight(.medium))
            Text(n.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Text(CzechFormat.relativeDay(n.updatedAt, now: Date(), calendar: app.calendar)).font(.caption2).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { edit(EntityRef(kind: .note, id: n.id)) }
        .swipeActions { deleteButton(EntityRef(kind: .note, id: n.id), n.displayTitle) }
    }
}

struct TrashView: View {
    @EnvironmentObject var app: AppModel
    struct TrashItem: Identifiable { var id: String { ref.id }; var ref: EntityRef; var title: String; var deletedAt: Date }
    @State private var items: [TrashItem] = []
    @State private var confirmEmpty = false

    var body: some View {
        List {
            SwiftUI.Section {
                if items.isEmpty { EmptyHint(text: "Koš je prázdný.", systemImage: "trash") }
                ForEach(items) { it in
                    HStack(spacing: 12) {
                        KindBadge(kind: it.ref.kind)
                        VStack(alignment: .leading) {
                            Text(it.title.isEmpty ? it.ref.kind.czechName : it.title)
                            Text("Smazáno " + CzechFormat.relativeDay(it.deletedAt, now: Date(), calendar: app.calendar)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Obnovit") { restore(it.ref) }.buttonStyle(.bordered).controlSize(.small)
                    }
                }
            } footer: { Text("Položky se z koše trvale mažou po 30 dnech.") }
        }
        .navigationTitle("Koš")
        .toolbar {
            if !items.isEmpty {
                Button("Vysypat", role: .destructive) { confirmEmpty = true }
            }
        }
        .confirmationDialog("Trvale smazat vše v koši? Tuto akci nejde vrátit.", isPresented: $confirmEmpty, titleVisibility: .visible) {
            Button("Trvale smazat", role: .destructive) {
                _ = try? app.store?.purgeDeleted(before: Date().addingTimeInterval(1))
                load()
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        items = ((try? app.store?.deletedItems()) ?? []).map { TrashItem(ref: $0.ref, title: $0.title, deletedAt: $0.deletedAt) }
    }

    private func restore(_ ref: EntityRef) {
        guard let store = app.store, var snap = try? store.snapshot(ref), case .object(var o) = snap else { return }
        o["deletedAt"] = nil
        snap = .object(o)
        app.saveEdit(ref: ref, after: snap, summary: "Obnoveno z koše")
        load()
    }
}
