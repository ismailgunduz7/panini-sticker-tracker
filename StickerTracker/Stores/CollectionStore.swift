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

    /// Called when a sticker's first spare is registered (duplicate count goes
    /// 0 -> 1) via an interactive add, so a "new trade" push can be offered to
    /// friends missing it. Never fired during load/sync/reset.
    @ObservationIgnored var onNewSpares: (([String]) -> Void)?

    /// While an account is linked, a full reset must survive sync: rows are
    /// zeroed instead of deleted, so the reset wins over the server copy
    /// rather than the old data merging back on the next pull.
    @ObservationIgnored var preservesResetTombstones = false

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
        let previousCount = entries[code]?.duplicateCount ?? 0
        var entry = entries[code] ?? CollectionEntry(code: code, isOwned: false, duplicateCount: 0, updatedAt: .now)
        entry.duplicateCount = max(0, entry.duplicateCount + delta)
        // Having a duplicate implies owning the sticker.
        if entry.duplicateCount > 0 { entry.isOwned = true }
        entry.updatedAt = .now
        persist(entry)
        // First spare for this sticker: a new trade may now exist for friends.
        if previousCount == 0 && entry.duplicateCount > 0 {
            onNewSpares?([code])
        }
    }

    /// Registers `copies` physical copies of a scanned sticker. One copy fills the
    /// album slot; only the copies beyond that become spares. So the first copy of
    /// a sticker you don't yet own just marks it owned (no duplicate), and any
    /// extra copies — or copies of a sticker you already own — become duplicates.
    func registerScannedCopies(_ code: String, copies: Int) {
        guard copies > 0 else { return }
        let spareDelta = isOwned(code) ? copies : copies - 1
        if spareDelta > 0 {
            adjustDuplicates(code, by: spareDelta) // also marks the sticker owned
        } else {
            setOwned([code], owned: true) // first copy of a new sticker: album only
        }
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
        if preservesResetTombstones, !entries.isEmpty {
            let now = Date.now
            for code in entries.keys {
                entries[code] = CollectionEntry(code: code, isOwned: false, duplicateCount: 0, updatedAt: now)
            }
            let zeroed = Array(entries.values)
            Task { [repository] in
                for entry in zeroed {
                    try? await repository.upsert(entry)
                }
            }
        } else {
            entries = [:]
            Task { [repository] in
                try? await repository.resetAll()
            }
        }
        onEntriesChanged?(entries)
    }

    /// Applies rows pulled from the server, keeping whichever side of each
    /// sticker is newer (last-write-wins, mirroring the server-side upsert).
    func applyRemote(_ remote: [CollectionEntry]) {
        var changed = false
        for entry in remote {
            if let local = entries[entry.code], local.updatedAt >= entry.updatedAt { continue }
            entries[entry.code] = entry
            Task { [repository] in
                try? await repository.upsert(entry)
            }
            changed = true
        }
        if changed { onEntriesChanged?(entries) }
    }

    private func persist(_ entry: CollectionEntry) {
        entries[entry.code] = entry
        Task { [repository] in
            try? await repository.upsert(entry)
        }
        onEntriesChanged?(entries)
    }
}
