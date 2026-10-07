import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public enum ModelKind: String, Codable, Sendable, CaseIterable {
    case llm, speech

    public var czechName: String {
        switch self {
        case .llm: return "Vypravěč (jazykový model)"
        case .speech: return "Rozpoznávání řeči"
        }
    }
    public var fileExtension: String { self == .speech ? "bin" : "gguf" }
}

/// Známé modely. Aplikace NIC nestahuje – odkazy slouží jen jako informace, odkud si model stáhnout ručně.
/// Kontrolní součet:
///  - sha1 u modelů Whisper je zveřejněný v repozitáři whisper.cpp (models/README.md),
///  - sha256 u modelů z Hugging Face opíšeš ze stránky souboru („SHA256“) – aplikace ho porovná.
public struct CatalogModel: Identifiable, Equatable, Sendable {
    public var id: String
    public var kind: ModelKind
    public var name: String
    public var fileName: String
    public var approxSizeMB: Int
    public var sha256: String?
    public var sha1: String?
    public var source: String
    public var note: String
    public var recommended: Bool
}

public enum ModelCatalog {
    public static let models: [CatalogModel] = [
        .init(id: "gemma-3-4b-it-q4km", kind: .llm, name: "Gemma 3 4B Instruct (Q4_K_M)",
              fileName: "google_gemma-3-4b-it-Q4_K_M.gguf", approxSizeMB: 2500, sha256: nil, sha1: nil,
              source: "huggingface.co/bartowski/google_gemma-3-4b-it-GGUF",
              note: "Doporučený vypravěč: nejplynulejší čeština v této velikosti. Na iPhonu 14 Pro poběží s kontextem 4096.",
              recommended: true),
        .init(id: "qwen3-4b-instruct-2507-q4km", kind: .llm, name: "Qwen3 4B Instruct 2507 (Q4_K_M)",
              fileName: "Qwen3-4B-Instruct-2507-Q4_K_M.gguf", approxSizeMB: 2500, sha256: nil, sha1: nil,
              source: "huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF",
              note: "Alternativa: přesnější v pravidlech, čeština o něco strojovější.",
              recommended: false),
        .init(id: "whisper-large-v3-turbo-q5_0", kind: .speech, name: "Whisper large-v3-turbo (q5_0)",
              fileName: "ggml-large-v3-turbo-q5_0.bin", approxSizeMB: 547, sha256: nil,
              sha1: "e050f7970618a659205450ad97eb95a18d69c9ee",
              source: "huggingface.co/ggerganov/whisper.cpp",
              note: "Nepovinné – jen pokud chceš tahy říkat hlasem.", recommended: false),
    ]

    public static func match(fileName: String) -> CatalogModel? {
        models.first { $0.fileName.lowercased() == fileName.lowercased() }
    }
}

public struct FileDigest: Equatable, Sendable {
    public var sha256: String
    public var sha1: String
    public var size: Int64
}

public enum ModelVerifier {
    public enum Verdict: Equatable, Sendable {
        /// Shoda se známým nebo zadaným součtem.
        case verified(String)
        /// Součet se NESHODUJE – soubor odmítnout.
        case mismatch(expected: String, actual: String)
        /// Není s čím porovnat – uživatel musí výslovně potvrdit.
        case unknown
    }

    /// Spočítá SHA-256 a SHA-1 souboru po blocích (i pro soubory o velikosti GB).
    public static func digest(of url: URL, progress: ((Double) -> Void)? = nil,
                              isCancelled: () -> Bool = { false }) throws -> FileDigest {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        var h256 = SHA256()
        var h1 = Insecure.SHA1()
        var done: Int64 = 0
        while true {
            if isCancelled() { throw CocoaError(.userCancelled) }
            let chunk = try autoreleasepoolCompat { try handle.read(upToCount: 8 << 20) ?? Data() }
            if chunk.isEmpty { break }
            h256.update(data: chunk)
            h1.update(data: chunk)
            done += Int64(chunk.count)
            if size > 0 { progress?(Double(done) / Double(size)) }
        }
        return FileDigest(sha256: h256.finalize().map { String(format: "%02x", $0) }.joined(),
                          sha1: h1.finalize().map { String(format: "%02x", $0) }.joined(), size: done)
    }

    /// Porovná součet se zadaným (od uživatele) nebo s katalogem.
    public static func verdict(digest: FileDigest, fileName: String, expected: String?) -> Verdict {
        let exp = expected?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "sha256:", with: "")
        if let exp, !exp.isEmpty {
            if exp.count == 64 { return exp == digest.sha256 ? .verified("SHA-256") : .mismatch(expected: exp, actual: digest.sha256) }
            if exp.count == 40 { return exp == digest.sha1 ? .verified("SHA-1") : .mismatch(expected: exp, actual: digest.sha1) }
            return .mismatch(expected: exp, actual: digest.sha256)
        }
        if let m = ModelCatalog.match(fileName: fileName) {
            if let s = m.sha256 { return s == digest.sha256 ? .verified("SHA-256 (katalog)") : .mismatch(expected: s, actual: digest.sha256) }
            if let s = m.sha1 { return s == digest.sha1 ? .verified("SHA-1 (katalog whisper.cpp)") : .mismatch(expected: s, actual: digest.sha1) }
        }
        return .unknown
    }

    /// Kontrola hlavičky souboru – GGUF pro LLM/embedding, ggml pro Whisper.
    public static func checkMagic(url: URL, kind: ModelKind) -> Bool {
        guard let h = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? h.close() }
        guard let head = try? h.read(upToCount: 4), head.count == 4 else { return false }
        switch kind {
        case .llm: return head == Data("GGUF".utf8)
        case .speech: return head == Data([0x6c, 0x6d, 0x67, 0x67]) // 0x67676d6c little-endian ("ggml")
        }
    }
}

@inline(__always)
func autoreleasepoolCompat<T>(_ body: () throws -> T) rethrows -> T {
    #if canImport(ObjectiveC)
    return try autoreleasepool(invoking: body)
    #else
    return try body()
    #endif
}
