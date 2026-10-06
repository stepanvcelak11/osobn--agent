import SwiftUI
import AVFoundation
import AgentCore

struct SettingsView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var notifications: NotificationService
    @EnvironmentObject var ai: AIService
    @AppStorage("appearance") private var appearance: String = AppearanceMode.dark.rawValue
    @AppStorage("textScale") private var textScale: Int = -1
    @AppStorage("tts.auto") private var autoSpeak = false
    @AppStorage("tts.voice") private var voiceId = ""
    @AppStorage("tts.rate") private var ttsRate: Double = 0.5
    @AppStorage("notif.showContent") private var showContent = false
    @State private var lockBackground = 0
    @State private var lockIdle = 120
    @State private var wipeAfter = 0
    @State private var summary = NotificationService.shared.summarySettings
    @State private var confirmWipe = false
    @State private var confirmWipe2 = false
    @State private var showChangePassword = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Vzhled") {
                    Picker("Režim", selection: $appearance) {
                        ForEach(AppearanceMode.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    Picker("Velikost textu", selection: $textScale) {
                        Text("Podle systému").tag(-1)
                        ForEach(0..<TextScale.labels.count, id: \.self) { Text(TextScale.labels[$0]).tag($0) }
                    }
                }

                Section {
                    Picker("Zamknout po odchodu", selection: $lockBackground) {
                        Text("Okamžitě").tag(0)
                        Text("Po 30 s").tag(30)
                        Text("Po 1 min").tag(60)
                        Text("Po 5 min").tag(300)
                    }
                    Picker("Zamknout při nečinnosti", selection: $lockIdle) {
                        Text("Po 1 min").tag(60)
                        Text("Po 2 min").tag(120)
                        Text("Po 5 min").tag(300)
                        Text("Po 10 min").tag(600)
                    }
                    Picker("Smazat data po neúspěšných pokusech", selection: $wipeAfter) {
                        Text("Nikdy").tag(0)
                        Text("Po 5 pokusech").tag(5)
                        Text("Po 10 pokusech").tag(10)
                        Text("Po 15 pokusech").tag(15)
                    }
                    Button("Změnit nouzové heslo") { showChangePassword = true }
                    Button("Zamknout teď") { app.lock() }
                    NavigationLink("Stav zabezpečení") { SecurityStatusView() }
                } header: { Text("Zabezpečení") } footer: {
                    if wipeAfter > 0 { Text("Po \(wipeAfter) neúspěšných pokusech o odemčení se zničí šifrovací klíče a data budou nenávratně ztracena.") }
                }

                Section {
                    Toggle("Potvrzovat i vytváření", isOn: Binding(get: { app.agentSettings.confirmAllWrites },
                                                                    set: { app.agentSettings.confirmAllWrites = $0; app.saveAgentSettings() }))
                    Picker("Výchozí čas, když chybí", selection: Binding(get: { app.agentSettings.defaultHour },
                                                                         set: { app.agentSettings.defaultHour = $0; app.saveAgentSettings() })) {
                        ForEach([7, 8, 9, 10, 12], id: \.self) { Text("\($0):00").tag($0) }
                    }
                    Picker("Upozornění před událostí", selection: Binding(get: { app.agentSettings.eventAlertMinutes },
                                                                          set: { app.agentSettings.eventAlertMinutes = $0; app.saveAgentSettings() })) {
                        ForEach([0, 5, 10, 15, 30, 60], id: \.self) { Text($0 == 0 ? "V čas začátku" : "\($0) min").tag($0) }
                    }
                } header: { Text("Agent") } footer: {
                    Text("Mazání a hromadné změny agent vždy provede až po tvém potvrzení.")
                }

                Section {
                    if !notifications.authorized {
                        Button("Povolit notifikace") { Task { await notifications.requestAuthorization() } }
                    }
                    Toggle("Zobrazovat názvy v notifikacích", isOn: $showContent)
                    Toggle("Ranní přehled", isOn: $summary.morningEnabled)
                    if summary.morningEnabled { timePicker("Čas ranního přehledu", minutes: $summary.morningMinutes) }
                    Toggle("Večerní shrnutí", isOn: $summary.eveningEnabled)
                    if summary.eveningEnabled { timePicker("Čas večerního shrnutí", minutes: $summary.eveningMinutes) }
                } header: { Text("Notifikace") } footer: {
                    Text("Ve výchozím stavu notifikace neobsahují žádný text z tvých dat. Když názvy zapneš, doporučujeme v Nastavení iOS → Oznámení → Náhledy zvolit „Po odemknutí“.")
                }

                Section {
                    Toggle("Číst odpovědi nahlas", isOn: $autoSpeak)
                    Picker("Hlas", selection: $voiceId) {
                        Text("Výchozí český").tag("")
                        ForEach(Speaker.czechVoices, id: \.identifier) { v in
                            Text("\(v.name)\(v.quality == .premium ? " (prémiový)" : v.quality == .enhanced ? " (vylepšený)" : "")").tag(v.identifier)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Rychlost řeči")
                        Slider(value: $ttsRate, in: 0.2...0.8)
                    }
                    Button("Vyzkoušet hlas") { app.speaker.speak("Dobrý den, jsem tvůj osobní asistent. Vše běží přímo v telefonu.") }
                } header: { Text("Hlas") } footer: {
                    Text("Čtení nahlas používá hlasy iOS uložené v telefonu. Kvalitnější český hlas stáhneš v Nastavení iOS → Zpřístupnění → Předčítání obsahu → Hlasy → Čeština.")
                }

                Section("Lokální AI") {
                    NavigationLink { ModelsView() } label: {
                        HStack {
                            Text("Modely")
                            Spacer()
                            stateText(ai.llmState)
                        }
                    }
                    NavigationLink("Test modelu (čeština a nástroje)") { BenchmarkView() }
                }

                Section("Data") {
                    NavigationLink("Šifrovaná záloha") { BackupView() }
                    NavigationLink("Koš") { TrashView() }
                    Button("Smazat všechna data…", role: .destructive) { confirmWipe = true }
                }

                Section("O aplikaci") {
                    LabeledContent("Verze", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                    NavigationLink("Licence a závislosti") { LicensesView() }
                }
            }
            .navigationTitle("Nastavení")
        }
        .onAppear {
            lockBackground = app.lockAfterBackground
            lockIdle = app.lockAfterIdle
            wipeAfter = KeyManager.config.wipeAfterFailures
            summary = notifications.summarySettings
        }
        .onChange(of: lockBackground) { _, v in app.lockAfterBackground = v }
        .onChange(of: lockIdle) { _, v in app.lockAfterIdle = v }
        .onChange(of: wipeAfter) { _, v in var c = KeyManager.config; c.wipeAfterFailures = v; KeyManager.config = c }
        .onChange(of: showContent) { _, _ in reschedule() }
        .onChange(of: summary.morningEnabled) { _, _ in saveSummary() }
        .onChange(of: summary.morningMinutes) { _, _ in saveSummary() }
        .onChange(of: summary.eveningEnabled) { _, _ in saveSummary() }
        .onChange(of: summary.eveningMinutes) { _, _ in saveSummary() }
        .confirmationDialog("Smazat všechna data?", isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Pokračovat", role: .destructive) { confirmWipe2 = true }
        } message: { Text("Zničí se šifrovací klíče a smaže databáze. Modely zůstanou.") }
        .alert("Opravdu nevratně smazat?", isPresented: $confirmWipe2) {
            Button("Smazat vše", role: .destructive) { app.wipeEverything() }
            Button("Zrušit", role: .cancel) {}
        } message: { Text("Bez zálohy už data nepůjde obnovit.") }
        .sheet(isPresented: $showChangePassword) { ChangePasswordView() }
    }

    private func stateText(_ s: AIService.State) -> some View {
        Group {
            switch s {
            case .none: Text("nenačten").foregroundStyle(.secondary)
            case .loading: ProgressView().controlSize(.small)
            case .ready(let n): Text(n).foregroundStyle(.secondary).lineLimit(1)
            case .failed: Text("chyba").foregroundStyle(.red)
            }
        }
        .font(.subheadline)
    }

    private func timePicker(_ label: String, minutes: Binding<Int>) -> some View {
        DatePicker(label, selection: Binding(
            get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date())! },
            set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0) }),
                   displayedComponents: .hourAndMinute)
    }

    private func saveSummary() {
        notifications.summarySettings = summary
        Task { await notifications.scheduleSummaries() }
    }

    private func reschedule() {
        guard let s = app.store else { return }
        Task { await notifications.reschedule(store: s, calendar: app.calendar) }
    }
}

