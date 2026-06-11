import SwiftUI

/// Lets the user start a duplicate pile for an owned sticker that doesn't have
/// one yet. Candidates are owned stickers with a zero duplicate count, grouped
/// by country (then the special sections) in album order.
struct AddDuplicateSheet: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private struct CandidateGroup: Identifiable {
        let id: String
        let title: String
        let codes: [String]
    }

    var body: some View {
        NavigationStack {
            Group {
                let groups = candidateGroups
                if groups.isEmpty {
                    ContentUnavailableView {
                        Label("No Stickers Available", systemImage: "doc.on.doc")
                    } description: {
                        Text("Only owned stickers without a duplicate can be added here.")
                    }
                } else {
                    List {
                        ForEach(groups) { group in
                            Section(group.title) {
                                ForEach(group.codes, id: \.self) { code in
                                    HStack {
                                        Text(verbatim: code)
                                            .font(.subheadline.weight(.semibold).monospacedDigit())
                                        Spacer()
                                        Button {
                                            add(code)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title3)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Duplicate")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("Search code or country"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func add(_ code: String) {
        withAnimation {
            store.adjustDuplicates(code, by: 1)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var candidateGroups: [CandidateGroup] {
        var result: [CandidateGroup] = []
        for country in AlbumDefinition.countries {
            let codes = country.stickerCodes.filter { eligible($0) && matches($0, country.name) }
            if !codes.isEmpty {
                result.append(CandidateGroup(id: country.code, title: country.name, codes: codes))
            }
        }
        for section in SpecialSection.allCases {
            let codes = section.stickerCodes.filter { eligible($0) && matches($0, section.displayName) }
            if !codes.isEmpty {
                result.append(CandidateGroup(id: section.id, title: section.displayName, codes: codes))
            }
        }
        return result
    }

    /// Owned, but no duplicate yet — duplicates only make sense for stickers you have.
    private func eligible(_ code: String) -> Bool {
        store.isOwned(code) && store.duplicateCount(code) == 0
    }

    private func matches(_ code: String, _ name: String) -> Bool {
        searchText.isEmpty
            || code.localizedCaseInsensitiveContains(searchText)
            || name.localizedCaseInsensitiveContains(searchText)
    }
}

#Preview {
    AddDuplicateSheet()
        .environment(CollectionStore(repository: PreviewRepository()))
}
