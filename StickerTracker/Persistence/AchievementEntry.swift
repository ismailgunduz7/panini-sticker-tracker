import Foundation

/// Storage-agnostic snapshot of one unlocked achievement.
/// Mirrors the `CollectionEntry` pattern so a future Supabase-backed
/// implementation can reuse the contract unchanged.
struct AchievementEntry: Hashable, Codable, Sendable {
    var id: String
    var unlockedAt: Date
}

/// Abstraction over achievement-unlock storage.
protocol AchievementRepository {
    func loadAll() async throws -> [AchievementEntry]
    func unlock(_ entry: AchievementEntry) async throws
    func revoke(_ id: String) async throws
    func resetAll() async throws
}
