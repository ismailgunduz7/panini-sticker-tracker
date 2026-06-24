import SwiftUI

/// Shows the two-way trade matches between the local collection and a scanned
/// one: what the other collector can give you, and what you can give them.
struct TradeResultView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let theirs: TradePayload

    var body: some View {
        let mine = TradePayload.current(store)
        let theyGive = TradeMatch.theyGiveYou(mine: mine, theirs: theirs)
        let youGive = TradeMatch.youGiveThem(mine: mine, theirs: theirs)

        NavigationStack {
            List {
                direction("They can give you", groups: theyGive)
                direction("You can give them", groups: youGive)
            }
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func direction(_ title: LocalizedStringKey, groups: [TradeGroup]) -> some View {
        Section {
            if groups.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: group.title)
                            .font(.subheadline.weight(.semibold))
                        Text(verbatim: group.codes.joined(separator: ", "))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Text(verbatim: "\(groups.reduce(0) { $0 + $1.count })")
                    .monospacedDigit()
            }
        }
    }
}

#Preview {
    TradeResultView(theirs: TradePayload(owned: ["MEX1", "MEX2"], duplicates: ["MEX2"]))
        .environment(CollectionStore(repository: PreviewRepository()))
}
