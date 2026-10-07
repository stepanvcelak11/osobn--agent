import SwiftUI
import UIKit
import RealmCore

struct GameView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var ai: AIService
    @ObservedObject var session: GameSession
    @State private var input = ""
    @FocusState private var inputFocused: Bool
    @State private var sheet: SheetKind?
    @State private var showMenu = false
    @State private var confirmAbandon = false
    @AppStorage(TextSize.key) private var textScale = 1.0

    enum SheetKind: String, Identifiable { case story, memory, help; var id: String { rawValue } }

    private var story: Story { session.story }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.stroke)
            log
            if !story.isOver {
                InputBar(session: session, input: $input, focused: $inputFocused)
            }
        }
        .background(Theme.bg0)
        .overlay(alignment: .top) { toastView }
        .confirmationDialog("Menu", isPresented: $showMenu, titleVisibility: .hidden) {
            Button("Zpět do menu") { app.closeSession() }
            Button("Postava a cíl") { sheet = .story }
            Button("Paměť vypravěče") { sheet = .memory }
            Button("Jak hrát") { sheet = .help }
            if !story.isOver { Button("Ukončit příběh", role: .destructive) { confirmAbandon = true } }
            Button("Zrušit", role: .cancel) {}
        }
        .alert("Ukončit příběh?", isPresented: $confirmAbandon) {
            Button("Ukončit", role: .destructive) { session.abandon() }
            Button("Hrát dál", role: .cancel) {}
        } message: { Text("Vypravěč napíše závěr a hra skončí.") }
        .sheet(item: $sheet) { k in
            switch k {
            case .story: StorySheet(story: story)
            case .memory: MemorySheet(story: story) { session.setMemory($0, note: $1) }
            case .help: HelpView()
            }
        }
        .onAppear {
            #if DEBUG
            if let s = Demo.sheet { sheet = SheetKind(rawValue: s) }
            #endif
        }
    }

    // MARK: Hlavička

    private var header: some View {
        HStack(spacing: 12) {
            Button { showMenu = true } label: {
                Image(systemName: "line.3.horizontal").font(.title3).foregroundStyle(Theme.parchment)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Menu")
            Button { sheet = .story } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(story.title).font(.system(.headline, design: .serif)).foregroundStyle(Theme.parchment).lineLimit(1)
                    HStack(spacing: 10) {
                        Label(story.hero.name, systemImage: story.hero.heroClass.icon)
                        progress
                        if ai.lastTurnOnline { Image(systemName: "cloud").accessibilityLabel("Vypráví online vypravěč") }
                    }
                    .font(.caption).foregroundStyle(Theme.dimText)
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    /// Postup k cíli a nezdary – jen tečky, žádná čísla statistik.
    private var progress: some View {
        HStack(spacing: 8) {
            if story.mode == .endless {
                Text("✦ \(story.completedStages)")
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<story.stages.count, id: \.self) { i in
                        Circle().fill(i < story.completedStages ? Theme.ember : Theme.bg2).frame(width: 7, height: 7)
                    }
                }
                .accessibilityLabel("Postup \(story.completedStages) z \(story.stages.count)")
            }
            if story.setbacks > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<story.maxSetbacks, id: \.self) { i in
                        Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            .foregroundStyle(i < story.setbacks ? Theme.blood : Theme.bg2)
                    }
                }
                .accessibilityLabel("Nezdary \(story.setbacks) z \(story.maxSetbacks)")
            }
        }
    }

    // MARK: Deník

    private var log: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(story.log) { e in
                        EntryView(entry: e, scale: textScale).id(e.id)
                    }
                    if let p = session.pendingAction {
                        EntryView(entry: Entry(kind: .player, text: p, input: session.pendingMode, roll: session.liveRoll), scale: textScale)
                    }
                    if let b = session.busy, b != .epilogue {
                        StreamingView(label: b.label, text: session.streamingText, scale: textScale)
                    }
                    if !session.isBusy && session.canRetry && !story.isOver { turnTools }
                    if let err = session.error {
                        Text(err).font(.footnote).foregroundStyle(Theme.blood)
                    }
                    if story.isOver { ending }
                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: story.log.count) { _, _ in scrollDown(proxy) }
            .onChange(of: session.streamingText) { _, _ in scrollDown(proxy) }
            .onChange(of: session.pendingAction) { _, _ in scrollDown(proxy) }
            .onChange(of: inputFocused) { _, f in if f { scrollDown(proxy) } }
            .onAppear { scrollDown(proxy) }
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy) { proxy.scrollTo("bottom", anchor: .bottom) }

    private var turnTools: some View {
        HStack(spacing: 10) {
            Button { session.retry() } label: { Label("Znovu", systemImage: "arrow.clockwise") }
            Button { session.undo() } label: { Label("Vrátit tah", systemImage: "arrow.uturn.backward") }
        }
        .font(.footnote)
        .buttonStyle(.bordered)
        .tint(Theme.dimText)
    }

    // MARK: Konec

    private var ending: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(story.end?.czechName ?? "Konec")
                .font(Theme.title(24))
                .foregroundStyle(story.end == .victory ? Theme.gold : (story.end == .defeat ? Theme.blood : Theme.parchment))
            if let ep = story.epilogue {
                Text(ep).font(TextSize.narration(textScale)).italic().foregroundStyle(Theme.parchment).lineSpacing(5)
            } else if session.busy == .epilogue {
                StreamingView(label: GameSession.Busy.epilogue.label, text: session.streamingText, scale: textScale)
            }
            Text("\(story.hero.name) · \(story.hero.className) · \(story.turns) tahů")
                .font(.footnote).foregroundStyle(Theme.dimText)
            Button("Zpět do menu") { app.closeSession() }.buttonStyle(EmberButtonStyle())
        }
        .padding(16)
        .panel()
    }

    @ViewBuilder private var toastView: some View {
        if let t = session.toast {
            Text(t)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.parchment)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.bg2, in: Capsule())
                .padding(.top, 56)
                .task(id: t) {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    session.toast = nil
                }
        }
    }
}

