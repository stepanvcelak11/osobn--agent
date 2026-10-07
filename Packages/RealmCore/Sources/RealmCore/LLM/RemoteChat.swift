import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Model, který místo jednoho textového promptu bere zprávy (online API).
public protocol ChatModel: LanguageModel {
    func chat(system: String, messages: [PromptMessage], options: GenerationOptions,
              onToken: @escaping @Sendable (String) -> Bool) async throws -> (text: String, stats: GenerationStats)
}

public struct RemoteModelOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
}

/// Online vypravěč (volitelný). Hra je vždy hratelná offline – online je jen lepší vypravěč navrch.
public enum RemoteProvider: String, Codable, CaseIterable, Sendable, Identifiable {
    case anthropic, gemini
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .anthropic: return "Claude (Anthropic)"
        case .gemini: return "Gemini (Google)"
        }
    }

    public var models: [RemoteModelOption] {
        switch self {
        case .anthropic: return [.init(id: "claude-haiku-4-5-20251001", label: "Claude Haiku 4.5 – rychlý a levný"),
                                 .init(id: "claude-sonnet-5-5", label: "Claude Sonnet 5.5 – nejlepší vyprávění"),
                                 .init(id: "claude-opus-5-5", label: "Claude Opus 5.5 – nejchytřejší, nejdražší")]
        case .gemini: return [.init(id: "gemini-flash-latest", label: "Gemini Flash – rychlý, má bezplatnou úroveň"),
                              .init(id: "gemini-flash-lite-latest", label: "Gemini Flash-Lite – nejrychlejší"),
                              .init(id: "gemini-pro-latest", label: "Gemini Pro – nejlepší, pomalejší")]
        }
    }

    public var defaultModel: String { models[0].id }

    public var keyURL: String {
        switch self {
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        }
    }

    public var keyHint: String {
        switch self {
        case .anthropic: return "Klíč začíná „sk-ant-“. Platí se podle spotřeby (kredit na console.anthropic.com)."
        case .gemini: return "Klíč z Google AI Studia. Bezplatná úroveň stačí na běžné hraní; Google ale může texty z bezplatné úrovně používat ke zlepšování svých služeb."
        }
    }
}

public struct RemoteConfig: Equatable, Sendable {
    public var provider: RemoteProvider
    public var model: String
    public var apiKey: String
    public init(provider: RemoteProvider, model: String, apiKey: String) {
        self.provider = provider; self.model = model.isEmpty ? provider.defaultModel : model; self.apiKey = apiKey
    }
}

public enum RemoteError: Error, CustomStringConvertible, Sendable {
    case http(Int, String)
    case api(String)
    case empty

    public var description: String {
        switch self {
        case .http(let code, let m):
            switch code {
            case 401, 403: return "Online vypravěč: neplatný klíč (\(m))"
            case 429: return "Online vypravěč: vyčerpaný limit nebo kredit (\(m))"
            default: return "Online vypravěč: chyba \(code) (\(m))"
            }
        case .api(let m): return "Online vypravěč: \(m)"
        case .empty: return "Online vypravěč neodpověděl"
        }
    }
}

