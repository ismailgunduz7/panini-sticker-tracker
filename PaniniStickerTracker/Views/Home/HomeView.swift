import SwiftUI

enum CountrySortOrder: String, CaseIterable, Identifiable {
    case albumOrder
    case name
    case completion

    var id: String { rawValue }
}

struct HomeView: View {
    @Environment(CollectionStore.self) private var store
    @State private var searchText = ""
    @State private var sortOrder: CountrySortOrder = .albumOrder

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var filteredCountries: [Country] {
        var countries = AlbumDefinition.countries
        if !searchText.isEmpty {
            countries = countries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.code.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOrder {
        case .albumOrder:
            return countries
        case .name:
            return countries.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .completion:
            return countries.sorted {
                store.ownedCount(in: $0.stickerCodes) > store.ownedCount(in: $1.stickerCodes)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    overallProgressHeader

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredCountries) { country in
                            NavigationLink(value: country) {
                                CountryCardView(country: country)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if searchText.isEmpty {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(SpecialSection.allCases) { section in
                                NavigationLink(value: section) {
                                    SpecialSectionCardView(section: section)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Album")
            .navigationDestination(for: Country.self) { CountryDetailView(country: $0) }
            .navigationDestination(for: SpecialSection.self) { SpecialDetailView(section: $0) }
            .searchable(text: $searchText, prompt: Text("Search country"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sortOrder) {
                            Text("Album Order").tag(CountrySortOrder.albumOrder)
                            Text("Name").tag(CountrySortOrder.name)
                            Text("Completion").tag(CountrySortOrder.completion)
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

    private var overallProgressHeader: some View {
        let owned = store.ownedCount(in: AlbumDefinition.countries.flatMap(\.stickerCodes))
            + store.ownedCount(in: AlbumDefinition.fwcStickers.map(\.code))
            + store.ownedCount(in: Array(AlbumDefinition.extraStickerCodes))
        let total = AlbumDefinition.totalStickerCount

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Overall Progress")
                    .font(.headline)
                Spacer()
                Text("\(owned) / \(total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(owned), total: Double(total))
                .tint(.green)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    HomeView()
        .environment(CollectionStore(repository: PreviewRepository()))
}
