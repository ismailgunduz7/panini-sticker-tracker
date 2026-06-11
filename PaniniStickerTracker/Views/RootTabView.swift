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

    var body: some View {
        TabView {
            Tab("Album", systemImage: "book.pages") {
                HomeView()
            }
            Tab("Stats", systemImage: "chart.bar.fill") {
                StatsView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .preferredColorScheme(AppearancePreference(rawValue: appearanceRaw)?.colorScheme)
    }
}

#Preview {
    RootTabView()
        .environment(CollectionStore(repository: PreviewRepository()))
}

/// In-memory repository for previews.
final class PreviewRepository: CollectionRepository {
    func loadAll() async throws -> [CollectionEntry] { [] }
    func upsert(_ entry: CollectionEntry) async throws {}
    func resetAll() async throws {}
}
