import Foundation
import Observation

/// One sticker captured during a scan, with the number of copies to register.
struct ScannedItem: Identifiable, Hashable {
    let code: String
    var count: Int
    var id: String { code }
}

/// Holds the running list of stickers scanned in a single camera session, with
/// the most recently scanned sticker first. The list is committed to the
/// collection only when the user taps Done — until then nothing is persisted.
@Observable
final class ScanSession {
    private(set) var items: [ScannedItem] = []

    /// When true, each scanned sticker is registered as a duplicate (which also
    /// implies ownership). When false, stickers are only marked as owned.
    var registerDuplicates = true

    /// Adds a freshly scanned code. Codes already in the session are ignored so
    /// keeping a sticker in frame doesn't inflate its count. Returns whether the
    /// code was newly added, letting the caller fire feedback only on real adds.
    @discardableResult
    func add(_ code: String) -> Bool {
        guard !items.contains(where: { $0.code == code }) else { return false }
        items.insert(ScannedItem(code: code, count: 1), at: 0)
        return true
    }

    func contains(_ code: String) -> Bool {
        items.contains { $0.code == code }
    }

    func adjust(_ code: String, by delta: Int) {
        guard let index = items.firstIndex(where: { $0.code == code }) else { return }
        let newCount = items[index].count + delta
        if newCount <= 0 {
            items.remove(at: index)
        } else {
            items[index].count = newCount
        }
    }

    func remove(_ code: String) {
        items.removeAll { $0.code == code }
    }

    /// Commits every scanned sticker to the collection.
    func apply(to store: CollectionStore) {
        for item in items {
            if registerDuplicates {
                store.adjustDuplicates(item.code, by: item.count)
            } else {
                store.setOwned([item.code], owned: true)
            }
        }
    }
}
