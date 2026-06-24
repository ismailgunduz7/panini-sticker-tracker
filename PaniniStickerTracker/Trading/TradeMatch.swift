import Foundation

/// A country (or special section) and the matching trade codes within it.
struct TradeGroup: Identifiable {
    let id: String
    let title: String
    let codes: [String]

    var count: Int { codes.count }
}

/// Computes two-way trade matches between the local collection and a scanned one.
enum TradeMatch {
    /// Their spares that you don't own yet.
    static func theyGiveYou(mine: TradePayload, theirs: TradePayload) -> [TradeGroup] {
        grouped(theirs.duplicates.subtracting(mine.owned))
    }

    /// Your spares that they don't own yet.
    static func youGiveThem(mine: TradePayload, theirs: TradePayload) -> [TradeGroup] {
        grouped(mine.duplicates.subtracting(theirs.owned))
    }

    /// Buckets a set of codes into album-ordered groups (World Cup, each country,
    /// Special, Coca-Cola), keeping each group's in-album sticker order.
    private static func grouped(_ codes: Set<String>) -> [TradeGroup] {
        var result: [TradeGroup] = []

        func add(id: String, title: String, candidates: [String]) {
            let present = candidates.filter(codes.contains)
            if !present.isEmpty {
                result.append(TradeGroup(id: id, title: title, codes: present))
            }
        }

        add(id: SpecialSection.fwc.id,
            title: SpecialSection.fwc.displayName,
            candidates: AlbumDefinition.fwcStickers.map(\.code))
        for country in AlbumDefinition.countries {
            add(id: country.code, title: country.name, candidates: country.stickerCodes)
        }
        add(id: SpecialSection.special.id,
            title: SpecialSection.special.displayName,
            candidates: [AlbumDefinition.specialSticker.code])
        add(id: SpecialSection.cocaCola.id,
            title: SpecialSection.cocaCola.displayName,
            candidates: AlbumDefinition.cocaColaStickers.map(\.code))

        return result
    }
}
