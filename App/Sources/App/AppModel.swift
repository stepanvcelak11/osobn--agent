import Foundation
import SwiftUI
import AgentCore

enum AppTab: Hashable { case home, data, chat, settings }

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var undoActionId: String?
}

/// Ústřední stav aplikace: zámek, data, agent, modely.
@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable { case launching, onboarding, locked, unlocked, wiped }

    @Published private(set) var phase: Phase = .launching
    @Published private(set) var store: DataStore?
    @Published private(set) var agent: AgentEngine?
    /// Zvyšuje se při každé změně dat – obrazovky se podle něj obnoví.
    @Published private(set) var dataVersion = 0
    @Published var tab: AppTab = .home
    @Published var lockMessage: String?
    @Published var isUnlocking = false
    @Published var showCapture = false
    @Published var toast: Toast?
    @Published var shieldVisible = false
    @Published var isJailbroken = false
    @Published var agentSettings = AgentSettings()

    let models = ModelManager()
    let ai = AIService()
    let notifications = NotificationService.shared
    let recorder = AudioRecorder()
    let speaker = Speaker()
    private(set) var semantic: SemanticSearch?
    var calendar: Calendar { CzechFormat.calendar() }

    private var lastActivity = Date()
    private var backgroundedAt: Date?
    private var idleTimer: Timer?
    private var changeTask: Task<Void, Never>?
    private var pendingCaptureAfterUnlock = false

    // Nastavení zámku (sekundy)
    var lockAfterBackground: Int {
        get { UserDefaults.standard.object(forKey: "lock.background") as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: "lock.background"); objectWillChange.send() }
    }
    var lockAfterIdle: Int {
        get { UserDefaults.standard.object(forKey: "lock.idle") as? Int ?? 120 }
        set { UserDefaults.standard.set(newValue, forKey: "lock.idle"); objectWillChange.send() }
    }
    var autoSpeak: Bool {
        get { UserDefaults.standard.bool(forKey: "tts.auto") }
        set { UserDefaults.standard.set(newValue, forKey: "tts.auto"); objectWillChange.send() }
    }

    // MARK: - Start

    func start() {
        guard phase == .launching else { return }
        notifications.configure()
        isJailbroken = DeviceIntegrity.isJailbroken
        // Keychain přežije odinstalaci aplikace – bez databáze klíče zahodíme.
        if KeyManager.isSetUp && !AppPaths.databaseExists { KeyManager.wipeAll() }
        AppPaths.clearTemp()
        phase = KeyManager.isSetUp ? .locked : .onboarding
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIdle() }
        }
    }

    // MARK: - Nastavení a odemčení

    func completeOnboarding(recoveryPassword: String) async throws {
        let key = try await Task.detached(priority: .userInitiated) {
            try KeyManager.setUp(recoveryPassword: recoveryPassword)
        }.value
        try openStore(key: key)
        await notifications.requestAuthorization()
    }

    func unlockWithBiometrics() async {
        guard phase == .locked, !isUnlocking else { return }
        isUnlocking = true
        defer { isUnlocking = false }
        lockMessage = nil
        do {
            let key = try await KeyManager.unlockWithBiometrics()
            try openStore(key: key)
        } catch KeyManager.KeyError.cancelled {
            // nic
        } catch {
            lockMessage = (error as? LocalizedError)?.errorDescription ?? "\(error)"
            checkWipe()
        }
    }

    func unlockWithRecovery(password: String) async {
        isUnlocking = true
        defer { isUnlocking = false }
        do {
            let key = try await Task.detached(priority: .userInitiated) { try KeyManager.unlockWithRecovery(password: password) }.value
            try openStore(key: key)
        } catch {
            let left = KeyManager.config.wipeAfterFailures > 0 ? " Zbývá pokusů: \(max(0, KeyManager.config.wipeAfterFailures - KeyManager.failures))." : ""
            lockMessage = "Nesprávné heslo." + left
            checkWipe()
        }
    }

    private func checkWipe() {
        if KeyManager.shouldWipe { wipeEverything() }
    }

    private func openStore(key: Data) throws {
        var k = key
        defer { k.resetBytes(in: 0..<k.count) }
        let s = try DataStore.open(path: AppPaths.databaseURL.path, key: k)
        AppPaths.protectDatabaseFiles()
        store = s
        if let json = try? s.setting("agent.settings"), let d = json.data(using: .utf8),
           let st = try? JSONDecoder().decode(AgentSettings.self, from: d) {
            agentSettings = st
        }
        let engine = AgentEngine(store: s, model: ai.llm, calendar: calendar, settings: agentSettings)
        agent = engine
        s.onChange = { [weak self] in
            Task { @MainActor in self?.dataDidChange() }
        }
        models.attach(store: s)
        models.cleanupPartial()
        phase = .unlocked
        lastActivity = Date()
        dataVersion += 1
        _ = try? s.purgeDeleted(before: Date().addingTimeInterval(-30 * 86400))
        if pendingCaptureAfterUnlock { pendingCaptureAfterUnlock = false; showCapture = true }
        Task {
            await loadModels()
            await notifications.reschedule(store: s, calendar: calendar)
        }
    }

    func loadModels() async {
        await ai.loadLLM(models.active(.llm))
        await ai.loadEmbedder(models.active(.embedding))
        agent?.model = ai.llm
        if let s = store {
            let search = SemanticSearch(store: s, embedder: ai.embedder)
            semantic = search
            agent?.executor.searcher = search
            Task.detached(priority: .background) { _ = try? await search.refresh() }
        }
    }

    func saveAgentSettings() {
        agent?.settings = agentSettings
        if let d = try? JSONEncoder().encode(agentSettings) {
            try? store?.setSetting("agent.settings", String(decoding: d, as: UTF8.self))
        }
    }

    // MARK: - Zámek

    func lock() {
        guard phase == .unlocked else { return }
        changeTask?.cancel()
        agent?.clearPending()
        recorder.cancel()
        speaker.stop()
        ai.clearSensitiveState()
        models.detach()
        agent = nil
        semantic = nil
        store?.db.close()
        store = nil
        showCapture = false
        toast = nil
        phase = .locked
    }

    func noteActivity() { lastActivity = Date() }

    private func checkIdle() {
        guard phase == .unlocked, lockAfterIdle > 0 else { return }
        if recorder.isRecording { lastActivity = Date(); return }
        if Date().timeIntervalSince(lastActivity) > TimeInterval(lockAfterIdle) { lock() }
    }

    func scenePhaseChanged(_ p: ScenePhase) {
        switch p {
        case .active:
            shieldVisible = false
            consumePendingCaptureFlag()
            if let b = backgroundedAt, phase == .unlocked, Date().timeIntervalSince(b) >= TimeInterval(lockAfterBackground) {
                lock()
            }
            backgroundedAt = nil
            lastActivity = Date()
            if phase == .unlocked, let s = store {
                Task { await notifications.reschedule(store: s, calendar: calendar) }
                dataVersion += 1
            }
        case .inactive:
            // Skrýt obsah v přepínači aplikací
            shieldVisible = true
        case .background:
            shieldVisible = true
            backgroundedAt = Date()
            if lockAfterBackground == 0 { lock() }
        @unknown default:
            shieldVisible = true
        }
    }

    // MARK: - Data

    private func dataDidChange() {
        dataVersion += 1
        changeTask?.cancel()
        changeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let self, !Task.isCancelled, let s = self.store else { return }
            await self.notifications.reschedule(store: s, calendar: self.calendar)
            if let search = self.semantic { _ = try? await search.refresh() }
        }
    }

    /// Odešle zprávu agentovi.
    func send(_ text: String, mode: AgentMode = .chat, progress: (@Sendable (AgentProgress) -> Void)? = nil) async -> AgentReply? {
        guard let agent else { return nil }
        noteActivity()
        agent.calendar = calendar
        let reply = await agent.handle(text, mode: mode, progress: progress)
        dataVersion += 1
        if autoSpeak && !reply.text.isEmpty { speaker.speak(reply.text) }
        noteActivity()
        return reply
    }

    // MARK: - Akce z karet

    func confirm(_ id: String) { perform { try $0.confirm(actionId: id) } }
    func reject(_ id: String) { perform { try $0.reject(actionId: id) } }
    func undo(_ id: String) { perform { try $0.undo(actionId: id) }; toast = Toast(text: "Vráceno zpět") }

    private func perform(_ f: (ToolExecutor) throws -> ActionRecord) {
        guard let ex = agent?.executor else { return }
        do { _ = try f(ex) } catch { toast = Toast(text: "Akci nelze provést: \(error)") }
        dataVersion += 1
    }

    /// Úprava entity uživatelem (formulář) – zapíše se jako vratná akce.
    func saveEdit(ref: EntityRef, after: JSONValue, summary: String, pendingActionId: String? = nil) {
        guard let ex = agent?.executor else { return }
        do {
            if let pid = pendingActionId { try ex.amendPending(actionId: pid, after: after, summary: summary) }
            else { try ex.recordUserEdit(ref: ref, after: after, summary: summary) }
        } catch { toast = Toast(text: "Uložení selhalo: \(error)") }
        dataVersion += 1
    }

    /// Ruční vytvoření položky.
    func create(kind: EntityKind, entity: JSONValue, summary: String, id: String) {
        saveEdit(ref: EntityRef(kind: kind, id: id), after: entity, summary: summary)
    }

    /// Smazání potvrzené uživatelem v UI (jde vrátit).
    func delete(_ ref: EntityRef, title: String) {
        guard let ex = agent?.executor, let store, let snap = try? store.snapshot(ref) else { return }
        do {
            var a = ActionRecord(tool: "delete_item", args: .object([:]), status: .pending, summary: "Smazáno: \(title)",
                                 entity: ref, before: snap, after: nil, source: "uživatel")
            try store.insert(a)
            a = try ex.confirm(actionId: a.id)
            toast = Toast(text: "Smazáno: \(title)", undoActionId: a.id)
        } catch { toast = Toast(text: "Smazání selhalo") }
        dataVersion += 1
    }

    func toggleTask(_ t: TaskItem) {
        var n = t
        n.doneAt = t.isDone ? nil : Date()
        n.updatedAt = Date()
        saveEdit(ref: EntityRef(kind: .task, id: t.id), after: JSONValue.from(n), summary: t.isDone ? "Znovu otevřeno: \(t.title)" : "Splněno: \(t.title)")
        if !t.isDone, let last = try? store?.lastAppliedAction() { toast = Toast(text: "Splněno: \(t.title)", undoActionId: last.id) }
    }

    // MARK: - Odkazy a rychlé zachycení

    func handleURL(_ url: URL) {
        guard url.scheme == "osobniagent" else { return }
        if url.host == "capture" { requestCapture() }
    }

    /// Zkratka (App Intent) nastaví příznak – zpracujeme ho po návratu do popředí.
    func consumePendingCaptureFlag() {
        if UserDefaults.standard.bool(forKey: "pendingCapture") {
            UserDefaults.standard.set(false, forKey: "pendingCapture")
            requestCapture()
        }
    }

    func requestCapture() {
        if phase == .unlocked { showCapture = true } else { pendingCaptureAfterUnlock = true }
    }

    // MARK: - Smazání všeho

    func wipeEverything() {
        lock()
        ai.unloadAll()
        notifications.removeAll()
        KeyManager.wipeAll()
        phase = .wiped
    }

    func restartAfterWipe() {
        phase = KeyManager.isSetUp ? .locked : .onboarding
    }
}
