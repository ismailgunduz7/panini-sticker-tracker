import Foundation
import Observation
import Supabase

/// Friendships and friend requests, loaded through the get_friendships RPC.
/// All mutations go through server-side RPCs that enforce who may do what;
/// this store just mirrors the result.
@Observable
final class FriendStore {
    /// One row of the friends screen — an accepted friend or a pending
    /// request, identified by the other user's id.
    struct Friendship: Identifiable, Equatable {
        let id: UUID
        let username: String
        let displayName: String
        let isPending: Bool
        let requestedByMe: Bool
    }

    /// A username search hit from search_profiles.
    struct Candidate: Identifiable, Codable, Sendable {
        let id: UUID
        let username: String
        let displayName: String

        enum CodingKeys: String, CodingKey {
            case id, username
            case displayName = "display_name"
        }
    }

    enum RequestError: LocalizedError {
        case notFound, alreadyFriends, alreadyPending, declined, other

        var errorDescription: String? {
            switch self {
            case .notFound: String(localized: "No user with that username was found.")
            case .alreadyFriends: String(localized: "You are already friends.")
            case .alreadyPending: String(localized: "There is already a pending request between you.")
            case .declined: String(localized: "This user declined your previous request.")
            case .other: String(localized: "Something went wrong. Please try again.")
            }
        }
    }

    private(set) var friends: [Friendship] = []
    private(set) var incomingRequests: [Friendship] = []
    private(set) var outgoingRequests: [Friendship] = []
    private(set) var hasLoaded = false
    private(set) var isLoading = false

    var pendingBadgeCount: Int { incomingRequests.count }

    @ObservationIgnored private let client: SupabaseClient
    @ObservationIgnored private var pendingSpares: Set<String> = []
    @ObservationIgnored private var announceTask: Task<Void, Never>?

    init(client: SupabaseClient) {
        self.client = client
    }

    func clear() {
        friends = []
        incomingRequests = []
        outgoingRequests = []
        hasLoaded = false
    }

