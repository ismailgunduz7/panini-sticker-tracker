import Foundation

/// The six FIFA confederations a national team can belong to.
enum Confederation: String, CaseIterable, Identifiable, Hashable, Sendable {
    case uefa = "UEFA"
    case conmebol = "CONMEBOL"
    case concacaf = "CONCACAF"
    case caf = "CAF"
    case afc = "AFC"
    case ofc = "OFC"

    var id: String { rawValue }

    /// Display name — these are proper nouns, shown verbatim.
    var displayName: String { rawValue }

    var symbolName: String {
        switch self {
        case .uefa: "globe.europe.africa.fill"
        case .conmebol: "globe.americas.fill"
        case .concacaf: "globe.americas.fill"
        case .caf: "globe.europe.africa.fill"
        case .afc: "globe.asia.australia.fill"
        case .ofc: "globe.asia.australia.fill"
        }
    }

    /// Confederation of a country, by album code. Returns `nil` for unknown codes.
    static func of(_ countryCode: String) -> Confederation? {
        membership[countryCode]
    }

    /// Country codes belonging to this confederation, in album order.
    var countryCodes: [String] {
        AlbumDefinition.countries.filter { Confederation.of($0.code) == self }.map(\.code)
    }

    private static let membership: [String: Confederation] = [
        // Group A
        "MEX": .concacaf, "RSA": .caf, "KOR": .afc, "CZE": .uefa,
        // Group B
        "CAN": .concacaf, "BIH": .uefa, "QAT": .afc, "SUI": .uefa,
        // Group C
        "BRA": .conmebol, "MAR": .caf, "HAI": .concacaf, "SCO": .uefa,
        // Group D
        "USA": .concacaf, "PAR": .conmebol, "AUS": .afc, "TUR": .uefa,
        // Group E
        "GER": .uefa, "CUW": .concacaf, "CIV": .caf, "ECU": .conmebol,
        // Group F
        "NED": .uefa, "JPN": .afc, "SWE": .uefa, "TUN": .caf,
        // Group G
        "BEL": .uefa, "EGY": .caf, "IRN": .afc, "NZL": .ofc,
        // Group H
        "ESP": .uefa, "CPV": .caf, "KSA": .afc, "URU": .conmebol,
        // Group I
        "FRA": .uefa, "SEN": .caf, "IRQ": .afc, "NOR": .uefa,
        // Group J
        "ARG": .conmebol, "ALG": .caf, "AUT": .uefa, "JOR": .afc,
        // Group K
        "POR": .uefa, "COD": .caf, "UZB": .afc, "COL": .conmebol,
        // Group L
        "ENG": .uefa, "CRO": .uefa, "GHA": .caf, "PAN": .concacaf,
    ]
}