/// Sestavení požadavků a čtení streamu (SSE) – bez sítě, aby šlo testovat.
public enum RemoteAPI {
    public static func request(_ c: RemoteConfig, system: String, messages: [PromptMessage],
                               maxTokens: Int, temperature: Float) throws -> URLRequest {
        let body: [String: Any]
        var req: URLRequest
        switch c.provider {
        case .anthropic:
            req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            req.setValue(c.apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            var msgs: [[String: Any]] = messages.map { ["role": $0.role == .assistant ? "assistant" : "user", "content": $0.content] }
            // Historie se jen prodlužuje – poslední zpráva jako bod cache zlevní další tahy.
            if var last = msgs.last, let text = last["content"] as? String {
                last["content"] = [["type": "text", "text": text, "cache_control": ["type": "ephemeral"]]]
                msgs[msgs.count - 1] = last
            }
            body = ["model": c.model, "max_tokens": maxTokens, "temperature": Double(temperature), "stream": true,
                    "system": [["type": "text", "text": system, "cache_control": ["type": "ephemeral"]]],
                    "messages": msgs]
        case .gemini:
            let model = c.model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? c.model
            req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse")!)
            req.setValue(c.apiKey, forHTTPHeaderField: "x-goog-api-key")
            let safety = ["HARM_CATEGORY_HARASSMENT", "HARM_CATEGORY_HATE_SPEECH", "HARM_CATEGORY_SEXUALLY_EXPLICIT", "HARM_CATEGORY_DANGEROUS_CONTENT"]
                .map { ["category": $0, "threshold": "BLOCK_ONLY_HIGH"] }
            body = ["systemInstruction": ["parts": [["text": system]]],
                    "contents": messages.map { ["role": $0.role == .assistant ? "model" : "user", "parts": [["text": $0.content]]] },
                    "generationConfig": ["temperature": Double(temperature), "maxOutputTokens": maxTokens],
                    "safetySettings": safety]
        }
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    /// Jeden řádek streamu → kousek textu (nil = řádek bez textu). Chyba ve streamu se vyhodí.
    public static func delta(_ p: RemoteProvider, line: String) throws -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard payload != "[DONE]", let data = payload.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = obj["error"] as? [String: Any] { throw RemoteError.api(err["message"] as? String ?? "chyba") }
        switch p {
        case .anthropic:
            guard obj["type"] as? String == "content_block_delta", let d = obj["delta"] as? [String: Any] else { return nil }
            return d["text"] as? String
        case .gemini:
            guard let c = (obj["candidates"] as? [[String: Any]])?.first,
                  let parts = (c["content"] as? [String: Any])?["parts"] as? [[String: Any]] else { return nil }
            // „Myšlenky“ modelu nevypisujeme, jen odpověď.
            let text = parts.filter { ($0["thought"] as? Bool) != true }.compactMap { $0["text"] as? String }.joined()
            return text.isEmpty ? nil : text
        }
    }

    /// Čitelná chyba z odpovědi serveru.
    public static func errorMessage(_ data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["error"] as? [String: Any], let m = err["message"] as? String { return String(m.prefix(160)) }
        return String(decoding: data.prefix(160), as: UTF8.self)
    }
}

/// Online vypravěč se zálohou: když není signál nebo online selže, hned vypráví model v telefonu.
public final class HybridModel: ChatModel, @unchecked Sendable {
    public let primary: ChatModel
    public let backup: LanguageModel?
    /// Vyprávěl poslední tah online vypravěč?
    public private(set) var lastWasOnline = false
    public private(set) var lastError: String?

    public init(primary: ChatModel, backup: LanguageModel?) { self.primary = primary; self.backup = backup }

    public var displayName: String { primary.displayName }
    public var template: ChatTemplate { primary.template }
    public var contextLength: Int { primary.contextLength }
    public func countTokens(_ text: String) -> Int { primary.countTokens(text) }

    public func generate(prompt: String, options: GenerationOptions, onToken: @escaping @Sendable (String) -> Bool) async throws -> (text: String, stats: GenerationStats) {
        guard let backup else { throw LanguageModelError.notLoaded }
        return try await backup.generate(prompt: prompt, options: options, onToken: onToken)
    }

    public func chat(system: String, messages: [PromptMessage], options: GenerationOptions,
                     onToken: @escaping @Sendable (String) -> Bool) async throws -> (text: String, stats: GenerationStats) {
        do {
            let r = try await primary.chat(system: system, messages: messages, options: options, onToken: onToken)
            guard r.text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 15 else { throw RemoteError.empty }
            lastWasOnline = true
            lastError = nil
            return r
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            lastError = (error as? RemoteError)?.description ?? "Online vypravěč není dostupný"
            lastWasOnline = false
            guard let backup else { throw error }
            let trimmed = Self.fit(system: system, messages: messages, for: backup, reserve: options.maxTokens + 64)
            return try await backup.generate(prompt: backup.template.render(trimmed), options: options, onToken: onToken)
        }
    }

    /// Zkrátí historii tak, aby se vešla do menšího modelu v telefonu.
    static func fit(system: String, messages: [PromptMessage], for m: LanguageModel, reserve: Int) -> [PromptMessage] {
        var rest = messages
        while true {
            let all = [PromptMessage(.system, system)] + rest
            if rest.count <= 1 || m.countTokens(m.template.render(all)) <= m.contextLength - reserve { return all }
            rest.removeFirst(min(2, rest.count - 1))
        }
    }
}
