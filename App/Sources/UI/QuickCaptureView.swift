import SwiftUI
import AppIntents
import AgentCore

/// Rychlé zachycení: nadiktuj (nebo napiš) myšlenku, agent ji sám zařadí jako poznámku / úkol / připomínku.
struct QuickCaptureView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var recorder: AudioRecorder
    @EnvironmentObject var chat: ChatController
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var result: AgentReply?
    @State private var autoStarted = false
    @AppStorage("input.preferTyping") private var preferTyping = false
    @FocusState private var textFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let r = result {
                    resultView(r)
                } else {
                    Text("Řekni, co tě napadlo. Agent to sám zařadí.")
                        .font(.headline).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Spacer()
                    if chat.transcribing || chat.busy {
                        ProgressView(chat.transcribing ? "Přepisuji…" : "Zařazuji…")
                    } else {
                        Button {
                            Task { await toggleRecording() }
                        } label: {
                            ZStack {
                                Circle().fill(recorder.isRecording ? Color.red : Theme.accent)
                                    .frame(width: 120, height: 120)
                                    .scaleEffect(recorder.isRecording ? 1 + CGFloat(recorder.level) * 0.3 : 1)
                                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 44, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(recorder.isRecording ? "Zastavit a uložit" : "Začít diktovat")
                        Text(recorder.isRecording ? "Klepni pro uložení · \(Int(recorder.elapsed)) s" : "Klepni a mluv")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack {
                        TextField(preferTyping ? "Napiš myšlenku" : "…nebo napiš", text: $text)
                            .textFieldStyle(.roundedBorder)
                            .focused($textFocused)
                            .submitLabel(.done)
                            .onSubmit { Task { await sendText() } }
                        Button("Uložit") { Task { await sendText() } }
                            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || chat.busy)
                    }
                }
            }
            .padding(24)
            .navigationTitle("Rychlý záznam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result == nil ? "Zrušit" : "Hotovo") { recorder.cancel(); dismiss() }
                }
            }
            .animation(.easeOut(duration: 0.15), value: recorder.level)
        }
        .task {
            // Ze widgetu rovnou začneme nahrávat (nebo psát, když uživatel dává přednost psaní)
            if preferTyping || app.models.active(.speech) == nil {
                textFocused = true
            } else if !autoStarted {
                autoStarted = true
                try? await recorder.start()
            }
        }
    }

    private func resultView(_ r: AgentReply) -> some View {
        VStack(spacing: 16) {
            if r.actions.isEmpty {
                Text(r.text.isEmpty ? "Nic se neuložilo." : r.text).font(.body)
            } else {
                ForEach(r.actions) { a in ActionCardView(action: a) }
                if !r.text.isEmpty { Text(r.text).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            Button("Další záznam") {
                result = nil
                text = ""
            }
            .buttonStyle(.bordered)
        }
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            let samples = recorder.stop()
            result = await chat.transcribeAndSend(samples: samples, app: app, mode: .capture)
        } else {
            do { try await recorder.start() } catch { chat.error = (error as? LocalizedError)?.errorDescription }
        }
    }

    private func sendText() async {
        let t = text
        text = ""
        result = await chat.send(t, app: app, mode: .capture)
    }
}

// MARK: - Zkratka (Shortcuts / Klepnutí na zadní stranu / Siri)

struct QuickCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Rychlý záznam"
    static var description = IntentDescription("Otevře Osobního agenta a začne diktovat myšlenku.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Aplikace se otevře; po odemčení se zobrazí rychlý záznam.
        UserDefaults.standard.set(true, forKey: "pendingCapture")
        NotificationCenter.default.post(name: .quickCaptureRequested, object: nil)
        return .result()
    }
}

struct OsobniAgentShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: QuickCaptureIntent(),
                    phrases: ["Rychlý záznam v \(.applicationName)", "Zapiš myšlenku v \(.applicationName)"],
                    shortTitle: "Rychlý záznam",
                    systemImageName: "mic.badge.plus")
    }
}

extension Notification.Name {
    static let quickCaptureRequested = Notification.Name("oa.quickCapture")
}
