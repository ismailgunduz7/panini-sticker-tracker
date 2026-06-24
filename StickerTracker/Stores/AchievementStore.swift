import Foundation
import Observation

/// Tracks which achievements are unlocked and decides when new ones are earned.
///
/// Evaluation is driven from collection changes:
/// - `load()` then `backfill(entries:)` catch up silently on first launch so
///   existing progress is recorded without spamming notifications.
/// - `evaluate(entries:)` runs after every sticker change and announces any
///   newly earned achievement via the toast queue.
@Observable
final class AchievementStore {
    /// Achievement id → unlock date.
    private(set) var unlocked: [String: Date] = [:]
    private(set) var isLoaded = false

    /// FIFO queue of achievements waiting to be shown as a toast.
    var toastQueue: [Achievement] = []

    @ObservationIgnored private let repository: AchievementRepository

    init(repository: AchievementRepository) {
        self.repository = repository
    }

    func isUnlocked(_ id: String) -> Bool { unlocked[id] != nil }
    var unlockedCount: Int { unlocked.count }

    func load() async {
        guard !isLoaded else { return }
        do {
            let all = try await repository.loadAll()
            unlocked = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.unlockedAt) })
            isLoaded = true
        } catch {
            assertionFailure("Failed to load achievements: \(error)")
        }
    }

    /// Record any already-satisfied achievements without announcing them.
    func backfill(entries: [String: CollectionEntry]) {
        apply(entries: entries, announce: false)
    }

    /// Re-evaluate after a collection change, announcing anything newly earned.
    func evaluate(entries: [String: CollectionEntry]) {
        apply(entries: entries, announce: true)
    }

    func dismissCurrentToast() {
        if !toastQueue.isEmpty { toastQueue.removeFirst() }
    }

    func resetAll() {
        unlocked = [:]
        toastQueue = []
        Task { [repository] in
            try? await repository.resetAll()
        }
    }

    // MARK: - Core

    /// Achievements track current collection state, so they unlock when their
    /// condition becomes satisfied and are revoked if it stops holding (e.g. the
    /// last qualifying sticker is removed). Only unlocks are announced.
    private func apply(entries: [String: CollectionEntry], announce: Bool) {
        let context = AchievementContext(entries: entries)
        let now = Date.now
        for achievement in Achievement.all {
            let satisfied = achievement.isSatisfied(context)
            let wasUnlocked = unlocked[achievement.id] != nil
            if satisfied, !wasUnlocked {
                unlocked[achievement.id] = now
                persistUnlock(AchievementEntry(id: achievement.id, unlockedAt: now))
                if announce { toastQueue.append(achievement) }
            } else if !satisfied, wasUnlocked {
                unlocked[achievement.id] = nil
                toastQueue.removeAll { $0.id == achievement.id }
                persistRevoke(achievement.id)
            }
        }
    }

    private func persistUnlock(_ entry: AchievementEntry) {
        Task { [repository] in
            try? await repository.unlock(entry)
        }
    }

    private func persistRevoke(_ id: String) {
        Task { [repository] in
            try? await repository.revoke(id)
        }
    }
}
