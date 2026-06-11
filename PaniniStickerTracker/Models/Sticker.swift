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
}
