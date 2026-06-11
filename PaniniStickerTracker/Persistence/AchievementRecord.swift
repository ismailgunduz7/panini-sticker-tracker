import Foundation
import SwiftData

/// Persisted record of an unlocked achievement. A row exists only once an
/// achievement has been earned.
@Model
final class AchievementRecord {
    @Attribute(.unique) var id: String
    var unlockedAt: Date

    init(id: String, unlockedAt: Date = .now) {
        self.id = id
        self.unlockedAt = unlockedAt
    }
}
