import SwiftUI

struct StickerCellView: View {
    @Environment(CollectionStore.self) private var store
    let sticker: Sticker
    let theme: CountryTheme

    private var isOwned: Bool { store.isOwned(sticker.code) }
    private var duplicates: Int { store.duplicateCount(sticker.code) }

    var body: some View {
        Button {
            store.toggle(sticker.code)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: sticker.symbolName)
                    .font(.body)
                Text(verbatim: sticker.code)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.vertical, 6)
            .foregroundStyle(isOwned ? theme.contrastingText : Color.secondary)
            .background(
                isOwned
                    ? AnyShapeStyle(theme.gradient)
                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isOwned ? Color.clear : Color.secondary.opacity(0.3),
                                  style: StrokeStyle(lineWidth: 1, dash: isOwned ? [] : [4]))
            )
            .overlay(alignment: .topTrailing) {
                if duplicates > 0 {
                    Text(verbatim: "×\(duplicates + 1)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.orange, in: Capsule())
                        .foregroundStyle(.white)
                        .offset(x: 4, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                store.adjustDuplicates(sticker.code, by: 1)
            } label: {
                Label("Add Duplicate", systemImage: "plus.circle")
            }
            if duplicates > 0 {
                Button {
                    store.adjustDuplicates(sticker.code, by: -1)
                } label: {
                    Label("Remove Duplicate", systemImage: "minus.circle")
                }
            }
        }
        .accessibilityLabel(Text(verbatim: sticker.code))
        .accessibilityAddTraits(isOwned ? [.isSelected] : [])
    }
}
