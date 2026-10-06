import Foundation
import SwiftUI
import AgentCore

struct InstalledModel: Codable, Identifiable, Equatable {
    var id: String
    var kind: ModelKind
    var fileName: String
    var displayName: String
    var sha256: String
    var sha1: String
    var size: Int64
    var verifiedBy: String      // „SHA-256“, „SHA-1 (katalog whisper.cpp)“, „potvrzeno uživatelem“
    var importedAt: Date

    var url: URL { AppPaths.modelsDirectory.appendingPathComponent(id).appendingPathExtension(kind.fileExtension) }
    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
    var sizeText: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
}

/// Výsledek importu čekající na rozhodnutí (neznámý hash).
struct PendingImport: Identifiable, Equatable {
    var id: String
    var kind: ModelKind
    var fileName: String
    var tempURL: URL
    var digest: FileDigest
}

/// Správa modelů: ruční import ze souboru, ověření kontrolního součtu, výběr aktivního modelu.
/// Aplikace modely NIKDY nestahuje z internetu (ani nemá síťový kód).
@MainActor
final class ModelManager: ObservableObject {
    @Published private(set) var installed: [InstalledModel] = []
    @Published var importProgress: Double?
    @Published var importStatus: String = ""

    private var store: DataStore?
    private let manifestKey = "models.installed"

    func attach(store: DataStore) {
        self.store = store
        reload()
    }

    func detach() {
        store = nil
        installed = []
    }

    func reload() {
        guard let store, let json = try? store.setting(manifestKey), let data = json.data(using: .utf8),
              let list = try? JSONDecoder.withDates.decode([InstalledModel].self, from: data) else {
            installed = []
            return
        }
        installed = list.filter(\.exists)
    }

    private func save() {
        guard let store, let data = try? JSONEncoder.withDates.encode(installed) else { return }
        try? store.setSetting(manifestKey, String(decoding: data, as: UTF8.self))
    }

    func active(_ kind: ModelKind) -> InstalledModel? {
        guard let id = try? store?.setting("model.active.\(kind.rawValue)") else {
            return installed.first { $0.kind == kind }
        }
        return installed.first { $0.id == id } ?? installed.first { $0.kind == kind }
    }

    func activate(_ m: InstalledModel) {
        try? store?.setSetting("model.active.\(m.kind.rawValue)", m.id)
        objectWillChange.send()
    }

    func delete(_ m: InstalledModel) {
        try? FileManager.default.removeItem(at: m.url)
        installed.removeAll { $0.id == m.id }
        save()
    }

    enum ImportOutcome {
        case installed(InstalledModel)
        case needsConfirmation(PendingImport)
    }

    enum ImportError: LocalizedError {
        case notEnoughSpace(String)
        case wrongFormat(ModelKind)
        case mismatch(expected: String, actual: String)
        case access

        var errorDescription: String? {
            switch self {
            case .notEnoughSpace(let s): return "Na telefonu není dost místa (potřeba \(s))."
            case .wrongFormat(let k): return "Soubor nemá formát pro „\(k.czechName)“ (\(k == .speech ? "ggml .bin" : "GGUF"))."
            case .mismatch(let e, let a): return "KONTROLNÍ SOUČET NESEDÍ – soubor byl odmítnut a smazán.\nOčekáváno: \(e)\nSpočteno: \(a)"
            case .access: return "K souboru nelze přistoupit."
            }
        }
    }

    /// Zkopíruje soubor do aplikace, ověří formát a kontrolní součet.
    func importModel(from source: URL, kind: ModelKind, expectedHash: String?) async throws -> ImportOutcome {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let size = (try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        if size > 0 && AppPaths.freeDiskBytes < size + 200_000_000 {
            throw ImportError.notEnoughSpace(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        let id = UUID().uuidString
        let tmp = AppPaths.modelsDirectory.appendingPathComponent("import-\(id).part")
        importStatus = "Kopíruji soubor…"
        importProgress = 0
        defer { importProgress = nil }
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.copyItem(at: source, to: tmp)
        }.value
        guard ModelVerifier.checkMagic(url: tmp, kind: kind) else {
            try? FileManager.default.removeItem(at: tmp)
            throw ImportError.wrongFormat(kind)
        }
        importStatus = "Počítám kontrolní součet…"
        let digest = try await Task.detached(priority: .userInitiated) { [weak self] in
            try ModelVerifier.digest(of: tmp) { p in
                Task { @MainActor in self?.importProgress = p }
            }
        }.value
        let fileName = source.lastPathComponent
        let pending = PendingImport(id: id, kind: kind, fileName: fileName, tempURL: tmp, digest: digest)
        switch ModelVerifier.verdict(digest: digest, fileName: fileName, expected: expectedHash) {
        case .verified(let how):
            return .installed(try finalize(pending, verifiedBy: how))
        case .mismatch(let e, let a):
            try? FileManager.default.removeItem(at: tmp)
            throw ImportError.mismatch(expected: e, actual: a)
        case .unknown:
            return .needsConfirmation(pending)
        }
    }

    /// Uživatel výslovně potvrdil hash (porovnal ho se zdrojem).
    func confirm(_ p: PendingImport) throws -> InstalledModel {
        try finalize(p, verifiedBy: "potvrzeno uživatelem")
    }

    func discard(_ p: PendingImport) {
        try? FileManager.default.removeItem(at: p.tempURL)
    }

    private func finalize(_ p: PendingImport, verifiedBy: String) throws -> InstalledModel {
        let catalogName = ModelCatalog.match(fileName: p.fileName)?.name
        let m = InstalledModel(id: p.id, kind: p.kind, fileName: p.fileName,
                               displayName: catalogName ?? (p.fileName as NSString).deletingPathExtension,
                               sha256: p.digest.sha256, sha1: p.digest.sha1, size: p.digest.size,
                               verifiedBy: verifiedBy, importedAt: Date())
        try FileManager.default.moveItem(at: p.tempURL, to: m.url)
        AppPaths.excludeFromBackup(m.url)
        installed.append(m)
        save()
        if active(p.kind) == nil || installed.filter({ $0.kind == p.kind }).count == 1 { activate(m) }
        return m
    }

    /// Znovu spočítá hash a porovná s uloženým (ochrana proti podvržení souboru).
    func reverify(_ m: InstalledModel) async -> Bool {
        importStatus = "Ověřuji \(m.displayName)…"
        importProgress = 0
        defer { importProgress = nil }
        let url = m.url
        let d = try? await Task.detached { [weak self] in
            try ModelVerifier.digest(of: url) { p in Task { @MainActor in self?.importProgress = p } }
        }.value
        return d?.sha256 == m.sha256
    }

    /// Smaže nedokončené importy.
    func cleanupPartial() {
        let dir = AppPaths.modelsDirectory
        for f in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where f.hasSuffix(".part") {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
    }
}

extension JSONEncoder {
    static var withDates: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }
}

extension JSONDecoder {
    static var withDates: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }
}
