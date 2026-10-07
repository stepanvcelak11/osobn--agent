import SwiftUI
import AVFoundation
import RealmCore

struct SettingsView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var ai: AIService
    @EnvironmentObject var speaker: Speaker
    @EnvironmentObject var downloader: ModelDownloader
    @EnvironmentObject var models: ModelManager
    @AppStorage("tts.enabled") private var ttsEnabled = false
    @AppStorage("tts.rate") private var ttsRate = 0.5
    @AppStorage("tts.voice") private var ttsVoice = ""
    @AppStorage("fx.haptics") private var haptics = true
    @AppStorage(TextSize.key) private var textScale = 1.0
    @AppStorage("voice.autoDownload") private var voiceDownload = true
    @AppStorage(OnlineSettings.enabledKey) private var onlineOn = false
    @AppStorage(OnlineSettings.providerKey) private var providerRaw = RemoteProvider.gemini.rawValue
    @AppStorage(OnlineSettings.modelKey) private var model = ""
    @State private var apiKey = ""
    @State private var testResult: String?
    @State private var testing = false
    @State private var confirmDelete = false

    private var provider: RemoteProvider { RemoteProvider(rawValue: providerRaw) ?? .gemini }

    var body: some View {
        Form {
            onlineSection

            Section("Čitelnost") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Velikost písma příběhu").font(.footnote)
                    Slider(value: $textScale, in: 0.85...1.4, step: 0.05)
                    Text("Mlha houstne a z ní vystupuje postava v kápi.")
                        .font(TextSize.narration(textScale))
                        .foregroundStyle(Theme.parchment)
                }
                Toggle("Haptická odezva", isOn: $haptics)
            }

            Section {
                Toggle("Vypravěč čte nahlas", isOn: $ttsEnabled)
                if ttsEnabled {
                    Picker("Hlas", selection: $ttsVoice) {
                        Text("Výchozí český").tag("")
                        ForEach(Speaker.czechVoices, id: \.identifier) { v in Text(v.name).tag(v.identifier) }
                    }
                    Slider(value: $ttsRate, in: 0.3...0.65)
                    Button("Vyzkoušet hlas") { speaker.speak("Mlha se zvedá z bažin a v dálce zavyl vlk.") }
                }
                Toggle("Hlasové ovládání (stáhnout ~550 MB)", isOn: $voiceDownload)
                    .onChange(of: voiceDownload) { _, on in if on { downloader.startIfNeeded(models: models) } }
            } header: { Text("Hlas") } footer: {
                Text("Předčítání používá hlasy iOS. Hlasové ovládání přepisuje řeč přímo v telefonu.")
            }

            Section {
                NavigationLink("Modely v telefonu") { ModelsView() }
                Button("Smazat všechny uložené hry", role: .destructive) { confirmDelete = true }
            }

            Section("O hře") {
                LabeledContent("Verze", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                Text("Hra běží offline: vypravěč se jednou stáhne z Hugging Face (ověřeno SHA-256) a pak vše běží v telefonu. Online vypravěč je nepovinný – jen když ho zapneš, posílá se text příběhu zvolené službě (Anthropic nebo Google). Žádné účty, analytika ani reklamy. Hry se ukládají jen v telefonu.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg0)
        .navigationTitle("Nastavení")
        .onAppear { apiKey = OnlineSettings.apiKey(provider) }
        .alert("Smazat všechny hry?", isPresented: $confirmDelete) {
            Button("Smazat", role: .destructive) { app.deleteAllSaves() }
            Button("Zrušit", role: .cancel) {}
        } message: { Text("Tohle nejde vrátit.") }
    }

    private var onlineSection: some View {
        Section {
            Toggle("Online vypravěč", isOn: $onlineOn)
            if onlineOn {
                Picker("Služba", selection: $providerRaw) {
                    ForEach(RemoteProvider.allCases) { Text($0.displayName).tag($0.rawValue) }
                }
                .onChange(of: providerRaw) { _, _ in
                    model = ""
                    apiKey = OnlineSettings.apiKey(provider)
                    testResult = nil
                }
                Picker("Model", selection: Binding(get: { model.isEmpty ? provider.defaultModel : model }, set: { model = $0 })) {
                    ForEach(provider.models) { Text($0.label).tag($0.id) }
                }
                SecureField("API klíč", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: apiKey) { _, v in OnlineSettings.setApiKey(v, for: provider); testResult = nil }
                if let u = URL(string: provider.keyURL) { Link("Kde získám klíč?", destination: u) }
                Button {
                    testing = true
                    testResult = nil
                    Task {
                        if let cfg = OnlineSettings.config {
                            testResult = await RemoteChatModel(config: cfg).test() ?? "✓ Funguje"
                        } else {
                            testResult = "Chybí klíč."
                        }
                        testing = false
                    }
                } label: {
                    HStack { Text("Vyzkoušet spojení"); if testing { Spacer(); ProgressView() } }
                }
                .disabled(apiKey.isEmpty || testing)
                if let t = testResult {
                    Text(t).font(.footnote).foregroundStyle(t.hasPrefix("✓") ? Theme.good : Theme.blood)
                }
            }
        } header: { Text("Lepší vypravěč online (nepovinné)") } footer: {
            Text(onlineOn ? provider.keyHint + " Klíč je uložený jen v tomto telefonu (Klíčenka). Když není signál nebo služba neodpoví, vypráví hned vypravěč v telefonu."
                          : "Hra je plně hratelná offline. Online vypravěč (Claude nebo Gemini) vypráví lépe a rychleji, ale potřebuje internet a vlastní klíč.")
        }
    }
}