struct ChangePasswordView: View {
    @EnvironmentObject var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new1 = ""
    @State private var new2 = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                SecureField("Současné nouzové heslo", text: $current)
                SecureField("Nové heslo (aspoň 10 znaků)", text: $new1)
                SecureField("Nové heslo znovu", text: $new2)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Nouzové heslo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložit") { Task { await save() } }
                        .disabled(working || !PasswordPolicy.isAcceptable(new1) || new1 != new2 || current.isEmpty)
                }
            }
        }
    }

    private func save() async {
        working = true
        defer { working = false }
        let cur = current, n = new1
        do {
            try await Task.detached {
                var key = try KeyManager.unlockWithRecovery(password: cur)
                defer { key.resetBytes(in: 0..<key.count) }
                try KeyManager.changeRecoveryPassword(currentKey: key, newPassword: n)
            }.value
            dismiss()
        } catch {
            self.error = "Současné heslo není správné."
        }
    }
}

struct SecurityStatusView: View {
    @EnvironmentObject var app: AppModel
    var body: some View {
        List {
            row("Šifrování databáze", Database.cipherVersionString.map { "SQLCipher \($0), AES-256" } ?? "NEAKTIVNÍ", ok: Database.cipherVersionString != nil)
            row("Klíč v Secure Enclave", KeyManager.secureEnclaveAvailable ? "ano, vázaný na \(KeyManager.biometryDescription)" : "nedostupné", ok: KeyManager.secureEnclaveAvailable)
            row("Kód zařízení", DeviceIntegrity.hasPasscode ? "nastaven" : "NENASTAVEN", ok: DeviceIntegrity.hasPasscode)
            row("Jailbreak", app.isJailbroken ? "zjištěny známky jailbreaku" : "nezjištěn", ok: !app.isJailbroken)
            row("Zálohy do iCloudu", "data vyloučena", ok: true)
            row("Síť", "aplikace neobsahuje síťový kód", ok: true)
            row("Analytika a telemetrie", "žádná", ok: true)
            row("Neúspěšné pokusy o odemčení", "\(KeyManager.failures)", ok: KeyManager.failures == 0)
            Section {
                Text("Snímky obrazovky iOS zakázat neumožňuje. Aplikace skrývá obsah v přepínači aplikací a při nahrávání či zrcadlení obrazovky a upozorní tě, když snímek pořídíš.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Stav zabezpečení")
    }

    private func row(_ title: String, _ value: String, ok: Bool) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.shield.fill" : "exclamationmark.triangle.fill").foregroundStyle(ok ? .green : .orange)
            VStack(alignment: .leading) {
                Text(title)
                Text(value).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            item("llama.cpp (b11440)", "MIT – lokální běh jazykových modelů")
            item("whisper.cpp (v1.9.2)", "MIT – offline přepis řeči")
            item("SQLCipher (4.19.0)", "BSD-3 – šifrovaná databáze")
            item("Argon2 (PHC reference)", "CC0 / Apache 2.0 – odvození klíče z hesla")
            item("Modely", "Licence podle zvoleného modelu (Qwen: Apache 2.0, Gemma: Gemma Terms of Use, Whisper: MIT)")
            Section {
                Text("Aplikace nepoužívá žádné další knihovny třetích stran, analytiku ani reklamy.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Licence")
    }
    private func item(_ t: String, _ d: String) -> some View {
        VStack(alignment: .leading) { Text(t); Text(d).font(.caption).foregroundStyle(.secondary) }
    }
}
