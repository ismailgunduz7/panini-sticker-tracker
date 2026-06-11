import Foundation
import SwiftData

final class LocalCollectionRepository: CollectionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadAll() async throws -> [CollectionEntry] {
        let models = try context.fetch(FetchDescriptor<StickerEntry>())
        return models.map {
            CollectionEntry(code: $0.code, isOwned: $0.isOwned,
                            duplicateCount: $0.duplicateCount, updatedAt: $0.updatedAt)
        }
    }

    func upsert(_ entry: CollectionEntry) async throws {
        let code = entry.code
        let descriptor = FetchDescriptor<StickerEntry>(predicate: #Predicate { $0.code == code })
        if let existing = try context.fetch(descriptor).first {
            existing.isOwned = entry.isOwned
            existing.duplicateCount = entry.duplicateCount
            existing.updatedAt = entry.updatedAt
        } else {
            context.insert(StickerEntry(code: entry.code, isOwned: entry.isOwned,
                                        duplicateCount: entry.duplicateCount, updatedAt: entry.updatedAt))
        }
        try context.save()
    }

    func resetAll() async throws {
        try context.delete(model: StickerEntry.self)
        try context.save()
    }
}
