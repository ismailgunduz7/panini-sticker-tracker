import SwiftUI

/// Detail screen for FWC, special (00) and Coca-Cola stickers,
/// grouped by their physical location in the album.
struct SpecialDetailView: View {
    @Environment(CollectionStore.self) private var store
    let section: SpecialSection

    private var title: LocalizedStringKey {
        switch section {
        case .fwc: "World Cup Stickers"
        case .special: "Special Sticker"
        case .cocaCola: "Coca-Cola Stickers"
        }
    }

    private var locationGroups: [(location: StickerLocation, stickers: [Sticker])] {
        var order: [StickerLocation] = []
        var grouped: [StickerLocation: [Sticker]] = [:]
        for sticker in section.stickers {
            if grouped[sticker.location] == nil { order.append(sticker.location) }
            grouped[sticker.location, default: []].append(sticker)
        }
        return order.map { ($0, grouped[$0]!) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(locationGroups, id: \.location) { group in
                    PageGridView(
                        title: locationTitle(group.location),
                        stickers: group.stickers,
                        theme: section.theme
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func locationTitle(_ location: StickerLocation) -> Text {
        switch location {
        case .page(let number): Text("Page \(number)")
        case .frontCover: Text("Front Cover")
        case .backCoverInside: Text("Inside Back Cover")
        }
    }
}

#Preview {
    NavigationStack {
        SpecialDetailView(section: .fwc)
    }
    .environment(CollectionStore(repository: PreviewRepository()))
}
