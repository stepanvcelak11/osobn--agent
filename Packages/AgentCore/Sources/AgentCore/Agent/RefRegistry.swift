import Foundation

/// Krátké odkazy (U1, P2…) pro model místo dlouhých UUID.
public final class RefRegistry: @unchecked Sendable {
    private var byShort: [String: EntityRef] = [:]
    private var byRef: [EntityRef: String] = [:]
    private var counters: [EntityKind: Int] = [:]
    private let lock = NSLock()

    public init() {}

    public func short(for ref: EntityRef) -> String {
        lock.lock(); defer { lock.unlock() }
        if let s = byRef[ref] { return s }
        let n = (counters[ref.kind] ?? 0) + 1
        counters[ref.kind] = n
        let s = ref.kind.refPrefix + String(n)
        byShort[s] = ref
        byRef[ref] = s
        return s
    }

    public func resolve(_ short: String) -> EntityRef? {
        lock.lock(); defer { lock.unlock() }
        let key = short.trimmingCharacters(in: CharacterSet(charactersIn: " []#()")).uppercased()
        return byShort[key]
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        byShort = [:]; byRef = [:]; counters = [:]
    }
}
