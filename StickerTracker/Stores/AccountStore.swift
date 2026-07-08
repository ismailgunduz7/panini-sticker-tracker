import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Supabase

/// Owns the Supabase auth session and the user's profile. The album keeps
/// working without an account; this store only powers the social features.
@Observable
final class AccountStore {
    enum Phase: Equatable {
        case loading
        case signedOut
        /// Authenticated but no profile row yet — username setup pending.
        case needsProfile
        case signedIn(UserProfile)
    }

    enum ProfileClaimError: LocalizedError {
        case taken, invalid, reserved, other

        var errorDescription: String? {
            switch self {
            case .taken: String(localized: "That username is already taken.")
            case .invalid: String(localized: "Usernames are 3–20 characters: lowercase letters, numbers, dots and underscores.")
            case .reserved: String(localized: "That username is not available.")
            case .other: String(localized: "Something went wrong. Please try again.")
            }
        }
    }

    private(set) var phase: Phase = .loading
    private(set) var errorMessage: String?
    /// Prefill for the profile-setup screen, captured from the first Apple
    /// authorization (Apple never returns name/email again afterwards).
    private(set) var suggestedUsername = ""
    private(set) var suggestedDisplayName = ""

    /// Fired whenever a signed-in session with a profile becomes ready, so
    /// the app can kick off the initial sync/migration.
    @ObservationIgnored var onSignedIn: (() -> Void)?
    @ObservationIgnored var onSignedOut: (() -> Void)?

    @ObservationIgnored private let client: SupabaseClient
    @ObservationIgnored private var currentNonce: String?

    private static let usernameSuggestionKey = "account.suggestedUsername"
    private static let displayNameSuggestionKey = "account.suggestedDisplayName"

    var profile: UserProfile? {
        if case .signedIn(let profile) = phase { profile } else { nil }
    }

    init(client: SupabaseClient) {
        self.client = client
    }

    func bootstrap() async {
        guard (try? await client.auth.session) != nil else {
            phase = .signedOut
            return
        }
        await refreshProfile()
    }

    // MARK: - Sign in with Apple

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        errorMessage = nil
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        // Apple receives the SHA256 of the nonce; the raw value goes to
        // Supabase, which verifies the pair to prevent token replay.
        request.nonce = SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, any Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = String(localized: "Sign in failed. Please try again.")
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce
            else {
                errorMessage = String(localized: "Sign in failed. Please try again.")
                return
            }
            captureSuggestions(from: credential)
            do {
                try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
                )
                await refreshProfile()
            } catch {
                errorMessage = String(localized: "Sign in failed. Please try again.")
            }
        }
    }

    /// Apple provides name and email only on the very first authorization,
    /// so they are persisted immediately in case setup is interrupted.
    private func captureSuggestions(from credential: ASAuthorizationAppleIDCredential) {
        let defaults = UserDefaults.standard
        if let name = credential.fullName {
            let formatted = PersonNameComponentsFormatter.localizedString(from: name, style: .default)
            if !formatted.isEmpty {
                defaults.set(formatted, forKey: Self.displayNameSuggestionKey)
            }
        }
        // A Hide My Email relay address has a meaningless local part; suggest
        // nothing in that case and let the user type a name.
        if let email = credential.email,
           !email.hasSuffix("@privaterelay.appleid.com"),
           let localPart = email.split(separator: "@").first {
            let sanitized = String(
                localPart.lowercased()
                    .filter { "abcdefghijklmnopqrstuvwxyz0123456789_.".contains($0) }
                    .prefix(20)
            )
            if sanitized.count >= 3 {
                defaults.set(sanitized, forKey: Self.usernameSuggestionKey)
            }
        }
    }

    // MARK: - Profile

    private func refreshProfile() async {
        guard let userId = try? await client.auth.session.user.id else {
            phase = .signedOut
            return
        }
        do {
            let profiles: [UserProfile] = try await client.from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            if var profile = profiles.first {
                if !profile.isActive {
                    // Returning after a sign-out: become visible again.
                    try await client.from("profiles")
                        .update(["is_active": true])
                        .eq("id", value: userId)
                        .execute()
                    profile.isActive = true
                }
                phase = .signedIn(profile)
                onSignedIn?()
            } else {
                let defaults = UserDefaults.standard
                suggestedUsername = defaults.string(forKey: Self.usernameSuggestionKey) ?? ""
                suggestedDisplayName = defaults.string(forKey: Self.displayNameSuggestionKey) ?? ""
                phase = .needsProfile
            }
        } catch {
            errorMessage = String(localized: "Could not load your profile. Check your connection and try again.")
            phase = .signedOut
        }
    }

    func claimProfile(username: String, displayName: String) async throws {
        struct Params: Encodable {
            let p_username: String
            let p_display_name: String
        }
        do {
            try await client
                .rpc("claim_profile", params: Params(p_username: username, p_display_name: displayName))
                .execute()
        } catch {
            let raw = String(describing: error)
            if raw.contains("username_taken") { throw ProfileClaimError.taken }
            if raw.contains("username_invalid") { throw ProfileClaimError.invalid }
            if raw.contains("username_reserved") { throw ProfileClaimError.reserved }
            throw ProfileClaimError.other
        }
        UserDefaults.standard.removeObject(forKey: Self.usernameSuggestionKey)
        UserDefaults.standard.removeObject(forKey: Self.displayNameSuggestionKey)
        await refreshProfile()
    }

    func setShareFullAlbum(_ share: Bool) async {
        guard var profile, let userId = try? await client.auth.session.user.id else { return }
        do {
            try await client.from("profiles")
                .update(["share_full_album": share])
                .eq("id", value: userId)
                .execute()
            profile.shareFullAlbum = share
            phase = .signedIn(profile)
        } catch {
            errorMessage = String(localized: "Could not update the setting. Check your connection.")
        }
    }

    // MARK: - Leaving

    /// Sign-out keeps all server data but hides the profile from friends.
    /// Local album data is untouched — the app returns to accountless mode.
    func signOut() async {
        if let userId = try? await client.auth.session.user.id {
            _ = try? await client.from("profiles")
                .update(["is_active": false])
                .eq("id", value: userId)
                .execute()
        }
        try? await client.auth.signOut()
        phase = .signedOut
        onSignedOut?()
    }

    /// Permanent: cascades away the profile, friendships and the server copy
    /// of the collection, and frees the username. Local data stays on device.
    func deleteAccount() async {
        do {
            try await client.rpc("delete_account").execute()
        } catch {
            errorMessage = String(localized: "Could not delete your account. Check your connection and try again.")
            return
        }
        try? await client.auth.signOut(scope: .local)
        phase = .signedOut
        onSignedOut?()
    }

    private static func randomNonce() -> String {
        let charset = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-._"
        // SystemRandomNumberGenerator (behind randomElement) is
        // cryptographically secure.
        return String((0..<32).compactMap { _ in charset.randomElement() })
    }
}
