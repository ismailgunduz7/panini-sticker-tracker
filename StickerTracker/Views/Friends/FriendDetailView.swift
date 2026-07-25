import SwiftUI

/// A friend's collection. When they share their full album you can browse
/// everything they own, are missing, and have as spares in separate tabs;
/// otherwise only the tradable overlap is shown. Trade matches are computed
/// with the same TradeMatch pipeline as the QR flow.
struct FriendDetailView: View {
    let friend: FriendStore.Friendship

    @Environment(FriendStore.self) private var friendStore
    @Environment(CollectionStore.self) private var store
    @State private var loadState: LoadState = .loading
    @State private var startingTrade = false
    @State private var tab: Tab = .trade

    private enum LoadState {
        case loading
        case failed
        case loaded(FriendStore.FriendCollection)
    }

    /// The browse tabs available when the friend shares their full album.
    private enum Tab: String, CaseIterable, Identifiable {
        case trade, owned, missing, spares

        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .trade: "Trade"
            case .owned: "Owned"
            case .missing: "Missing"
            case .spares: "Spares"
            }
        }
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
                let sharesFullAlbum = collection.ownedCount != nil
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

                    if sharesFullAlbum {
                        Section {
                            Picker("View", selection: $tab) {
                                ForEach(Tab.allCases) { tab in
                                    Text(tab.label).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                    }

                    content(for: sharesFullAlbum ? tab : .trade, collection: collection)
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

    @ViewBuilder
    private func content(for tab: Tab, collection: FriendStore.FriendCollection) -> some View {
        switch tab {
        case .trade:
            TradeMatchSections(theirs: collection.payload)
        case .owned:
            browseSections(collection.payload.owned,
                           emptyMessage: "This friend hasn't collected any stickers yet.")
        case .missing:
            let missing = Set(AlbumDefinition.orderedStickerCodes)
                .subtracting(collection.payload.owned)
            browseSections(missing, emptyMessage: "This friend has completed the album!")
        case .spares:
            browseSections(collection.payload.duplicates,
                           emptyMessage: "This friend has no spare stickers.")
        }
    }

    /// Album-ordered sections of sticker codes, one per country/special section.
    @ViewBuilder
    private func browseSections(_ codes: Set<String>, emptyMessage: LocalizedStringKey) -> some View {
        let groups = TradeMatch.grouped(codes)
        if groups.isEmpty {
            Section {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(groups) { group in
                Section {
                    Text(verbatim: group.codes.joined(separator: ", "))
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                } header: {
                    HStack {
                        Text(verbatim: group.title)
                        Spacer()
                        Text(verbatim: "\(group.count)")
                            .monospacedDigit()
                    }
                }
            }
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
