import SwiftUI

/// The Account tab: the signed-in profile summary plus a way into the rest
/// of the app's preferences. Settings that are not account-related live on a
/// pushed `SettingsView` page.
struct AccountView: View {
    @Environment(AccountStore.self) private var account
    @Environment(CollectionStore.self) private var store
    @Environment(AchievementStore.self) private var achievements
    @State private var showingSignOutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingResetConfirmation = false

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

                Section {
                    if case .signedIn = account.phase {
                        Button("Delete Account", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                            Button("Delete Account", role: .destructive) {
                                Task { await account.deleteAccount() }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Your friendships and online collection are removed permanently. The album on this device is kept.")
                        }
                    }
                    Button("Reset All Data", role: .destructive) {
                        showingResetConfirmation = true
                    }
                    .alert("Reset All Data", isPresented: $showingResetConfirmation) {
                        Button("Reset All Data", role: .destructive) {
                            store.resetAll()
                            achievements.resetAll()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This deletes all collection data on this device and cannot be undone.")
                    }
                } header: {
                    Text("Danger Zone")
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
