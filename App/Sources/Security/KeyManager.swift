import Foundation
import Security
import LocalAuthentication
import CryptoKit
import AgentCore

/// Správa šifrovacího klíče databáze.
///
/// - Klíč databáze = 32 náhodných bajtů. Nikdy není v kódu ani v souboru v čitelné podobě.
/// - Je zašifrovaný veřejným klíčem z Secure Enclave (ECIES P-256 + AES-GCM). Soukromý klíč
///   neopustí Secure Enclave a jeho použití vyžaduje Face ID (`biometryCurrentSet` – po změně
///   nastavení Face ID přestane platit).
/// - Druhá kopie je zabalená nouzovým heslem (Argon2id + AES-256-GCM) – pro případ změny Face ID.
/// - Vše v Keychainu s `ThisDeviceOnly` → nejde do iCloudu ani do záloh.
enum KeyManager {
    private static let seTag = "cz.osobniagent.key.se".data(using: .utf8)!
    private static let service = "cz.osobniagent.keys"
    private static let seWrappedAccount = "dbkey.se"
    private static let recoveryAccount = "dbkey.recovery"
    private static let failAccount = "auth.failures"
    private static let configAccount = "security.config"

    enum KeyError: Error, LocalizedError {
        case secureEnclave(String)
        case notSetUp
        case biometryInvalidated
        case cancelled
        case authFailed

        var errorDescription: String? {
            switch self {
            case .secureEnclave(let m): return "Chyba zabezpečení: \(m)"
            case .notSetUp: return "Aplikace ještě není nastavená"
            case .biometryInvalidated: return "Nastavení Face ID se změnilo. Odemkni nouzovým heslem."
            case .cancelled: return "Zrušeno"
            case .authFailed: return "Ověření se nezdařilo"
            }
        }
    }

    static var isSetUp: Bool { readItem(recoveryAccount) != nil }

    static var secureEnclaveAvailable: Bool { SecureEnclave.isAvailable }

