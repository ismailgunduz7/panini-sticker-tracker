//
//  PaniniStickerTrackerApp.swift
//  PaniniStickerTracker
//
//  Created by Ismail on 11.06.2026.
//

import SwiftUI
import SwiftData

@main
struct PaniniStickerTrackerApp: App {
    private let container: ModelContainer
    @State private var store: CollectionStore

    init() {
        do {
            let container = try ModelContainer(for: StickerEntry.self)
            self.container = container
            _store = State(initialValue: CollectionStore(
                repository: LocalCollectionRepository(context: container.mainContext)
            ))
        } catch {
            fatalError("Failed to set up persistence: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .task { await store.load() }
        }
        .modelContainer(container)
    }
}
