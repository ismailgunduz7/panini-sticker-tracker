//
//  StickerTrackerApp.swift
//  StickerTracker
//
//  Created by Ismail on 11.06.2026.
//

import SwiftUI
import SwiftData

@main
struct StickerTrackerApp: App {
    private let container: ModelContainer
    private let syncEngine: SyncEngine
    @State private var store: CollectionStore
    @State private var achievementStore: AchievementStore
    @State private var accountStore: AccountStore
    @State private var friendStore: FriendStore
    @State private var pushService: PushNotificationService
    @State private var notificationRouter: NotificationRouter
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let container = try ModelContainer(for: StickerEntry.self, AchievementRecord.self)
            self.container = container
            let store = CollectionStore(
                repository: LocalCollectionRepository(context: container.mainContext)
            )
            let achievementStore = AchievementStore(
                repository: LocalAchievementRepository(context: container.mainContext)
            )
            let accountStore = AccountStore(client: SupabaseService.client)
            let friendStore = FriendStore(client: SupabaseService.client)
            let pushService = PushNotificationService(client: SupabaseService.client)
            let notificationRouter = NotificationRouter()
            let syncEngine = SyncEngine(client: SupabaseService.client, store: store)
            self.syncEngine = syncEngine

            syncEngine.isReady = { accountStore.profile != nil }
            // Re-evaluate achievements and push to the server (when an
            // account is linked) on every collection change.
            store.onEntriesChanged = { [achievementStore, syncEngine] entries in
                achievementStore.evaluate(entries: entries)
                syncEngine.schedulePush()
            }
            accountStore.onSignedIn = { [store, syncEngine, friendStore, pushService] in
                store.preservesResetTombstones = true
                syncEngine.syncNow()
                Task { await friendStore.refresh() }
                pushService.enableAfterSignIn()
            }
            accountStore.onSignedOut = { [store, friendStore, pushService] in
                store.preservesResetTombstones = false
                friendStore.clear()
                pushService.disableOnSignOut()
            }

            _store = State(initialValue: store)
            _achievementStore = State(initialValue: achievementStore)
            _accountStore = State(initialValue: accountStore)
            _friendStore = State(initialValue: friendStore)
            _pushService = State(initialValue: pushService)
            _notificationRouter = State(initialValue: notificationRouter)
        } catch {
            fatalError("Failed to set up persistence: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(achievementStore)
                .environment(accountStore)
                .environment(friendStore)
                .environment(pushService)
                .environment(notificationRouter)
                .task {
                    // Bridge the app-delegate's remote-notification callbacks
                    // into the stores now that they exist.
                    appDelegate.onDeviceToken = { [pushService] data in pushService.handleToken(data) }
                    appDelegate.onFriendActivity = { [accountStore, friendStore] in
                        if accountStore.profile != nil { Task { await friendStore.refresh() } }
                    }
                    appDelegate.onOpenFriends = { [notificationRouter] in notificationRouter.selectedTab = .friends }
                    // Flush a tap that arrived during cold launch, before wiring.
                    if appDelegate.pendingOpenFriends {
                        notificationRouter.selectedTab = .friends
                        appDelegate.pendingOpenFriends = false
                    }

                    await store.load()
                    await achievementStore.load()
                    // First-launch catch-up: record existing progress silently.
                    achievementStore.backfill(entries: store.entries)
                    await accountStore.bootstrap()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        syncEngine.syncNow()
                        if accountStore.profile != nil {
                            Task { await friendStore.refresh() }
                        }
                    }
                }
        }
        .modelContainer(container)
    }
}
