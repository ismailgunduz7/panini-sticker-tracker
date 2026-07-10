import SwiftUI
import AVFoundation
import PhotosUI
import VisionKit

/// The Trade tab: show your collection as a QR for others to scan, or scan
/// someone else's to see what you can swap.
struct TradeView: View {
    @Environment(CollectionStore.self) private var store

    private enum Mode: Hashable { case myQR, scan }
    private enum SaveStatus { case saved, failed }

    @State private var mode: Mode = .myQR
    @State private var result: ScannedTrade?
    @State private var showInvalid = false
    @State private var scannerID = UUID()
    @State private var cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @State private var pickerItem: PhotosPickerItem?
    @State private var saveStatus: SaveStatus?

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
        .onDisappear {
            // TabView keeps tab views alive, so the scanner is never
            // dismantled by a tab switch alone; leaving scan mode here is
            // what actually releases the camera.
            if mode == .scan { mode = .myQR }
        }
        .task { await requestCameraAccessIfNeeded() }
        .toolbar {
            if mode == .scan {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await scanPicked(item) }
        }
        .sheet(item: $result, onDismiss: { scannerID = UUID() }) { scanned in
            TradeResultView(theirs: scanned.payload)
        }
        .alert("Invalid QR code", isPresented: $showInvalid) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This QR code isn't a Sticker Tracker trade code.")
        }
        .alert("Saved to Photos", isPresented: .constant(saveStatus == .saved)) {
            Button("OK", role: .cancel) { saveStatus = nil }
        }
        .alert("Couldn't Save", isPresented: .constant(saveStatus == .failed)) {
            Button("OK", role: .cancel) { saveStatus = nil }
        } message: {
            Text("Allow photo access in Settings to save your QR code.")
        }
    }

    // MARK: - My QR

    private var myQRImage: UIImage? {
        QRCodeGenerator.image(for: TradePayload.current(store).url().absoluteString)
    }

    private var myQR: some View {
        VStack(spacing: 20) {
            Spacer()
            if let image = myQRImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 12) {
                    Button {
                        save(image)
                    } label: {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)

                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview("My Trade QR", image: Image(uiImage: image))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
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

    private func save(_ image: UIImage) {
        Task {
            saveStatus = await PhotoLibrarySaver.save(image) ? .saved : .failed
        }
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

    /// Decodes a QR from a photo the user picked from their library.
    private func scanPicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let string = QRCodeGenerator.decode(image),
              let url = URL(string: string) else {
            showInvalid = true
            return
        }
        handle(url: url)
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
    .environment(AccountStore(client: SupabaseService.client))
    .environment(FriendStore(client: SupabaseService.client))
}
