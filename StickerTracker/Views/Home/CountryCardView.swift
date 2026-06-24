import SwiftUI

struct CountryCardView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    let country: Country

    private var ownedCount: Int { store.ownedCount(in: country.stickerCodes) }
    private var isComplete: Bool { ownedCount == Country.stickersPerCountry }
    private var textColor: Color { country.theme.contrastingText }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(verbatim: country.code)
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(textColor.opacity(0.18), in: Capsule())
                Spacer()
                if isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                }
            }

            Spacer(minLength: 0)

            Text(verbatim: country.name)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)

            Text("Group \(country.group)")
                .font(.caption)
                .opacity(0.85)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(ownedCount), total: Double(Country.stickersPerCountry))
                    .tint(textColor)
                Text("\(ownedCount) / \(Country.stickersPerCountry)")
                    .font(.caption2.monospacedDigit())
                    .opacity(0.85)
            }
        }
        .foregroundStyle(textColor)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .background(
            country.theme.gradient
                .overlay(colorScheme == .dark ? Color.black.opacity(0.25) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    CountryCardView(country: AlbumDefinition.countries[15])
        .environment(CollectionStore(repository: PreviewRepository()))
        .frame(width: 180)
        .padding()
}
