import Foundation

/// Storage-agnostic snapshot of one sticker's collection state.
/// Keeps SwiftData types out of the repository contract so a future
/// Supabase-backed implementation can reuse it unchanged.
struct CollectionEntry: Hashable, Codable, Sendable {
    var code: String
    var isOwned: Bool
    var duplicateCount: Int
    var updatedAt: Date
}

/// Abstraction over collection-state storage. `LocalCollectionRepository` is the
/// SwiftData implementation; a `SupabaseCollectionRepository` can be added later.
/// `updatedAt` is carried through for future sync/merge logic.
protocol CollectionRepository {
    func loadAll() async throws -> [CollectionEntry]
    func upsert(_ entry: CollectionEntry) async throws
    func resetAll() async throws
}
