import Foundation
import SwiftData

/// Persisted collection state for a single sticker. Records are created lazily —
/// only stickers the user has interacted with have a row.
@Model
final class StickerEntry {
    @Attribute(.unique) var code: String
    var isOwned: Bool
    var duplicateCount: Int
    var updatedAt: Date

    init(code: String, isOwned: Bool = false, duplicateCount: Int = 0, updatedAt: Date = .now) {
        self.code = code
        self.isOwned = isOwned
        self.duplicateCount = duplicateCount
        self.updatedAt = updatedAt
    }
}
