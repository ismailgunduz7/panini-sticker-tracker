import Foundation

struct Country: Identifiable, Hashable, Sendable {
    let code: String      // e.g. "TUR"
    let name: String      // album name, e.g. "Türkiye"
    let group: String     // "A"..."L"
    let startPage: Int    // first of the country's two album pages
    let theme: CountryTheme

    var id: String { code }

    var confederation: Confederation? { Confederation.of(code) }

    static let stickersPerCountry = 20
    static let stickersPerPage = 10

    var stickers: [Sticker] {
        (1...Self.stickersPerCountry).map { index in
            Sticker(
                code: "\(code)\(index)",
                index: index,
                type: index == 1 ? .federationLogo : (index == 13 ? .teamPhoto : .player),
                location: .page(index <= Self.stickersPerPage ? startPage : startPage + 1)
            )
        }
    }

    var stickerCodes: [String] {
        (1...Self.stickersPerCountry).map { "\(code)\($0)" }
    }

    var firstPageCodes: [String] { (1...10).map { "\(code)\($0)" } }
    var secondPageCodes: [String] { (11...20).map { "\(code)\($0)" } }
}
