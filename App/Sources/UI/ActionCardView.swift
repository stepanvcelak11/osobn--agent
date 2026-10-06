import SwiftUI
import AgentCore

/// Karta akce agenta: co vytvořil / změnil, s tlačítky Potvrdit / Upravit / Zpět.
struct ActionCardView: View {
    @EnvironmentObject var app: AppModel
    var action: ActionRecord
    @State private var editing = false

    private var kind: EntityKind? { action.entity?.kind }
    private var snapshot: JSONValue? { action.after ?? action.before }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let kind { KindBadge(kind: kind) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(header).font(.caption.weight(.semibold)).foregroundStyle(headerColor)
                    Text(title).font(.headline).strikethrough(action.status == .undone || action.status == .rejected)
                }
                Spacer()
            }
            ForEach(details, id: \.self) { d in
                Label(d.text, systemImage: d.icon).font(.subheadline).foregroundStyle(.secondary)
            }
            if !action.notes.isEmpty && action.status != .undone {
                ForEach(action.notes, id: \.self) { n in
                    Label(n, systemImage: "info.circle").font(.caption).foregroundStyle(.orange)
                }
            }
            buttons
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(action.status == .pending ? Color.orange.opacity(0.6) : .clear, lineWidth: 1.5)
        )
        .sheet(isPresented: $editing) {
            if let ref = action.entity, let snap = snapshot {
                EntityEditSheet(ref: ref, snapshot: snap) { newSnap, summary in
                    app.saveEdit(ref: ref, after: newSnap, summary: summary,
                                 pendingActionId: action.status == .pending ? action.id : nil)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var buttons: some View {
        switch action.status {
        case .pending:
            HStack(spacing: 10) {
                Button(isDelete ? "Smazat" : "Potvrdit") { app.confirm(action.id) }
                    .buttonStyle(.borderedProminent)
                    .tint(isDelete ? .red : Theme.accent)
                if !isDelete { Button("Upravit") { editing = true }.buttonStyle(.bordered) }
                Button("Zrušit") { app.reject(action.id) }.buttonStyle(.bordered)
            }
            .controlSize(.small)
        case .applied:
            HStack(spacing: 10) {
                if !isDelete && action.entity != nil { Button("Upravit") { editing = true }.buttonStyle(.bordered) }
                Button("Zpět") { app.undo(action.id) }.buttonStyle(.bordered)
            }
            .controlSize(.small)
        case .undone, .rejected:
            EmptyView()
        }
    }

    private var isDelete: Bool { action.tool == "delete_item" }

    private var header: String {
        switch action.status {
        case .pending: return isDelete ? "ČEKÁ NA POTVRZENÍ – SMAZÁNÍ" : "ČEKÁ NA POTVRZENÍ"
        case .undone: return "VRÁCENO ZPĚT"
        case .rejected: return "ZRUŠENO"
        case .applied:
            switch action.tool {
            case "delete_item": return "SMAZÁNO"
            case "complete_task": return "SPLNĚNO"
            case "update_item", "user_edit": return "UPRAVENO"
            default: return "\(kind?.czechName.uppercased() ?? "AKCE") VYTVOŘENA".replacingOccurrences(of: "ÚKOL VYTVOŘENA", with: "ÚKOL VYTVOŘEN")
            }
        }
    }

    private var headerColor: Color {
        switch action.status {
        case .pending: return .orange
        case .undone, .rejected: return .secondary
        case .applied: return isDelete ? .red : Theme.color(for: kind ?? .note)
        }
    }

    private var title: String {
        snapshot?["title"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
            ?? snapshot?["body"]?.stringValue.map { String($0.prefix(80)) }
            ?? action.summary
    }

    struct Detail: Hashable { var icon: String; var text: String }

    private var details: [Detail] {
        guard let snap = snapshot, let kind else { return [] }
        let cal = app.calendar
        let now = Date()
        var out: [Detail] = []
        switch kind {
        case .reminder:
            if let r = snap.decode(Reminder.self) {
                if let rec = r.recurrence {
                    out.append(Detail(icon: "repeat", text: CzechText.capitalizeFirst(rec.czechDescription)))
                    out.append(Detail(icon: "clock", text: "Poprvé " + CzechFormat.relativeDateTime(r.dueAt, now: now, calendar: cal)))
                } else {
                    out.append(Detail(icon: "clock", text: CzechText.capitalizeFirst(CzechFormat.relativeDateTime(r.dueAt, now: now, calendar: cal))))
                }
            }
        case .task:
            if let t = snap.decode(TaskItem.self) {
                if let d = t.dueAt { out.append(Detail(icon: "calendar", text: "Termín " + CzechFormat.relativeDateTime(d, now: now, calendar: cal, hasTime: t.dueHasTime))) }
                if t.priority > 0 { out.append(Detail(icon: "exclamationmark", text: "Důležité")) }
            }
        case .event:
            if let e = snap.decode(Event.self) {
                var s = CzechText.capitalizeFirst(CzechFormat.relativeDateTime(e.startAt, now: now, calendar: cal, hasTime: !e.allDay))
                if let end = e.endAt, !e.allDay { s += "–" + CzechFormat.time(end, calendar: cal) }
                out.append(Detail(icon: "clock", text: s))
                if !e.location.isEmpty { out.append(Detail(icon: "mappin.and.ellipse", text: e.location)) }
            }
        case .note:
            if let n = snap.decode(Note.self), !n.title.isEmpty {
                out.append(Detail(icon: "text.alignleft", text: String(n.body.prefix(140))))
            }
        }
        return out
    }
}
