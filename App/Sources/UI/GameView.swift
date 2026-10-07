import SwiftUI
import UIKit
import RealmCore

struct GameView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var models: ModelManager
    @EnvironmentObject var ai: AIService
    @EnvironmentObject var speaker: Speaker
    @ObservedObject var session: GameSession
    @State private var input = ""
    @State private var sheet: SheetKind?
    @State private var showMenu = false
    @State private var confirmAbandon = false
    @State private var showGameOver = true
    @FocusState private var inputFocused: Bool
    @AppStorage("tts.enabled") private var ttsEnabled = false

    enum SheetKind: String, Identifiable {
        case inventory, chronicle, settlement, achievements, help, world, memory
        var id: String { rawValue }
    }

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var state: GameState { session.state }

    private var dangerIntensity: Double {
        let hp = state.hero.hp < 25 ? Double(25 - state.hero.hp) / 25 : 0
        let st = state.hero.stress >= 70 ? Double(state.hero.stress - 60) / 40 : 0
        return min(1, max(hp, st))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                gameContent
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background {
            ZStack {
                SceneBackdrop(scene: state.scene, phase: state.phase, weather: state.weather)
                DangerVignette(intensity: dangerIntensity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.diceOverlay)
        .animation(.easeInOut(duration: 0.6), value: state.isOver)
        .confirmationDialog("Menu", isPresented: $showMenu, titleVisibility: .hidden) { menuButtons }
        .alert("Ukončit hru?", isPresented: $confirmAbandon) {
            Button("Ukončit a napsat epilog", role: .destructive) { session.abandon() }
            Button("Pokračovat ve hře", role: .cancel) {}
        } message: { Text("Hra skončí a vypravěč napíše epilog. Uložená kronika zůstane.") }
        .sheet(item: $sheet) { kind in sheetView(kind) }
        .onReceive(minuteTimer) { _ in session.refreshSimulation() }
        .onAppear {
            session.refreshSimulation()
            #if DEBUG
            if let s = Demo.sheet { sheet = SheetKind(rawValue: s) }
            #endif
        }
    }

    @ViewBuilder private var gameContent: some View {
            VStack(spacing: 8) {
                DashboardView(state: state, onMenu: { showMenu = true },
                              onSettlement: { sheet = state.mode == .quest ? .inventory : .settlement },
                              onHero: { sheet = .inventory }, onWorld: { sheet = .world })
                story
                if !state.isOver {
                    InputBar(session: session, input: $input, focused: $inputFocused)
                } else if !showGameOver {
                    Button("Zobrazit konec") { showGameOver = true }.buttonStyle(EmberButtonStyle()).padding(.horizontal, 20)
                }
            }
            if let roll = session.diceOverlay {
                DiceOverlay(roll: roll) { withAnimation { session.diceOverlay = nil } }
                    .transition(.opacity)
                    .zIndex(5)
            }
            if state.isOver && showGameOver {
                GameOverView(session: session, onClose: { showGameOver = false })
                    .transition(.opacity)
                    .zIndex(6)
            }
            overlays
    }

    // MARK: Příběh

    private var story: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(rows, id: \.entry.id) { row in
                        if let d = row.newDay { DayDivider(day: d) }
                        LogEntryView(entry: row.entry, paranoid: state.hero.stress >= 70 && row.entry.kind == .narration)
                            .id(row.entry.id)
                            .contextMenu { entryMenu(row.entry) }
                    }
                    if let p = session.pendingAction {
                        LogEntryView(entry: { var e = LogEntry(kind: .player, text: p); e.input = session.pendingMode == .act ? nil : session.pendingMode; return e }()).id("pending")
                    }
                    if !session.isBusy && session.canRetry && !state.isOver { turnTools }
                    if let b = session.busy, b != .epilogue {
                        StreamingNarration(busy: b, text: session.streamingText, roll: session.liveRoll).id("stream")
                    }
                    Color.clear.frame(height: 6).id("bottom")
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: state.log.count) { _, _ in scrollDown(proxy) }
            .onChange(of: session.streamingText) { _, _ in scrollDown(proxy, animated: false) }
            .onChange(of: session.pendingAction) { _, _ in scrollDown(proxy) }
            .onChange(of: inputFocused) { _, f in if f { scrollDown(proxy) } }
            .onAppear { scrollDown(proxy, animated: false) }
        }
    }

    /// Záznamy deníku s vyznačeným začátkem nového dne.
    private var rows: [(entry: LogEntry, newDay: Int?)] {
        var lastDay = state.log.first(where: { $0.day != nil })?.day ?? 1
        return state.log.map { e in
            guard e.kind == .player, let d = e.day, d > lastDay else { return (e, nil) }
            lastDay = d
            return (e, d)
        }
    }

    /// „Znovu“ a „Vrátit“ pod posledním vyprávěním (jako v AI Dungeon).
    private var turnTools: some View {
        HStack(spacing: 10) {
            Spacer()
            Button { session.retry() } label: { Label("Znovu", systemImage: "arrow.triangle.2.circlepath") }
                .accessibilityHint("Vypravěč převypráví poslední tah. Hod kostkou zůstane stejný.")
            Button { session.undo() } label: { Label("Vrátit tah", systemImage: "arrow.uturn.backward") }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Theme.dimText)
        .buttonStyle(.plain)
        .padding(.top, -8)
    }

    @ViewBuilder private func entryMenu(_ e: LogEntry) -> some View {
        Button { UIPasteboard.general.string = e.text } label: { Label("Kopírovat", systemImage: "doc.on.doc") }
        if e.kind == .narration, e.id == state.log.last(where: { $0.kind == .narration })?.id, session.canRetry {
            Button { session.retry() } label: { Label("Převyprávět (stejný hod)", systemImage: "arrow.triangle.2.circlepath") }
            Button(role: .destructive) { session.undo() } label: { Label("Vrátit tah", systemImage: "arrow.uturn.backward") }
        }
        if e.kind == .narration {
            Button { speaker.speak(e.text) } label: { Label("Přečíst nahlas", systemImage: "speaker.wave.2") }
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated { withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("bottom", anchor: .bottom) } }
        else { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    // MARK: Překryvy (toast, úspěch, chyba)

    @ViewBuilder private var overlays: some View {
        VStack {
            if let a = session.achievement {
                AchievementToast(achievement: a)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 3_500_000_000)
                        withAnimation { session.achievement = nil }
                    }
            }
            if let t = session.toast {
                Text(t).font(.footnote).foregroundStyle(Theme.parchment)
                    .padding(.horizontal, 14).padding(.vertical, 10).panel(14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation { session.toast = nil }
                    }
            }
            if let e = session.error {
                Text(e).font(.footnote).foregroundStyle(.white)
                    .padding(12).background(Theme.blood.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { session.error = nil }
                    .transition(.opacity)
            }
            Spacer()
        }
        .padding(.top, 4)
        .padding(.horizontal, 20)
        .animation(.spring(duration: 0.4), value: session.achievement)
        .animation(.spring(duration: 0.4), value: session.toast)
        .zIndex(10)
    }

    // MARK: Menu a listy

    @ViewBuilder private var menuButtons: some View {
        Button("🎒 Hrdina a inventář") { sheet = .inventory }
        Button("🌦️ Svět, postavy, zakázky") { sheet = .world }
        Button("🧠 Paměť vypravěče") { sheet = .memory }
        if state.mode != .quest { Button(state.mode.hasSettlement ? "🏰 Osada a stavby" : "🐎 Karavana a cesta") { sheet = .settlement } }
        Button("📜 Kronika") { sheet = .chronicle }
        Button("🏆 Úspěchy") { sheet = .achievements }
        Button("❓ Jak hrát") { sheet = .help }
        Button(ttsEnabled ? "🔇 Vypravěč potichu" : "🔊 Vypravěč nahlas") {
            ttsEnabled.toggle()
            if !ttsEnabled { speaker.stop() }
        }
        if !state.isOver { Button("Ukončit hru…", role: .destructive) { confirmAbandon = true } }
        Button("Zpět na titulní obrazovku") { app.closeSession() }
        Button("Zavřít", role: .cancel) {}
    }

    @ViewBuilder private func sheetView(_ kind: SheetKind) -> some View {
        switch kind {
        case .inventory:
            InventorySheet(hero: state.hero, now: state.worldTime) { item in
                sheet = nil
                input = input.isEmpty ? "Použiju \(item.name) a " : input + " (\(item.name))"
                inputFocused = true
            }
        case .chronicle: ChronicleSheet(state: state)
        case .settlement: SettlementSheet(state: state) { text in
            sheet = nil
            input = text
            inputFocused = true
        }
        case .achievements: AchievementsView(unlocked: Set(state.achievements))
        case .help: HelpView()
        case .world: WorldSheet(state: state)
        case .memory: MemorySheet(state: state) { m, n in session.setMemory(m, note: n) }
        }
    }
}

