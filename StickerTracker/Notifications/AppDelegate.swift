import UIKit
import UserNotifications

/// Bridges UIKit's remote-notification callbacks into the SwiftUI world. The
/// app wires these closures in `StickerTrackerApp` once its stores exist; a
/// cold-launch tap that arrives before wiring is remembered in
/// `pendingOpenFriends` and flushed then.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Called with the raw APNs device token once registration succeeds.
    var onDeviceToken: ((Data) -> Void)?
    /// Called when a notification arrives while the app is foregrounded.
    var onFriendActivity: (() -> Void)?
    /// Called when the user taps a notification.
    var onOpenFriends: (() -> Void)?

    /// Set when a tap is handled before `onOpenFriends` is wired (cold launch).
    var pendingOpenFriends = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        onDeviceToken?(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        // Best-effort: a failed registration just means no pushes this launch.
    }

    // Show a banner (and refresh the friends list) for pushes that land while
    // the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        onFriendActivity?()
        return [.banner, .sound]
    }

    // A tap on any notification routes to the Friends tab.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let onOpenFriends {
            onOpenFriends()
        } else {
            pendingOpenFriends = true
        }
    }
}
