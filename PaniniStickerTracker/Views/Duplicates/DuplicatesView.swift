import SwiftUI

enum DuplicateSortField: String, CaseIterable, Identifiable {
    case albumOrder
    case name
    case duplicateCount

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .albumOrder: "Album Order"
        case .name: "Name"
        case .duplicateCount: "Duplicate Count"
        }
    }

    /// Direction applied the first time this field is selected.
    var defaultAscending: Bool {
        switch self {
        case .albumOrder, .name: true
        case .duplicateCount: false   // most duplicates first
        }
    }
}

/// A country (or special section) and its stickers the user owns spares of.
private struct DuplicateGroup: Identifiable {
    let id: String
    let title: String
    let items: [DuplicateItem]

    var totalCount: Int { items.reduce(0) { $0 + $1.count } }
}

private struct DuplicateItem: Identifiable {
    let code: String
    let count: Int   // number of spare copies
    var id: String { code }
}

struct DuplicatesView: View {
    @Environment(CollectionStore.self) private var store
    @AppStorage("duplicatesSortField") private var sortFieldRaw = DuplicateSortField.albumOrder.rawValue
    @AppStorage("duplicatesSortAscending") private var sortAscending = true

    private var sortField: DuplicateSortField {
        DuplicateSortField(rawValue: sortFieldRaw) ?? .albumOrder
    }

    var body: some View {
        Group {
            let groups = sortedGroups
            if groups.isEmpty {
                ContentUnavailableView {
                    Label("No Duplicates", systemImage: "doc.on.doc")
                } description: {
                    Text("Stickers you own more than one of will appear here.")
                }
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.items) { item in
                                HStack {
                                    Text(verbatim: item.code)
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                    Spacer()
                                    Text(verbatim: "×\(item.count)")
                                        .font(.caption.weight(.bold))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(.orange, in: Capsule())
                                        .foregroundStyle(.white)
                                }
                            }
                        } header: {
                            HStack {
                                Text(verbatim: group.title)
                                Spacer()
                                Text(verbatim: "\(group.totalCount)")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Duplicates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(DuplicateSortField.allCases) { field in
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

    /// Selecting the current field flips its direction; selecting a new field
    /// applies that field's default direction.
    private func selectSort(_ field: DuplicateSortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortFieldRaw = field.rawValue
            sortAscending = field.defaultAscending
        }
    }

    /// Duplicate groups in natural album order: countries first, then the
    /// special sections, each keeping its in-album sticker order.
    private var albumOrderGroups: [DuplicateGroup] {
        var result: [DuplicateGroup] = []
        for country in AlbumDefinition.countries {
            let items = duplicateItems(in: country.stickerCodes)
            if !items.isEmpty {
                result.append(DuplicateGroup(id: country.code, title: country.name, items: items))
            }
        }
        for section in SpecialSection.allCases {
            let items = duplicateItems(in: section.stickerCodes)
            if !items.isEmpty {
                result.append(DuplicateGroup(id: section.id, title: specialTitle(section), items: items))
            }
        }
        return result
    }

    private var sortedGroups: [DuplicateGroup] {
        let ascending: [DuplicateGroup]
        switch sortField {
        case .albumOrder:
            ascending = albumOrderGroups
        case .name:
            ascending = albumOrderGroups.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .duplicateCount:
            ascending = albumOrderGroups.sorted { $0.totalCount < $1.totalCount }
        }
        return sortAscending ? ascending : ascending.reversed()
    }

    private func duplicateItems(in codes: [String]) -> [DuplicateItem] {
        codes.compactMap { code in
            let count = store.duplicateCount(code)
            return count > 0 ? DuplicateItem(code: code, count: count) : nil
        }
    }

    private func specialTitle(_ section: SpecialSection) -> String {
        switch section {
        case .fwc: String(localized: "World Cup")
        case .special: String(localized: "Special")
        case .cocaCola: String(localized: "Coca-Cola")
        }
    }
}

#Preview {
    NavigationStack {
        DuplicatesView()
    }
    .environment(CollectionStore(repository: PreviewRepository()))
}
