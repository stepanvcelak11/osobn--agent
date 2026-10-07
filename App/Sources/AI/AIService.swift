import Foundation
import SwiftUI
import RealmCore
#if !SHOTS
import LlamaKit
import WhisperBridge
#else
/// Cíl pro snímky v simulátoru: llama.cpp ani whisper.cpp nemají simulátorovou knihovnu.
final class LlamaEngine: LanguageModel, @unchecked Sendable {
    var displayName: String { "" }
    var template: ChatTemplate { .chatml }
    var contextLength: Int { 0 }
    func generate(prompt: String, options: GenerationOptions, onToken: @escaping @Sendable (String) -> Bool) async throws -> (text: String, stats: GenerationStats) { ("", GenerationStats()) }
    func countTokens(_ text: String) -> Int { 0 }
    func resetCache() {}
}
struct LlamaLoadOptions { var contextLength = 0 }
final class WhisperTranscriber {
    func transcribe(samples: [Float], language: String, initialPrompt: String?) async throws -> String { "" }
}
#endif

/// Drží načtené lokální modely (vypravěč a volitelně rozpoznávání řeči).
@MainActor
final class AIService: ObservableObject {
    enum State: Equatable {
        case none
        case loading(String)
        case ready(String)
        case failed(String)
    }

    @Published private(set) var llmState: State = .none
    @Published private(set) var speechState: State = .none

    private(set) var llm: LlamaEngine?
    private var whisper: WhisperTranscriber?
    private var whisperModelId: String?
    private var whisperReleaseTask: Task<Void, Never>?

    var contextLength: Int {
        get { UserDefaults.standard.object(forKey: "llm.context") as? Int ?? 4096 }
        set { UserDefaults.standard.set(newValue, forKey: "llm.context") }
    }

    var isLLMReady: Bool { if case .ready = llmState { return true } else { return false } }

    func loadLLM(_ m: InstalledModel?) async {
        guard let m else { llm = nil; llmState = .none; return }
        if case .ready(let n) = llmState, n == m.displayName, llm != nil { return }
        llm = nil
        llmState = .loading(m.displayName)
        let path = m.url.path, name = m.displayName
        var opts = LlamaLoadOptions()
        opts.contextLength = contextLength
        #if !SHOTS
        // Celý model běží na grafickém čipu; procesoru stačí dvě vlákna (víc jen zbytečně hřeje).
        opts.threads = 2
        #endif
        let options = opts
        do {
            #if SHOTS
            let engine = LlamaEngine()
            _ = (path, name, options)
            if engine.contextLength == 0 { throw SpeechError.noModel }
            #else
            let engine = try await Task.detached(priority: .userInitiated) {
                try LlamaEngine(path: path, name: name, options: options)
            }.value
            #endif
            llm = engine
            llmState = .ready(name)
        } catch {
            llmState = .failed(String(describing: error))
        }
    }

    /// Whisper se načítá až při prvním diktování a po chvíli se uvolní (šetří paměť pro vypravěče).
    func transcriber(for m: InstalledModel?) async throws -> WhisperTranscriber {
        guard let m else { throw SpeechError.noModel }
        scheduleWhisperRelease()
        if let whisper, whisperModelId == m.id { return whisper }
        speechState = .loading(m.displayName)
        let path = m.url.path
        do {
            #if SHOTS
            _ = path
            let w = WhisperTranscriber()
            #else
            let w = try await Task.detached(priority: .userInitiated) { try WhisperTranscriber(modelPath: path) }.value
            #endif
            whisper = w
            whisperModelId = m.id
            speechState = .ready(m.displayName)
            return w
        } catch {
            speechState = .failed(String(describing: error))
            throw error
        }
    }

    private func scheduleWhisperRelease() {
        whisperReleaseTask?.cancel()
        whisperReleaseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 90_000_000_000)
            guard !Task.isCancelled else { return }
            self?.releaseSpeech()
        }
    }

    func releaseSpeech() {
        whisperReleaseTask?.cancel()
        whisperReleaseTask = nil
        whisper = nil
        whisperModelId = nil
        speechState = .none
    }

    /// Nová hra = nový kontext; starý příběh nemá v paměti modelu co dělat.
    func resetContext() { llm?.resetCache() }

    func handleMemoryWarning() { releaseSpeech() }
}

enum SpeechError: LocalizedError {
    case noModel, micDenied, tooShort

    var errorDescription: String? {
        switch self {
        case .noModel: return "Není nahraný model pro rozpoznávání řeči (Modely)."
        case .micDenied: return "Aplikace nemá přístup k mikrofonu (Nastavení iOS → Pocket Realm)."
        case .tooShort: return "Nahrávka je příliš krátká."
        }
    }
}
