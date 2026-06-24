import Foundation

enum StickerLocation: Hashable, Sendable {
    case page(Int)
    case frontCover
    case backCoverInside

    var pageNumber: Int? {
        if case .page(let number) = self { return number }
        return nil
    }
}

struct Sticker: Identifiable, Hashable, Sendable {
    let code: String
    let index: Int
    let type: StickerType
    let location: StickerLocation

    var id: String { code }

    /// Per-sticker icon. FWC stickers have varied contents, so they get
    /// index-specific symbols instead of the generic type symbol.
    var symbolName: String {
        guard type == .fwc else { return type.symbolName }
        switch index {
        case 1: return "circle.tophalf.filled"      // official emblem, top half
        case 2: return "circle.bottomhalf.filled"   // official emblem, bottom half
        case 3: return "pawprint.fill"              // official mascots
        case 4: return "quote.bubble.fill"          // official slogan
        case 5: return "soccerball"                 // official ball
        case 6...8: return "globe.americas.fill"    // host country emblems (CAN, MEX, USA)
        default: return "trophy.fill"               // past winners' team photos (9-19)
        }
    }
}
