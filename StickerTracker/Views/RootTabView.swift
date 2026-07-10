import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct RootTabView: View {
    @AppStorage("appearancePreference") private var appearanceRaw = AppearancePreference.system.rawValue
    @Environment(FriendStore.self) private var friendStore
    @Environment(NotificationRouter.self) private var router
    @State private var incomingTrade: IncomingTrade?

    private struct IncomingTrade: Identifiable {
        let id = UUID()
        let payload: TradePayload
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Album", systemImage: "book.pages", value: RootTab.album) {
                HomeView()
            }
            Tab("Trade", systemImage: "arrow.left.arrow.right", value: RootTab.trade) {
                NavigationStack { TradeView() }
            }
            Tab("Friends", systemImage: "person.2.fill", value: RootTab.friends) {
                NavigationStack { FriendsView() }
            }
            .badge(friendStore.pendingBadgeCount)
            Tab("Stats", systemImage: "chart.bar.fill", value: RootTab.stats) {
                StatsView()
            }
            Tab("Account", systemImage: "person.crop.circle.fill", value: RootTab.account) {
                AccountView()
            }
        }
        .preferredColorScheme(AppearancePreference(rawValue: appearanceRaw)?.colorScheme)
        .achievementOverlay()
        .onOpenURL { url in
            if let payload = TradePayload.from(url: url) {
                incomingTrade = IncomingTrade(payload: payload)
            }
        }
        .sheet(item: $incomingTrade) { trade in
            TradeResultView(theirs: trade.payload)
        }
    }
}

#Preview {
    RootTabView()
        .environment(CollectionStore(repository: PreviewRepository()))
        .environment(AchievementStore(repository: PreviewAchievementRepository()))
        .environment(AccountStore(client: SupabaseService.client))
        .environment(FriendStore(client: SupabaseService.client))
        .environment(NotificationRouter())
}

/// In-memory repository for previews.
final class PreviewRepository: CollectionRepository {
    func loadAll() async throws -> [CollectionEntry] { [] }
    func upsert(_ entry: CollectionEntry) async throws {}
    func resetAll() async throws {}
}

/// In-memory achievement repository for previews.
final class PreviewAchievementRepository: AchievementRepository {
    func loadAll() async throws -> [AchievementEntry] { [] }
    func unlock(_ entry: AchievementEntry) async throws {}
    func revoke(_ id: String) async throws {}
    func resetAll() async throws {}
}
