import Foundation

/// Umístění souborů. Vše je v kontejneru aplikace, vyloučeno ze záloh iCloud/iTunes
/// a chráněno ochranou dat iOS (`complete` = nečitelné, když je telefon zamčený).
enum AppPaths {
    static var appSupport: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OsobniAgent", isDirectory: true)
        ensureDirectory(url, protection: .complete)
        return url
    }

    static var dataDirectory: URL {
        let url = appSupport.appendingPathComponent("Data", isDirectory: true)
        ensureDirectory(url, protection: .complete)
        return url
    }

    static var databaseURL: URL { dataDirectory.appendingPathComponent("agent.db") }

    static var databaseExists: Bool { FileManager.default.fileExists(atPath: databaseURL.path) }

    /// Modely jsou veřejné soubory – chráněné, ale dostupné i po zamčení (kvůli běžícímu přepisu).
    static var modelsDirectory: URL {
        let url = appSupport.appendingPathComponent("Models", isDirectory: true)
        ensureDirectory(url, protection: .completeUntilFirstUserAuthentication)
        return url
    }

    /// Dočasné soubory (export zálohy) – mažou se hned po použití.
    static var tempDirectory: URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("oa-tmp", isDirectory: true)
        ensureDirectory(url, protection: .complete)
        return url
    }

    static func ensureDirectory(_ url: URL, protection: FileProtectionType) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true,
                                    attributes: [.protectionKey: protection])
        }
        excludeFromBackup(url)
    }

    static func excludeFromBackup(_ url: URL) {
        var u = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? u.setResourceValues(values)
    }

    /// Ochrana dat pro soubory databáze (i pomocné soubory SQLite).
    static func protectDatabaseFiles() {
        let fm = FileManager.default
        for suffix in ["", "-journal", "-wal", "-shm"] {
            let path = databaseURL.path + suffix
            if fm.fileExists(atPath: path) {
                try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: path)
                excludeFromBackup(URL(fileURLWithPath: path))
            }
        }
    }

    static func deleteAllUserData() {
        let fm = FileManager.default
        try? fm.removeItem(at: dataDirectory)
        try? fm.removeItem(at: tempDirectory)
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }

    static func clearTemp() {
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("oa-tmp"))
    }

    static var freeDiskBytes: Int64 {
        let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }
}