/// Spodní lišta: předměty, volný text, diktování.
struct InputBar: View {
    @EnvironmentObject var models: ModelManager
    @EnvironmentObject var ai: AIService
    @ObservedObject var session: GameSession
    @Binding var input: String
    var focused: FocusState<Bool>.Binding
    @StateObject private var recorder = AudioRecorder()
    @State private var transcribing = false
    @State private var micError: String?
    @AppStorage("input.mode") private var modeRaw = InputMode.act.rawValue
    private var mode: InputMode { InputMode(rawValue: modeRaw) ?? .act }

    var body: some View {
        VStack(spacing: 8) {
            if !session.state.hero.items.isEmpty && !session.isBusy { itemChips }
            HStack(alignment: .bottom, spacing: 8) {
                modePicker
                TextField("", text: $input, prompt: Text(placeholder).foregroundColor(Theme.dimText), axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .lineLimit(1...5)
                    .focused(focused)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(focused.wrappedValue ? Theme.ember.opacity(0.6) : Theme.stroke))
                    .disabled(session.isBusy || recorder.isRecording)
                if models.active(.speech) != nil && input.isEmpty && !session.isBusy { micButton }
                actionButton
            }
            if let micError { Text(micError).font(.caption2).foregroundStyle(Theme.blood) }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var placeholder: String {
        if recorder.isRecording { return "Poslouchám… (klepni znovu pro konec)" }
        if transcribing { return "Přepisuji řeč…" }
        return mode.placeholder
    }

    /// Čin / Řeč / Příběh – jak bude tah zadán (jako v AI Dungeon).
    private var modePicker: some View {
        Menu {
            ForEach([InputMode.act, .say, .story], id: \.self) { m in
                Button { modeRaw = m.rawValue; Haptics.impact(.light) } label: {
                    Label(modeTitle(m), systemImage: m.icon)
                }
            }
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(mode == .act ? Theme.parchment : Theme.ember)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(mode == .act ? Theme.stroke : Theme.ember.opacity(0.5)))
        }
        .disabled(session.isBusy)
        .accessibilityLabel("Způsob tahu: \(mode.czechName)")
    }

    private func modeTitle(_ m: InputMode) -> String {
        switch m {
        case .act: return "Čin – co uděláš"
        case .say: return "Řeč – co řekneš"
        case .story: return "Příběh – co se stane"
        case .proceed: return "Pokračuj"
        }
    }

    private var itemChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("🎒").font(.caption)
                ForEach(session.state.hero.items) { item in
                    Button {
                        input = input.isEmpty ? "Použiju \(item.name) a " : input + " (\(item.name))"
                        focused.wrappedValue = true
                    } label: {
                        Label(item.label, systemImage: item.kind.icon)
                            .font(.caption)
                            .foregroundStyle(Theme.parchment)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(Theme.stroke))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var micButton: some View {
        Button { Task { await toggleMic() } } label: {
            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                .font(.headline)
                .foregroundStyle(recorder.isRecording ? .white : Theme.parchment)
                .frame(width: 44, height: 44)
                .background(recorder.isRecording ? Theme.blood : Color.white.opacity(0.1), in: Circle())
                .scaleEffect(recorder.isRecording ? 1 + CGFloat(recorder.level) * 0.25 : 1)
        }
        .disabled(transcribing)
        .accessibilityLabel(recorder.isRecording ? "Ukončit diktování" : "Diktovat tah")
    }

    @ViewBuilder private var actionButton: some View {
        if session.isBusy {
            Button { session.cancel() } label: {
                Image(systemName: "stop.circle.fill").font(.system(size: 40)).foregroundStyle(Theme.dimText)
            }
            .accessibilityLabel("Zrušit tah")
            .disabled(session.busy == .intro || session.busy == .epilogue)
        } else if input.trimmingCharacters(in: .whitespaces).isEmpty {
            // Prázdné pole = „Pokračuj“: vypravěč vypráví dál a svět jedná sám.
            Button {
                focused.wrappedValue = false
                session.send("", mode: .proceed)
            } label: {
                Image(systemName: "forward.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.parchment.opacity(0.55))
            }
            .accessibilityLabel("Pokračuj v příběhu")
        } else {
            Button {
                let t = input
                input = ""
                focused.wrappedValue = false
                session.send(t, mode: mode)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.ember)
                    .shadow(color: Theme.ember.opacity(0.6), radius: 8)
            }
            .accessibilityLabel("Odeslat tah")
        }
    }

    private func toggleMic() async {
        micError = nil
        if recorder.isRecording {
            let samples = recorder.stop()
            guard samples.count > 16_000 / 2 else { micError = SpeechError.tooShort.localizedDescription; return }
            transcribing = true
            defer { transcribing = false }
            do {
                let w = try await ai.transcriber(for: models.active(.speech))
                let text = try await w.transcribe(samples: samples, language: "cs", initialPrompt: "Hrdina tasí meč a vstoupí do kobky.")
                input = text.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                micError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            }
        } else {
            do { try await recorder.start() } catch { micError = (error as? LocalizedError)?.errorDescription ?? "\(error)" }
        }
    }
}

struct AchievementToast: View {
    let achievement: Achievement
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon).font(.title2).foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.id == "level" ? "Nová úroveň" : "Úspěch odemčen").font(.caption2).foregroundStyle(Theme.gold)
                Text(achievement.title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment)
            }
            Spacer()
        }
        .padding(12)
        .panel(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold.opacity(0.5)))
        .shadow(color: Theme.gold.opacity(0.3), radius: 14)
    }
}
