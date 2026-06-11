import SwiftUI

enum CountrySortField: String, CaseIterable, Identifiable {
    case albumOrder
    case name
    case completion

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .albumOrder: "Album Order"
        case .name: "Name"
        case .completion: "Completion"
        }
    }

    /// Direction applied the first time this field is selected.
    var defaultAscending: Bool {
        switch self {
        case .albumOrder, .name: true
        case .completion: false   // most complete first
        }
    }
}

struct HomeView: View {
    @Environment(CollectionStore.self) private var store
    @State private var searchText = ""
    @AppStorage("homeSortField") private var sortFieldRaw = CountrySortField.albumOrder.rawValue
    @AppStorage("homeSortAscending") private var sortAscending = true

    private var sortField: CountrySortField {
        CountrySortField(rawValue: sortFieldRaw) ?? .albumOrder
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var filteredCountries: [Country] {
        var countries = AlbumDefinition.countries
        if !searchText.isEmpty {
            countries = countries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.code.localizedCaseInsensitiveContains(searchText)
            }
        }
        // Build the ascending order for the chosen field, then flip if needed.
        let ascending: [Country]
        switch sortField {
        case .albumOrder:
            ascending = countries
        case .name:
            ascending = countries.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .completion:
            ascending = countries.sorted {
                store.ownedCount(in: $0.stickerCodes) < store.ownedCount(in: $1.stickerCodes)
            }
        }
        return sortAscending ? ascending : ascending.reversed()
    }

    /// Selecting the current field flips its direction; selecting a new field
    /// applies that field's default direction.
    private func selectSort(_ field: CountrySortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortFieldRaw = field.rawValue
            sortAscending = field.defaultAscending
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
                    NavigationLink {
                        DuplicatesView()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(CountrySortField.allCases) { field in
                            Button {
                                selectSort(field)
                            } label: {
                                if sortField == field {
                                    Label(field.label,
                                          systemImage: sortAscending ? "chevron.up" : "chevron.down")
                                } else {
                                    Text(field.label)
                                }
                            }
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
