import Foundation

/// A single physical album page belonging to a country (10 stickers each).
struct AlbumPage: Identifiable, Hashable, Sendable {
    let number: Int
    let countryCode: String
    let stickerCodes: [String]

    var id: Int { number }
}

/// The complete, immutable definition of the FIFA World Cup 2026 Panini album.
/// Static data only — collection state lives in the persistence layer.
enum AlbumDefinition {

    // MARK: - Countries (album page order)

    static let countries: [Country] = [
        // Group A
        Country(code: "MEX", name: "Mexico", group: "A", startPage: 8, theme: .init(primaryHex: "006847", secondaryHex: "CE1126")),
        Country(code: "RSA", name: "South Africa", group: "A", startPage: 10, theme: .init(primaryHex: "007A4D", secondaryHex: "FFB612")),
        Country(code: "KOR", name: "Korea Republic", group: "A", startPage: 12, theme: .init(primaryHex: "C60C30", secondaryHex: "003478")),
        Country(code: "CZE", name: "Czechia", group: "A", startPage: 14, theme: .init(primaryHex: "D7141A", secondaryHex: "11457E")),
        // Group B
        Country(code: "CAN", name: "Canada", group: "B", startPage: 16, theme: .init(primaryHex: "D80621", secondaryHex: "8E0517")),
        Country(code: "BIH", name: "Bosnia-Herzegovina", group: "B", startPage: 18, theme: .init(primaryHex: "002395", secondaryHex: "FECB00")),
        Country(code: "QAT", name: "Qatar", group: "B", startPage: 20, theme: .init(primaryHex: "8A1538", secondaryHex: "5C0E26")),
        Country(code: "SUI", name: "Switzerland", group: "B", startPage: 22, theme: .init(primaryHex: "DA291C", secondaryHex: "A81B11")),
        // Group C
        Country(code: "BRA", name: "Brazil", group: "C", startPage: 24, theme: .init(primaryHex: "FFDF00", secondaryHex: "009C3B")),
        Country(code: "MAR", name: "Morocco", group: "C", startPage: 26, theme: .init(primaryHex: "C1272D", secondaryHex: "006233")),
        Country(code: "HAI", name: "Haiti", group: "C", startPage: 28, theme: .init(primaryHex: "00209F", secondaryHex: "D21034")),
        Country(code: "SCO", name: "Scotland", group: "C", startPage: 30, theme: .init(primaryHex: "0065BF", secondaryHex: "003E7E")),
        // Group D
        Country(code: "USA", name: "USA", group: "D", startPage: 32, theme: .init(primaryHex: "002868", secondaryHex: "BF0A30")),
        Country(code: "PAR", name: "Paraguay", group: "D", startPage: 34, theme: .init(primaryHex: "D52B1E", secondaryHex: "0038A8")),
        Country(code: "AUS", name: "Australia", group: "D", startPage: 36, theme: .init(primaryHex: "FFCD00", secondaryHex: "00843D")),
        Country(code: "TUR", name: "Türkiye", group: "D", startPage: 38, theme: .init(primaryHex: "E30A17", secondaryHex: "9E0610")),
        // Group E
        Country(code: "GER", name: "Germany", group: "E", startPage: 40, theme: .init(primaryHex: "262626", secondaryHex: "FFCC00")),
        Country(code: "CUW", name: "Curaçao", group: "E", startPage: 42, theme: .init(primaryHex: "002B7F", secondaryHex: "F9E814")),
        Country(code: "CIV", name: "Côte d'Ivoire", group: "E", startPage: 44, theme: .init(primaryHex: "FF8200", secondaryHex: "009A44")),
        Country(code: "ECU", name: "Ecuador", group: "E", startPage: 46, theme: .init(primaryHex: "FFD100", secondaryHex: "0072CE")),
        // Group F
        Country(code: "NED", name: "Netherlands", group: "F", startPage: 48, theme: .init(primaryHex: "FF6200", secondaryHex: "21468B")),
        Country(code: "JPN", name: "Japan", group: "F", startPage: 50, theme: .init(primaryHex: "0B1F66", secondaryHex: "BC002D")),
        Country(code: "SWE", name: "Sweden", group: "F", startPage: 52, theme: .init(primaryHex: "FECC02", secondaryHex: "005293")),
        Country(code: "TUN", name: "Tunisia", group: "F", startPage: 54, theme: .init(primaryHex: "E70013", secondaryHex: "9D000D")),
        // Group G (note: album skips pages 56-57)
        Country(code: "BEL", name: "Belgium", group: "G", startPage: 58, theme: .init(primaryHex: "C8102E", secondaryHex: "FDDA24")),
        Country(code: "EGY", name: "Egypt", group: "G", startPage: 60, theme: .init(primaryHex: "CE1126", secondaryHex: "8C0D1C")),
        Country(code: "IRN", name: "IR Iran", group: "G", startPage: 62, theme: .init(primaryHex: "239F40", secondaryHex: "DA0000")),
        Country(code: "NZL", name: "New Zealand", group: "G", startPage: 64, theme: .init(primaryHex: "1A1A1A", secondaryHex: "4A4A4A")),
        // Group H
        Country(code: "ESP", name: "Spain", group: "H", startPage: 66, theme: .init(primaryHex: "AA151B", secondaryHex: "F1BF00")),
        Country(code: "CPV", name: "Cabo Verde", group: "H", startPage: 68, theme: .init(primaryHex: "003893", secondaryHex: "F7D116")),
        Country(code: "KSA", name: "Saudi Arabia", group: "H", startPage: 70, theme: .init(primaryHex: "006C35", secondaryHex: "0A4A26")),
        Country(code: "URU", name: "Uruguay", group: "H", startPage: 72, theme: .init(primaryHex: "55B5E5", secondaryHex: "1F4E79")),
        // Group I
        Country(code: "FRA", name: "France", group: "I", startPage: 74, theme: .init(primaryHex: "002654", secondaryHex: "CE1126")),
        Country(code: "SEN", name: "Senegal", group: "I", startPage: 76, theme: .init(primaryHex: "00853F", secondaryHex: "FDEF42")),
        Country(code: "IRQ", name: "Iraq", group: "I", startPage: 78, theme: .init(primaryHex: "007A3D", secondaryHex: "CE1126")),
        Country(code: "NOR", name: "Norway", group: "I", startPage: 80, theme: .init(primaryHex: "BA0C2F", secondaryHex: "00205B")),
        // Group J
        Country(code: "ARG", name: "Argentina", group: "J", startPage: 82, theme: .init(primaryHex: "75AADB", secondaryHex: "233E77")),
        Country(code: "ALG", name: "Algeria", group: "J", startPage: 84, theme: .init(primaryHex: "006233", secondaryHex: "D21034")),
        Country(code: "AUT", name: "Austria", group: "J", startPage: 86, theme: .init(primaryHex: "ED2939", secondaryHex: "9E1B26")),
        Country(code: "JOR", name: "Jordan", group: "J", startPage: 88, theme: .init(primaryHex: "CE1126", secondaryHex: "007A3D")),
        // Group K
        Country(code: "POR", name: "Portugal", group: "K", startPage: 90, theme: .init(primaryHex: "DA291C", secondaryHex: "046A38")),
        Country(code: "COD", name: "Congo DR", group: "K", startPage: 92, theme: .init(primaryHex: "007FFF", secondaryHex: "F7D618")),
        Country(code: "UZB", name: "Uzbekistan", group: "K", startPage: 94, theme: .init(primaryHex: "0099B5", secondaryHex: "1EB53A")),
        Country(code: "COL", name: "Colombia", group: "K", startPage: 96, theme: .init(primaryHex: "FCD116", secondaryHex: "003893")),
        // Group L
        Country(code: "ENG", name: "England", group: "L", startPage: 98, theme: .init(primaryHex: "CE1124", secondaryHex: "002366")),
        Country(code: "CRO", name: "Croatia", group: "L", startPage: 100, theme: .init(primaryHex: "D50A2D", secondaryHex: "171796")),
        Country(code: "GHA", name: "Ghana", group: "L", startPage: 102, theme: .init(primaryHex: "006B3F", secondaryHex: "FCD116")),
        Country(code: "PAN", name: "Panama", group: "L", startPage: 104, theme: .init(primaryHex: "DA121A", secondaryHex: "005293")),
    ]

