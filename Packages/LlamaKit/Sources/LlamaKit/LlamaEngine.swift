import Foundation
import RealmCore
@_implementationOnly import llama

public struct LlamaLoadOptions: Sendable {
    public var contextLength: Int = 3072
    public var gpuLayers: Int32 = 99
    public var threads: Int32 = Int32(max(2, min(4, ProcessInfo.processInfo.activeProcessorCount - 2)))
    public init() {}
}

public enum LlamaError: Error, CustomStringConvertible {
    case loadFailed(String)
    case contextFailed
    case tokenizeFailed

    public var description: String {
        switch self {
        case .loadFailed(let p): return "Model se nepodařilo načíst (\((p as NSString).lastPathComponent)). Je soubor celý a ve formátu GGUF?"
        case .contextFailed: return "Nepodařilo se vytvořit kontext modelu (málo paměti?)"
        case .tokenizeFailed: return "Chyba tokenizace"
        }
    }
}

/// Jednorázová inicializace backendu llama.cpp. Logy potlačíme – nesmí obsahovat obsah konverzací.
enum LlamaBackend {
    static let initialize: Void = {
        llama_log_set({ _, _, _ in }, nil)
        llama_backend_init()
    }()
}

/// Lokální jazykový model nad llama.cpp (Metal na iPhonu). Vše běží na jedné sériové frontě.
public final class LlamaEngine: LanguageModel, @unchecked Sendable {
    public let displayName: String
    public let template: ChatTemplate
    public let contextLength: Int
    public let modelSizeBytes: UInt64

    private let model: OpaquePointer
    private let ctx: OpaquePointer
    private let vocab: OpaquePointer
    private let queue = DispatchQueue(label: "cz.osobniagent.llama", qos: .userInitiated)
    private var cachedTokens: [llama_token] = []
    private let nBatch: Int32 = 512
    private var cancelRequested = false

    /// Načte model ze souboru (blokuje – volat mimo hlavní vlákno).
    public init(path: String, name: String, options: LlamaLoadOptions = LlamaLoadOptions()) throws {
        _ = LlamaBackend.initialize
        var mp = llama_model_default_params()
        mp.n_gpu_layers = options.gpuLayers
        guard let m = llama_model_load_from_file(path, mp) else { throw LlamaError.loadFailed(path) }
        var cp = llama_context_default_params()
        cp.n_ctx = UInt32(options.contextLength)
        cp.n_batch = UInt32(nBatch)
        cp.n_ubatch = UInt32(nBatch)
        cp.n_threads = options.threads
        cp.n_threads_batch = options.threads
        cp.no_perf = true
        guard let c = llama_init_from_model(m, cp) else {
            llama_model_free(m)
            throw LlamaError.contextFailed
        }
        model = m
        ctx = c
        vocab = llama_model_get_vocab(m)
        displayName = name
        contextLength = Int(llama_n_ctx(c))
        modelSizeBytes = llama_model_size(m)
        if let t = llama_model_chat_template(m, nil) {
            template = ChatTemplate.detect(templateString: String(cString: t))
        } else {
            template = .chatml
        }
    }

    deinit {
        llama_free(ctx)
        llama_model_free(model)
    }

    public func cancel() { cancelRequested = true }

    public func countTokens(_ text: String) -> Int {
        queue.sync { (try? tokenize(text, addSpecial: false).count) ?? text.count / 3 }
    }

    // MARK: - Generování

