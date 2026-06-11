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
    @State private var showingAdd = false

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
                    Text("Press and hold a sticker on its album page to add a duplicate.")
                }
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.items) { item in
                                HStack(spacing: 16) {
                                    Text(verbatim: item.code)
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                    Spacer()
                                    Button {
                                        adjust(item.code, by: -1)
                                    } label: {
                                        Image(systemName: item.count == 1 ? "trash.fill" : "minus.circle.fill")
                                            .font(.title3)
                                    }
                                    .buttonStyle(.borderless)
                                    .tint(item.count == 1 ? .red : .secondary)

                                    Text(verbatim: "×\(item.count)")
                                        .font(.subheadline.weight(.bold).monospacedDigit())
                                        .frame(minWidth: 34)

                                    Button {
                                        adjust(item.code, by: 1)
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                    }
                                    .buttonStyle(.borderless)
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
        .sheet(isPresented: $showingAdd) {
            AddDuplicateSheet()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
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

    private func adjust(_ code: String, by delta: Int) {
        store.adjustDuplicates(code, by: delta)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                result.append(DuplicateGroup(id: section.id, title: section.displayName, items: items))
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
}

#Preview {
    NavigationStack {
        DuplicatesView()
    }
    .environment(CollectionStore(repository: PreviewRepository()))
}