    static let groups: [String] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"]

    static func country(forCode code: String) -> Country? {
        countriesByCode[code]
    }

    private static let countriesByCode: [String: Country] =
        Dictionary(uniqueKeysWithValues: countries.map { ($0.code, $0) })

    // MARK: - World Cup (FWC) stickers

    private static let fwcPageMap: [(page: Int, indices: ClosedRange<Int>)] = [
        (1, 1...4), (2, 5...6), (3, 7...8),
        (106, 9...10), (107, 11...13), (108, 14...15), (109, 16...19),
    ]

    static let fwcStickers: [Sticker] = fwcPageMap.flatMap { page, indices in
        indices.map { Sticker(code: "FWC\($0)", index: $0, type: .fwc, location: .page(page)) }
    }

    // MARK: - Special & Coca-Cola stickers

    static let specialSticker = Sticker(code: "00", index: 0, type: .special, location: .frontCover)

    static let cocaColaStickers: [Sticker] =
        (1...5).map { Sticker(code: "CC\($0)", index: $0, type: .cocaCola, location: .page(112)) } +
        (6...12).map { Sticker(code: "CC\($0)", index: $0, type: .cocaCola, location: .backCoverInside) }

    // MARK: - Totals

    static let countryStickerCount = countries.count * Country.stickersPerCountry  // 960
    static let fwcStickerCount = fwcStickers.count                                 // 19
    static let extraStickerCount = 1 + cocaColaStickers.count                      // 00 + CC = 13

    /// Total album size including 00 + Coca-Cola.
    static let totalStickerCount = countryStickerCount + fwcStickerCount + extraStickerCount  // 992
    /// Total when 00 + Coca-Cola are excluded from stats.
    static let totalStickerCountWithoutExtras = countryStickerCount + fwcStickerCount         // 979

    static let countryStickerCodes: Set<String> =
        Set(countries.flatMap(\.stickerCodes))

    static let extraStickerCodes: Set<String> =
        Set([specialSticker.code] + cocaColaStickers.map(\.code))

    /// Country pages only — the universe for "closest page" / "completed pages" stats.
    static let countryPages: [AlbumPage] = countries.flatMap { country in
        [
            AlbumPage(number: country.startPage, countryCode: country.code, stickerCodes: country.firstPageCodes),
            AlbumPage(number: country.startPage + 1, countryCode: country.code, stickerCodes: country.secondPageCodes),
        ]
    }
}
