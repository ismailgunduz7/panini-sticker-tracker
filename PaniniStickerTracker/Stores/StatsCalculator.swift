import Foundation

struct CountryStat: Hashable, Sendable {
    let countryCode: String
    let ownedCount: Int
}

struct PageStat: Hashable, Sendable {
    let pageNumber: Int
    let countryCode: String
    let ownedCount: Int
    let totalCount: Int
}

struct GroupStat: Hashable, Sendable {
    let group: String
    let ownedCount: Int
    let totalCount: Int
}

struct AlbumStats: Sendable {
    var totalOwned: Int
    var totalCount: Int

    var mostCollectedCountry: CountryStat?
    var leastCollectedCountry: CountryStat?
    var completedCountryCount: Int

    /// Country pages only — FWC/CC pages are excluded by design.
    var closestPage: PageStat?
    var completedPageCount: Int

    var groupStats: [GroupStat]

    var totalDuplicates: Int
    var mostDuplicatedCountry: CountryStat?

    var federationLogosOwned: Int
    var teamPhotosOwned: Int
    var missingCount: Int

    var recentlyCollected: [CollectionEntry]

    var completionFraction: Double {
        totalCount == 0 ? 0 : Double(totalOwned) / Double(totalCount)
    }
}

/// Pure stat computation over the static album definition + dynamic entries.
/// Scope rules:
/// - country stickers (960): all stats
/// - FWC (19): total progress only
/// - 00 + Coca-Cola (13): total progress only, and only when `includeExtras`
enum StatsCalculator {

    static func compute(entries: [String: CollectionEntry], includeExtras: Bool) -> AlbumStats {
        func owned(_ code: String) -> Bool { entries[code]?.isOwned ?? false }

        // Per-country counts
        var countryCounts: [String: Int] = [:]
        var countryDuplicates: [String: Int] = [:]
        for country in AlbumDefinition.countries {
            var count = 0
            var dupes = 0
            for code in country.stickerCodes {
                if let entry = entries[code] {
                    if entry.isOwned { count += 1 }
                    dupes += entry.duplicateCount
                }
            }
            countryCounts[country.code] = count
            countryDuplicates[country.code] = dupes
        }

        let countryOwnedTotal = countryCounts.values.reduce(0, +)
        let fwcOwned = AlbumDefinition.fwcStickers.count { owned($0.code) }
        let extrasOwned = AlbumDefinition.extraStickerCodes.count { owned($0) }

        let totalOwned = countryOwnedTotal + fwcOwned + (includeExtras ? extrasOwned : 0)
        let totalCount = includeExtras
            ? AlbumDefinition.totalStickerCount
            : AlbumDefinition.totalStickerCountWithoutExtras

        // Most / least collected country (only meaningful once something is collected;
        // ties resolved by album order)
        var mostCollected: CountryStat?
        var leastCollected: CountryStat?
        if countryOwnedTotal > 0 {
            for country in AlbumDefinition.countries {
                let count = countryCounts[country.code] ?? 0
                if mostCollected == nil || count > mostCollected!.ownedCount {
                    mostCollected = CountryStat(countryCode: country.code, ownedCount: count)
                }
                if leastCollected == nil || count < leastCollected!.ownedCount {
                    leastCollected = CountryStat(countryCode: country.code, ownedCount: count)
                }
            }
        }

        let completedCountries = AlbumDefinition.countries.count {
            countryCounts[$0.code] == Country.stickersPerCountry
        }

        // Pages (country pages only)
        var closest: PageStat?
        var completedPages = 0
        for page in AlbumDefinition.countryPages {
            let count = page.stickerCodes.count { owned($0) }
            if count == page.stickerCodes.count {
                completedPages += 1
            } else if count > 0 {
                if closest == nil || count > closest!.ownedCount {
                    closest = PageStat(pageNumber: page.number, countryCode: page.countryCode,
                                       ownedCount: count, totalCount: page.stickerCodes.count)
                }
            }
        }

        // Groups
        let groupStats = AlbumDefinition.groups.map { group in
            let members = AlbumDefinition.countries.filter { $0.group == group }
            let count = members.reduce(0) { $0 + (countryCounts[$1.code] ?? 0) }
            return GroupStat(group: group, ownedCount: count,
                             totalCount: members.count * Country.stickersPerCountry)
        }

        // Duplicates (country + FWC + extras, regardless of scope toggle: physical dupes are real)
        let totalDuplicates = entries.values.reduce(0) { $0 + $1.duplicateCount }
        var mostDuplicated: CountryStat?
        for country in AlbumDefinition.countries {
            let dupes = countryDuplicates[country.code] ?? 0
            if dupes > 0, dupes > (mostDuplicated?.ownedCount ?? 0) {
                mostDuplicated = CountryStat(countryCode: country.code, ownedCount: dupes)
            }
        }

        // Type-based fun stats
        let federationLogos = AlbumDefinition.countries.count { owned("\($0.code)1") }
        let teamPhotos = AlbumDefinition.countries.count { owned("\($0.code)13") }

        // Recently collected (owned, newest first)
        let recent = entries.values
            .filter(\.isOwned)
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(8)

        return AlbumStats(
            totalOwned: totalOwned,
            totalCount: totalCount,
            mostCollectedCountry: mostCollected,
            leastCollectedCountry: leastCollected,
            completedCountryCount: completedCountries,
            closestPage: closest,
            completedPageCount: completedPages,
            groupStats: groupStats,
            totalDuplicates: totalDuplicates,
            mostDuplicatedCountry: mostDuplicated,
            federationLogosOwned: federationLogos,
            teamPhotosOwned: teamPhotos,
            missingCount: totalCount - totalOwned,
            recentlyCollected: Array(recent)
        )
    }
}
