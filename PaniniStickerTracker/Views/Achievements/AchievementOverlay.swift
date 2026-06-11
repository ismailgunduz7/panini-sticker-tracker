import SwiftUI

/// Presents newly unlocked achievements as a top banner with a confetti burst,
/// one at a time, draining `AchievementStore.toastQueue`.
private struct AchievementOverlay: ViewModifier {
    @Environment(AchievementStore.self) private var store

    @State private var current: Achievement?
    @State private var confettiID = UUID()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if current != nil {
                    ConfettiView()
                        .id(confettiID)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .top) {
                if let current {
                    AchievementToastView(achievement: current)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { store.dismissCurrentToast() }
                }
            }
            .task(id: store.toastQueue.first?.id) {
                guard let next = store.toastQueue.first else {
                    withAnimation(.spring(duration: 0.3)) { current = nil }
                    return
                }
                confettiID = UUID()
                withAnimation(.spring(duration: 0.4)) { current = next }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                do {
                    try await Task.sleep(for: .seconds(3.2))
                } catch {
                    return // cancelled (e.g. tapped to dismiss)
                }
                withAnimation(.spring(duration: 0.3)) { current = nil }
                try? await Task.sleep(for: .seconds(0.3))
                store.dismissCurrentToast()
            }
    }
}

extension View {
    /// Shows achievement-unlock toasts + confetti over the receiver.
    func achievementOverlay() -> some View { modifier(AchievementOverlay()) }
}

/// The banner shown when an achievement is unlocked.
struct AchievementToastView: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.symbolName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(achievement.tint.gradient, in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(achievement.tint.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

#Preview {
    AchievementToastView(achievement: Achievement.all[0])
        .padding()
}
