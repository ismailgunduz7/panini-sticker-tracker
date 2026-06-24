import Foundation

/// A snapshot of one collector's album, compact enough to fit in a QR code.
/// Only presence matters: which stickers are owned, and which have a spare.
/// Duplicate counts are intentionally dropped — trading only cares whether a
/// spare exists.
struct TradePayload: Equatable {
    let owned: Set<String>
    let duplicates: Set<String>

    /// Bumped whenever the wire format or `orderedStickerCodes` ordering changes,
    /// so an incompatible QR can be rejected rather than misread.
    static let version: UInt8 = 1
    static let scheme = "panini"
    static let host = "trade"

    /// Builds the payload for the local collection.
    static func current(_ store: CollectionStore) -> TradePayload {
        var owned: Set<String> = []
        var duplicates: Set<String> = []
        for code in AlbumDefinition.orderedStickerCodes {
            if store.isOwned(code) { owned.insert(code) }
            if store.duplicateCount(code) > 0 { duplicates.insert(code) }
        }
        return TradePayload(owned: owned, duplicates: duplicates)
    }

    // MARK: - Encoding

    /// `panini://trade?v=1&d=<base64url>` where the data is a version byte
    /// followed by an owned bitmask and a duplicates bitmask.
    func url() -> URL {
        var data = Data([Self.version])
        data.append(Self.bitmask(for: owned))
        data.append(Self.bitmask(for: duplicates))

        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [
            URLQueryItem(name: "v", value: String(Self.version)),
            URLQueryItem(name: "d", value: data.base64URLEncodedString()),
        ]
        return components.url!
    }

    static func from(url: URL) -> TradePayload? {
        guard url.scheme == scheme, url.host == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = components.queryItems?.first(where: { $0.name == "d" })?.value,
              let data = Data(base64URLEncoded: encoded)
        else { return nil }

        let codes = AlbumDefinition.orderedStickerCodes
        let maskBytes = (codes.count + 7) / 8
        // version + owned mask + duplicates mask
        guard data.count == 1 + maskBytes * 2, data[data.startIndex] == version else { return nil }

        let ownedRange = data.index(data.startIndex, offsetBy: 1)
        let dupRange = data.index(ownedRange, offsetBy: maskBytes)
        let owned = decodeCodes(in: data[ownedRange..<dupRange], codes: codes)
        let duplicates = decodeCodes(in: data[dupRange...], codes: codes)
        return TradePayload(owned: owned, duplicates: duplicates)
    }

    // MARK: - Bitmask helpers

    private static func bitmask(for set: Set<String>) -> Data {
        let codes = AlbumDefinition.orderedStickerCodes
        var bytes = [UInt8](repeating: 0, count: (codes.count + 7) / 8)
        for (index, code) in codes.enumerated() where set.contains(code) {
            bytes[index / 8] |= 1 << (index % 8)
        }
        return Data(bytes)
    }

    private static func decodeCodes(in mask: Data.SubSequence, codes: [String]) -> Set<String> {
        var result: Set<String> = []
        let bytes = Array(mask)
        for (index, code) in codes.enumerated() where index / 8 < bytes.count {
            if bytes[index / 8] & (1 << (index % 8)) != 0 { result.insert(code) }
        }
        return result
    }
}

// MARK: - base64url

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        self.init(base64Encoded: base64)
    }
}
