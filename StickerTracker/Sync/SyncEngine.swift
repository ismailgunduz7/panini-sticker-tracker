import Foundation
import Supabase

/// Two-way sync between the local collection and the user's rows on Supabase.
/// The device stays the source of truth; the server copy exists so friends
/// can compute trade matches. Merge policy is last-write-wins per sticker,
/// mirrored on the server by upsert_sticker_entries.
final class SyncEngine {
    /// Set by the app: sync runs only while a signed-in profile exists
    /// (sticker_entries has a foreign key to profiles).
    var isReady: () -> Bool = { false }

    private let client: SupabaseClient
    private let store: CollectionStore
    private var pushDebounce: Task<Void, Never>?
    private var isSyncing = false

    init(client: SupabaseClient, store: CollectionStore) {
        self.client = client
        self.store = store
    }

    /// Full two-way sync: pull + merge, then push local changes. Also serves
    /// as the initial migration when an account is first linked (with no
    /// lastSyncedAt, every local entry counts as dirty and is uploaded).
    func syncNow() {
        Task { await sync(pull: true) }
    }

    /// Debounced push-only sync, called after every local mutation.
    func schedulePush() {
        guard isReady() else { return }
        pushDebounce?.cancel()
        pushDebounce = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await sync(pull: false)
        }
    }

    private func sync(pull: Bool) async {
        guard isReady(), !isSyncing else { return }
        guard let userId = try? await client.auth.session.user.id else { return }
        isSyncing = true
        defer { isSyncing = false }

        let syncStart = Date.now

        if pull {
            do {
                let rows: [RemoteEntry] = try await client.from("sticker_entries")
                    .select()
                    .execute()
                    .value
                store.applyRemote(rows.compactMap(\.collectionEntry))
            } catch {
                return // Offline or transient failure; retried on next trigger.
            }
        }

        let lastSynced = Self.lastSyncedAt(for: userId)
        let dirty = store.entries.values.filter { entry in
            lastSynced.map { entry.updatedAt > $0 } ?? true
        }
        if !dirty.isEmpty {
            struct Params: Encodable {
                let p_entries: [RemoteEntry]
            }
            do {
                try await client
                    .rpc("upsert_sticker_entries", params: Params(p_entries: dirty.map(RemoteEntry.init)))
                    .execute()
            } catch {
                return // Keep lastSyncedAt untouched so these stay dirty.
            }
        }
        Self.setLastSyncedAt(syncStart, for: userId)
    }

    // MARK: - Wire format

    private struct RemoteEntry: Codable, Sendable {
        let code: String
        let isOwned: Bool
        let duplicateCount: Int
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case code
            case isOwned = "is_owned"
            case duplicateCount = "duplicate_count"
            case updatedAt = "updated_at"
        }

        init(_ entry: CollectionEntry) {
            code = entry.code
            isOwned = entry.isOwned
            duplicateCount = entry.duplicateCount
            updatedAt = PostgresTimestamp.format(entry.updatedAt)
        }

        var collectionEntry: CollectionEntry? {
            guard let date = PostgresTimestamp.parse(updatedAt) else { return nil }
            return CollectionEntry(code: code, isOwned: isOwned, duplicateCount: duplicateCount, updatedAt: date)
        }
    }

    // MARK: - Sync watermark

    /// Device-local watermark: entries with updatedAt beyond this are dirty.
    /// Keyed by user id so switching accounts cannot leak state; compared
    /// against timestamps from this same device's clock, so server/device
    /// clock skew does not affect dirtiness.
    private static func watermarkKey(for userId: UUID) -> String {
        "sync.lastSyncedAt.\(userId.uuidString)"
    }

    private static func lastSyncedAt(for userId: UUID) -> Date? {
        let interval = UserDefaults.standard.double(forKey: watermarkKey(for: userId))
        return interval > 0 ? Date(timeIntervalSinceReferenceDate: interval) : nil
    }

    private static func setLastSyncedAt(_ date: Date, for userId: UUID) {
        UserDefaults.standard.set(date.timeIntervalSinceReferenceDate, forKey: watermarkKey(for: userId))
    }
}
