import Foundation

/// Umístění souborů – vše v kontejneru aplikace, vyloučeno ze záloh iCloud.
enum AppPaths {
    static var appSupport: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PocketRealm", isDirectory: true)
        ensureDirectory(url)
        return url
    }

    static var savesDirectory: URL {
        let url = appSupport.appendingPathComponent("Saves", isDirectory: true)
        ensureDirectory(url)
        return url
    }

    static var modelsDirectory: URL {
        let url = appSupport.appendingPathComponent("Models", isDirectory: true)
        ensureDirectory(url)
        return url
    }

    static var modelManifest: URL { modelsDirectory.appendingPathComponent("models.json") }

    static func ensureDirectory(_ url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true,
                                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        }
        excludeFromBackup(url)
    }

    static func excludeFromBackup(_ url: URL) {
        var u = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? u.setResourceValues(values)
    }

    static var freeDiskBytes: Int64 {
        let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }
}
