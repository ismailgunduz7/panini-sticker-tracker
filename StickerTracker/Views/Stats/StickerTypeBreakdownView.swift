import SwiftUI

/// Alphabetical collected/missing country breakdown for one per-country
/// sticker type (federation logo, team photo), opened from the stats list.
struct StickerTypeBreakdownView: View {
    let title: LocalizedStringKey
    /// The sticker's number within each country's strip.
    let stickerNumber: Int

    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let sorted = AlbumDefinition.countries.sorted { $0.name < $1.name }
        let collected = sorted.filter { store.isOwned(code(for: $0)) }
        let missing = sorted.filter { !store.isOwned(code(for: $0)) }

        NavigationStack {
            List {
                Section("Collected (\(collected.count))") {
                    if collected.isEmpty {
                        Text("None yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(collected, id: \.code) { country in
                            row(country)
                        }
                    }
                }
                Section("Missing (\(missing.count))") {
                    if missing.isEmpty {
                        Text("None — complete!")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(missing, id: \.code) { country in
                            row(country)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func code(for country: Country) -> String {
        "\(country.code)\(stickerNumber)"
    }

    private func row(_ country: Country) -> some View {
        HStack {
            Text(verbatim: country.name)
            Spacer()
            Text(verbatim: code(for: country))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StickerTypeBreakdownView(title: "Federation Logos", stickerNumber: 1)
        .environment(CollectionStore(repository: PreviewRepository()))
}
