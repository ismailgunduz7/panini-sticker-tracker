import Foundation

enum StickerType: String, Codable, Hashable, Sendable {
    case federationLogo
    case teamPhoto
    case player
    case fwc
    case special
    case cocaCola

    var symbolName: String {
        switch self {
        case .federationLogo: "shield.fill"
        case .teamPhoto: "person.3.fill"
        case .player: "person.fill"
        case .fwc: "trophy.fill"
        case .special: "star.fill"
        case .cocaCola: "takeoutbag.and.cup.and.straw.fill"
        }
    }
}
