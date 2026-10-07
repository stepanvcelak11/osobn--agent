import SwiftUI
import AgentCore

struct HomeView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var ai: AIService
    @EnvironmentObject var notifications: NotificationService
    @State private var overview: DayOverview?
    @State private var summary = ""
    @State private var modelSummary: String?
    @State private var summarizing = false
    @State private var editing: EditTarget?
    @State private var now = Date()

    struct EditTarget: Identifiable { var id: String { ref.id }; var ref: EntityRef; var snapshot: JSONValue }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    quickActions
                    if app.isJailbroken {
                        Label("Zařízení vypadá jako jailbreaknuté – šifrování nemusí data spolehlivě chránit.", systemImage: "exclamationmark.octagon.fill")
                            .font(.footnote).foregroundStyle(.red)
                    }
                    if let ov = overview {
                        nowCard(ov)
                        summaryCard
                        todaySection(ov)
                        tasksSection(ov)
                        upcomingSection(ov)
                        notesSection(ov)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { reload() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: reload)
        .onChange(of: app.dataVersion) { _, _ in reload() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in now = Date(); reload() }
        .onChange(of: notifications.openedFromNotification) { _, id in
            if let id, id.hasPrefix("sum-") { Task { await summarize(evening: id == "sum-evening") } }
            notifications.openedFromNotification = nil
        }
        .sheet(item: $editing) { t in
            EntityEditSheet(ref: t.ref, snapshot: t.snapshot) { snap, summary in app.saveEdit(ref: t.ref, after: snap, summary: summary) }
        }
    }

    private func reload() {
        guard let b = app.overviewBuilder() else { return }
        overview = try? b.overview()
        summary = (try? b.deterministicSummary(evening: isEvening)) ?? ""
    }

    private var isEvening: Bool { app.calendar.component(.hour, from: now) >= 18 }

    private var greeting: String {
        let h = app.calendar.component(.hour, from: now)
        switch h {
        case 4..<9: return "Dobré ráno"
        case 9..<12: return "Dobré dopoledne"
        case 12..<18: return "Dobré odpoledne"
        default: return "Dobrý večer"
        }
    }

    /// Rychlé akce na dosah palce.
    private var quickActions: some View {
        HStack(spacing: 10) {
            quickButton("Nahrát", "waveform.badge.mic", .red) { app.showRecording = true }
            quickButton("Hodiny", "alarm", .purple) { app.showClock = true }
            quickButton("Zachytit", "bolt.fill", .orange) { app.requestCapture() }
            quickButton("Napsat", "keyboard", Theme.accent) {
                app.tab = .chat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { NotificationCenter.default.post(name: .focusChatInput, object: nil) }
            }
        }
    }

    private func quickButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3.weight(.semibold)).foregroundStyle(color)
                Text(title).font(.caption).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting).font(.subheadline).foregroundStyle(.secondary)
            Text(CzechFormat.headerDate(now, calendar: app.calendar)).font(.largeTitle.bold())
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Teď / nejbližší

    @ViewBuilder private func nowCard(_ ov: DayOverview) -> some View {
        if let cur = ov.current {
            Card {
                Label("PRÁVĚ PROBÍHÁ", systemImage: "dot.radiowaves.left.and.right").font(.caption.weight(.bold)).foregroundStyle(.green)
                itemRow(cur, showRelative: false)
            }
        }
        if let next = ov.next, let d = next.date {
            Card {
                HStack {
                    Label("NEJBLIŽŠÍ", systemImage: "arrow.forward.circle").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                    Spacer()
                    Text(CzechFormat.relativeInterval(d, now: now)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                itemRow(next, showRelative: true)
            }
        } else if ov.current == nil {
            Card { EmptyHint(text: "V příštích dnech nemáš nic naplánovaného.", systemImage: "sun.max") }
        }
    }

    // MARK: Shrnutí

    private var summaryCard: some View {
        Card {
            HStack {
                Label(isEvening ? "Večerní shrnutí" : "Shrnutí dne", systemImage: "text.quote").font(.headline)
                Spacer()
                if ai.isLLMReady {
                    Button {
                        Task { await summarize(evening: isEvening) }
                    } label: {
                        if summarizing { ProgressView().controlSize(.small) } else { Image(systemName: "sparkles") }
                    }
                    .disabled(summarizing)
                    .accessibilityLabel("Shrnout pomocí modelu")
                }
            }
            Text(modelSummary ?? summary).font(.body).foregroundStyle(.primary).animation(.default, value: modelSummary)
        }
    }

    private func summarize(evening: Bool) async {
        guard let agent = app.agent, !summarizing else { return }
        summarizing = true
        modelSummary = ""
        let text = await agent.summary(evening: evening) { p in
            if case .partialAnswer(let s) = p { Task { @MainActor in modelSummary = s } }
        }
        modelSummary = text
        summarizing = false
    }

    // MARK: Sekce

    private func todaySection(_ ov: DayOverview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Dnes", systemImage: "calendar")
            Card(padding: 6) {
                if ov.todayItems.isEmpty {
                    EmptyHint(text: "Na dnešek nic.").padding(10)
                } else {
                    ForEach(ov.todayItems) { item in
                        itemRow(item, showRelative: false).padding(8)
                        if item.id != ov.todayItems.last?.id { Divider().padding(.leading, 52) }
                    }
                }
            }
        }
    }

    private func tasksSection(_ ov: DayOverview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Nesplněné úkoly", systemImage: "checklist",
                          trailing: ov.openTasks.count > 5 ? "Vše (\(ov.openTasks.count))" : nil) { app.tab = .data }
            Card(padding: 6) {
                if ov.openTasks.isEmpty {
                    EmptyHint(text: "Žádné nesplněné úkoly.", systemImage: "checkmark.seal").padding(10)
                } else {
                    ForEach(ov.openTasks.prefix(5)) { t in
                        TaskRow(task: t, now: now).padding(8)
                        if t.id != ov.openTasks.prefix(5).last?.id { Divider().padding(.leading, 52) }
                    }
                }
            }
        }
    }

    private func upcomingSection(_ ov: DayOverview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Příštích 7 dní", systemImage: "calendar.badge.clock")
            if ov.upcoming.isEmpty {
                Card { EmptyHint(text: "Nic naplánovaného.") }
            } else {
                let groups = Dictionary(grouping: ov.upcoming) { app.calendar.startOfDay(for: $0.date ?? now) }
                ForEach(groups.keys.sorted(), id: \.self) { day in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(CzechText.capitalizeFirst(CzechFormat.relativeDay(day, now: now, calendar: app.calendar)))
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 4)
                        Card(padding: 6) {
                            ForEach(groups[day] ?? []) { item in itemRow(item, showRelative: false).padding(8) }
                        }
                    }
                }
            }
        }
    }

    private func notesSection(_ ov: DayOverview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Nedávné poznámky", systemImage: "note.text",
                          trailing: ov.recentNotes.isEmpty ? nil : "Vše") { app.tab = .data }
            if ov.recentNotes.isEmpty {
                Card { EmptyHint(text: "Zatím žádné poznámky. Řekni třeba „poznamenej si…“.") }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ov.recentNotes) { n in
                            Button { editing = EditTarget(ref: EntityRef(kind: .note, id: n.id), snapshot: JSONValue.from(n)) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(n.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    Text(n.body).font(.caption).foregroundStyle(.secondary).lineLimit(4)
                                    Spacer(minLength: 0)
                                    Text(CzechFormat.relativeDay(n.updatedAt, now: now, calendar: app.calendar)).font(.caption2).foregroundStyle(.tertiary)
                                }
                                .padding(12)
                                .frame(width: 170, height: 130, alignment: .topLeading)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func subtitle(_ item: AgendaItem, showRelative: Bool) -> String {
        let cal = app.calendar
        var parts: [String] = []
        if let d = item.date {
            if showRelative {
                parts.append(CzechFormat.relativeDateTime(d, now: now, calendar: cal, hasTime: item.hasTime))
            } else if item.hasTime {
                var t = CzechFormat.time(d, calendar: cal)
                if let e = item.endDate { t += "–" + CzechFormat.time(e, calendar: cal) }
                parts.append(t)
            } else {
                parts.append("celý den")
            }
        }
        if let loc = item.location { parts.append(loc) }
        if let src = item.source { parts.append(src) }
        return parts.joined(separator: " · ")
    }

    private func itemRow(_ item: AgendaItem, showRelative: Bool) -> some View {
        Button {
            guard !item.isExternal else { return }
            if let snap = try? app.store?.snapshot(item.ref) { editing = EditTarget(ref: item.ref, snapshot: snap) }
        } label: {
            HStack(spacing: 12) {
                KindBadge(kind: item.ref.kind)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.body).foregroundStyle(.primary).lineLimit(2)
                    HStack(spacing: 6) {
                        Text(subtitle(item, showRelative: showRelative))
                        if item.recurrenceText != nil { Image(systemName: "repeat") }
                    }
                    .font(.caption).foregroundStyle(item.isOverdue ? .red : .secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct TaskRow: View {
    @EnvironmentObject var app: AppModel
    var task: TaskItem
    var now: Date

    private var dueLine: (text: String, overdue: Bool)? {
        guard let d = task.dueAt else { return nil }
        let overdue = !task.isDone && (task.dueHasTime ? d < now : d < app.calendar.startOfDay(for: now))
        let when = CzechFormat.relativeDateTime(d, now: now, calendar: app.calendar, hasTime: task.dueHasTime)
        return (overdue ? "Po termínu · " + when : when, overdue)
    }
    var body: some View {
        HStack(spacing: 12) {
            Button { app.toggleTask(task) } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(task.isDone ? .green : .secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? "Označit jako nesplněné" : "Označit jako splněné")
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).strikethrough(task.isDone).foregroundStyle(task.isDone ? .secondary : .primary)
                if let line = dueLine {
                    Text(line.text).font(.caption).foregroundStyle(line.overdue ? Color.red : Color.secondary)
                }
            }
            Spacer()
            if task.priority > 0 { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange).accessibilityLabel("Důležité") }
        }
    }
}
