import CoreImage.CIFilterBuiltins
import UIKit

/// Renders strings into QR code images with CoreImage.
enum QRCodeGenerator {
    private static let context = CIContext()

    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        // The raw image is tiny (one pixel per module); scale up without
        // smoothing so the modules stay crisp.
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Reads the first QR payload found in a still image (e.g. one picked from
    /// the photo library), or `nil` if none.
    static func decode(_ image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image)
            ?? image.cgImage.map(CIImage.init) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: context,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) ?? []
        for case let qr as CIQRCodeFeature in features {
            if let message = qr.messageString { return message }
        }
        return nil
    }
}
