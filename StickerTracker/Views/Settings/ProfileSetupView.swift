import SwiftUI

/// Post-sign-in username and display-name setup, prefilled from what Apple
/// provided on first authorization. Dismissible: the user can finish later
/// from Settings (the account stays in the needs-profile state until then).
struct ProfileSetupView: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var displayName = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private static let allowedCharacters = Set("abcdefghijklmnopqrstuvwxyz0123456789_.")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: username) { _, newValue in
                            username = String(
                                newValue.lowercased()
                                    .filter { Self.allowedCharacters.contains($0) }
                                    .prefix(20)
                            )
                        }
                } footer: {
                    Text("3–20 characters: lowercase letters, numbers, dots and underscores. Friends find you by this name.")
                }

                Section {
                    TextField("Display Name", text: $displayName)
                } footer: {
                    Text("Optional. Shown to your friends alongside your username.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Profile")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Create") { submit() }
                            .disabled(username.count < 3)
                    }
                }
            }
            .onAppear {
                if username.isEmpty { username = account.suggestedUsername }
                if displayName.isEmpty { displayName = account.suggestedDisplayName }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await account.claimProfile(username: username, displayName: displayName)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
