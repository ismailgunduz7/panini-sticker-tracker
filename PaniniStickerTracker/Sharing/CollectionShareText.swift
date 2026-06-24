import SwiftUI

/// Which slice of the collection a share covers.
enum ShareScope: String, CaseIterable, Identifiable {
    case owned
    case missing
    case duplicates

    var id: String { rawValue }

    /// Short label for the share menu.
    var menuLabel: LocalizedStringKey {
        switch self {
        case .owned: "Owned"
        case .missing: "Missing"
        case .duplicates: "Duplicates"
        }
    }

    var systemImage: String {
        switch self {
        case .owned: "checkmark.circle"
        case .missing: "circle.dashed"
        case .duplicates: "plus.square.on.square"
        }
    }

    /// Heading printed at the top of the shared text.
    var heading: String {
        switch self {
        case .owned: String(localized: "Stickers I Own")
        case .missing: String(localized: "Stickers I'm Missing")
        case .duplicates: String(localized: "My Duplicates")
        }
    }

    func includes(_ code: String, in store: CollectionStore) -> Bool {
        switch self {
        case .owned: store.isOwned(code)
        case .missing: !store.isOwned(code)
        case .duplicates: store.duplicateCount(code) > 0
        }
    }
}

/// Builds the plain-text representation of a slice of the collection, grouped by
/// section (World Cup, each country, Coca-Cola) with each line listing the
/// sticker numbers in that group, e.g. `MEX: 1, 2, 5`. Duplicate counts are
/// irrelevant here — a sticker is listed if it has at least one spare.
struct CollectionShareText {
    let store: CollectionStore

    func text(for scope: ShareScope) -> String {
        var lines = [scope.heading, ""]
        let countBefore = lines.count

        appendGroup("FWC", AlbumDefinition.fwcStickers, scope, into: &lines)
        for country in AlbumDefinition.countries {
            appendGroup(country.code, country.stickers, scope, into: &lines)
        }
        appendGroup("CC", AlbumDefinition.cocaColaStickers, scope, into: &lines)
        if scope.includes(AlbumDefinition.specialSticker.code, in: store) {
            lines.append(AlbumDefinition.specialSticker.code)
        }

        if lines.count == countBefore {
            lines.append(String(localized: "None"))
        }
        return lines.joined(separator: "\n")
    }

    private func appendGroup(_ label: String,
                             _ stickers: [Sticker],
                             _ scope: ShareScope,
                             into lines: inout [String]) {
        let numbers = stickers
            .filter { scope.includes($0.code, in: store) }
            .map { String($0.index) }
        guard !numbers.isEmpty else { return }
        lines.append("\(label): \(numbers.joined(separator: ", "))")
    }
}
