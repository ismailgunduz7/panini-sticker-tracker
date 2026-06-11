import SwiftUI

struct CountryDetailView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    let country: Country

    private var ownedCount: Int { store.ownedCount(in: country.stickerCodes) }
    private var allOwned: Bool { ownedCount == Country.stickersPerCountry }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                PageGridView(
                    title: Text("Page \(country.startPage)"),
                    stickers: Array(country.stickers[0..<10]),
                    theme: country.theme
                )
                PageGridView(
                    title: Text("Page \(country.startPage + 1)"),
                    stickers: Array(country.stickers[10..<20]),
                    theme: country.theme
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text(verbatim: country.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.setOwned(country.stickerCodes, owned: !allOwned)
                } label: {
                    allOwned
                        ? Label("Clear All", systemImage: "xmark.circle")
                        : Label("Mark All", systemImage: "checkmark.circle")
                }
            }
        }
    }

    private var header: some View {
        let textColor = country.theme.contrastingText
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: country.name)
                        .font(.title2.bold())
                    Text("Group \(country.group)")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Text(verbatim: country.code)
                    .font(.headline.weight(.heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(textColor.opacity(0.18), in: Capsule())
            }
            ProgressView(value: Double(ownedCount), total: Double(Country.stickersPerCountry))
                .tint(textColor)
            Text("\(ownedCount) / \(Country.stickersPerCountry)")
                .font(.caption.monospacedDigit())
                .opacity(0.85)
        }
        .foregroundStyle(textColor)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            country.theme.gradient
                .overlay(colorScheme == .dark ? Color.black.opacity(0.25) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        CountryDetailView(country: AlbumDefinition.countries[15])
    }
    .environment(CollectionStore(repository: PreviewRepository()))
}
