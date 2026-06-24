import SwiftUI
import VisionKit

/// Live camera text scanner. Wraps VisionKit's `DataScannerViewController`,
/// restricts recognition to a centered region, and reports both newly seen
/// sticker codes (`onCode`) and the code currently framed (`onCurrentCode`, or
/// `nil` when none) so the UI can show a ready/not-ready state.
///
/// A code is only committed via `onCode` once it has stayed framed, unchanged,
/// for `confirmDelay`. This debounce keeps a half-read code from being added too
/// early — e.g. catching `ARG1` on the way to `ARG14`.
struct DataScannerView: UIViewControllerRepresentable {
    /// How long a code must stay framed before it's committed.
    private static let confirmDelay: TimeInterval = 0.5

    /// Centered scan window, in the view's coordinate space. Text outside it is
    /// ignored.
    let regionOfInterest: CGRect
    /// Fires once a valid code has stayed framed for `confirmDelay`.
    let onCode: (String) -> Void
    /// The valid code currently framed, or `nil` when nothing valid is in view.
    let onCurrentCode: (String?) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        scanner.regionOfInterest = regionOfInterest
        try? scanner.startScanning()
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(confirmDelay: Self.confirmDelay, onCode: onCode, onCurrentCode: onCurrentCode)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let confirmDelay: TimeInterval
        private let onCode: (String) -> Void
        private let onCurrentCode: (String?) -> Void

        /// Valid codes for the items currently recognized, keyed by item id.
        private var currentCodes: [RecognizedItem.ID: String] = [:]
        /// Last code committed while it stays continuously framed — avoids
        /// re-adding the same sticker every frame.
        private var committedCode: String?
        /// True while a settle window is counting down.
        private var settling = false
        /// How many frames each code was seen during the current settle window.
        private var tally: [String: Int] = [:]

        init(confirmDelay: TimeInterval,
             onCode: @escaping (String) -> Void,
             onCurrentCode: @escaping (String?) -> Void) {
            self.confirmDelay = confirmDelay
            self.onCode = onCode
            self.onCurrentCode = onCurrentCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for case let .text(text) in addedItems {
                currentCodes[text.id] = StickerCodeParser.code(from: text.transcript)
            }
            evaluate()
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for case let .text(text) in updatedItems {
                currentCodes[text.id] = StickerCodeParser.code(from: text.transcript)
            }
            evaluate()
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didRemove removedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in removedItems {
                currentCodes[item.id] = nil
            }
            evaluate()
        }

        private func evaluate() {
            let code = currentCodes.values.first
            onCurrentCode(code)

            // Clear the "still framed" lock once the sticker leaves, so the next
            // sticker (or this one again) can be committed.
            if code == nil { committedCode = nil }

            // Tally every valid sighting during the window. We don't restart the
            // window on each frame and we commit the *most-seen* code rather than
            // whatever happens to be framed at the final instant — this rides out
            // OCR dropouts and lets a half-read code (ARG1 → ARG14) settle on the
            // value that actually dominates.
            guard let code, code != committedCode else { return }
            tally[code, default: 0] += 1

            guard !settling else { return }
            settling = true
            DispatchQueue.main.asyncAfter(deadline: .now() + confirmDelay) { [weak self] in
                guard let self else { return }
                self.settling = false
                defer { self.tally = [:] }
                guard let best = self.tally.max(by: { $0.value < $1.value })?.key,
                      best != self.committedCode else { return }
                self.committedCode = best
                self.onCode(best)
            }
        }
    }
}
