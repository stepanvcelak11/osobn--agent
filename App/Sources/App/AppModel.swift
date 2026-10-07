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

    var running: [SaveSummary] { saves.filter { $0.end == nil } }

    func refreshSaves() { saves = store.list() }

    func loadModels() async {
        await ai.loadLLM(models.active(.llm))
    }

    private func makeSession(_ story: Story) -> GameSession {
        let ai = self.ai
        let s = GameSession(story: story, store: store,
                            model: { ai.narrator() },
                            modelLoading: { if case .loading = ai.llmState, OnlineSettings.config == nil { return true } else { return false } })
        s.onNarration = { [weak self] text in
            guard UserDefaults.standard.bool(forKey: "tts.enabled") else { return }
            self?.speaker.speak(text)
        }
        s.onTurnFinished = { [weak ai] in ai?.objectWillChange.send() }
        return s
    }

    func startNewGame(_ setup: NewStory) {
        ai.resetContext()
        let story = StoryEngine.newStory(setup)
        try? store.save(story)
        let s = makeSession(story)
        session = s
        s.runIntro()
        refreshSaves()
    }

    func open(_ id: String) {
        guard let story = try? store.load(id) else { refreshSaves(); return }
        ai.resetContext()
        let s = makeSession(story)
        session = s
        if story.needsIntro { s.runIntro() }
        if story.isOver && story.epilogue == nil { s.generateEpilogue() }
    }

    #if DEBUG
    func openDemo(_ name: String) {
        guard let story = Demo.story(name) else { return }
        session = makeSession(story)
    }
    #endif

    func closeSession() {
        session?.save()
        speaker.stop()
        session = nil
        refreshSaves()
    }

    func delete(_ id: String) {
        store.delete(id)
        refreshSaves()
    }

    func deleteAllSaves() {
        for s in store.list() { delete(s.id) }
    }
}
