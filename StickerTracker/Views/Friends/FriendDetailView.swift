import SwiftUI

/// A friend's tradable stickers: what they can give you and what you can
/// give them, computed with the same TradeMatch pipeline as the QR flow.
/// How much of their album is visible depends on their privacy setting.
struct FriendDetailView: View {
    let friend: FriendStore.Friendship

    @Environment(FriendStore.self) private var friendStore
    @Environment(CollectionStore.self) private var store
    @State private var loadState: LoadState = .loading
    @State private var startingTrade = false

    private enum LoadState {
        case loading
        case failed
        case loaded(FriendStore.FriendCollection)
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed:
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("Check your connection and try again.")
                } actions: {
                    Button("Retry") {
                        loadState = .loading
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .loaded(let collection):
                List {
                    if collection.ownedCount != nil || collection.lastUpdated != nil {
                        Section {
                            if let ownedCount = collection.ownedCount {
                                LabeledContent("Album Progress") {
                                    Text(verbatim: "\(ownedCount) / \(AlbumDefinition.orderedStickerCodes.count)")
                                        .monospacedDigit()
                                }
                            }
                            if let lastUpdated = collection.lastUpdated {
                                LabeledContent("Last Updated") {
                                    Text(lastUpdated, format: .relative(presentation: .named))
                                }
                            }
                        } footer: {
                            if collection.ownedCount == nil {
                                Text("This friend shares only the stickers you can trade with each other.")
                            }
                        }
                    }
                    TradeMatchSections(theirs: collection.payload)
                }
                .refreshable {
                    await load()
                }
                .safeAreaInset(edge: .bottom) {
                    if hasMatches(with: collection.payload) { startTradingBar(collection.payload) }
                }
                .sheet(isPresented: $startingTrade) {
                    TradeSessionView(theirs: collection.payload, title: "@\(friend.username)")
                }
            }
        }
        .navigationTitle("@\(friend.username)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func hasMatches(with theirs: TradePayload) -> Bool {
        let mine = TradePayload.current(store)
        return !TradeMatch.theyGiveYou(mine: mine, theirs: theirs).isEmpty
            || !TradeMatch.youGiveThem(mine: mine, theirs: theirs).isEmpty
    }

    private func startTradingBar(_ theirs: TradePayload) -> some View {
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

    private func load() async {
        do {
            loadState = .loaded(try await friendStore.loadCollection(of: friend.id))
        } catch {
            if case .loading = loadState { loadState = .failed }
        }
    }
}
