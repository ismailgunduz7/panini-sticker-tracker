import SwiftUI

struct SpecialSectionCardView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    let section: SpecialSection

    private var ownedCount: Int { store.ownedCount(in: section.stickerCodes) }
    private var total: Int { section.stickerCodes.count }
    private var textColor: Color { section.theme.contrastingText }

    private var title: LocalizedStringKey {
        switch section {
        case .fwc: "World Cup"
        case .special: "Special"
        case .cocaCola: "Coca-Cola"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: section.symbolName)
                    .font(.title3)
                Spacer()
                if ownedCount == total {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                }
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(ownedCount), total: Double(total))
                    .tint(textColor)
                Text("\(ownedCount) / \(total)")
                    .font(.caption2.monospacedDigit())
                    .opacity(0.85)
            }
        }
        .foregroundStyle(textColor)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(
            section.theme.gradient
                .overlay(colorScheme == .dark ? Color.black.opacity(0.25) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
