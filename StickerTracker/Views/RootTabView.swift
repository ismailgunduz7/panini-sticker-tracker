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
            Tab("Stats", systemImage: "chart.bar.fill") {
                StatsView()
            }
            Tab("Achievements", systemImage: "trophy.fill") {
                AchievementsView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
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
