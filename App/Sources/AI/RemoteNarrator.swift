import Foundation
import Security
import RealmCore

/// Online vypravěč přes HTTPS (Claude nebo Gemini). Odpověď se čte průběžně (stream), takže text naskakuje hned.
final class RemoteChatModel: ChatModel, @unchecked Sendable {
    let config: RemoteConfig
    private let session: URLSession

    init(config: RemoteConfig) {
        self.config = config
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 30
        c.timeoutIntervalForResource = 90
        c.waitsForConnectivity = false
        session = URLSession(configuration: c)
    }

    var displayName: String { config.provider.models.first { $0.id == config.model }?.label ?? config.model }
    var template: ChatTemplate { .chatml }
    /// Online modely mají obří kontext; víc než ~16 tisíc tokenů historie by jen prodražovalo hraní.
    var contextLength: Int { 16_000 }
    func countTokens(_ text: String) -> Int { text.count / 3 }

    func generate(prompt: String, options: GenerationOptions, onToken: @escaping @Sendable (String) -> Bool) async throws -> (text: String, stats: GenerationStats) {
        throw LanguageModelError.notLoaded
    }

    func chat(system: String, messages: [PromptMessage], options: GenerationOptions,
              onToken: @escaping @Sendable (String) -> Bool) async throws -> (text: String, stats: GenerationStats) {
        let req = try RemoteAPI.request(config, system: system, messages: messages,
                                        maxTokens: max(options.maxTokens, 300), temperature: options.temperature)
        let started = Date()
        let (bytes, response) = try await session.bytes(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            var body = Data()
            for try await b in bytes { body.append(b); if body.count > 4000 { break } }
            throw RemoteError.http(status, RemoteAPI.errorMessage(body))
        }
        var text = ""
        var stats = GenerationStats()
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard let piece = try RemoteAPI.delta(config.provider, line: line) else { continue }
            text += piece
            stats.generatedTokens += 1
            if !onToken(piece) { break }
        }
        stats.generationSeconds = Date().timeIntervalSince(started)
        return (text, stats)
    }

    /// Krátký zkušební dotaz z nastavení.
    func test() async -> String? {
        do {
            let r = try await chat(system: "Odpovídej česky jednou krátkou větou.",
                                   messages: [PromptMessage(.user, "Pozdrav hráče temné fantasy hry.")],
                                   options: GenerationOptions(maxTokens: 60, temperature: 0.7), onToken: { _ in true })
            return r.text.isEmpty ? (RemoteError.empty.description) : nil
        } catch {
            return (error as? RemoteError)?.description ?? error.localizedDescription
        }
    }
}

/// Nastavení online vypravěče. Klíč je v Klíčence (Keychain), jen v tomto telefonu.
enum OnlineSettings {
    static let enabledKey = "online.enabled", providerKey = "online.provider", modelKey = "online.model"

    static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var provider: RemoteProvider {
        RemoteProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") ?? .gemini
    }
    static var model: String { UserDefaults.standard.string(forKey: modelKey) ?? "" }

    static func apiKey(_ p: RemoteProvider) -> String { Keychain.get("api.\(p.rawValue)") ?? "" }
    static func setApiKey(_ key: String, for p: RemoteProvider) {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if k.isEmpty { Keychain.delete("api.\(p.rawValue)") } else { Keychain.set(k, for: "api.\(p.rawValue)") }
    }

    /// Platné nastavení, nebo nil (pak hraje jen vypravěč v telefonu).
    static var config: RemoteConfig? {
        guard enabled else { return nil }
        let p = provider
        let key = apiKey(p)
        guard !key.isEmpty else { return nil }
        let m = model
        return RemoteConfig(provider: p, model: p.models.contains { $0.id == m } ? m : p.defaultModel, apiKey: key)
    }
}

enum Keychain {
    static let service = "cz.pocketrealm.app"

    static func set(_ value: String, for account: String) {
        delete(account)
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecValueData as String: Data(value.utf8),
                                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        SecItemAdd(q as CFDictionary, nil)
    }

    static func get(_ account: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
    }
}
