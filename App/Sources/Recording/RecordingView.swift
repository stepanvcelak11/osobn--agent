import SwiftUI
import UniformTypeIdentifiers
import AgentCore

/// Přepis + shrnutí nahrávky a uložení jako poznámky.
@MainActor
final class RecordingProcessor: ObservableObject {
    struct Output {
        var summary: TranscriptSummary?
        var note: ActionRecord?
        var proposedTasks: [ActionRecord]
    }

    @Published private(set) var isRunning = false
    @Published private(set) var status = ""
    @Published private(set) var progress: Double = 0
    @Published var output: Output?
    @Published var error: String?
    private var task: Task<Void, Never>?

    func start(recorder: LongRecorder, app: AppModel, summarize: Bool) {
        guard !isRunning, let file = recorder.file else { return }
        isRunning = true
        output = nil
        error = nil
        let kind = recorder.kind
        let recordedAt = recorder.startedAt ?? Date()
        task = Task { [weak self] in
            await self?.run(file: file, kind: kind, recordedAt: recordedAt, app: app, summarize: summarize, recorder: recorder)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
        status = "Zrušeno"
    }

    private func run(file: EncryptedAudioFile, kind: RecordingKind, recordedAt: Date, app: AppModel, summarize: Bool, recorder: LongRecorder) async {
        defer { isRunning = false }
        do {
            // 1) Přepis po 5 minutách
            status = "Načítám rozpoznávání řeči…"
            let whisper = try await app.ai.transcriber(for: app.models.active(.speech))
            let total = max(1, file.duration)
            var parts: [String] = []
            try await file.readWindows(windowSeconds: 300) { samples, offset in
                try Task.checkCancellation()
                await MainActor.run {
                    self.status = "Přepisuji \(CzechDuration.clock(offset)) / \(CzechDuration.clock(total))…"
                    self.progress = offset / total * (summarize ? 0.7 : 1)
                    app.noteActivity()
                }
                let text = try await whisper.transcribe(samples: samples)
                if !text.isEmpty { parts.append("[\(CzechDuration.clock(offset))] " + text) }
            }
            try Task.checkCancellation()
            let transcript = parts.joined(separator: "\n")

            // 2) Shrnutí lokálním modelem
            var summary: TranscriptSummary?
            if summarize, let llm = app.ai.llm {
                status = "Shrnuji…"
                let summarizer = TranscriptSummarizer(model: llm)
                summary = try await summarizer.summarize(transcript: transcript, kind: kind, progress: { s, p in
                    Task { @MainActor in
                        self.status = s
                        self.progress = 0.7 + p * 0.3
                        app.noteActivity()
                    }
                }, isCancelled: { Task.isCancelled })
                llm.resetCache()
            }
            try Task.checkCancellation()

            // 3) Uložení jako poznámka (vratná akce) + navržené úkoly (čekají na potvrzení)
            guard let executor = app.agent?.executor else { throw KeyManager.KeyError.notSetUp }
            let s = summary ?? TranscriptSummary(title: "", summary: "", points: [], tasks: [])
            let title = kind.czechName + ": " + (s.title.isEmpty || s.title == kind.czechName
                ? CzechFormat.longDate(recordedAt, calendar: app.calendar) : s.title)
            let body = s.noteBody(transcript: transcript.isEmpty ? "(nebyla rozpoznána žádná řeč)" : transcript,
                                  recordedAt: recordedAt, duration: file.duration, calendar: app.calendar)
            let note = try await executor.execute(ToolCall("create_note", ["title": title, "text": body]), source: "nahrávka")
            var proposed: [ActionRecord] = []
            for t in s.tasks.prefix(10) {
                if let a = try await executor.propose(ToolCall("create_task", ["title": t]), source: "nahrávka").action { proposed.append(a) }
            }
            output = Output(summary: summary, note: note.action, proposedTasks: proposed)
            status = "Hotovo"
            progress = 1
            recorder.discard()   // smaže šifrovaný zvuk
        } catch is CancellationError {
            status = "Zrušeno"
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            status = ""
        }
    }
}

struct RecordingView: View {
    @EnvironmentObject var app: AppModel
    @EnvironmentObject var recorder: LongRecorder
    @EnvironmentObject var processor: RecordingProcessor
    @EnvironmentObject var ai: AIService
    @Environment(\.dismiss) private var dismiss
    @State private var showImporter = false
    @State private var summarize = true
    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if let out = processor.output { resultView(out) }
                    else if processor.isRunning { processingView }
                    else { recordingControls }
                }
                .padding(20)
            }
            .navigationTitle("Nahrávka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(recorder.isActive ? "Skrýt" : "Zavřít") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio, .mpeg4Audio, .wav, .mp3]) { result in
                guard case .success(let url) = result else { return }
                Task {
                    do { try await recorder.importAudio(from: url) }
                    catch { processor.error = "Soubor nejde načíst: \(error.localizedDescription)" }
                }
            }
            .alert("Nahrávka", isPresented: Binding(get: { processor.error != nil }, set: { if !$0 { processor.error = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(processor.error ?? "") }
            .confirmationDialog("Zahodit nahrávku?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Zahodit", role: .destructive) { recorder.discard() }
            }
        }
    }

    // MARK: Nahrávání

    @ViewBuilder private var recordingControls: some View {
        if recorder.state == .idle {
            Picker("Typ", selection: $recorder.kind) {
                ForEach(RecordingKind.allCases, id: \.self) { Text($0.czechName).tag($0) }
            }
            .pickerStyle(.segmented)
            Text("Nahrávání pokračuje i se zamčeným telefonem. Zvuk se ukládá jen dočasně, šifrovaně, a po zpracování se smaže. Nahrávej jen se souhlasem ostatních.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        Text(CzechDuration.clock(recorder.elapsed))
            .font(.system(size: 56, weight: .light, design: .rounded).monospacedDigit())
        if recorder.isActive {
            Capsule().fill(recorder.state == .recording ? Color.red : Color.orange)
                .frame(width: 40 + CGFloat(recorder.level) * 220, height: 8)
                .animation(.easeOut(duration: 0.1), value: recorder.level)
        }
        HStack(spacing: 28) {
            switch recorder.state {
            case .idle:
                bigButton("record.circle", "Nahrávat", .red) {
                    Task {
                        do { try await recorder.start() }
                        catch { processor.error = (error as? LocalizedError)?.errorDescription ?? "\(error)" }
                    }
                }
            case .recording:
                bigButton("pause.fill", "Pauza", .orange) { recorder.pause() }
                bigButton("stop.fill", "Konec", .red) { recorder.stop() }
            case .paused:
                bigButton("play.fill", "Pokračovat", .green) { recorder.resume() }
                bigButton("stop.fill", "Konec", .red) { recorder.stop() }
            case .finished:
                EmptyView()
            }
        }
        if recorder.state == .idle {
            Button("Vybrat zvukový soubor (např. z Diktafonu)…") { showImporter = true }
                .font(.subheadline)
        }
        if recorder.state == .finished {
            VStack(spacing: 12) {
                Text("Nahráno \(CzechDuration.format(recorder.elapsed))").font(.headline)
                Toggle("Shrnout pomocí modelu", isOn: $summarize).disabled(!ai.isLLMReady)
                if !ai.isLLMReady { Text("Jazykový model není načtený – uloží se jen přepis.").font(.caption).foregroundStyle(.secondary) }
                if app.models.active(.speech) == nil {
                    Label("Nejdřív nahraj model pro rozpoznávání řeči (Nastavení → Modely).", systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(.orange)
                }
                Button {
                    processor.start(recorder: recorder, app: app, summarize: summarize && ai.isLLMReady)
                } label: {
                    Label("Přepsat a uložit", systemImage: "text.badge.checkmark").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(app.models.active(.speech) == nil)
                Button("Zahodit nahrávku", role: .destructive) { confirmDiscard = true }
            }
        }
    }

    private func bigButton(_ icon: String, _ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 76, height: 76).background(color, in: Circle())
                Text(title).font(.subheadline)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: Zpracování

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: processor.progress)
            Text(processor.status).font(.subheadline).foregroundStyle(.secondary)
            Text("Nech aplikaci otevřenou. Hodinová nahrávka trvá zhruba 5–15 minut.").font(.caption).foregroundStyle(.secondary)
            Button("Zrušit", role: .destructive) { processor.cancel() }
        }
    }

    // MARK: Výsledek

    private func resultView(_ out: RecordingProcessor.Output) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let s = out.summary {
                Text(s.title).font(.title3.bold())
                if !s.summary.isEmpty { Text(s.summary) }
                if !s.points.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hlavní body").font(.headline)
                        ForEach(s.points, id: \.self) { Text("• " + $0) }
                    }
                }
            }
            if let n = out.note { ActionCardView(action: n) }
            if !out.proposedTasks.isEmpty {
                Text("Navržené úkoly – potvrď, které chceš:").font(.headline)
                ForEach(out.proposedTasks) { ActionCardView(action: $0) }
            }
            Button("Nová nahrávka") { processor.output = nil }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
    }
}
