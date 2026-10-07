import Foundation

public struct GenerationOptions: Sendable {
    public var maxTokens: Int = 384
    public var temperature: Float = 0.2
    public var topP: Float = 0.9
    public var grammar: String?
    public var seed: UInt32 = 42
    /// Text, jehož slovní obraty se nemají opakovat (předchozí vyprávění) – modely v telefonu ho „přečtou“
    /// do paměti postihu za opakování.
    public var avoidRepeating: String?
    public init(maxTokens: Int = 384, temperature: Float = 0.2, topP: Float = 0.9, grammar: String? = nil) {
        self.maxTokens = maxTokens; self.temperature = temperature; self.topP = topP; self.grammar = grammar
    }
}

public struct GenerationStats: Codable, Equatable, Sendable {
    public var promptTokens: Int = 0
    public var cachedPromptTokens: Int = 0
    public var generatedTokens: Int = 0
    public var promptSeconds: Double = 0
    public var generationSeconds: Double = 0
    public init() {}

    public var tokensPerSecond: Double { generationSeconds > 0 ? Double(generatedTokens) / generationSeconds : 0 }
    public var promptTokensPerSecond: Double {
        let n = promptTokens - cachedPromptTokens
        return promptSeconds > 0 ? Double(n) / promptSeconds : 0
    }
}

public enum LanguageModelError: Error, CustomStringConvertible {
    case notLoaded
    case contextOverflow
    case decodeFailed(Int32)
    case grammarInvalid
    case cancelled

    public var description: String {
        switch self {
        case .notLoaded: return "Model není načten"
        case .contextOverflow: return "Text je na model příliš dlouhý"
        case .decodeFailed(let c): return "Chyba výpočtu modelu (\(c))"
        case .grammarInvalid: return "Neplatná gramatika výstupu"
        case .cancelled: return "Přerušeno"
        }
    }
}

/// Lokální jazykový model (na iOS implementováno nad llama.cpp, v testech mock).
public protocol LanguageModel: AnyObject, Sendable {
    var displayName: String { get }
    var template: ChatTemplate { get }
    var contextLength: Int { get }
    /// Vygeneruje text. `onToken` vrací false = přerušit.
    func generate(prompt: String, options: GenerationOptions,
                  onToken: @escaping @Sendable (String) -> Bool) async throws -> (text: String, stats: GenerationStats)
    func countTokens(_ text: String) -> Int
}

/// Model pro vektory (sémantické hledání).
public protocol EmbeddingModel: AnyObject, Sendable {
    var modelId: String { get }
    func embed(_ text: String, isQuery: Bool) async throws -> [Float]
}

public struct PromptMessage: Equatable, Sendable {
    public enum Role: String, Sendable { case system, user, assistant }
    public var role: Role
    public var content: String
    public init(_ role: Role, _ content: String) { self.role = role; self.content = content }
}

/// Formát konverzace pro konkrétní rodinu modelů.
public enum ChatTemplate: String, Codable, Sendable, CaseIterable {
    case chatml          // Qwen, mnoho dalších
    case chatmlNoThink   // Qwen3 s přepínačem myšlení – vypneme ho
    case gemma
    case llama3
    case phi

    /// Rozpozná šablonu z metadat GGUF (`tokenizer.chat_template`).
    public static func detect(templateString: String?) -> ChatTemplate {
        guard let t = templateString else { return .chatml }
        if t.contains("<start_of_turn>") { return .gemma }
        if t.contains("<|start_header_id|>") { return .llama3 }
        if t.contains("<|im_start|>") {
            return t.contains("enable_thinking") || t.contains("<think>") ? .chatmlNoThink : .chatml
        }
        if t.contains("<|user|>") && t.contains("<|end|>") { return .phi }
        return .chatml
    }

    public func render(_ messages: [PromptMessage], addGenerationPrompt: Bool = true) -> String {
        var s = ""
        switch self {
        case .chatml, .chatmlNoThink:
            for m in messages { s += "<|im_start|>\(m.role.rawValue)\n\(m.content)<|im_end|>\n" }
            if addGenerationPrompt {
                s += "<|im_start|>assistant\n"
                if self == .chatmlNoThink { s += "<think>\n\n</think>\n\n" }
            }
        case .gemma:
            // Gemma nemá roli system – vloží se na začátek první zprávy uživatele.
            var pendingSystem: String?
            for m in messages {
                switch m.role {
                case .system: pendingSystem = (pendingSystem.map { $0 + "\n\n" } ?? "") + m.content
                case .user:
                    let content = pendingSystem.map { $0 + "\n\n" + m.content } ?? m.content
                    pendingSystem = nil
                    s += "<start_of_turn>user\n\(content)<end_of_turn>\n"
                case .assistant:
                    s += "<start_of_turn>model\n\(m.content)<end_of_turn>\n"
                }
            }
            if addGenerationPrompt { s += "<start_of_turn>model\n" }
        case .llama3:
            for m in messages {
                s += "<|start_header_id|>\(m.role.rawValue)<|end_header_id|>\n\n\(m.content)<|eot_id|>"
            }
            if addGenerationPrompt { s += "<|start_header_id|>assistant<|end_header_id|>\n\n" }
        case .phi:
            for m in messages { s += "<|\(m.role.rawValue)|>\n\(m.content)<|end|>\n" }
            if addGenerationPrompt { s += "<|assistant|>\n" }
        }
        return s
    }

    /// Řetězce, které ukončují odpověď (záloha k EOG tokenům).
    public var stopStrings: [String] {
        switch self {
        case .chatml, .chatmlNoThink: return ["<|im_end|>", "<|im_start|>"]
        case .gemma: return ["<end_of_turn>", "<start_of_turn>"]
        case .llama3: return ["<|eot_id|>", "<|start_header_id|>"]
        case .phi: return ["<|end|>", "<|user|>"]
        }
    }
}

/// Ochrana před vložením řídicích sekvencí šablony do dat uživatele (prompt/template injection).
public enum PromptSanitizer {
    static let dangerous: [(String, String)] = [
        ("<|", "‹|"), ("|>", "|›"),
        ("<start_of_turn>", "‹start_of_turn›"), ("<end_of_turn>", "‹end_of_turn›"),
        ("<bos>", "‹bos›"), ("<eos>", "‹eos›"), ("</s>", "‹/s›"), ("<s>", "‹s›"),
        ("[INST]", "[INST ]"), ("[/INST]", "[/INST ]"),
        ("<think>", "‹think›"), ("</think>", "‹/think›"),
        ("<data>", "‹data›"), ("</data>", "‹/data›"),
    ]

    public static func clean(_ s: String) -> String {
        var out = s
        for (a, b) in dangerous where out.contains(a) { out = out.replacingOccurrences(of: a, with: b) }
        return out
    }

    /// Zabalí data do značek, které model chápe jako „data, ne instrukce“.
    public static func wrapData(_ s: String) -> String { "<data>\n" + clean(s) + "\n</data>" }
}
