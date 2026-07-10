import SwiftUI

/// Shows the two-way trade matches between the local collection and a scanned
/// one: what the other collector can give you, and what you can give them.
struct TradeResultView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let theirs: TradePayload

    @State private var startingTrade = false

    private var hasMatches: Bool {
        let mine = TradePayload.current(store)
        return !TradeMatch.theyGiveYou(mine: mine, theirs: theirs).isEmpty
            || !TradeMatch.youGiveThem(mine: mine, theirs: theirs).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                TradeMatchSections(theirs: theirs)
            }
            .navigationTitle("Trade")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if hasMatches { startTradingBar }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $startingTrade) {
                TradeSessionView(theirs: theirs)
            }
        }
    }

    private var startTradingBar: some View {
        Button {
            startingTrade = true
        } label: {
            Label("Start Trading", systemImage: "arrow.left.arrow.right")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding()
        .background(.bar)
    }
}

#Preview {
    TradeResultView(theirs: TradePayload(owned: ["MEX1", "MEX2"], duplicates: ["MEX2"]))
        .environment(CollectionStore(repository: PreviewRepository()))
}
