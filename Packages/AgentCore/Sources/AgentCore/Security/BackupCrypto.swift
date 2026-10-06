import Foundation
import CArgon2
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public enum CryptoError: Error, CustomStringConvertible, Equatable {
    case badFormat
    case unsupportedVersion
    case wrongPasswordOrCorrupted
    case truncated
    case kdfFailed(Int32)
    case weakPassword

    public var description: String {
        switch self {
        case .badFormat: return "Soubor není záloha této aplikace"
        case .unsupportedVersion: return "Nepodporovaná verze zálohy"
        case .wrongPasswordOrCorrupted: return "Špatné heslo nebo poškozený soubor"
        case .truncated: return "Záloha je neúplná (zkrácený soubor)"
        case .kdfFailed(let c): return "Odvození klíče selhalo (\(c))"
        case .weakPassword: return "Heslo je příliš slabé"
        }
    }
}

/// Parametry Argon2id.
public struct KDFParams: Equatable, Sendable {
    public var memoryKiB: UInt32
    public var iterations: UInt32
    public var parallelism: UInt32
    /// Výchozí: 64 MiB, 3 průchody – na iPhonu cca 0,3–0,6 s.
    public static let standard = KDFParams(memoryKiB: 64 * 1024, iterations: 3, parallelism: 1)
    /// Jen pro testy.
    public static let fastForTests = KDFParams(memoryKiB: 1024, iterations: 1, parallelism: 1)
}

public enum KDF {
    /// Argon2id(heslo, sůl) → 32B klíč.
    public static func argon2id(password: String, salt: Data, params: KDFParams) throws -> SymmetricKey {
        let pwd = Data(password.precomposedStringWithCanonicalMapping.utf8)
        var out = [UInt8](repeating: 0, count: 32)
        let rc: Int32 = pwd.withUnsafeBytes { p in
            salt.withUnsafeBytes { s in
                argon2id_hash_raw(params.iterations, params.memoryKiB, params.parallelism,
                                  p.baseAddress, pwd.count, s.baseAddress, salt.count, &out, out.count)
            }
        }
        guard rc == 0 else { throw CryptoError.kdfFailed(rc) }
        defer { for i in out.indices { out[i] = 0 } }
        return SymmetricKey(data: out)
    }

    public static func randomBytes(_ n: Int) -> Data {
        var g = SystemRandomNumberGenerator()
        return Data((0..<n).map { _ in UInt8.random(in: 0...255, using: &g) })
    }
}

/// Formát zálohy:
///  "OSAGBK01" | ver(1) | kdf(1) | m(4) | t(4) | p(4) | salt(16) | noncePrefix(7) | chunk(4) | [len(4) | AES-GCM(ct+tag)]*
/// Hlavička je AAD každého bloku; nonce = prefix | index(4) | příznak posledního bloku(1) → nejde prohazovat ani zkracovat.
public enum BackupCrypto {
    static let magic = Data("OSAGBK01".utf8)
    static let version: UInt8 = 1
    static let chunkSize = 1 << 20

    public static func encrypt(_ plaintext: Data, password: String, params: KDFParams = .standard) throws -> Data {
        guard PasswordPolicy.isAcceptable(password) else { throw CryptoError.weakPassword }
        let salt = KDF.randomBytes(16)
        let prefix = KDF.randomBytes(7)
        let key = try KDF.argon2id(password: password, salt: salt, params: params)
        var header = magic
        header.append(version)
        header.append(1) // argon2id
        header.append(be32(params.memoryKiB)); header.append(be32(params.iterations)); header.append(be32(params.parallelism))
        header.append(salt)
        header.append(prefix)
        header.append(be32(UInt32(chunkSize)))

        var out = header
        var index: UInt32 = 0
        var offset = 0
        repeat {
            let end = min(offset + chunkSize, plaintext.count)
            let isLast = end == plaintext.count
            let chunk = plaintext.subdata(in: offset..<end)
            let nonce = try AES.GCM.Nonce(data: prefix + be32(index) + Data([isLast ? 1 : 0]))
            let sealed = try AES.GCM.seal(chunk, using: key, nonce: nonce, authenticating: header)
            let body = sealed.ciphertext + sealed.tag
            out.append(be32(UInt32(body.count)))
            out.append(body)
            offset = end
            index += 1
            if isLast { break }
        } while true
        return out
    }

