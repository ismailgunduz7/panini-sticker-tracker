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
    @State private var incomingTrade: IncomingTrade?

    private struct IncomingTrade: Identifiable {
        let id = UUID()
        let payload: TradePayload
    }

    var body: some View {
        TabView {
            Tab("Album", systemImage: "book.pages") {
                HomeView()
            }
            Tab("Trade", systemImage: "arrow.left.arrow.right") {
                NavigationStack { TradeView() }
            }
            Tab("Friends", systemImage: "person.2.fill") {
                NavigationStack { FriendsView() }
            }
            .badge(friendStore.pendingBadgeCount)
            Tab("Stats", systemImage: "chart.bar.fill") {
                StatsView()
            }
            Tab("Account", systemImage: "person.crop.circle.fill") {
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