    public func generate(prompt: String, options: GenerationOptions,
                         onToken: @escaping @Sendable (String) -> Bool) async throws -> (text: String, stats: GenerationStats) {
        cancelRequested = false
        return try await withCheckedThrowingContinuation { cont in
            queue.async {
                do {
                    let r = try self.generateSync(prompt: prompt, options: options, onToken: onToken)
                    cont.resume(returning: r)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func generateSync(prompt: String, options: GenerationOptions,
                              onToken: (String) -> Bool) throws -> (text: String, stats: GenerationStats) {
        var stats = GenerationStats()
        let tokens = try tokenize(prompt, addSpecial: true)
        let nCtx = Int(llama_n_ctx(ctx))
        guard tokens.count + options.maxTokens < nCtx else { throw LanguageModelError.contextOverflow }
        stats.promptTokens = tokens.count

        // Znovupoužití KV cache pro společný začátek (systémový prompt, historie).
        var common = 0
        while common < min(cachedTokens.count, tokens.count) && cachedTokens[common] == tokens[common] { common += 1 }
        if common == tokens.count { common -= 1 }
        let mem = llama_get_memory(ctx)
        if !llama_memory_seq_rm(mem, 0, llama_pos(common), -1) {
            llama_memory_clear(mem, true)
            common = 0
        }
        cachedTokens = Array(cachedTokens.prefix(common))
        stats.cachedPromptTokens = common

        let t0 = Date()
        var pos = common
        while pos < tokens.count {
            let end = min(pos + Int(nBatch), tokens.count)
            try decode(Array(tokens[pos..<end]), startPos: pos, logitsForLast: end == tokens.count)
            cachedTokens.append(contentsOf: tokens[pos..<end])
            pos = end
        }
        stats.promptSeconds = Date().timeIntervalSince(t0)

        // Vzorkování
        let sampler = try makeSampler(options)
        defer { llama_sampler_free(sampler) }

        let t1 = Date()
        var output = ""
        var pendingBytes: [UInt8] = []
        let stops = template.stopStrings
        for _ in 0..<options.maxTokens {
            if cancelRequested { break }
            let tok = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, tok) { break }
            pendingBytes += piece(tok)
            var text = ""
            if let s = String(bytes: pendingBytes, encoding: .utf8) {
                text = s; pendingBytes.removeAll()
            } else if pendingBytes.count >= 4 {
                text = String(decoding: pendingBytes, as: UTF8.self); pendingBytes.removeAll()
            }
            stats.generatedTokens += 1
            if !text.isEmpty {
                output += text
                if !onToken(text) { break }
            }
            if let stop = stops.first(where: { output.hasSuffix($0) }) {
                output = String(output.dropLast(stop.count))
                break
            }
            try decode([tok], startPos: cachedTokens.count, logitsForLast: true)
            cachedTokens.append(tok)
        }
        stats.generationSeconds = Date().timeIntervalSince(t1)
        return (output, stats)
    }

    private func makeSampler(_ o: GenerationOptions) throws -> UnsafeMutablePointer<llama_sampler> {
        let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())!
        if let g = o.grammar {
            guard let gs = llama_sampler_init_grammar(vocab, g, "root") else {
                llama_sampler_free(chain)
                throw LanguageModelError.grammarInvalid
            }
            llama_sampler_chain_add(chain, gs)
        }
        if o.temperature <= 0 {
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        } else {
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(40))
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(o.topP, 1))
            llama_sampler_chain_add(chain, llama_sampler_init_temp(o.temperature))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(o.seed))
        }
        return chain
    }

    private func decode(_ toks: [llama_token], startPos: Int, logitsForLast: Bool) throws {
        var batch = llama_batch_init(Int32(toks.count), 0, 1)
        defer { llama_batch_free(batch) }
        for (i, t) in toks.enumerated() {
            batch.token[i] = t
            batch.pos[i] = llama_pos(startPos + i)
            batch.n_seq_id[i] = 1
            batch.seq_id[i]![0] = 0
            batch.logits[i] = (logitsForLast && i == toks.count - 1) ? 1 : 0
        }
        batch.n_tokens = Int32(toks.count)
        let rc = llama_decode(ctx, batch)
        if rc != 0 { throw LanguageModelError.decodeFailed(rc) }
    }

    private func tokenize(_ text: String, addSpecial: Bool) throws -> [llama_token] {
        let utf8Count = text.utf8.count
        var buf = [llama_token](repeating: 0, count: utf8Count + 16)
        var n = llama_tokenize(vocab, text, Int32(utf8Count), &buf, Int32(buf.count), addSpecial, true)
        if n < 0 {
            buf = [llama_token](repeating: 0, count: Int(-n))
            n = llama_tokenize(vocab, text, Int32(utf8Count), &buf, Int32(buf.count), addSpecial, true)
        }
        guard n >= 0 else { throw LlamaError.tokenizeFailed }
        return Array(buf.prefix(Int(n)))
    }

    private func piece(_ tok: llama_token) -> [UInt8] {
        var buf = [CChar](repeating: 0, count: 64)
        var n = llama_token_to_piece(vocab, tok, &buf, Int32(buf.count), 0, false)
        if n < 0 {
            buf = [CChar](repeating: 0, count: Int(-n))
            n = llama_token_to_piece(vocab, tok, &buf, Int32(buf.count), 0, false)
        }
        return buf.prefix(Int(max(0, n))).map { UInt8(bitPattern: $0) }
    }

    /// Uvolní KV cache (např. po smazání historie).
    public func resetCache() {
        queue.sync {
            llama_memory_clear(llama_get_memory(ctx), true)
            cachedTokens = []
        }
    }
}

