import SwiftUI

/// The two trade-direction sections ("They can give you" / "You can give
/// them") computed against the local collection. Shared by the QR result
/// sheet and the friend detail screen; embed inside a List.
struct TradeMatchSections: View {
    @Environment(CollectionStore.self) private var store
    let theirs: TradePayload

    var body: some View {
        let mine = TradePayload.current(store)
        direction("They can give you", groups: TradeMatch.theyGiveYou(mine: mine, theirs: theirs))
        direction("You can give them", groups: TradeMatch.youGiveThem(mine: mine, theirs: theirs))
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
