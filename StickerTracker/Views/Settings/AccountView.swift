import SwiftUI

/// The Account tab: the signed-in profile summary plus a way into the rest
/// of the app's preferences. Settings that are not account-related live on a
/// pushed `SettingsView` page.
struct AccountView: View {
    @Environment(AccountStore.self) private var account
    @State private var showingSignOutConfirmation = false

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
            .toolbar {
                if case .signedIn = account.phase {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign Out") {
                            showingSignOutConfirmation = true
                        }
                    }
                }
            }
            .confirmationDialog(
                Text("Sign out? Your album stays on this device, and friends will no longer see your collection."),
                isPresented: $showingSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await account.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    AccountView()
        .environment(CollectionStore(repository: PreviewRepository()))
        .environment(AchievementStore(repository: PreviewAchievementRepository()))
        .environment(AccountStore(client: SupabaseService.client))
}