/// Jeden záznam deníku.
struct EntryView: View {
    let entry: Entry
    let scale: Double

    var body: some View {
        switch entry.kind {
        case .narration:
            Text(entry.text)
                .font(TextSize.narration(scale))
                .foregroundStyle(Theme.parchment)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        case .player:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: (entry.input ?? .act).icon).font(.footnote)
                    Text(entry.input == .say ? "„\(entry.text)“" : entry.text)
                        .font(.system(size: 17 * scale, design: .serif)).italic()
                }
                .foregroundStyle(Theme.ember)
                if let r = entry.roll { RollBadge(roll: r) }
            }
            .padding(.leading, 10)
            .overlay(alignment: .leading) { Rectangle().fill(Theme.ember.opacity(0.5)).frame(width: 2) }
        case .event:
            Text(entry.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(entry.text.hasPrefix("✖") ? Theme.blood : Theme.gold)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Výsledek hodu: vlastnost, čísla a výsledek.
struct RollBadge: View {
    let roll: Roll
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "dice")
            Text("\(roll.attribute.czechName): \(roll.die) \(roll.bonus >= 0 ? "+" : "−") \(abs(roll.bonus)) = \(roll.total)")
            Text("· \(roll.outcome.czechName)").fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(Theme.color(roll.outcome))
        .accessibilityElement(children: .combine)
    }
}

/// Rozepsané vyprávění, nebo čekání s počítadlem sekund.
struct StreamingView: View {
    let label: String
    let text: String
    let scale: Double
    @State private var started = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !text.isEmpty {
                Text(text).font(TextSize.narration(scale)).foregroundStyle(Theme.parchment).lineSpacing(6)
            }
            HStack(spacing: 8) {
                ProgressView().tint(Theme.ember)
                Text(label).font(.footnote).foregroundStyle(Theme.dimText)
                TimelineView(.periodic(from: started, by: 1)) { tl in
                    Text("\(Int(tl.date.timeIntervalSince(started))) s").font(.caption.monospacedDigit()).foregroundStyle(Theme.dimText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { started = Date() }
    }
}

/// Spodní lišta: způsob tahu, text, diktování, odeslání / Pokračuj.
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
        VStack(spacing: 6) {
            Picker("Způsob tahu", selection: $modeRaw) {
                ForEach([InputMode.act, .say, .story], id: \.self) { m in Text(m.czechName).tag(m.rawValue) }
            }
            .pickerStyle(.segmented)
            .disabled(session.isBusy)
            HStack(alignment: .bottom, spacing: 8) {
                TextField("", text: $input, prompt: Text(placeholder).foregroundColor(Theme.dimText), axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.parchment)
                    .lineLimit(1...5)
                    .focused(focused)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Theme.bg1, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.stroke))
                    .disabled(session.isBusy || recorder.isRecording)
                if models.active(.speech) != nil && input.isEmpty && !session.isBusy { micButton }
                actionButton
            }
            if let micError { Text(micError).font(.caption).foregroundStyle(Theme.blood) }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Theme.bg0)
    }

    private var placeholder: String {
        if recorder.isRecording { return "Poslouchám… (klepni znovu pro konec)" }
        if transcribing { return "Přepisuji řeč…" }
        return mode.placeholder
    }

    private var micButton: some View {
        Button { Task { await toggleMic() } } label: {
            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                .font(.headline)
                .foregroundStyle(recorder.isRecording ? Theme.bg0 : Theme.parchment)
                .frame(width: 44, height: 44)
                .background(recorder.isRecording ? Theme.blood : Theme.bg2, in: Circle())
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
            Button {
                focused.wrappedValue = false
                session.send("", mode: .proceed)
            } label: {
                Image(systemName: "forward.circle.fill").font(.system(size: 40)).foregroundStyle(Theme.dimText)
            }
            .accessibilityLabel("Pokračuj v příběhu")
        } else {
            Button {
                let t = input
                input = ""
                focused.wrappedValue = false
                session.send(t, mode: mode)
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 40)).foregroundStyle(Theme.ember)
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
                let text = try await w.transcribe(samples: samples, language: "cs", initialPrompt: "Vejdu do krčmy a zeptám se hostinského.")
                input = text.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                micError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            }
        } else {
            do { try await recorder.start() } catch { micError = (error as? LocalizedError)?.errorDescription ?? "\(error)" }
        }
    }
}
