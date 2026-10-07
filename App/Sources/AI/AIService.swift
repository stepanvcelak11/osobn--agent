import Foundation
import SwiftUI
import AgentCore
import LlamaKit
import WhisperBridge

/// Drží načtené lokální modely (jazykový model, vektory, řeč).
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
    @Published private(set) var embeddingState: State = .none

    private(set) var llm: LlamaEngine?
    private(set) var embedder: LlamaEmbedder?
    private var whisper: WhisperTranscriber?
    private var whisperModelId: String?
    private var whisperReleaseTask: Task<Void, Never>?

    var contextLength: Int {
        get { UserDefaults.standard.object(forKey: "llm.context") as? Int ?? 3072 }
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
        let options = opts
        do {
            let engine = try await Task.detached(priority: .userInitiated) {
                try LlamaEngine(path: path, name: name, options: options)
            }.value
            llm = engine
            llmState = .ready(name)
        } catch {
            llmState = .failed(String(describing: error))
        }
    }

    func loadEmbedder(_ m: InstalledModel?) async {
        guard let m else { embedder = nil; embeddingState = .none; return }
        if case .ready(let n) = embeddingState, n == m.displayName, embedder != nil { return }
        embeddingState = .loading(m.displayName)
        let path = m.url.path, id = m.id
        do {
            embedder = try await Task.detached(priority: .utility) { try LlamaEmbedder(path: path, modelId: id) }.value
            embeddingState = .ready(m.displayName)
        } catch {
            embedder = nil
            embeddingState = .failed(String(describing: error))
        }
    }

    /// Whisper se načítá až při prvním diktování a po chvíli se uvolní (šetří paměť).
    func transcriber(for m: InstalledModel?) async throws -> WhisperTranscriber {
        guard let m else { throw SpeechError.noModel }
        scheduleWhisperRelease()
        if let whisper, whisperModelId == m.id { return whisper }
        speechState = .loading(m.displayName)
        let path = m.url.path
        do {
            let w = try await Task.detached(priority: .userInitiated) { try WhisperTranscriber(modelPath: path) }.value
            whisper = w
            whisperModelId = m.id
            speechState = .ready(m.displayName)
            return w
        } catch {
            speechState = .failed(String(describing: error))
            throw error
        }
    }

    /// Whisper (~0,5–1 GB) se uvolní po 2 minutách bez diktování – šetří paměť pro jazykový model.
    private func scheduleWhisperRelease() {
        whisperReleaseTask?.cancel()
        whisperReleaseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000_000)
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

    /// Při zamčení: z paměti modelu zmizí kontext konverzace (KV cache).
    func clearSensitiveState() {
        llm?.resetCache()
        releaseSpeech()
    }

    func unloadAll() {
        llm = nil; embedder = nil; whisper = nil; whisperModelId = nil
        llmState = .none; embeddingState = .none; speechState = .none
    }

    /// Při nedostatku paměti uvolníme nejdřív řeč a vektory.
    func handleMemoryWarning() {
        releaseSpeech()
        embedder = nil
        embeddingState = .none
    }
}

enum SpeechError: LocalizedError {
    case noModel
    case micDenied
    case tooShort
    case busy

    var errorDescription: String? {
        switch self {
        case .noModel: return "Není nahraný model pro rozpoznávání řeči (Nastavení → Modely)."
        case .micDenied: return "Aplikace nemá přístup k mikrofonu (Nastavení iOS → Osobní agent)."
        case .tooShort: return "Nahrávka je příliš krátká."
        case .busy: return "Právě běží nahrávání přednášky – diktování teď nejde. Napiš to prosím."
        }
    }
}
