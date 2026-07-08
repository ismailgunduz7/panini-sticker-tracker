import Foundation

/// Postgres `timestamptz` values are carried as strings because the wire
/// format (up to six fraction digits, `+00:00` offsets) doesn't reliably
/// match what Foundation's ISO8601 decoding strategies accept.
enum PostgresTimestamp {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let whole: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func format(_ date: Date) -> String {
        fractional.string(from: date)
    }

    static func parse(_ string: String) -> Date? {
        if let date = fractional.date(from: string) ?? whole.date(from: string) {
            return date
        }
        // ISO8601DateFormatter only parses exactly three fraction digits;
        // normalize the fraction and retry.
        guard let dot = string.firstIndex(of: ".") else { return nil }
        var end = string.index(after: dot)
        while end < string.endIndex, string[end].isNumber {
            end = string.index(after: end)
        }
        let fraction = String(string[string.index(after: dot)..<end].prefix(3))
            .padding(toLength: 3, withPad: "0", startingAt: 0)
        return fractional.date(from: String(string[..<dot] + "." + fraction + string[end...]))
    }
}
