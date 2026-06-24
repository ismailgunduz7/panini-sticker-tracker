import SwiftUI

struct CountryDetailView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var country: Country
    @State private var slideEdge: Edge = .trailing

    init(country: Country) {
        _country = State(initialValue: country)
    }

    private var ownedCount: Int { store.ownedCount(in: country.stickerCodes) }
    private var allOwned: Bool { ownedCount == Country.stickersPerCountry }

    private var countryIndex: Int {
        AlbumDefinition.countries.firstIndex(of: country) ?? 0
    }
    private var previousCountry: Country? {
        countryIndex > 0 ? AlbumDefinition.countries[countryIndex - 1] : nil
    }
    private var nextCountry: Country? {
        countryIndex < AlbumDefinition.countries.count - 1
            ? AlbumDefinition.countries[countryIndex + 1] : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                CountryPageView(country: country, pageIndex: 1)
                CountryPageView(country: country, pageIndex: 2)
            }
            .padding(.horizontal)
            .padding(.bottom)
            .id(country.code)
            .transition(.push(from: slideEdge))
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

    private func go(to neighbor: Country?, slideFrom edge: Edge) {
        guard let neighbor else { return }
        slideEdge = edge
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.snappy) {
            country = neighbor
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
            HStack {
                if let previousCountry {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                        Text(verbatim: previousCountry.code)
                    }
                }
                Spacer()
                Text("\(ownedCount) / \(Country.stickersPerCountry)")
                    .font(.caption.monospacedDigit())
                Spacer()
                if let nextCountry {
                    HStack(spacing: 3) {
                        Text(verbatim: nextCountry.code)
                        Image(systemName: "chevron.right")
                    }
                }
            }
            .font(.caption2.weight(.semibold))
            .opacity(0.7)
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
        .gesture(
            DragGesture(minimumDistance: 25)
                .onEnded { value in
                    // Only react to mostly-horizontal swipes so vertical
                    // scrolling over the header keeps working.
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < 0 {
                        go(to: nextCountry, slideFrom: .trailing)
                    } else {
                        go(to: previousCountry, slideFrom: .leading)
                    }
                }
        )
    }
}

#Preview {
    NavigationStack {
        CountryDetailView(country: AlbumDefinition.countries[15])
    }
    .environment(CollectionStore(repository: PreviewRepository()))
}