    public static func decrypt(_ data: Data, password: String) throws -> Data {
        let headerLen = 8 + 1 + 1 + 12 + 16 + 7 + 4
        guard data.count >= headerLen, data.prefix(8) == magic else { throw CryptoError.badFormat }
        let bytes = [UInt8](data)
        guard bytes[8] == version else { throw CryptoError.unsupportedVersion }
        guard bytes[9] == 1 else { throw CryptoError.unsupportedVersion }
        let params = KDFParams(memoryKiB: rd32(bytes, 10), iterations: rd32(bytes, 14), parallelism: rd32(bytes, 18))
        // Ochrana proti podvrženým extrémním parametrům.
        guard params.memoryKiB >= 8, params.memoryKiB <= 1 << 21, params.iterations >= 1, params.iterations <= 64,
              params.parallelism >= 1, params.parallelism <= 16 else { throw CryptoError.badFormat }
        let salt = Data(bytes[22..<38])
        let prefix = Data(bytes[38..<45])
        let header = Data(bytes[0..<headerLen])
        let key = try KDF.argon2id(password: password, salt: salt, params: params)

        var out = Data()
        var pos = headerLen
        var index: UInt32 = 0
        var sawLast = false
        while pos < bytes.count {
            guard !sawLast else { throw CryptoError.badFormat }
            guard pos + 4 <= bytes.count else { throw CryptoError.truncated }
            let len = Int(rd32(bytes, pos)); pos += 4
            guard len >= 16, pos + len <= bytes.count else { throw CryptoError.truncated }
            let body = Data(bytes[pos..<(pos + len)]); pos += len
            let isLast = pos == bytes.count
            let nonce = try AES.GCM.Nonce(data: prefix + be32(index) + Data([isLast ? 1 : 0]))
            do {
                let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: body.prefix(len - 16), tag: body.suffix(16))
                out.append(try AES.GCM.open(box, using: key, authenticating: header))
            } catch {
                throw index == 0 ? CryptoError.wrongPasswordOrCorrupted : CryptoError.truncated
            }
            if isLast { sawLast = true }
            index += 1
        }
        guard sawLast else { throw CryptoError.truncated }
        return out
    }

    static func be32(_ v: UInt32) -> Data { Data([UInt8(v >> 24), UInt8((v >> 16) & 0xff), UInt8((v >> 8) & 0xff), UInt8(v & 0xff)]) }
    static func rd32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3])
    }
}

/// Zabalení 32B klíče heslem (nouzové heslo k databázi).
/// Formát: "OSAGKW01" | m(4) | t(4) | p(4) | salt(16) | AES-GCM combined(nonce+ct+tag)
public enum KeyWrap {
    static let magic = Data("OSAGKW01".utf8)

    public static func wrap(_ key: Data, password: String, params: KDFParams = .standard) throws -> Data {
        let salt = KDF.randomBytes(16)
        let k = try KDF.argon2id(password: password, salt: salt, params: params)
        var header = magic
        header.append(BackupCrypto.be32(params.memoryKiB)); header.append(BackupCrypto.be32(params.iterations))
        header.append(BackupCrypto.be32(params.parallelism)); header.append(salt)
        let sealed = try AES.GCM.seal(key, using: k, authenticating: header)
        guard let combined = sealed.combined else { throw CryptoError.badFormat }
        return header + combined
    }

    public static func unwrap(_ blob: Data, password: String) throws -> Data {
        guard blob.count > 8 + 12 + 16 + 28, blob.prefix(8) == magic else { throw CryptoError.badFormat }
        let b = [UInt8](blob)
        let params = KDFParams(memoryKiB: BackupCrypto.rd32(b, 8), iterations: BackupCrypto.rd32(b, 12), parallelism: BackupCrypto.rd32(b, 16))
        guard params.memoryKiB <= 1 << 21, params.iterations <= 64, params.parallelism <= 16 else { throw CryptoError.badFormat }
        let salt = Data(b[20..<36])
        let header = Data(b[0..<36])
        let k = try KDF.argon2id(password: password, salt: salt, params: params)
        do {
            let box = try AES.GCM.SealedBox(combined: Data(b[36...]))
            return try AES.GCM.open(box, using: k, authenticating: header)
        } catch { throw CryptoError.wrongPasswordOrCorrupted }
    }
}

public enum PasswordPolicy {
    public static let minLength = 10

    /// Minimálně 10 znaků a ne jen opakovaný znak / jednoduchá řada.
    public static func isAcceptable(_ p: String) -> Bool {
        guard p.count >= minLength else { return false }
        if Set(p).count < 4 { return false }
        let banned = ["1234567890", "0123456789", "heslo12345", "password12", "qwertzuiop", "qwertyuiop"]
        return !banned.contains(p.lowercased())
    }

    public static func hint(_ p: String) -> String? {
        if p.count < minLength { return "Heslo musí mít aspoň \(minLength) znaků." }
        if !isAcceptable(p) { return "Heslo je příliš jednoduché." }
        return nil
    }
}

public enum Hashing {
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    public static func sha256Hex(_ s: String) -> String { sha256Hex(Data(s.utf8)) }
}
