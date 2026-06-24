import SwiftUI

struct AchievementsView: View {
    @Environment(AchievementStore.self) private var achievements

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var unlockedTotal: Int {
        Achievement.all.count { achievements.isUnlocked($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryHeader

                    ForEach(AchievementCategory.allCases) { category in
                        let items = Achievement.all.filter { $0.category == category }
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.title)
                                .font(.headline)
                                .padding(.horizontal, 4)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(items) { achievement in
                                    AchievementBadgeView(
                                        achievement: achievement,
                                        unlockedAt: achievements.unlocked[achievement.id]
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Achievements")
        }
    }

    private var summaryHeader: some View {
        let total = Achievement.all.count
        let fraction = total == 0 ? 0 : Double(unlockedTotal) / Double(total)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Unlocked")
                    .font(.headline)
                Spacer()
                Text("\(unlockedTotal) / \(total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: fraction)
                .tint(.yellow)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct AchievementBadgeView: View {
    let achievement: Achievement
    let unlockedAt: Date?

    private var isUnlocked: Bool { unlockedAt != nil }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isUnlocked ? achievement.symbolName : "lock.fill")
                .font(.title)
                .foregroundStyle(isUnlocked ? .white : Color.secondary)
                .frame(width: 56, height: 56)
                .background(
                    isUnlocked
                        ? AnyShapeStyle(achievement.tint.gradient)
                        : AnyShapeStyle(Color(.tertiarySystemFill)),
                    in: Circle()
                )

            VStack(spacing: 3) {
                Text(achievement.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(achievement.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(isUnlocked ? .primary : .secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(minHeight: 160)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .topTrailing) {
            if isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(achievement.tint)
                    .padding(8)
            }
        }
        .opacity(isUnlocked ? 1 : 0.7)
    }
}

#Preview {
    AchievementsView()
        .environment(AchievementStore(repository: PreviewAchievementRepository()))
}
