import Foundation
import Observation

/// In-memory source of truth for collection state. Updates are applied
/// optimistically and persisted through the repository in the background.
@Observable
final class CollectionStore {
    private(set) var entries: [String: CollectionEntry] = [:]
    private(set) var isLoaded = false

    @ObservationIgnored private let repository: CollectionRepository

    /// Called after any mutation so downstream consumers (e.g. achievements)
    /// can re-evaluate. Not invoked during `load()`.
    @ObservationIgnored var onEntriesChanged: (([String: CollectionEntry]) -> Void)?

    init(repository: CollectionRepository) {
        self.repository = repository
    }

    func load() async {
        guard !isLoaded else { return }
        do {
            let all = try await repository.loadAll()
            entries = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })
            isLoaded = true
        } catch {
            assertionFailure("Failed to load collection: \(error)")
        }
    }

    // MARK: - Queries

    func isOwned(_ code: String) -> Bool {
        entries[code]?.isOwned ?? false
    }

    func duplicateCount(_ code: String) -> Int {
        entries[code]?.duplicateCount ?? 0
    }

    func ownedCount(in codes: [String]) -> Int {
        codes.count { isOwned($0) }
    }

    // MARK: - Mutations

    func toggle(_ code: String) {
        var entry = entries[code] ?? CollectionEntry(code: code, isOwned: false, duplicateCount: 0, updatedAt: .now)
        entry.isOwned.toggle()
        if !entry.isOwned { entry.duplicateCount = 0 }
        entry.updatedAt = .now
        persist(entry)
    }

    func adjustDuplicates(_ code: String, by delta: Int) {
        var entry = entries[code] ?? CollectionEntry(code: code, isOwned: false, duplicateCount: 0, updatedAt: .now)
        entry.duplicateCount = max(0, entry.duplicateCount + delta)
        // Having a duplicate implies owning the sticker.
        if entry.duplicateCount > 0 { entry.isOwned = true }
        entry.updatedAt = .now
        persist(entry)
    }

    func setOwned(_ codes: [String], owned: Bool) {
        for code in codes where isOwned(code) != owned {
            var entry = entries[code] ?? CollectionEntry(code: code, isOwned: false, duplicateCount: 0, updatedAt: .now)
            entry.isOwned = owned
            if !owned { entry.duplicateCount = 0 }
            entry.updatedAt = .now
            persist(entry)
        }
    }

    func resetAll() {
        entries = [:]
        Task { [repository] in
            try? await repository.resetAll()
        }
        onEntriesChanged?(entries)
    }

    private func persist(_ entry: CollectionEntry) {
        entries[entry.code] = entry
        Task { [repository] in
            try? await repository.upsert(entry)
        }
        onEntriesChanged?(entries)
    }
}