    func refresh() async {
        guard (try? await client.auth.session) != nil else {
            clear()
            return
        }
        struct Row: Codable, Sendable {
            let userId: UUID
            let username: String
            let displayName: String
            let status: String
            let requestedByMe: Bool

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case username
                case displayName = "display_name"
                case status
                case requestedByMe = "requested_by_me"
            }
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [Row] = try await client.rpc("get_friendships").execute().value
            let all = rows.map {
                Friendship(id: $0.userId, username: $0.username, displayName: $0.displayName,
                           isPending: $0.status == "pending", requestedByMe: $0.requestedByMe)
            }
            friends = all.filter { !$0.isPending }.sorted { $0.username < $1.username }
            incomingRequests = all.filter { $0.isPending && !$0.requestedByMe }
            outgoingRequests = all.filter { $0.isPending && $0.requestedByMe }
            hasLoaded = true
        } catch {
            // Offline or transient failure: keep whatever was shown before.
        }
    }

    /// Buffer newly registered spares and, after a short debounce, tell the
    /// server so accepted friends missing them get a "new trade" push. A scan
    /// of many stickers thus becomes one call. Best-effort: offline (or signed
    /// out) just fails silently.
    func announceNewSpares(_ codes: [String]) {
        pendingSpares.formUnion(codes)
        announceTask?.cancel()
        announceTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !pendingSpares.isEmpty else { return }
            struct Params: Encodable { let p_codes: [String] }
            let batch = Array(pendingSpares)
            pendingSpares.removeAll()
            _ = try? await client.rpc("announce_new_spares", params: Params(p_codes: batch)).execute()
        }
    }

    func search(_ query: String) async -> [Candidate] {
        struct Params: Encodable {
            let p_query: String
        }
        return (try? await client.rpc("search_profiles", params: Params(p_query: query))
            .execute().value) ?? []
    }

    func sendRequest(toUsername username: String) async throws {
        struct Params: Encodable {
            let p_username: String
        }
        do {
            try await client.rpc("send_friend_request", params: Params(p_username: username)).execute()
        } catch {
            let raw = String(describing: error)
            if raw.contains("user_not_found") { throw RequestError.notFound }
            if raw.contains("already_friends") { throw RequestError.alreadyFriends }
            if raw.contains("request_already_pending") { throw RequestError.alreadyPending }
            if raw.contains("request_declined") { throw RequestError.declined }
            throw RequestError.other
        }
        await refresh()
    }

    func accept(_ userId: UUID) async {
        struct Params: Encodable {
            let p_requester: UUID
        }
        _ = try? await client.rpc("accept_friend_request", params: Params(p_requester: userId)).execute()
        await refresh()
    }

    func decline(_ userId: UUID) async {
        struct Params: Encodable {
            let p_requester: UUID
        }
        _ = try? await client.rpc("decline_friend_request", params: Params(p_requester: userId)).execute()
        await refresh()
    }

    /// Removes an accepted friendship, or cancels the caller's own pending request.
    func remove(_ userId: UUID) async {
        struct Params: Encodable {
            let p_other: UUID
        }
        _ = try? await client.rpc("remove_friendship", params: Params(p_other: userId)).execute()
        await refresh()
    }

    // MARK: - Friend collections

    /// A friend's collection as far as their privacy setting allows, shaped
    /// as a TradePayload so the existing TradeMatch pipeline applies as-is.
    struct FriendCollection {
        let payload: TradePayload
        /// Album progress; only known when the friend shares the full album.
        let ownedCount: Int?
        let lastUpdated: Date?
    }

    /// Fetches what a friend's privacy setting exposes via the
    /// get_friend_collection RPC and reshapes it for TradeMatch.
    func loadCollection(of friendId: UUID) async throws -> FriendCollection {
        struct EntryRow: Codable, Sendable {
            let code: String
            let isOwned: Bool
            let duplicateCount: Int

            enum CodingKeys: String, CodingKey {
                case code
                case isOwned = "is_owned"
                case duplicateCount = "duplicate_count"
            }
        }
        struct ProfileRow: Codable, Sendable {
            let shareFullAlbum: Bool

            enum CodingKeys: String, CodingKey {
                case shareFullAlbum = "share_full_album"
            }
        }
        struct Params: Encodable {
            let p_friend: UUID
        }

        // The friend's privacy setting decides how to interpret the rows;
        // their profile row is readable thanks to the friends-read RLS policy.
        let profiles: [ProfileRow] = try await client.from("profiles")
            .select("share_full_album")
            .eq("id", value: friendId)
            .execute().value
        guard let sharesFullAlbum = profiles.first?.shareFullAlbum else {
            throw RequestError.other
        }

        let rows: [EntryRow] = try await client
            .rpc("get_friend_collection", params: Params(p_friend: friendId))
            .execute().value

        let duplicates = Set(rows.filter { $0.duplicateCount > 0 }.map(\.code))
        let owned: Set<String>
        let ownedCount: Int?
        if sharesFullAlbum {
            // Full album: rows are the friend's real (lazily created) entries;
            // absent codes are simply not owned.
            owned = Set(rows.filter(\.isOwned).map(\.code))
            ownedCount = owned.count
        } else {
            // Intersection mode: is_owned=false rows are explicit "friend
            // needs this" markers for the caller's spares. Every other code is
            // treated as owned so TradeMatch's set subtraction excludes it —
            // fine, because those codes never appear in the caller's spares.
            let needsMarkers = Set(rows.filter { !$0.isOwned }.map(\.code))
            owned = Set(AlbumDefinition.orderedStickerCodes).subtracting(needsMarkers)
            ownedCount = nil
        }

        let lastUpdatedRaw: String? = try? await client
            .rpc("get_friend_last_updated", params: Params(p_friend: friendId))
            .execute().value
        let lastUpdated = lastUpdatedRaw.flatMap(PostgresTimestamp.parse)

        return FriendCollection(
            payload: TradePayload(owned: owned, duplicates: duplicates),
            ownedCount: ownedCount,
            lastUpdated: lastUpdated
        )
    }
}
