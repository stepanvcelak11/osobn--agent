import Foundation
import SwiftUI
import RealmCore

/// Jednorázové automatické stažení vypravěče (a hlasového ovládání) z Hugging Face.
/// Stahuje se na pozadí (pokračuje i po zamčení telefonu), soubor se ověří podle SHA-256 a velikosti,
/// pak už hra běží úplně offline. Jinam se aplikace nepřipojuje.
@MainActor
final class ModelDownloader: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case waiting(String)
        case downloading(name: String, received: Int64, total: Int64)
        case verifying(name: String, progress: Double)
        case failed(String)
        case done
    }

    @Published private(set) var phase: Phase = .idle
    /// Hotový model – aplikace ho načte.
    var onInstalled: ((ModelKind) -> Void)?

    static let sessionId = "cz.pocketrealm.models"
    private var session: URLSession!
    private weak var models: ModelManager?
    private var queue: [DownloadSource] = []
    private var failedIds: Set<String> = []
    private var starting = false

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
        cfg.isDiscretionary = false
        cfg.sessionSendsLaunchEvents = true
        cfg.allowsCellularAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        cfg.allowsConstrainedNetworkAccess = true
        cfg.timeoutIntervalForResource = 60 * 60 * 24
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    var isWorking: Bool {
        switch phase {
        case .downloading, .verifying, .waiting: return true
        default: return false
        }
    }

    /// Stáhne, co chybí: nejdřív vypravěče, pak hlasové ovládání.
    func startIfNeeded(models: ModelManager) {
        self.models = models
        guard !isWorking, !starting else { return }
        starting = true
        var q: [DownloadSource] = []
        if models.active(.llm) == nil { q += ModelCatalog.narratorDownloads.filter { !failedIds.contains($0.id) } }
        if models.active(.speech) == nil && UserDefaults.standard.object(forKey: "voice.autoDownload") as? Bool ?? true {
            q += ModelCatalog.voiceDownloads.filter { !failedIds.contains($0.id) }
        }
        queue = q
        session.getAllTasks { tasks in
            let running = tasks.first { $0.state == .running || $0.state == .suspended }
            Task { @MainActor in
                self.starting = false
                if let t = running, let id = t.taskDescription, let src = ModelCatalog.download(id: id) {
                    self.phase = .downloading(name: src.name, received: t.countOfBytesReceived, total: src.size)
                    if t.state == .suspended { t.resume() }
                } else {
                    self.next()
                }
            }
        }
    }

    func retry(models: ModelManager) {
        failedIds = []
        phase = .idle
        startIfNeeded(models: models)
    }

    private func next() {
        guard let models else { return }
        // přeskoč zrcadla pro druh, který už je nainstalovaný
        while let first = queue.first, models.active(first.kind) != nil { queue.removeFirst() }
        guard let src = queue.first else {
            if case .failed = phase { return }
            phase = models.active(.llm) != nil ? .done : .idle
            return
        }
        if AppPaths.freeDiskBytes > 0 && AppPaths.freeDiskBytes < src.size + 400_000_000 {
            phase = .failed("V telefonu není dost místa – vypravěč potřebuje asi \(ByteCountFormatter.string(fromByteCount: src.size + 400_000_000, countStyle: .file)). Uvolni místo a zkus to znovu.")
            return
        }
        guard let url = URL(string: src.url) else { queue.removeFirst(); next(); return }
        var req = URLRequest(url: url)
        req.setValue("PocketRealm/2", forHTTPHeaderField: "User-Agent")
        let task: URLSessionDownloadTask
        if let data = UserDefaults.standard.data(forKey: "resume.\(src.id)") {
            task = session.downloadTask(withResumeData: data)
            UserDefaults.standard.removeObject(forKey: "resume.\(src.id)")
        } else {
            task = session.downloadTask(with: req)
        }
        task.taskDescription = src.id
        task.countOfBytesClientExpectsToReceive = src.size
        phase = .downloading(name: src.name, received: 0, total: src.size)
        task.resume()
    }

    /// Ověří stažený soubor a nainstaluje ho.
    private func finish(source: DownloadSource, file: URL) async {
        phase = .verifying(name: source.name, progress: 0)
        let digest = try? await Task.detached(priority: .userInitiated) { [weak self] in
            try ModelVerifier.digest(of: file, progress: { p in
                Task { @MainActor in self?.phase = .verifying(name: source.name, progress: p) }
            })
        }.value
        guard let digest, digest.sha256 == source.sha256, digest.size == source.size,
              ModelVerifier.checkMagic(url: file, kind: source.kind) else {
            try? FileManager.default.removeItem(at: file)
            failedIds.insert(source.id)
            queue.removeAll { $0.id == source.id }
            if queue.contains(where: { $0.kind == source.kind }) { next() }
            else { phase = .failed("Stažený soubor neprošel kontrolou (poškozený přenos). Zkus to prosím znovu.") }
            return
        }
        do {
            _ = try models?.installDownloaded(file: file, source: source, digest: digest)
            queue.removeAll { $0.kind == source.kind }
            onInstalled?(source.kind)
            next()
        } catch {
            phase = .failed("Model se nepodařilo uložit: \(error.localizedDescription)")
        }
    }

    fileprivate func handleFailure(source: DownloadSource?, error: Error?, resumeData: Data?) {
        guard let source else { return }
        if let resumeData {
            // přerušeno (síť) – pokračuje se příště od místa přerušení
            UserDefaults.standard.set(resumeData, forKey: "resume.\(source.id)")
            phase = .waiting("Stahování se přerušilo – pokračuje automaticky, až bude připojení.")
            Task {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                if case .waiting = self.phase { self.next() }
            }
            return
        }
        failedIds.insert(source.id)
        queue.removeAll { $0.id == source.id }
        if queue.contains(where: { $0.kind == source.kind }) { next() }
        else if source.kind == .speech { phase = models?.active(.llm) != nil ? .done : .idle }
        else { phase = .failed("Vypravěče se nepodařilo stáhnout (\(error?.localizedDescription ?? "chyba serveru")). Zkontroluj připojení a zkus to znovu.") }
    }
}

extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let id = downloadTask.taskDescription
        Task { @MainActor in
            guard let id, let src = ModelCatalog.download(id: id) else { return }
            self.phase = .downloading(name: src.name, received: totalBytesWritten, total: src.size)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Soubor je nutné přesunout hned (systém ho po návratu smaže).
        guard let id = downloadTask.taskDescription, let src = ModelCatalog.download(id: id) else { return }
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        let dest = AppPaths.modelsDirectory.appendingPathComponent("download-\(id).part")
        try? FileManager.default.removeItem(at: dest)
        let moved = (try? FileManager.default.moveItem(at: location, to: dest)) != nil
        Task { @MainActor in
            if moved && status == 200 {
                await self.finish(source: src, file: dest)
            } else {
                try? FileManager.default.removeItem(at: dest)
                self.handleFailure(source: src, error: URLError(.badServerResponse), resumeData: nil)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let id = task.taskDescription
        let resume = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        let cancelled = (error as NSError).code == NSURLErrorCancelled && resume == nil
        Task { @MainActor in
            guard !cancelled else { return }
            self.handleFailure(source: id.flatMap(ModelCatalog.download(id:)), error: error, resumeData: resume)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            AppDelegate.backgroundCompletion?()
            AppDelegate.backgroundCompletion = nil
        }
    }
}
