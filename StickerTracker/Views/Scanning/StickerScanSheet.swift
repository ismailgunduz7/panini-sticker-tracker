import SwiftUI
import AVFoundation
import VisionKit

/// Full-screen camera sheet that continuously reads sticker codes and lets the
/// user review them before committing. Stays open, scanning, until the user taps
/// Done (apply) or Cancel (discard).
struct StickerScanSheet: View {
    @Environment(CollectionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var session = ScanSession()
    @State private var cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    /// The code currently framed in the scan window, or `nil` when none — drives
    /// the frame's ready (green) / not-ready (red) state.
    @State private var currentCode: String?
    /// A just-added code kept on screen briefly after it leaves the frame, so the
    /// confirmation chip lingers instead of vanishing the moment the camera moves.
    @State private var recentlyAddedCode: String?
    @State private var lingerTask: Task<Void, Never>?
    /// Whether the "Register Duplicates" explanation modal is shown.
    @State private var showingRegisterInfo = false

    private var scannerSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cameraSection
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .background(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()

                controls
            }
            .navigationTitle("Scan Stickers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done (\(session.items.count))") {
                        session.apply(to: store)
                        dismiss()
                    }
                    .disabled(session.items.isEmpty)
                }
            }
        }
        .task { await requestCameraAccessIfNeeded() }
        .sheet(isPresented: $showingRegisterInfo) {
            registerInfoSheet
        }
    }

    /// Explains what the Register Duplicates toggle does in each state.
    private var registerInfoSheet: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("On")
                                .font(.headline)
                            Text("Each copy you scan counts toward your collection. The first copy of a sticker you don't have yet fills its album slot; any extra copies — or copies of a sticker you already own — are added as duplicates you can trade.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.on.square.fill")
                            .foregroundStyle(.green)
                    }
                    .labelStyle(.titleAndIcon)
                }

                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Off")
                                .font(.headline)
                            Text("Scanned stickers are only marked as owned in your album. Extra copies are ignored, so nothing is added to your duplicates. Use this when you're just filling in stickers you're missing.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.square.fill")
                            .foregroundStyle(.secondary)
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
            .navigationTitle("Register Duplicates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingRegisterInfo = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var cameraSection: some View {
        if scannerSupported && cameraAuthorized {
            GeometryReader { proxy in
                let frame = scanFrame(in: proxy.size)
                DataScannerView(
                    regionOfInterest: frame,
                    onCode: handle(code:),
                    onCurrentCode: { currentCode = $0 }
                )
                .overlay { scanFrameOverlay(frame) }
            }
        } else {
            cameraUnavailable
        }
    }

    /// Centered scan window — wide and short to suit the short codes.
    private func scanFrame(in size: CGSize) -> CGRect {
        let width = size.width * 0.6
        let height = min(size.height * 0.28, 110)
        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
    }

    private struct ChipState {
        let code: String
        let subtitle: LocalizedStringKey?
        let color: Color
    }

    /// What to show below the frame: the framed code (with an "Already Added"
    /// note when it's in the session), otherwise a lingering "Added" confirmation.
    private var chipState: ChipState? {
        if let currentCode {
            return session.contains(currentCode)
                ? ChipState(code: currentCode, subtitle: "Already Added", color: .orange)
                : ChipState(code: currentCode, subtitle: nil, color: .green)
        }
        if let recentlyAddedCode {
            return ChipState(code: recentlyAddedCode, subtitle: "Added", color: .green)
        }
        return nil
    }

    private func scanFrameOverlay(_ frame: CGRect) -> some View {
        let ready = currentCode != nil
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(ready ? Color.green : Color.red, lineWidth: 3)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)

            if let chip = chipState {
                VStack(spacing: 4) {
                    Text(verbatim: chip.code)
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(chip.color, in: Capsule())
                    if let subtitle = chip.subtitle {
                        Text(subtitle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.55), in: Capsule())
                    }
                }
                .position(x: frame.midX, y: frame.maxY + 28)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: ready)
    }

    private var cameraUnavailable: some View {
        ContentUnavailableView {
            Label(
                cameraAuthorized ? "Camera Unavailable" : "Camera Access Needed",
                systemImage: "camera.fill"
            )
            .foregroundStyle(.white)
        } description: {
            Text(cameraAuthorized
                 ? "This device can't scan text with the camera."
                 : "Allow camera access in Settings to scan sticker codes.")
            .foregroundStyle(.white.opacity(0.7))
        } actions: {
            if !cameraAuthorized, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { UIApplication.shared.open(url) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $session.registerDuplicates) {
                HStack(spacing: 6) {
                    Text("Register Duplicates")
                    Button {
                        showingRegisterInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("What does Register Duplicates do?")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            if session.items.isEmpty {
                ContentUnavailableView(
                    "No Stickers Yet",
                    systemImage: "viewfinder",
                    description: Text("Point the camera at a sticker code to add it.")
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(session.items) { item in
                            row(for: item)
                        }
                    } header: {
                        HStack {
                            Text("Scanned Stickers")
                            Spacer()
                            Text(verbatim: "\(session.items.count)")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func row(for item: ScannedItem) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.code)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(verbatim: Self.displayName(for: item.code))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if session.registerDuplicates {
                Button {
                    adjust(item.code, by: -1)
                } label: {
                    Image(systemName: item.count == 1 ? "trash.fill" : "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .tint(item.count == 1 ? .red : .secondary)

                Text(verbatim: "×\(item.count)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .frame(minWidth: 34)

                Button {
                    adjust(item.code, by: 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    session.remove(item.code)
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .tint(.red)
            }
        }
    }

    // MARK: - Scanning

    private func handle(code: String) {
        guard session.add(code) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Keep the confirmation chip up for a moment after the camera moves on.
        recentlyAddedCode = code
        lingerTask?.cancel()
        lingerTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            if recentlyAddedCode == code { recentlyAddedCode = nil }
        }
    }

    private func adjust(_ code: String, by delta: Int) {
        withAnimation { session.adjust(code, by: delta) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func requestCameraAccessIfNeeded() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else { return }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthorized = granted
    }

    /// Human-readable section the code belongs to, shown beneath the code.
    private static func displayName(for code: String) -> String {
        if code.hasPrefix("FWC") { return SpecialSection.fwc.displayName }
        if code.hasPrefix("CC") { return SpecialSection.cocaCola.displayName }
        if code == AlbumDefinition.specialSticker.code { return SpecialSection.special.displayName }
        let countryCode = String(code.prefix(3))
        return AlbumDefinition.country(forCode: countryCode)?.name ?? countryCode
    }
}

#Preview {
    StickerScanSheet()
        .environment(CollectionStore(repository: PreviewRepository()))
}
