import Foundation

/// Turns a raw OCR text fragment into a valid album sticker code, or `nil`.
///
/// Album codes come in a few shapes — country / World Cup stickers are three
/// letters plus a 1–2 digit index (`EGY6`, `FWC5`), Coca-Cola stickers are two
/// letters plus an index (`CC3`), and the cover sticker is the literal `00`.
///
/// Matching is **whole-token**: a code is only accepted if a recognized token
/// resolves exactly to it. This stops noise like `COD` being mistaken for `00`
/// just because two characters look like zeros — `00` is returned only when the
/// token really is `00`. To cope with the World Cup font (whose `Q` reads badly,
/// breaking `QAT` / `IRQ`), tokens that don't match exactly are retried with
/// OCR-confusable character swaps, accepted only when exactly one valid code
/// results.
enum StickerCodeParser {

    static func code(from text: String) -> String? {
        // Codes are usually one short token; allow for the index being split off
        // ("ARG 14") by also trying the whitespace-joined whole string.
        var tokens = text
            .split(whereSeparator: \.isWhitespace)
            .map(cleanToken)
            .filter { !$0.isEmpty }
        tokens.append(tokens.joined())

        for token in tokens {
            if let code = resolve(token) { return code }
        }
        return nil
    }

    /// Keep only alphanumerics, uppercased.
    private static func cleanToken<S: StringProtocol>(_ token: S) -> String {
        String(token.unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(Character.init))
            .uppercased()
    }

    private static func resolve(_ token: String) -> String? {
        guard (2...5).contains(token.count) else { return nil }
        if AlbumDefinition.allStickerCodes.contains(token) { return token }
        // `00` must be read exactly; never reach it through fuzzy swaps.
        let matches = ocrVariants(of: token)
            .intersection(AlbumDefinition.allStickerCodes)
            .subtracting([AlbumDefinition.specialSticker.code])
        return matches.count == 1 ? matches.first : nil
    }

    /// Characters the OCR commonly confuses, grouped so any member can stand in
    /// for any other when an exact match fails.
    private static let confusions: [Character: [Character]] = {
        let groups: [[Character]] = [
            ["0", "O", "Q", "D"],
            ["1", "I", "L"],
            ["5", "S"],
            ["8", "B"],
            ["2", "Z"],
            ["6", "G"],
        ]
        var map: [Character: [Character]] = [:]
        for group in groups {
            for character in group { map[character] = group }
        }
        return map
    }()

    /// All strings reachable from `token` by swapping confusable characters.
    /// Bails out (empty) if the combinations explode, so a noisy read can't
    /// stall the scanner.
    private static func ocrVariants(of token: String) -> Set<String> {
        var results: Set<String> = [""]
        for character in token {
            let options = confusions[character] ?? [character]
            var next: Set<String> = []
            for prefix in results {
                for option in options { next.insert(prefix + String(option)) }
            }
            if next.count > 4000 { return [] }
            results = next
        }
        return results
    }
}
