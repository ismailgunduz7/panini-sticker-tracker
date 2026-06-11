import Foundation
import SwiftData

final class LocalAchievementRepository: AchievementRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func loadAll() async throws -> [AchievementEntry] {
        let models = try context.fetch(FetchDescriptor<AchievementRecord>())
        return models.map { AchievementEntry(id: $0.id, unlockedAt: $0.unlockedAt) }
    }

    func unlock(_ entry: AchievementEntry) async throws {
        let id = entry.id
        let descriptor = FetchDescriptor<AchievementRecord>(predicate: #Predicate { $0.id == id })
        if try context.fetch(descriptor).first == nil {
            context.insert(AchievementRecord(id: entry.id, unlockedAt: entry.unlockedAt))
            try context.save()
        }
    }

    func resetAll() async throws {
        try context.delete(model: AchievementRecord.self)
        try context.save()
    }
}
