import SwiftUI

/// A country album page reproducing the real booklet layout: a 3×4 grid
/// with merged cells (the "We Are" banner on page 1, the wide team photo
/// on page 2) and a non-sticker group cell.
struct CountryPageView: View {
    @Environment(CollectionStore.self) private var store
    let country: Country
    let pageIndex: Int  // 1 = stickers 1-10, 2 = stickers 11-20

    private var pageNumber: Int {
        pageIndex == 1 ? country.startPage : country.startPage + 1
    }

    private var pageCodes: [String] {
        pageIndex == 1 ? country.firstPageCodes : country.secondPageCodes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Page \(pageNumber)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(store.ownedCount(in: pageCodes)) / \(pageCodes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                if pageIndex == 1 {
                    GridRow {
                        WeAreBanner(country: country)
                            .gridCellColumns(2)
                        cell(1)
                        cell(2)
                    }
                    GridRow { cell(3); cell(4); cell(5); cell(6) }
                    GridRow { cell(7); cell(8); cell(9); cell(10) }
                } else {
                    GridRow {
                        cell(11)
                        cell(12)
                        teamPhotoCell
                            .gridCellColumns(2)
                    }
                    GridRow { cell(14); cell(15); cell(16); cell(17) }
                    GridRow {
                        groupCell
                        cell(18); cell(19); cell(20)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground).opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    private func cell(_ index: Int) -> some View {
        StickerCellView(sticker: country.stickers[index - 1], theme: country.theme)
    }

    /// The wide team-photo slot spans two grid columns, but the sticker itself
    /// is one column wide and centered — from the middle of the cell above 16
    /// to the middle of the one above 17, like in the printed album.
    private var teamPhotoCell: some View {
        GeometryReader { proxy in
            cell(13)
                .frame(width: (proxy.size.width - 8) / 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The album shows the group's team flags here; we show the group label.
    private var groupCell: some View {
        Text("Group \(country.group)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: 58)
    }
}

/// The merged page-1 cell: "WE ARE" over the country name, both lines
/// stretched to the same width like in the printed album — the font stays
/// the same, only the letter width changes per country name length.
private struct WeAreBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    let country: Country

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HorizontallyStretchedText(
                text: "WE ARE",
                color: Color.readableVariant(ofHex: country.theme.primaryHex, for: colorScheme)
            )
            HorizontallyStretchedText(
                text: country.name.uppercased(),
                color: Color.readableVariant(ofHex: country.theme.secondaryHex, for: colorScheme)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58)
    }
}

/// Single-line text scaled horizontally to exactly fill the available width.
private struct HorizontallyStretchedText: View {
    let text: String
    let color: Color
    @State private var naturalWidth: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            Text(verbatim: text)
                .font(.system(size: 15, weight: .black))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(color)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { naturalWidth = $0 }
                .scaleEffect(
                    x: naturalWidth > 0 ? proxy.size.width / naturalWidth : 1,
                    y: 1,
                    anchor: .leading
                )
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 18)
    }
}

extension Color {
    /// Blends extreme theme colors toward the foreground so they stay readable
    /// on the neutral cell background in the given color scheme.
    static func readableVariant(ofHex hex: String, for scheme: ColorScheme) -> Color {
        let luminance = relativeLuminance(ofHex: hex)
        let base = Color(hex: hex)
        switch scheme {
        case .light where luminance > 0.6:
            return base.mix(with: .black, by: 0.35)
        case .dark where luminance < 0.05:
            return base.mix(with: .white, by: 0.45)
        default:
            return base
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            CountryPageView(country: AlbumDefinition.countries[15], pageIndex: 1)
            CountryPageView(country: AlbumDefinition.countries[15], pageIndex: 2)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .environment(CollectionStore(repository: PreviewRepository()))
}
