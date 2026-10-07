import Foundation
import SwiftUI
import RealmCore

/// Jedna rozehraná hra: drží příběh, volá vypravěče, ukládá.
@MainActor
final class GameSession: ObservableObject, Identifiable {
    enum Busy: Equatable {
        case intro, narrating, epilogue, waitingForModel
        var label: String {
            switch self {
            case .intro: return "Vypravěč začíná příběh…"
            case .narrating: return "Vypravěč píše…"
            case .epilogue: return "Píše se legenda…"
            case .waitingForModel: return "Vypravěč se probouzí…"
            }
        }
    }

    @Published private(set) var story: Story
    @Published private(set) var busy: Busy?
    @Published private(set) var streamingText = ""
    @Published private(set) var pendingAction: String?
    @Published private(set) var pendingMode: InputMode = .act
    @Published private(set) var liveRoll: Roll?
    @Published var toast: String?
    @Published var error: String?
    /// Příběh před posledním tahem (pro „Vrátit“ a „Znovu“).
    @Published private(set) var undoStory: Story?
    private var lastInput: (text: String, mode: InputMode)?
    private var variation: UInt32 = 0

    nonisolated let id: String
    private let store: SaveStore
    private let modelProvider: () -> LanguageModel?
    private let modelLoading: () -> Bool
    private var task: Task<Void, Never>?
    var onNarration: ((String) -> Void)?
    var onTurnFinished: (() -> Void)?

    init(story: Story, store: SaveStore, model: @escaping () -> LanguageModel?, modelLoading: @escaping () -> Bool) {
        self.story = story
        self.id = story.id
        self.store = store
        self.modelProvider = model
        self.modelLoading = modelLoading
    }

    var isBusy: Bool { busy != nil }

    func setMemory(_ memory: String, note: String) {
        story.memory = String(memory.prefix(500))
        story.note = String(note.prefix(200))
        save()
    }

    func save() { try? store.save(story) }

    private func waitForModel() async {
        var waited = 0
        while modelLoading() && waited < 240 {
            busy = .waitingForModel
            try? await Task.sleep(nanoseconds: 250_000_000)
            waited += 1
        }
    }

    // MARK: Úvod

    func runIntro() {
        guard story.needsIntro, task == nil else { return }
        task = Task {
            await waitForModel()
            busy = .intro
            streamingText = ""
            let engine = StoryEngine(model: modelProvider())
            let s = await engine.intro(story) { t in Task { @MainActor in self.publishStream(t) } }
            story = s
            finishTask()
            save()
            if let text = s.log.last(where: { $0.kind == .narration })?.text { onNarration?(text) }
        }
    }

    // MARK: Tah

    var canUndo: Bool { undoStory != nil && task == nil && !story.isOver }
    var canRetry: Bool { canUndo && lastInput != nil }

    func undo() {
        guard canUndo, let prev = undoStory else { return }
        story = prev
        undoStory = nil
        lastInput = nil
        save()
        toast = "Tah vrácen."
    }

    /// Nové vyprávění téhož tahu. Kostka zůstává stejná.
    func retry() {
        guard canRetry, let prev = undoStory, let last = lastInput else { return }
        story = prev
        undoStory = nil
        variation &+= 1
        send(last.text, mode: last.mode, variation: variation)
    }

    func send(_ raw: String, mode: InputMode = .act, variation: UInt32 = 0) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || mode == .proceed, task == nil, !story.isOver else { return }
        if variation == 0 { self.variation = 0 }
        let before = story
        pendingAction = mode == .proceed ? nil : text
        pendingMode = mode
        streamingText = ""
        liveRoll = nil
        error = nil
        task = Task {
            await waitForModel()
            busy = .narrating
            let engine = StoryEngine(model: modelProvider())
            do {
                let r = try await engine.play(story, input: text, mode: mode, variation: variation) { ev in
                    Task { @MainActor in self.handle(ev) }
                }
                undoStory = before
                lastInput = (text, mode)
                story = r.story
                save()
                if let roll = r.roll { Haptics.outcome(roll.outcome) }
                if r.completedStage != nil, !r.story.isOver { toast = "Příběh se posunul" }
                if let n = r.story.log.last(where: { $0.kind == .narration })?.text { onNarration?(n) }
            } catch is CancellationError {
                toast = "Tah zrušen."
            } catch {
                self.error = (error as? GameError)?.description ?? "Vypravěč zaváhal: \(error)"
            }
            finishTask()
            onTurnFinished?()
            if story.isOver { generateEpilogue() }
        }
    }

    private func handle(_ ev: TurnEvent) {
        guard task != nil else { return }
        switch ev {
        case .rolled(let roll): liveRoll = roll
        case .narrating(let t): publishStream(t)
        }
    }

    private func finishTask() {
        busy = nil
        pendingAction = nil
        streamingText = ""
        pendingStream = nil
        liveRoll = nil
        task = nil
    }

    // Text se překresluje nejvýš ~8× za sekundu – šetří procesor, který potřebuje vypravěč.
    private var pendingStream: String?
    private var streamFlush: Task<Void, Never>?

    private func publishStream(_ t: String) {
        pendingStream = t
        guard streamFlush == nil else { return }
        streamFlush = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard let self else { return }
            if self.task != nil, let p = self.pendingStream { self.streamingText = p }
            self.pendingStream = nil
            self.streamFlush = nil
        }
    }

    func cancel() { task?.cancel() }

    // MARK: Konec

    func abandon() {
        task?.cancel()
        story = StoryEngine.abandon(story)
        save()
        generateEpilogue()
    }

    func generateEpilogue() {
        guard story.isOver, story.epilogue == nil else { return }
        let start = { [weak self] in
            guard let self else { return }
            self.task = Task {
                self.busy = .epilogue
                self.streamingText = ""
                let engine = StoryEngine(model: self.modelProvider())
                let s = await engine.epilogue(self.story) { t in Task { @MainActor in self.publishStream(t) } }
                self.story = s
                self.finishTask()
                self.save()
            }
        }
        if task == nil { start() } else {
            Task {
                while self.task != nil { try? await Task.sleep(nanoseconds: 100_000_000) }
                start()
            }
        }
    }
}
