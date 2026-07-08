import SwiftUI

/// Shows the two-way trade matches between the local collection and a scanned
/// one: what the other collector can give you, and what you can give them.
struct TradeResultView: View {
    @Environment(\.dismiss) private var dismiss
    let theirs: TradePayload

    var body: some View {
        NavigationStack {
            List {
                TradeMatchSections(theirs: theirs)
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
}

#Preview {
    TradeResultView(theirs: TradePayload(owned: ["MEX1", "MEX2"], duplicates: ["MEX2"]))
        .environment(CollectionStore(repository: PreviewRepository()))
}
