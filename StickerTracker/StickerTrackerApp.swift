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
    @State private var store: CollectionStore
    @State private var achievementStore: AchievementStore

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
            // Re-evaluate achievements on every collection change.
            store.onEntriesChanged = { [achievementStore] entries in
                achievementStore.evaluate(entries: entries)
            }
            _store = State(initialValue: store)
            _achievementStore = State(initialValue: achievementStore)
        } catch {
            fatalError("Failed to set up persistence: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .environment(achievementStore)
                .task {
                    await store.load()
                    await achievementStore.load()
                    // First-launch catch-up: record existing progress silently.
                    achievementStore.backfill(entries: store.entries)
                }
        }
        .modelContainer(container)
    }
}
