import Observation

/// The bottom-bar tabs. Used as `TabView` selection values so a notification
/// tap can jump to a specific tab.
enum RootTab: Hashable {
    case album, trade, friends, stats, account
}

/// Drives `TabView` selection so taps on a push notification can route the
/// user to the right tab (all current notifications are friend-related).
@Observable
final class NotificationRouter {
    var selectedTab: RootTab = .album
}
