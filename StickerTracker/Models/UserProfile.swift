import Foundation

/// The signed-in user's row in the Supabase `profiles` table.
struct UserProfile: Codable, Equatable, Sendable {
    var id: UUID
    var username: String
    var displayName: String
    /// The single privacy setting: when false (the default), friends only see
    /// the trade intersection instead of the whole album.
    var shareFullAlbum: Bool
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case shareFullAlbum = "share_full_album"
        case isActive = "is_active"
    }
}
