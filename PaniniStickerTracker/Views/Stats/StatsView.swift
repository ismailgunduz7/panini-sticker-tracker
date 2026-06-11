import SwiftUI

struct StatsView: View {
    @Environment(CollectionStore.self) private var store
    @AppStorage("includeExtrasInStats") private var includeExtras = true

    private var stats: AlbumStats {
        StatsCalculator.compute(entries: store.entries, includeExtras: includeExtras)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Overall") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Total Progress")
                                .font(.headline)
                            Spacer()
                            Text(stats.completionFraction, format: .percent.precision(.fractionLength(1)))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.green)
                        }
                        ProgressView(value: stats.completionFraction)
                            .tint(.green)
                        Text("\(stats.totalOwned) of \(stats.totalCount) stickers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    statRow("square.grid.3x3.topleft.filled", .blue, "Missing Stickers",
                            value: "\(stats.missingCount)")
                }

                Section("Countries") {
                    countryRow("crown.fill", .yellow, "Most Collected",
                               stat: stats.mostCollectedCountry, of: Country.stickersPerCountry)
                    countryRow("tortoise.fill", .brown, "Least Collected",
                               stat: stats.leastCollectedCountry, of: Country.stickersPerCountry)
                    statRow("checkmark.seal.fill", .green, "Completed Countries",
                            value: "\(stats.completedCountryCount) / \(AlbumDefinition.countries.count)")
                    statRow("shield.fill", .indigo, "Federation Logos",
                            value: "\(stats.federationLogosOwned) / \(AlbumDefinition.countries.count)")
                    statRow("person.3.fill", .teal, "Team Photos",
                            value: "\(stats.teamPhotosOwned) / \(AlbumDefinition.countries.count)")
                }

                Section("Pages") {
                    if let page = stats.closestPage,
                       let country = AlbumDefinition.country(forCode: page.countryCode) {
                        HStack {
                            iconBadge("flag.pattern.checkered", .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Closest Page to Completion")
                                Text(verbatim: "\(country.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Page \(page.pageNumber)")
                                    .font(.subheadline.weight(.semibold))
                                Text(verbatim: "\(page.ownedCount) / \(page.totalCount)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        statRow("flag.pattern.checkered", .orange, "Closest Page to Completion", value: "—")
                    }
                    statRow("book.closed.fill", .green, "Completed Pages",
                            value: "\(stats.completedPageCount) / \(AlbumDefinition.countryPages.count)")
                }

                Section("Groups") {
                    ForEach(stats.groupStats, id: \.group) { group in
                        HStack(spacing: 12) {
                            Text(verbatim: group.group)
                                .font(.subheadline.weight(.bold))
                                .frame(width: 26, height: 26)
                                .background(Color.accentColor.opacity(0.15), in: Circle())
                            ProgressView(value: Double(group.ownedCount), total: Double(group.totalCount))
                            Text(verbatim: "\(group.ownedCount)/\(group.totalCount)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .trailing)
                        }
                    }
                }

                Section("Duplicates") {
                    statRow("doc.on.doc.fill", .orange, "Total Duplicates",
                            value: "\(stats.totalDuplicates)")
                    countryRow("doc.on.doc.fill", .pink, "Most Duplicates",
                               stat: stats.mostDuplicatedCountry, of: nil)
                }

                if !stats.recentlyCollected.isEmpty {
                    Section("Recently Collected") {
                        ForEach(stats.recentlyCollected, id: \.code) { entry in
                            HStack {
                                Text(verbatim: entry.code)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                Spacer()
                                Text(entry.updatedAt, format: .relative(presentation: .named))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: - Row helpers

    private func iconBadge(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.caption)
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7))
    }

    private func statRow(_ symbol: String, _ color: Color, _ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            iconBadge(symbol, color)
            Text(title)
            Spacer()
            Text(verbatim: value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func countryRow(_ symbol: String, _ color: Color, _ title: LocalizedStringKey,
                            stat: CountryStat?, of total: Int?) -> some View {
        HStack {
            iconBadge(symbol, color)
            Text(title)
            Spacer()
            if let stat, let country = AlbumDefinition.country(forCode: stat.countryCode) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: country.name)
                        .font(.subheadline.weight(.semibold))
                    Text(verbatim: total.map { "\(stat.ownedCount) / \($0)" } ?? "\(stat.ownedCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(verbatim: "—")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    StatsView()
        .environment(CollectionStore(repository: PreviewRepository()))
}