    static var biometryDescription: String {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else { return "nedostupné" }
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "biometrie"
        }
    }

    // MARK: - Nastavení

    /// První spuštění: vytvoří klíč databáze a zabalí ho Secure Enclave + nouzovým heslem.
    static func setUp(recoveryPassword: String) throws -> Data {
        var key = KDF.randomBytes(32)
        defer { key.resetBytes(in: 0..<key.count) }
        try storeWithSecureEnclave(key)
        let recovery = try KeyWrap.wrap(key, password: recoveryPassword)
        try writeItem(recoveryAccount, recovery)
        resetFailures()
        return Data(key)
    }

    private static func storeWithSecureEnclave(_ key: Data) throws {
        deleteSEKey()
        let pub = try createSEKey()
        var error: Unmanaged<CFError>?
        guard let wrapped = SecKeyCreateEncryptedData(pub, .eciesEncryptionCofactorVariableIVX963SHA256AESGCM, key as CFData, &error) as Data? else {
            throw KeyError.secureEnclave(error?.takeRetainedValue().localizedDescription ?? "šifrování klíče")
        }
        try writeItem(seWrappedAccount, wrapped)
    }

    private static func createSEKey() throws -> SecKey {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                           [.privateKeyUsage, .biometryCurrentSet], &error) else {
            throw KeyError.secureEnclave("přístupová pravidla")
        }
        var attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: seTag,
                kSecAttrAccessControl as String: access,
            ] as [String: Any],
        ]
        if SecureEnclave.isAvailable { attrs[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave }
        guard let priv = SecKeyCreateRandomKey(attrs as CFDictionary, &error), let pub = SecKeyCopyPublicKey(priv) else {
            throw KeyError.secureEnclave(error?.takeRetainedValue().localizedDescription ?? "vytvoření klíče (je nastaven kód zařízení?)")
        }
        return pub
    }

    private static func deleteSEKey() {
        let q: [String: Any] = [kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: seTag]
        SecItemDelete(q as CFDictionary)
    }

    // MARK: - Odemčení

    /// Odemkne Face ID. Vrací klíč databáze.
    static func unlockWithBiometrics() async throws -> Data {
        guard let wrapped = readItem(seWrappedAccount) else { throw KeyError.notSetUp }
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Zrušit"
        ctx.localizedFallbackTitle = ""
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Odemknout osobní data")
            guard ok else { throw KeyError.authFailed }
        } catch let e as LAError {
            switch e.code {
            case .userCancel, .appCancel, .systemCancel, .userFallback: throw KeyError.cancelled
            case .authenticationFailed, .biometryLockout:
                registerFailure()
                throw KeyError.authFailed
            default: throw KeyError.secureEnclave(e.localizedDescription)
            }
        }
        let q: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: seTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: ctx,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        guard status == errSecSuccess, let item else {
            // Klíč zmizel = změnilo se Face ID (biometryCurrentSet).
            throw KeyError.biometryInvalidated
        }
        let priv = item as! SecKey
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateDecryptedData(priv, .eciesEncryptionCofactorVariableIVX963SHA256AESGCM, wrapped as CFData, &error) as Data? else {
            throw KeyError.biometryInvalidated
        }
        resetFailures()
        return key
    }

    /// Odemkne nouzovým heslem. Po úspěchu znovu vytvoří klíč v Secure Enclave (např. po změně Face ID).
    static func unlockWithRecovery(password: String) throws -> Data {
        guard let blob = readItem(recoveryAccount) else { throw KeyError.notSetUp }
        do {
            let key = try KeyWrap.unwrap(blob, password: password)
            resetFailures()
            try? storeWithSecureEnclave(key)
            return key
        } catch {
            registerFailure()
            throw KeyError.authFailed
        }
    }

    static func changeRecoveryPassword(currentKey: Data, newPassword: String) throws {
        let blob = try KeyWrap.wrap(currentKey, password: newPassword)
        try writeItem(recoveryAccount, blob)
    }

    // MARK: - Neúspěšné pokusy a smazání

    struct SecurityConfig: Codable {
        /// 0 = vypnuto
        var wipeAfterFailures: Int = 0
    }

    static var config: SecurityConfig {
        get { readItem(configAccount).flatMap { try? JSONDecoder().decode(SecurityConfig.self, from: $0) } ?? SecurityConfig() }
        set { if let d = try? JSONEncoder().encode(newValue) { try? writeItem(configAccount, d) } }
    }

    static var failures: Int {
        readItem(failAccount).flatMap { String(data: $0, encoding: .utf8) }.flatMap(Int.init) ?? 0
    }

    static func registerFailure() {
        try? writeItem(failAccount, Data(String(failures + 1).utf8))
    }

    static func resetFailures() { try? writeItem(failAccount, Data("0".utf8)) }

    /// Má se po tolika pokusech vše smazat?
    static var shouldWipe: Bool {
        let limit = config.wipeAfterFailures
        return limit > 0 && failures >= limit
    }

    /// Nevratně zničí klíče (data v databázi se tím stanou nečitelnými) a smaže soubory.
    static func wipeAll() {
        deleteSEKey()
        for acc in [seWrappedAccount, recoveryAccount, failAccount] { deleteItem(acc) }
        AppPaths.deleteAllUserData()
    }

    // MARK: - Keychain

    private static func baseQuery(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func writeItem(_ account: String, _ data: Data) throws {
        SecItemDelete(baseQuery(account) as CFDictionary)
        var q = baseQuery(account)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        q[kSecAttrSynchronizable as String] = false
        let st = SecItemAdd(q as CFDictionary, nil)
        guard st == errSecSuccess else { throw KeyError.secureEnclave("Keychain \(st)") }
    }

    static func readItem(_ account: String) -> Data? {
        var q = baseQuery(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    static func deleteItem(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}
