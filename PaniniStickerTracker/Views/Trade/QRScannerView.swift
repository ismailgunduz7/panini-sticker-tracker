import SwiftUI
import Vision
import VisionKit

/// Live camera QR scanner. Wraps VisionKit's `DataScannerViewController` in
/// barcode mode and reports the first scanned payload as a URL.
struct QRScannerView: UIViewControllerRepresentable {
    let onURL: (URL) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        try? scanner.startScanning()
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onURL: onURL)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onURL: (URL) -> Void
        /// Fire only once — the result screen takes over after the first read.
        private var handled = false

        init(onURL: @escaping (URL) -> Void) {
            self.onURL = onURL
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for case let .barcode(barcode) in addedItems {
                guard !handled,
                      let string = barcode.payloadStringValue,
                      let url = URL(string: string),
                      url.scheme == TradePayload.scheme
                else { continue }
                handled = true
                onURL(url)
                return
            }
        }
    }
}
