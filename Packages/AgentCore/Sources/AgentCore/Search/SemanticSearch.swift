import Foundation

/// Sémantické hledání v poznámkách: lokální vektory (uložené šifrovaně v DB) + fulltext.
public final class SemanticSearch: NoteSearching, @unchecked Sendable {
    public let store: DataStore
    public let embedder: EmbeddingModel?

    public init(store: DataStore, embedder: EmbeddingModel?) {
        self.store = store; self.embedder = embedder
    }

    static func text(for n: Note) -> String {
        let t = (n.title.isEmpty ? "" : n.title + "\n") + n.body
        return t.count > 2000 ? String(t.prefix(2000)) : t
    }

    /// Dopočítá vektory pro nové / změněné poznámky. Vrací počet přepočtených.
    @discardableResult
    public func refresh(isCancelled: () -> Bool = { false }) async throws -> Int {
        guard let embedder else { return 0 }
        let existing = Dictionary(uniqueKeysWithValues: try store.embeddings(model: embedder.modelId).map { ($0.ref.id, $0.contentHash) })
        let notes = try store.notes(limit: 100_000)
        var count = 0
        for n in notes {
            if isCancelled() { break }
            let text = Self.text(for: n)
            let hash = Hashing.sha256Hex(text)
            if existing[n.id] == hash { continue }
            let v = try await embedder.embed(text, isQuery: false)
            try store.upsertEmbedding(EntityRef(kind: .note, id: n.id), model: embedder.modelId, vector: Self.normalized(v), contentHash: hash)
            count += 1
        }
        // Úklid vektorů smazaných poznámek
        let live = Set(notes.map(\.id))
        for id in existing.keys where !live.contains(id) {
            try store.db.execute("DELETE FROM embeddings WHERE entity_kind='note' AND entity_id=?", [id])
        }
        return count
    }

    public func search(_ query: String, limit: Int) async throws -> [(note: Note, score: Double)] {
        var scores: [String: Double] = [:]
        // Fulltext (funguje i bez modelu)
        for (i, n) in try store.searchNotes(query, limit: 20).enumerated() {
            scores[n.id, default: 0] += 0.35 - Double(i) * 0.01
        }
        if let embedder {
            let q = Self.normalized(try await embedder.embed(query, isQuery: true))
            for e in try store.embeddings(model: embedder.modelId) where e.vector.count == q.count {
                let s = Self.dot(q, e.vector)
                if s > 0.2 { scores[e.ref.id, default: 0] += s }
            }
        }
        let top = scores.sorted { $0.value > $1.value }.prefix(limit)
        return try top.compactMap { id, score in
            guard let n = try store.note(id: id), n.deletedAt == nil else { return nil }
            return (n, score)
        }
    }

    static func normalized(_ v: [Float]) -> [Float] {
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        return norm > 0 ? v.map { $0 / norm } : v
    }

    static func dot(_ a: [Float], _ b: [Float]) -> Double {
        var s: Float = 0
        for i in 0..<min(a.count, b.count) { s += a[i] * b[i] }
        return Double(s)
    }
}
