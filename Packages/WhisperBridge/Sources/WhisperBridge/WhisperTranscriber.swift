import Foundation
@_implementationOnly import whisper

public enum WhisperError: Error, CustomStringConvertible {
    case loadFailed
    case transcriptionFailed(Int32)

    public var description: String {
        switch self {
        case .loadFailed: return "Model pro rozpoznávání řeči se nepodařilo načíst"
        case .transcriptionFailed(let c): return "Přepis řeči selhal (\(c))"
        }
    }
}

/// Offline přepis řeči (whisper.cpp). Zvuk se zpracuje jen v paměti, nikam se neukládá ani neposílá.
public final class WhisperTranscriber: @unchecked Sendable {
    private let ctx: OpaquePointer
    private let queue = DispatchQueue(label: "cz.osobniagent.whisper", qos: .userInitiated)

    public init(modelPath: String, useGPU: Bool = true) throws {
        whisper_log_set({ _, _, _ in }, nil)
        var p = whisper_context_default_params()
        p.use_gpu = useGPU
        p.flash_attn = true
        guard let c = whisper_init_from_file_with_params(modelPath, p) else { throw WhisperError.loadFailed }
        ctx = c
    }

    deinit { whisper_free(ctx) }

    /// Přepíše 16 kHz mono float PCM na text (čeština).
    public func transcribe(samples: [Float], language: String = "cs", initialPrompt: String? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { cont.resume(returning: try self.transcribeSync(samples, language: language, prompt: initialPrompt)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    private func transcribeSync(_ samples: [Float], language: String, prompt: String?) throws -> String {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(2, min(4, ProcessInfo.processInfo.activeProcessorCount - 2)))
        params.translate = false
        params.no_context = true
        params.no_timestamps = true
        params.single_segment = false
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.suppress_blank = true
        params.suppress_nst = true
        params.detect_language = false
        let rc: Int32 = language.withCString { lang in
            params.language = lang
            if let prompt {
                return prompt.withCString { pr in
                    params.initial_prompt = pr
                    return samples.withUnsafeBufferPointer { whisper_full(ctx, params, $0.baseAddress, Int32($0.count)) }
                }
            }
            return samples.withUnsafeBufferPointer { whisper_full(ctx, params, $0.baseAddress, Int32($0.count)) }
        }
        guard rc == 0 else { throw WhisperError.transcriptionFailed(rc) }
        var text = ""
        for i in 0..<whisper_full_n_segments(ctx) {
            if let c = whisper_full_get_segment_text(ctx, i) { text += String(cString: c) }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
