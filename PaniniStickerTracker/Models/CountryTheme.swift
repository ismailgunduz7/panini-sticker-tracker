import SwiftUI

struct CountryTheme: Hashable, Sendable {
    let primaryHex: String
    let secondaryHex: String

    var primary: Color { Color(hex: primaryHex) }
    var secondary: Color { Color(hex: secondaryHex) }

    /// Text color guaranteed to stay readable on the primary background,
    /// chosen by WCAG relative luminance.
    var contrastingText: Color {
        Color.contrastingText(onHex: primaryHex)
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }

    /// WCAG relative luminance of a hex color (0 = black, 1 = white).
    static func relativeLuminance(ofHex hex: String) -> Double {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = channel(Double((value >> 16) & 0xFF) / 255)
        let g = channel(Double((value >> 8) & 0xFF) / 255)
        let b = channel(Double(value & 0xFF) / 255)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    static func contrastingText(onHex hex: String) -> Color {
        relativeLuminance(ofHex: hex) > 0.4 ? .black : .white
    }
}
