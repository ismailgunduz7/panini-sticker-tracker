import SwiftUI

/// The Account tab: the signed-in profile summary plus a way into the rest
/// of the app's preferences. Settings that are not account-related live on a
/// pushed `SettingsView` page.
struct AccountView: View {
    var body: some View {
        NavigationStack {
            List {
                AccountSectionView()

                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}

#Preview {
    AccountView()
        .environment(CollectionStore(repository: PreviewRepository()))
        .environment(AchievementStore(repository: PreviewAchievementRepository()))
        .environment(AccountStore(client: SupabaseService.client))
}
