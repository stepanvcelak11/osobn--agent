import SwiftUI
import EventKit
import AgentCore

/// Nastavení propojení s aplikacemi Apple. Vše je ve výchozím stavu vypnuté.
struct IntegrationsView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var apple: AppleIntegration
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Toggle("Zapisovat události do Kalendáře", isOn: Binding(
                    get: { apple.calendarSyncOn },
                    set: { on in Task { await setCalendarSync(on) } }))
                if apple.calendarSyncOn {
                    Picker("Kalendář", selection: Binding(get: { apple.calendarId ?? "" }, set: { apple.calendarId = $0.isEmpty ? nil : $0 })) {
                        Text("Výchozí").tag("")
                        ForEach(apple.writableCalendars(), id: \.calendarIdentifier) { c in
                            Text("\(c.title) (\(c.source.title))").tag(c.calendarIdentifier)
                        }
                    }
                }
                Toggle("Zobrazovat události z Kalendáře v přehledu", isOn: Binding(
                    get: { apple.calendarReadOn },
                    set: { on in Task { await setCalendarRead(on) } }))
            } header: { Text("Kalendář Apple") } footer: {
                Text("Události vytvořené agentem se zapíšou i do zvoleného kalendáře; úpravy, smazání a „Zpět“ se propíšou. Pokud je kalendář v iCloudu, synchronizuje se do cloudu – pro čistě lokální uložení zvol kalendář „Na iPhonu“. Upozornění dál posílá tato aplikace (bez citlivého textu). Při zapnutí zobrazování agent uvidí tvé události z Kalendáře (jen v telefonu, nikam se neposílají).")
            }

            Section {
                Toggle("Zapisovat připomínky do Připomínek", isOn: Binding(
                    get: { apple.remindersSyncOn },
                    set: { on in Task { await setReminders(on, tasks: false) } }))
                Toggle("Zapisovat i úkoly", isOn: Binding(
                    get: { apple.tasksSyncOn },
                    set: { on in Task { await setReminders(on, tasks: true) } }))
                if apple.remindersSyncOn || apple.tasksSyncOn {
                    Picker("Seznam", selection: Binding(get: { apple.reminderListId ?? "" }, set: { apple.reminderListId = $0.isEmpty ? nil : $0 })) {
                        Text("Výchozí").tag("")
                        ForEach(apple.reminderLists(), id: \.calendarIdentifier) { c in
                            Text(c.title).tag(c.calendarIdentifier)
                        }
                    }
                }
            } header: { Text("Připomínky Apple") } footer: {
                Text("Připomínky i úkoly se zkopírují do aplikace Připomínky (bez upozornění, aby nechodila dvakrát). Splnění a smazání se propíše.")
            }

            Section {
                TextField("Název zkratky", text: Binding(get: { apple.notesShortcutName }, set: { apple.notesShortcutName = $0 }))
                    .autocorrectionDisabled()
            } header: { Text("Poznámky Apple (přes Zkratky)") } footer: {
                Text("Apple pro Poznámky nemá rozhraní pro aplikace. Vytvoř si v aplikaci Zkratky zkratku s tímto názvem: akce „Vytvořit poznámku“ s obsahem „Vstup zkratky“ (v podrobnostech zkratky zapni „Přijímat: Text“). U poznámky pak klepni na „Do Poznámek Apple“ – aplikace se na chvíli přepne do Zkratek a vrátí se.")
            }

            if apple.calendarSyncOn || apple.remindersSyncOn || apple.tasksSyncOn {
                Section {
                    Button("Zkopírovat existující položky teď") {
                        app.syncAppleNow()
                        message = "Kopírování probíhá na pozadí."
                    }
                }
            }
        }
        .navigationTitle("Propojení")
        .id(apple.version)
        .alert("Propojení", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
    }

    private func setCalendarSync(_ on: Bool) async {
        if on && !apple.calendarAuthorized {
            guard await apple.requestCalendarAccess() else { return denied("Kalendáři") }
        }
        apple.calendarSyncOn = on
        if on { app.syncAppleNow() }
    }

    private func setCalendarRead(_ on: Bool) async {
        if on && !apple.calendarAuthorized {
            guard await apple.requestCalendarAccess() else { return denied("Kalendáři") }
        }
        apple.calendarReadOn = on
        app.bumpData()
    }

    private func setReminders(_ on: Bool, tasks: Bool) async {
        if on && !apple.remindersAuthorized {
            guard await apple.requestRemindersAccess() else { return denied("Připomínkám") }
        }
        if tasks { apple.tasksSyncOn = on } else { apple.remindersSyncOn = on }
        if on { app.syncAppleNow() }
    }

    private func denied(_ what: String) {
        message = "Přístup k \(what) není povolen. Povol ho v Nastavení iOS → Soukromí a zabezpečení."
    }
}
