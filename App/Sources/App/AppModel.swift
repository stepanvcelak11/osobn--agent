import Foundation
import SwiftUI
import RealmCore

@MainActor
final class AppModel: ObservableObject {
    @Published var session: GameSession?
    @Published private(set) var saves: [SaveSummary] = []

    let store = SaveStore(directory: AppPaths.savesDirectory)
    let models = ModelManager()
    let ai = AIService()
    let speaker = Speaker()
    let downloader = ModelDownloader()

    init() {
        downloader.onInstalled = { [weak self] kind in
            guard let self, kind == .llm else { return }
            Task { await self.loadModels() }
        }
    }

    var latestUnfinished: SaveSummary? { saves.first { $0.end == nil } }

    func refreshSaves() { saves = store.list() }

    func loadModels() async {
        await ai.loadLLM(models.active(.llm))
    }

    private func makeSession(_ state: GameState, hook: String?) -> GameSession {
        let ai = self.ai
        let s = GameSession(state: state, store: store, hook: hook,
                            model: { ai.llm }, modelLoading: { if case .loading = ai.llmState { return true } else { return false } })
        s.onNarration = { [weak self] text in
            guard UserDefaults.standard.bool(forKey: "tts.enabled") else { return }
            self?.speaker.speak(text)
        }
        return s
    }

    func startNewGame(_ setup: NewGameSetup) {
        ai.resetContext()
        let (state, hook) = GameEngine.newGame(setup)
        try? store.save(state)
        let s = makeSession(state, hook: hook)
        withAnimation(.easeInOut(duration: 0.5)) { session = s }
        s.runIntro()
        refreshSaves()
    }

    func open(_ id: String) {
        guard let state = try? store.load(id) else { refreshSaves(); return }
        ai.resetContext()
        let s = makeSession(state, hook: nil)
        withAnimation(.easeInOut(duration: 0.5)) { session = s }
        if s.needsIntro { s.runIntro() }
        s.refreshSimulation()
        if state.isOver && state.epilogue == nil { s.generateEpilogue() }
    }

    #if DEBUG
    func openDemo(_ name: String) {
        guard let state = Demo.state(name) else { return }
        session = makeSession(state, hook: nil)
    }
    #endif

    func closeSession() {
        session?.save()
        speaker.stop()
        withAnimation(.easeInOut(duration: 0.4)) { session = nil }
        refreshSaves()
    }

    func delete(_ id: String) {
        store.delete(id)
        Task { await RealmNotifications.cancel(gameId: id) }
        refreshSaves()
    }

    func deleteAllSaves() {
        for s in store.list() { delete(s.id) }
    }

    /// Úspěchy napříč všemi hrami.
    func unlockedAchievements() -> Set<String> {
        var set = Set<String>()
        for s in saves { if let g = try? store.load(s.id) { set.formUnion(g.achievements) } }
        if let cur = session?.state { set.formUnion(cur.achievements) }
        return set
    }
}
