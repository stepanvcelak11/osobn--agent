import Foundation
import SwiftUI
import RealmCore

/// Jedna rozehraná hra: drží stav, volá engine, ukládá.
@MainActor
final class GameSession: ObservableObject, Identifiable {
    enum Busy: Equatable {
        case intro, interpreting, rolling, narrating, epilogue, waitingForModel
        var label: String {
            switch self {
            case .intro: return "Vypravěč rozdmýchává oheň…"
            case .interpreting: return "Vypravěč zvažuje tvůj záměr…"
            case .rolling: return "Kostky padají…"
            case .narrating: return "Vypravěč vypráví…"
            case .epilogue: return "Píše se legenda…"
            case .waitingForModel: return "Vypravěč se probouzí (načítání modelu)…"
            }
        }
    }

    @Published private(set) var state: GameState
    @Published private(set) var busy: Busy?
    @Published private(set) var streamingText = ""
    @Published private(set) var pendingAction: String?
    @Published private(set) var liveRoll: RollInfo?
    @Published var diceOverlay: RollInfo?
    @Published var toast: String?
    @Published var achievement: Achievement?
    @Published var error: String?
    @Published private(set) var lastStats: GenerationStats?

    nonisolated let id: String
    private let store: SaveStore
    private let modelProvider: () -> LanguageModel?
    private let modelLoading: () -> Bool
    private var task: Task<Void, Never>?
    var hook: String?
    var onNarration: ((String) -> Void)?

    init(state: GameState, store: SaveStore, hook: String? = nil,
         model: @escaping () -> LanguageModel?, modelLoading: @escaping () -> Bool) {
        self.state = state
        self.id = state.id
        self.store = store
        self.hook = hook
        self.modelProvider = model
        self.modelLoading = modelLoading
    }

    var needsIntro: Bool { state.log.isEmpty }
    var isBusy: Bool { busy != nil }

    func save() {
        try? store.save(state)
    }

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
        guard needsIntro, task == nil else { return }
        if hook == nil, let q = state.quest { hook = Catalog.quests.first { $0.objective == q.objective }?.hook }
        task = Task {
            await waitForModel()
            busy = .intro
            streamingText = ""
            let engine = GameEngine(model: modelProvider())
            let s = await engine.intro(state, hook: hook) { t in Task { @MainActor in self.streamingText = t } }
            state = s
            busy = nil
            streamingText = ""
            save()
            if let text = s.log.last?.text { onNarration?(text) }
            if s.mode.hasSettlement {
                await RealmNotifications.requestPermission()
                await RealmNotifications.reschedule(for: s)
            }
            task = nil
        }
    }

    // MARK: Tah

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, task == nil, !state.isOver else { return }
        pendingAction = text
        streamingText = ""
        liveRoll = nil
        error = nil
        task = Task {
            await waitForModel()
            busy = .interpreting
            let engine = GameEngine(model: modelProvider())
            do {
                let result = try await engine.playTurn(state, input: text, now: Date()) { ev in
                    Task { @MainActor in self.handle(ev) }
                }
                finish(result)
            } catch is CancellationError {
                toast = "Tah zrušen."
            } catch {
                self.error = (error as? GameError)?.description ?? "Vypravěč zaváhal: \(error)"
            }
            busy = nil
            pendingAction = nil
            streamingText = ""
            liveRoll = nil
            task = nil
        }
    }

    private func handle(_ ev: TurnEvent) {
        guard task != nil else { return }
        switch ev {
        case .interpreting:
            busy = .interpreting
        case .rolled(let roll, _):
            liveRoll = roll
            if roll.outcome != .auto && roll.outcome != .impossible {
                busy = .rolling
                diceOverlay = roll
            } else {
                busy = .narrating
            }
        case .narrating(let t):
            if busy != .narrating && diceOverlay == nil { busy = .narrating }
            streamingText = t
        }
    }

    private func finish(_ r: TurnResult) {
        let before = state
        state = r.state
        lastStats = r.stats
        save()
        if r.delta.hp < -10 { Haptics.impact(.heavy) }
        if let a = r.newAchievements.first { achievement = a }
        if let n = r.state.log.last(where: { $0.kind == .narration }), r.state.log.count > before.log.count {
            onNarration?(n.text)
        }
        if r.state.mode.hasSettlement { Task { await RealmNotifications.reschedule(for: r.state) } }
        if r.state.isOver { generateEpilogue() }
    }

    func cancel() {
        task?.cancel()
    }

    // MARK: Živý simulátor

    /// Dožene čas (při otevření, návratu do aplikace a každou minutu).
    func refreshSimulation() {
        guard state.mode.hasSettlement, !state.isOver, task == nil else { return }
        var s = state
        let report = Simulation.syncRealTime(&s, now: Date())
        guard s != state else { return }
        let hadEvents = !report.isEmpty
        state = s
        save()
        if hadEvents {
            toast = report.days > 0 ? "Mezitím uplynulo \(report.days) \(report.days == 1 ? "den" : report.days < 5 ? "dny" : "dní") – podívej se do deníku." : "V osadě se něco stalo."
            Haptics.impact(.light)
        }
        Task { await RealmNotifications.reschedule(for: s) }
        if s.isOver { generateEpilogue() }
    }

    // MARK: Konec

    func abandon() {
        task?.cancel()
        state = GameEngine.abandon(state)
        save()
        Task { await RealmNotifications.cancel(gameId: state.id) }
        generateEpilogue()
    }

    func generateEpilogue() {
        guard state.isOver, state.epilogue == nil else { return }
        let start = { [weak self] in
            guard let self else { return }
            self.task = Task {
                self.busy = .epilogue
                self.streamingText = ""
                let engine = GameEngine(model: self.modelProvider())
                let s = await engine.epilogue(self.state) { t in Task { @MainActor in self.streamingText = t } }
                self.state = s
                self.busy = nil
                self.streamingText = ""
                self.save()
                self.task = nil
                Task { await RealmNotifications.cancel(gameId: s.id) }
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
