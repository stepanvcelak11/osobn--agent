import SwiftUI
import AVFoundation
import RealmCore

struct SettingsView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var speaker: Speaker
    @AppStorage("tts.enabled") private var ttsEnabled = false
    @AppStorage("tts.rate") private var ttsRate = 0.5
    @AppStorage("tts.voice") private var ttsVoice = ""
    @AppStorage("fx.haptics") private var haptics = true
    @AppStorage("fx.embers") private var embers = true
    @AppStorage("notify.realm") private var notify = true
    @AppStorage("text.scale") private var textScale = 1.0
    @AppStorage("voice.autoDownload") private var voiceDownload = true
    @EnvironmentObject var downloader: ModelDownloader
    @EnvironmentObject var models: ModelManager
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section {
                Toggle("Vypravěč čte nahlas", isOn: $ttsEnabled)
                if ttsEnabled {
                    Picker("Hlas", selection: $ttsVoice) {
                        Text("Výchozí český").tag("")
                        ForEach(Speaker.czechVoices, id: \.identifier) { v in Text(v.name).tag(v.identifier) }
                    }
                    VStack(alignment: .leading) {
                        Text("Rychlost řeči").font(.caption)
                        Slider(value: $ttsRate, in: 0.3...0.65)
                    }
                    Button("Vyzkoušet hlas") { speaker.speak("Mlha se zvedá z bažin a v dálce zavyl vlk. Co uděláš?") }
                }
            } header: { Text("Hlas") } footer: {
                Text("Používá systémovou syntézu řeči v telefonu. Lepší české hlasy stáhneš v Nastavení iOS → Zpřístupnění → Předčítání obsahu → Hlasy.")
            }

            Section("Vzhled a pocit") {
                VStack(alignment: .leading) {
                    Text("Velikost písma příběhu").font(.caption)
                    Slider(value: $textScale, in: 0.85...1.35, step: 0.05)
                    Text("Mlha houstne a z ní vystupuje postava v kápi.")
                        .font(.system(size: 17 * textScale, design: .serif))
                        .foregroundStyle(Theme.parchment)
                }
                Toggle("Žhavé jiskry v pozadí", isOn: $embers)
                Toggle("Haptická odezva", isOn: $haptics)
            }

            Section {
                Toggle("Hlasové ovládání (stáhnout ~550 MB)", isOn: $voiceDownload)
                    .onChange(of: voiceDownload) { _, on in if on { downloader.startIfNeeded(models: models) } }
            } footer: {
                Text("Tahy pak můžeš říkat nahlas – řeč se přepisuje přímo v telefonu.")
            }

            Section {
                Toggle("Oznámení z osady", isOn: $notify)
            } footer: {
                Text("Hrozba 2 hodiny před útokem, dokončená stavba a nový den (Vláda nad osadou a Nekonečná říše). Oznámení vznikají jen v telefonu.")
            }

            Section {
                Button("Smazat všechny uložené hry", role: .destructive) { confirmDelete = true }
            }

            Section("O hře") {
                LabeledContent("Verze", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                Text("Pocket Realm se k internetu připojí jen jednou – ke stažení vypravěče (a hlasového ovládání) z Hugging Face; soubory se ověří kontrolním součtem SHA-256. Pak běží 100 % offline. Žádné účty, analytika ani reklamy. Hry se ukládají jen v telefonu a nezálohují se do iCloudu.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg0)
        .navigationTitle("Nastavení")
        .alert("Smazat všechny hry?", isPresented: $confirmDelete) {
            Button("Smazat", role: .destructive) { app.deleteAllSaves() }
            Button("Zrušit", role: .cancel) {}
        } message: { Text("Tohle nejde vrátit.") }
    }
}
