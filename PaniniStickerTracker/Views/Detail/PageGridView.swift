import SwiftUI

/// One album page: a titled grid of stickers.
struct PageGridView: View {
    @Environment(CollectionStore.self) private var store
    let title: Text
    let stickers: [Sticker]
    let theme: CountryTheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                title
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(store.ownedCount(in: stickers.map(\.code))) / \(stickers.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(stickers) { sticker in
                    StickerCellView(sticker: sticker, theme: theme)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground).opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 16))
    }
}
