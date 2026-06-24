import SwiftUI
import AVFoundation
import VisionKit

/// The Trade tab: show your collection as a QR for others to scan, or scan
/// someone else's to see what you can swap.
struct TradeView: View {
    @Environment(CollectionStore.self) private var store

    private enum Mode: Hashable { case myQR, scan }

    @State private var mode: Mode = .myQR
    @State private var result: ScannedTrade?
    @State private var showInvalid = false
    @State private var scannerID = UUID()
    @State private var cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized

    private struct ScannedTrade: Identifiable {
        let id = UUID()
        let payload: TradePayload
    }

    private var scannerSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                Text("My QR").tag(Mode.myQR)
                Text("Scan").tag(Mode.scan)
            }
            .pickerStyle(.segmented)
            .padding()

            switch mode {
            case .myQR: myQR
            case .scan: scanner
            }
        }
        .navigationTitle("Trade")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .task { await requestCameraAccessIfNeeded() }
        .sheet(item: $result, onDismiss: { scannerID = UUID() }) { scanned in
            TradeResultView(theirs: scanned.payload)
        }
        .alert("Invalid QR code", isPresented: $showInvalid) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This QR code isn't a Panini trade code.")
        }
    }

    // MARK: - My QR

    private var myQR: some View {
        VStack(spacing: 20) {
            Spacer()
            if let image = QRCodeGenerator.image(for: TradePayload.current(store).url().absoluteString) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            Text("Have another collector scan this to find stickers you can trade.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scan

    @ViewBuilder
    private var scanner: some View {
        if scannerSupported && cameraAuthorized {
            QRScannerView(onURL: handle(url:))
                .id(scannerID)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
        } else {
            cameraUnavailable
        }
    }

    private var cameraUnavailable: some View {
        ContentUnavailableView {
            Label(
                cameraAuthorized ? "Camera Unavailable" : "Camera Access Needed",
                systemImage: "camera.fill"
            )
        } description: {
            Text(cameraAuthorized
                 ? "This device can't scan QR codes with the camera."
                 : "Allow camera access in Settings to scan trade QR codes.")
        } actions: {
            if !cameraAuthorized, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { UIApplication.shared.open(url) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handle(url: URL) {
        if let payload = TradePayload.from(url: url) {
            result = ScannedTrade(payload: payload)
        } else {
            showInvalid = true
            scannerID = UUID()
        }
    }

    private func requestCameraAccessIfNeeded() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else { return }
        cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
    }
}

#Preview {
    NavigationStack {
        TradeView()
    }
    .environment(CollectionStore(repository: PreviewRepository()))
}
