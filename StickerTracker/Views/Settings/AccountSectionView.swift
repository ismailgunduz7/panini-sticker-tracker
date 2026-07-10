import AuthenticationServices
import SwiftUI

/// The Account section in Settings: sign in, profile summary, the privacy
/// toggle, and the two ways of leaving (reversible sign-out vs deletion).
struct AccountSectionView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingProfileSetup = false
    @State private var showingDeleteConfirmation = false
    @State private var hasAutoOpenedSetup = false
    @State private var editingDisplayName = ""
    @State private var showingNameEditor = false

    var body: some View {
        Section {
            switch account.phase {
            case .loading:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Checking account…")
                        .foregroundStyle(.secondary)
                }
            case .signedOut:
                SignInWithAppleButton(.signIn) { request in
                    account.prepareAppleRequest(request)
                } onCompletion: { result in
                    Task { await account.handleAppleCompletion(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 44)
                .listRowInsets(EdgeInsets())
            case .needsProfile:
                // Presentation modifiers live on individual rows, never on
                // the Section: List copies Section modifiers onto every row,
                // and duplicated sheet bindings dismiss each other.
                Button {
                    showingProfileSetup = true
                } label: {
                    Label("Choose Your Username", systemImage: "person.crop.circle.badge.plus")
                }
                .sheet(isPresented: $showingProfileSetup) {
                    ProfileSetupView()
                }
                .onAppear {
                    // Auto-open once right after sign-in; stay quiet on later
                    // visits so "Later" is respected.
                    if !hasAutoOpenedSetup {
                        hasAutoOpenedSetup = true
                        showingProfileSetup = true
                    }
                }
            case .signedIn(let profile):
                LabeledContent("Username", value: "@\(profile.username)")
                LabeledContent("Name") {
                    HStack(spacing: 8) {
                        Text(profile.displayName.isEmpty ? String(localized: "Not set") : profile.displayName)
                            .foregroundStyle(.secondary)
                        Button {
                            editingDisplayName = profile.displayName
                            showingNameEditor = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .alert("Edit Name", isPresented: $showingNameEditor) {
                    TextField("Display Name", text: $editingDisplayName)
                        .textInputAutocapitalization(.words)
                    Button("Cancel", role: .cancel) {}
                    Button("Save") { commitDisplayName(current: profile.displayName) }
                } message: {
                    Text("Your friends see this name alongside your username.")
                }
                Toggle("Share Full Album with Friends", isOn: shareFullAlbumBinding(profile))
                Button("Delete Account", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .confirmationDialog(
                    Text("Delete your account? Your friendships and online collection are removed permanently. The album on this device is kept."),
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Account", role: .destructive) {
                        Task { await account.deleteAccount() }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            if let message = account.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Account")
        } footer: {
            footerText
        }
    }

    private var footerText: Text {
        switch account.phase {
        case .loading, .signedOut:
            Text("Sign in to add friends and see which stickers you can trade with them.")
        case .needsProfile:
            Text("Pick a username so friends can find you.")
        case .signedIn:
            Text("When full album sharing is off, friends only see the stickers you can trade with each other.")
        }
    }

    private func commitDisplayName(current: String) {
        guard editingDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) != current else { return }
        Task { await account.updateDisplayName(editingDisplayName) }
    }

    private func shareFullAlbumBinding(_ profile: UserProfile) -> Binding<Bool> {
        Binding(
            get: { profile.shareFullAlbum },
            set: { newValue in Task { await account.setShareFullAlbum(newValue) } }
        )
    }
}