/// Model pro vektory (embeddingy) nad llama.cpp.
public final class LlamaEmbedder: EmbeddingModel, @unchecked Sendable {
    public let modelId: String
    private let model: OpaquePointer
    private let ctx: OpaquePointer
    private let vocab: OpaquePointer
    private let nEmbd: Int
    private let maxTokens: Int = 512
    private let queue = DispatchQueue(label: "cz.osobniagent.embed", qos: .utility)
    /// Prefixy podle rodiny modelu (EmbeddingGemma / E5).
    private let queryPrefix: String
    private let docPrefix: String

    public init(path: String, modelId: String) throws {
        _ = LlamaBackend.initialize
        var mp = llama_model_default_params()
        mp.n_gpu_layers = 99
        guard let m = llama_model_load_from_file(path, mp) else { throw LlamaError.loadFailed(path) }
        var cp = llama_context_default_params()
        cp.n_ctx = 512
        cp.n_batch = 512
        cp.n_ubatch = 512
        cp.embeddings = true
        cp.no_perf = true
        guard let c = llama_init_from_model(m, cp) else { llama_model_free(m); throw LlamaError.contextFailed }
        model = m; ctx = c; vocab = llama_model_get_vocab(m)
        nEmbd = Int(llama_model_n_embd_out(m) > 0 ? llama_model_n_embd_out(m) : llama_model_n_embd(m))
        self.modelId = modelId
        let lower = (path as NSString).lastPathComponent.lowercased()
        if lower.contains("embeddinggemma") {
            queryPrefix = "task: search result | query: "
            docPrefix = "title: none | text: "
        } else if lower.contains("e5") {
            queryPrefix = "query: "; docPrefix = "passage: "
        } else {
            queryPrefix = ""; docPrefix = ""
        }
    }

    deinit {
        llama_free(ctx)
        llama_model_free(model)
    }

    public func embed(_ text: String, isQuery: Bool) async throws -> [Float] {
        let input = (isQuery ? queryPrefix : docPrefix) + text
        return try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { cont.resume(returning: try self.embedSync(input)) } catch { cont.resume(throwing: error) }
            }
        }
    }

    private func embedSync(_ text: String) throws -> [Float] {
        let utf8Count = text.utf8.count
        var buf = [llama_token](repeating: 0, count: utf8Count + 16)
        var n = llama_tokenize(vocab, text, Int32(utf8Count), &buf, Int32(buf.count), true, false)
        if n < 0 { buf = [llama_token](repeating: 0, count: Int(-n)); n = llama_tokenize(vocab, text, Int32(utf8Count), &buf, Int32(buf.count), true, false) }
        guard n > 0 else { throw LlamaError.tokenizeFailed }
        let toks = Array(buf.prefix(min(Int(n), maxTokens)))
        llama_memory_clear(llama_get_memory(ctx), true)
        var batch = llama_batch_init(Int32(toks.count), 0, 1)
        defer { llama_batch_free(batch) }
        for (i, t) in toks.enumerated() {
            batch.token[i] = t
            batch.pos[i] = llama_pos(i)
            batch.n_seq_id[i] = 1
            batch.seq_id[i]![0] = 0
            batch.logits[i] = 1
        }
        batch.n_tokens = Int32(toks.count)
        let rc = llama_decode(ctx, batch)
        guard rc == 0 else { throw LanguageModelError.decodeFailed(rc) }
        if let p = llama_get_embeddings_seq(ctx, 0) {
            return Array(UnsafeBufferPointer(start: p, count: nEmbd))
        }
        // Bez poolingu – průměr přes tokeny.
        var sum = [Float](repeating: 0, count: nEmbd)
        var count = 0
        for i in 0..<toks.count {
            guard let p = llama_get_embeddings_ith(ctx, Int32(i)) else { continue }
            for j in 0..<nEmbd { sum[j] += p[j] }
            count += 1
        }
        return count > 0 ? sum.map { $0 / Float(count) } : sum
    }
}
