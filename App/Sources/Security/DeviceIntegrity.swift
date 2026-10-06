import Foundation
import MachO
import LocalAuthentication

/// Heuristická detekce jailbreaku. Nejde o neprůstřelnou ochranu – jen varování pro uživatele.
enum DeviceIntegrity {
    static var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return suspiciousFiles() || canWriteOutsideSandbox() || suspiciousLibraries()
        #endif
    }

    private static func suspiciousFiles() -> Bool {
        let paths = [
            "/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib", "/usr/sbin/sshd", "/etc/apt",
            "/private/var/lib/apt/", "/usr/bin/ssh", "/var/jb", "/private/preboot/jb",
            "/usr/lib/libjailbreak.dylib", "/bin/bash",
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private static func canWriteOutsideSandbox() -> Bool {
        let path = "/private/oa_jb_test_\(UUID().uuidString)"
        do {
            try "x".write(toFile: path, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: path)
            return true
        } catch { return false }
    }

    private static func suspiciousLibraries() -> Bool {
        let needles = ["substrate", "substitute", "libhooker", "frida", "cycript", "sslkillswitch", "ellekit"]
        for i in 0..<_dyld_image_count() {
            guard let c = _dyld_get_image_name(i) else { continue }
            let name = String(cString: c).lowercased()
            if needles.contains(where: { name.contains($0) }) { return true }
        }
        return false
    }

    /// Je nastaven kód zařízení? (Bez něj nefunguje Secure Enclave ani ochrana dat.)
    static var hasPasscode: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}
