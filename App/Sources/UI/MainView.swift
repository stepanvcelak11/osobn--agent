import SwiftUI
import AgentCore

/// Stav konverzace sdílený mezi chatem a tlačítkem mikrofonu.
@MainActor
final class ChatController: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var actions: [String: ActionRecord] = [:]
    @Published var busy = false
    @Published var progressText: String?
    @Published var streaming = ""
    @Published var transcribing = false
    @Published var error: String?

    func reload(_ store: DataStore?) {
        guard let store else { messages = []; actions = [:]; return }
        messages = (try? store.recentMessages(limit: 200)) ?? []
        var map: [String: ActionRecord] = [:]
        for m in messages { if let id = m.actionId, let a = try? store.action(id: id) { map[id] = a } }
        actions = map
    }

    func send(_ text: String, app: AppModel, mode: AgentMode = .chat) async -> AgentReply? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return nil }
        busy = true
        streaming = ""
        progressText = nil
        // Zobraz zprávu uživatele hned
        messages.append(ChatMessage(role: .user, text: t))
        let reply = await app.send(t, mode: mode) { [weak self] p in
            Task { @MainActor in
                switch p {
                case .thinking(let s): self?.progressText = s
                case .partialAnswer(let s): self?.streaming = s
                }
            }
        }
        busy = false
        progressText = nil
        streaming = ""
        reload(app.store)
        return reply
    }

    /// Přepíše nahrávku a pošle ji agentovi.
    func transcribeAndSend(samples: [Float], app: AppModel, mode: AgentMode = .chat) async -> AgentReply? {
        guard samples.count > 16_000 / 2 else { error = SpeechError.tooShort.errorDescription; return nil }
        transcribing = true
        defer { transcribing = false }
        do {
            let w = try await app.ai.transcriber(for: app.models.active(.speech))
            let text = try await w.transcribe(samples: samples, initialPrompt: "Připomínka, úkol, poznámka. Zítra v osm.")
            guard !text.isEmpty else { error = "Nic nebylo slyšet – zkus to prosím znovu."; return nil }
            return await send(text, app: app, mode: mode)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            return nil
        }
    }
}

struct MainView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var recorder: AudioRecorder
    @EnvironmentObject var longRecorder: LongRecorder
    @StateObject private var chat = ChatController()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch app.tab {
                case .home: HomeView()
                case .data: DataView()
                case .chat: ChatView()
                case .settings: SettingsView()
                }
            }
            .environmentObject(chat)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 76) }

            BottomBar(chat: chat)

            if let t = app.toast {
                ToastView(toast: t) { id in app.undo(id); app.toast = nil }
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: t.id) {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        if app.toast?.id == t.id { withAnimation { app.toast = nil } }
                    }
            }
            if recorder.isRecording || chat.transcribing {
                RecordingOverlay(transcribing: chat.transcribing)
                    .padding(.bottom, 96)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: app.toast)
        .animation(.easeOut(duration: 0.15), value: recorder.isRecording)
        .sheet(isPresented: $app.showCapture) {
            QuickCaptureView().environmentObject(chat)
        }
        .sheet(isPresented: $app.showRecording) { RecordingView() }
        .sheet(isPresented: $app.showClock) { NavigationStack { ClockView() } }
        .overlay(alignment: .top) {
            if longRecorder.isActive && !app.showRecording {
                Button { app.showRecording = true } label: {
                    HStack(spacing: 8) {
                        Circle().fill(longRecorder.state == .recording ? Color.red : Color.orange).frame(width: 9, height: 9)
                        Text(longRecorder.state == .recording ? "Nahrává se \(CzechDuration.clock(longRecorder.elapsed))" : "Nahrávání pozastaveno")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .alert("Chyba", isPresented: Binding(get: { chat.error != nil }, set: { if !$0 { chat.error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(chat.error ?? "") }
    }
}

/// Spodní lišta ovládaná palcem: Přehled · Data · [mikrofon] · Chat · Nastavení
struct BottomBar: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var chat: ChatController

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(.home, "Přehled", "sun.max")
            tabButton(.data, "Data", "tray.full")
            MicButton(chat: chat)
                .frame(maxWidth: .infinity)
                .offset(y: -10)
            tabButton(.chat, "Chat", "bubble.left.and.bubble.right")
            tabButton(.settings, "Nastavení", "gearshape")
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func tabButton(_ tab: AppTab, _ title: String, _ icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { app.tab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: app.tab == tab ? icon + ".fill" : icon).font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(app.tab == tab ? Theme.accent : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(app.tab == tab ? .isSelected : [])
    }
}

/// Velké tlačítko: podržet = diktovat (puštěním se odešle), klepnout = psát.
struct MicButton: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var recorder: AudioRecorder
    @AppStorage("input.preferTyping") private var preferTyping = false
    @ObservedObject var chat: ChatController
    var mode: AgentMode = .chat
    var size: CGFloat = 66
    @State private var pressing = false
    @State private var cancelled = false
    @State private var pressStart: Date?

    var body: some View {
        ZStack {
            Circle()
                .fill(recorder.isRecording ? Color.red : Theme.accent)
                .frame(width: size, height: size)
                .scaleEffect(recorder.isRecording ? 1.08 + CGFloat(recorder.level) * 0.25 : 1)
                .shadow(color: (recorder.isRecording ? Color.red : Theme.accent).opacity(0.35), radius: 12, y: 4)
            if chat.busy || chat.transcribing {
                ProgressView().tint(.white)
            } else {
                Image(systemName: recorder.isRecording ? "waveform" : (preferTyping && mode == .chat ? "keyboard" : "mic.fill"))
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeOut(duration: 0.1), value: recorder.level)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if !pressing {
                        pressing = true
                        cancelled = false
                        pressStart = Date()
                        // Krátké klepnutí = psaní; nahrávání začne po 0,25 s držení
                        Task {
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            if pressing && !recorder.isRecording && !chat.busy {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                do { try await recorder.start() } catch { chat.error = (error as? LocalizedError)?.errorDescription }
                            }
                        }
                    }
                    if v.translation.height < -80 { cancelled = true }
                }
                .onEnded { _ in
                    pressing = false
                    let held = Date().timeIntervalSince(pressStart ?? Date())
                    if recorder.isRecording {
                        let samples = recorder.stop()
                        if cancelled { return }
                        if mode == .chat { app.tab = .chat }
                        Task { _ = await chat.transcribeAndSend(samples: samples, app: app, mode: mode) }
                    } else if held < 0.25 && mode == .chat {
                        app.tab = .chat
                        NotificationCenter.default.post(name: .focusChatInput, object: nil)
                    }
                }
        )
        .accessibilityLabel(preferTyping ? "Napsat agentovi" : "Mluvit s agentem")
        .accessibilityHint("Klepnutím otevřeš psaní. Podrž a mluv, pusť pro odeslání.")
        .accessibilityAddTraits(.isButton)
    }
}

struct RecordingOverlay: View {
    @EnvironmentObject var recorder: AudioRecorder
    var transcribing: Bool
    var body: some View {
        HStack(spacing: 12) {
            if transcribing {
                ProgressView()
                Text("Přepisuji řeč…").font(.subheadline)
            } else {
                Circle().fill(.red).frame(width: 10, height: 10)
                Text("Poslouchám… \(Int(recorder.elapsed)) s").font(.subheadline.monospacedDigit())
                Text("· tažením nahoru zrušíš").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.thinMaterial, in: Capsule())
    }
}

extension Notification.Name {
    static let focusChatInput = Notification.Name("oa.focusChatInput")
}
