import Foundation

/// Non-country sticker sections of the album.
enum SpecialSection: String, Identifiable, CaseIterable, Hashable, Sendable {
    case fwc
    case special
    case cocaCola

    var id: String { rawValue }

    var stickers: [Sticker] {
        switch self {
        case .fwc: AlbumDefinition.fwcStickers
        case .special: [AlbumDefinition.specialSticker]
        case .cocaCola: AlbumDefinition.cocaColaStickers
        }
    }

    var stickerCodes: [String] { stickers.map(\.code) }

    var theme: CountryTheme {
        switch self {
        case .fwc: CountryTheme(primaryHex: "C9A227", secondaryHex: "8C6E14")
        case .special: CountryTheme(primaryHex: "1B1B3A", secondaryHex: "4B3FA0")
        case .cocaCola: CountryTheme(primaryHex: "F40009", secondaryHex: "8C0005")
        }
    }

    var symbolName: String {
        switch self {
        case .fwc: "trophy.fill"
        case .special: "star.fill"
        case .cocaCola: "takeoutbag.and.cup.and.straw.fill"
        }
    }
}
