import SwiftUI

/// Snapshot of collection state used to test whether achievements are satisfied.
/// Built once per evaluation so individual criteria stay cheap.
struct AchievementContext {
    let ownedCodes: Set<String>

    init(entries: [String: CollectionEntry]) {
        ownedCodes = Set(entries.values.filter(\.isOwned).map(\.code))
    }

    func owns(_ code: String) -> Bool { ownedCodes.contains(code) }
    func ownsAny<S: Sequence>(of codes: S) -> Bool where S.Element == String {
        codes.contains { ownedCodes.contains($0) }
    }
    func ownsAll<S: Sequence>(of codes: S) -> Bool where S.Element == String {
        codes.allSatisfy { ownedCodes.contains($0) }
    }
    func ownedCount<S: Sequence>(of codes: S) -> Int where S.Element == String {
        codes.count { ownedCodes.contains($0) }
    }

    /// All sticker codes belonging to a confederation's countries.
    func confederationStickerCodes(_ confederation: Confederation) -> [String] {
        confederation.countryCodes.flatMap { code in
            AlbumDefinition.country(forCode: code)?.stickerCodes ?? []
        }
    }
}

/// Grouping used to lay out the achievements screen.
enum AchievementCategory: String, CaseIterable, Identifiable, Sendable {
    case firstStickers
    case firstCompletions
    case milestones

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .firstStickers: "First Stickers"
        case .firstCompletions: "First Completions"
        case .milestones: "Milestones"
        }
    }
}

/// A single unlockable achievement: display metadata plus the predicate that
/// decides whether the current collection satisfies it.
struct Achievement: Identifiable {
    let id: String
    let category: AchievementCategory
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
    let symbolName: String
    let tint: Color
    let isSatisfied: (AchievementContext) -> Bool

    /// The full catalog, in display order.
    static let all: [Achievement] = firstStickers + firstCompletions + milestones

    static func byID(_ id: String) -> Achievement? { lookup[id] }
    private static let lookup: [String: Achievement] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    // MARK: - First sticker of a kind

    private static let firstStickers: [Achievement] = [
        Achievement(
            id: "first.player",
            category: .firstStickers,
            title: "First Player",
            detail: "Collect your first player sticker.",
            symbolName: "person.fill",
            tint: .blue,
            isSatisfied: { $0.ownsAny(of: AlbumDefinition.playerStickerCodes) }
        ),
        Achievement(
            id: "first.federationLogo",
            category: .firstStickers,
            title: "First Federation Logo",
            detail: "Collect your first country logo sticker.",
            symbolName: "shield.fill",
            tint: .indigo,
            isSatisfied: { $0.ownsAny(of: AlbumDefinition.federationLogoStickerCodes) }
        ),
        Achievement(
            id: "first.teamPhoto",
            category: .firstStickers,
            title: "First Team Photo",
            detail: "Collect your first team photo sticker.",
            symbolName: "person.3.fill",
            tint: .teal,
            isSatisfied: { $0.ownsAny(of: AlbumDefinition.teamPhotoStickerCodes) }
        ),
        Achievement(
            id: "first.fwc",
            category: .firstStickers,
            title: "First FWC Sticker",
            detail: "Collect your first FIFA World Cup sticker.",
            symbolName: "trophy.fill",
            tint: .yellow,
            isSatisfied: { $0.ownsAny(of: AlbumDefinition.fwcStickers.map(\.code)) }
        ),
    ] + Confederation.allCases.map { confederation in
        Achievement(
            id: "first.confederation.\(confederation.rawValue)",
            category: .firstStickers,
            title: "First \(confederation.displayName) Sticker",
            detail: "Collect your first sticker from a \(confederation.displayName) nation.",
            symbolName: confederation.symbolName,
            tint: .mint,
            isSatisfied: { ctx in
                ctx.ownsAny(of: ctx.confederationStickerCodes(confederation))
            }
        )
    }

    // MARK: - First completion of a scope

    private static let firstCompletions: [Achievement] = [
        Achievement(
            id: "complete.firstTeamPage",
            category: .firstCompletions,
            title: "Team Page",
            detail: "Complete a full team page.",
            symbolName: "book.closed.fill",
            tint: .orange,
            isSatisfied: { ctx in
                AlbumDefinition.countryPages.contains { ctx.ownsAll(of: $0.stickerCodes) }
            }
        ),
        Achievement(
            id: "complete.firstTeam",
            category: .firstCompletions,
            title: "First Team Complete",
            detail: "Complete every sticker of a single team.",
            symbolName: "flag.checkered",
            tint: .green,
            isSatisfied: { ctx in
                AlbumDefinition.countries.contains { ctx.ownsAll(of: $0.stickerCodes) }
            }
        ),
        Achievement(
            id: "complete.firstGroup",
            category: .firstCompletions,
            title: "First Group Complete",
            detail: "Complete every team in a single group.",
            symbolName: "square.grid.2x2.fill",
            tint: .purple,
            isSatisfied: { ctx in
                AlbumDefinition.groups.contains { group in
                    let codes = AlbumDefinition.countries
                        .filter { $0.group == group }
                        .flatMap(\.stickerCodes)
                    return ctx.ownsAll(of: codes)
                }
            }
        ),
        Achievement(
            id: "complete.firstConfederation",
            category: .firstCompletions,
            title: "First Confederation Complete",
            detail: "Complete every team of a single confederation.",
            symbolName: "globe",
            tint: .cyan,
            isSatisfied: { ctx in
                Confederation.allCases.contains { ctx.ownsAll(of: ctx.confederationStickerCodes($0)) }
            }
        ),
    ]

    // MARK: - Progress milestones

    private static let milestones: [Achievement] = [
        Achievement(
            id: "milestone.halfway",
            category: .milestones,
            title: "Halfway There",
            detail: "Collect half of the entire album.",
            symbolName: "50.circle.fill",
            tint: .pink,
            isSatisfied: { ctx in
                ctx.ownedCount(of: AlbumDefinition.allStickerCodes) * 2 >= AlbumDefinition.totalStickerCount
            }
        ),
        Achievement(
            id: "milestone.allParticipants",
            category: .milestones,
            title: "All Participants",
            detail: "Complete every team sticker in the album.",
            symbolName: "person.3.sequence.fill",
            tint: .green,
            isSatisfied: { $0.ownsAll(of: AlbumDefinition.countryStickerCodes) }
        ),
        Achievement(
            id: "milestone.fwcComplete",
            category: .milestones,
            title: "FWC Complete",
            detail: "Complete every FIFA World Cup sticker.",
            symbolName: "trophy.fill",
            tint: .yellow,
            isSatisfied: { $0.ownsAll(of: AlbumDefinition.fwcStickers.map(\.code)) }
        ),
        Achievement(
            id: "milestone.ccComplete",
            category: .milestones,
            title: "Coca-Cola Complete",
            detail: "Complete every Coca-Cola sticker.",
            symbolName: "takeoutbag.and.cup.and.straw.fill",
            tint: .red,
            isSatisfied: { $0.ownsAll(of: AlbumDefinition.cocaColaStickerCodes) }
        ),
        Achievement(
            id: "milestone.collectionComplete",
            category: .milestones,
            title: "Collection Complete",
            detail: "Collect every single sticker in the album.",
            symbolName: "crown.fill",
            tint: .orange,
            isSatisfied: { $0.ownsAll(of: AlbumDefinition.allStickerCodes) }
        ),
    ]
}
