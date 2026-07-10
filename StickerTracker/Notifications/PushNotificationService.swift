import Foundation
import Observation
import Supabase
import UIKit
import UserNotifications

/// Owns the push-notification lifecycle: asking for permission after sign-in,
/// registering for remote notifications, and keeping the APNs device token in
/// sync with Supabase. The token is stored server-side so the `push` Edge
/// Function can deliver friend-related notifications.
@Observable
final class PushNotificationService {
    @ObservationIgnored private let client: SupabaseClient
    @ObservationIgnored private var deviceToken: String?

    private struct TokenParams: Encodable {
        let p_token: String
    }

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Request permission (once) and register for remote notifications. Called
    /// after sign-in so accountless users are never prompted.
    func enableAfterSignIn() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
            // If the token was already captured earlier this launch, make sure
            // the server has it now that we're signed in.
            if let deviceToken { await register(deviceToken) }
        }
    }

    /// Store the freshly issued APNs token (from the app delegate).
    func handleToken(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        deviceToken = token
        Task { await register(token) }
    }

    /// Drop the token server-side so the user stops receiving pushes on this
    /// device after signing out.
    func disableOnSignOut() {
        guard let deviceToken else { return }
        Task { _ = try? await client.rpc("unregister_device_token", params: TokenParams(p_token: deviceToken)).execute() }
    }

    private func register(_ token: String) async {
        _ = try? await client.rpc("register_device_token", params: TokenParams(p_token: token)).execute()
    }
}
