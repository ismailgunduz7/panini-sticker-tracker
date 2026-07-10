# AGENTS.md

Guidance for AI agents working on **Sticker Tracker** — a FIFA World Cup 2026 Panini sticker album tracker for iOS.

## Project overview

Users mark owned stickers and duplicates, browse the album by country, view stats and achievements, scan sticker codes via camera, trade via QR codes, and (with an account) sync their collection to Supabase and find tradable stickers with friends.

| Layer | Technology |
|-------|------------|
| UI | SwiftUI (iOS 26+) |
| Local persistence | SwiftData |
| State | Swift `Observation` (`@Observable` stores) |
| Backend | Supabase (auth, Postgres, RLS, RPCs) |
| Auth | Sign in with Apple |
| Scanning | VisionKit, AVFoundation |
| Localization | English (source) + Turkish via `Localizable.xcstrings` |

**Target:** `StickerTracker` · **Bundle ID:** `com.ismailgunduz.StickerTracker` · **Display name:** `Sticker Tracker`

The Xcode project uses `PBXFileSystemSynchronizedRootGroup` — files added under `StickerTracker/` are picked up automatically; no manual `pbxproj` edits needed.

---

## Feature checklist

Living backlog. Add new ideas under **Planned**; move items to **Completed** when shipped.

- Use `- [ ]` for planned, `- [x]` for completed.
- One feature per line; keep descriptions short.
- Group related items under subheadings when the list grows.

### Completed

#### Album & collection
- [x] Static album definition — 48 countries, FWC, 00, Coca-Cola (992 stickers)
- [x] Home screen with themed country cards, search, and sort (album order / name / completion)
- [x] Persisted sort field and direction toggle
- [x] Country detail with printed album page layout (3×4 grid)
- [x] Swipe navigation between countries in detail view
- [x] Special sections (FWC, 00, Coca-Cola) with 5-column grid
- [x] Tap to toggle ownership; context menu to add/remove duplicates
- [x] SwiftData persistence behind a repository protocol
- [x] Offline-first usage without an account

#### Stats
- [x] Total progress, group bars, duplicate count
- [x] Most/least collected country, closest page, completed pages
- [x] Toggle to exclude 00 and Coca-Cola from stats
- [x] Federation logo and team photo breakdown (collected vs missing countries)

#### Achievements
- [x] Achievement system — first stickers, completions, milestones, duplicate hoarding
- [x] Toast and confetti on unlock; silent backfill on first launch
- [x] Revoke achievements when their condition no longer holds
- [x] Achievements tab

#### Duplicates
- [x] Duplicates page accessible from home toolbar
- [x] Independent sort field and direction, persisted
- [x] Duplicate count steppers and trash-to-remove
- [x] Instructive empty state
- [x] Add duplicates directly from the duplicates page

#### Scanning
- [x] Live camera scanner for stickers and duplicates
- [x] OCR confusable-character handling and settle-window commit logic

#### Sharing
- [x] Share owned, missing, or duplicate stickers as plain text

#### Trading
- [x] QR trading — encode/decode collection payload
- [x] Scan QR from camera; import QR from Photos; save QR to Photos
- [x] Share QR image from Trade tab
- [x] Deep link handling (`stickertracker://trade`)

#### Account & sync
- [x] Sign in with Apple and profile setup (username, display name)
- [x] Supabase sync — offline-first, last-write-wins
- [x] Full-album sharing privacy toggle
- [x] Sign out and account deletion

#### Friends
- [x] Search users, send/accept/decline friend requests
- [x] Friend list with pending-request badge
- [x] Tradable stickers between friends with privacy-aware collection read

#### Settings & polish
- [x] Appearance picker (system / light / dark)
- [x] Sort settings for home and duplicates pages
- [x] Reset all data
- [x] English and Turkish localization
- [x] Portrait-only orientation and app icon

### Planned

<!-- Add new ideas here as `- [ ] feature description`. Move to Completed when shipped. -->

---

## Directory structure

```
StickerTracker/
├── StickerTrackerApp.swift     # @main entry, dependency wiring
├── Models/                     # Static album data + domain types (no persistence)
├── Stores/                     # @Observable state + business logic
├── Persistence/                # Repository protocols, DTOs, SwiftData @Model
├── Sync/                       # Supabase client + SyncEngine
├── Views/                      # SwiftUI, grouped by feature
├── Scanning/                   # Camera session, code parser
├── Trading/                    # QR payload, trade matching
├── Sharing/                    # Plain-text share builders
└── Resources/Localizable.xcstrings

supabase/migrations/            # Numbered SQL migrations
```

Place new code in the folder that matches its responsibility. Do not mix concerns across layers.

---

## Architecture

### Layering

```
Views  →  @Environment(Store.self)  →  Stores (@Observable)
                                         ↓
                              Repository protocol (async)
                                         ↓
                              Local*Repository (SwiftData)
```

- **Models** — immutable static catalog (`AlbumDefinition`) and value types. Collection *state* is not a model; it lives in `CollectionEntry` (DTO) / `StickerEntry` (SwiftData).
- **Stores** — in-memory source of truth, optimistic mutations, Supabase-facing logic for social features.
- **Repositories** — storage abstraction. DTOs are storage-agnostic. Only `Local*Repository` exists today; protocols are written to allow future backends without changing store code.
- **Views** — never touch `ModelContext` or Supabase directly. Always go through stores.

### Stores

| Store | Responsibility |
|-------|----------------|
| `CollectionStore` | Owned/duplicate state, optimistic updates, sync hooks |
| `AchievementStore` | Unlock/revoke logic, toast queue |
| `AccountStore` | Supabase auth + profile lifecycle |
| `FriendStore` | Friendships, search, friend collections |
| `StatsCalculator` | Pure static functions — stateless stats computation |

Wire cross-store callbacks in `StickerTrackerApp.swift` (e.g. `onEntriesChanged`, `onSignedIn`). Use `@ObservationIgnored` on repositories, clients, and callbacks to avoid observation cycles.

### Sync (offline-first)

- Device is the source of truth; Supabase mirrors for social/trading.
- Local writes are immediate (in-memory + async SwiftData persist).
- `SyncEngine` handles pull/merge/push — not the repository layer.
- Merge policy: last-write-wins per sticker (`updatedAt`).
- Push is debounced (3 s) after mutations; full sync on foreground and sign-in.
- App works fully without an account.
- Achievements are local only — never sync to Supabase.

### Navigation

- Root: `TabView` in `RootTabView.swift` (Album, Trade, Stats, Achievements, Settings).
- Per-tab `NavigationStack` where needed.
- Type-safe destinations: `navigationDestination(for: Country.self)`.
- Sheets for scanning, friend search, trade results, profile setup.
- Deep links: `stickertracker://trade?...` handled in `RootTabView.onOpenURL`.
- In-view paging in `CountryDetailView` via swipe gestures (not `TabView`).

---

## Swift & SwiftUI conventions

### Observation (not ObservableObject)

- Use `@Observable final class` for stores and `ScanSession`.
- Inject stores at app root via `.environment(store)`.
- Consume in views with `@Environment(CollectionStore.self)`.
- Do **not** use `ObservableObject`, `@StateObject`, or `@Published`.

### Concurrency

- Project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` globally — no explicit `@MainActor` needed.
- Repository methods are `async`; stores fire `Task { }` for background persist.
- Use `assertionFailure` on load errors (dev-time signal, not user-facing).

### State placement

| Kind | Mechanism |
|------|-----------|
| Shared app state | `@Environment` stores |
| User preferences | `@AppStorage` with string raw values for enums |
| Ephemeral UI (sheets, selections) | `@State` |

Known `@AppStorage` keys: `appearancePreference`, `includeExtrasInStats`, `homeSortField`, `homeSortAscending`, `duplicatesSortField`, `duplicatesSortAscending`.

### Localization

1. SwiftUI string literals in views → auto-extracted to `Localizable.xcstrings`.
2. `String(localized:)` for programmatic strings (errors in stores).
3. `LocalizedStringResource` for achievement titles/details.
4. `LocalizedStringKey` for enum labels.
5. `Text(verbatim:)` for album data that must **not** be translated (country codes, sticker codes, counts).

Always add Turkish translations in `Localizable.xcstrings` when adding new user-facing strings.

### UI habits

- `Color(.systemGroupedBackground)` for screen backgrounds.
- `Label` + SF Symbols in toolbars.
- `ContentUnavailableView` for empty/auth-gated states.
- Haptic feedback on meaningful actions.
- `.buttonStyle(.plain)` on grid `NavigationLink`s to avoid blue tint.
- `// MARK: -` sections in larger files.
- Camera lifecycle must be explicitly managed (tear down when leaving scan views).

---

## Naming conventions

### Files

PascalCase matching the primary type, with suffixes:

- `*View` — SwiftUI screens and components
- `*Store` — observable state
- `*Repository` — persistence protocols/implementations
- `*Section` — settings subsection views

Group views by feature under `Views/<Feature>/`.

### Types

- **Structs** — value types, DTOs (`CollectionEntry`, `TradePayload`)
- **Classes** — `@Observable` stores, `@Model` entities, repository implementations
- **Enums** — static catalogs, finite state (`AlbumDefinition`, `AccountStore.Phase`)

### Properties

- camelCase throughout.
- Swift/Postgres mapping: `isOwned` locally → `is_owned` in `CodingKeys`.
- RPC params: snake_case with `p_` prefix (`p_username`, `p_entries`).

---

## Key domain rules

### AlbumDefinition is the single source of truth

All sticker/country/page layout lives in `AlbumDefinition`. Never hardcode sticker lists elsewhere — use `AlbumDefinition.orderedStickerCodes`, `AlbumDefinition.country(forCode:)`, etc.

### Lazy persistence

`StickerEntry` rows are created only for stickers the user interacted with. Absence of a row means not owned. Same on the server.

### Achievements revoke

Achievements are current-state predicates. Removing the last qualifying sticker must re-lock the achievement. Only **unlocks** are announced (toast + confetti). `backfill` on first launch is silent.

### Trade system reuse

`TradePayload` is the interchange format for QR trades **and** friend collections. `TradeMatch` pipeline is shared.

### Scan session

`ScanSession` buffers scans; nothing persists until the user taps Done. `registerDuplicates` controls duplicate vs own-only mode.

### Stats

Stats belong in `StatsCalculator.compute(entries:includeExtras:)` — not in views or stores. Returns `AlbumStats`.

---

## Supabase conventions

### Migrations

File format: `YYYYMMDDHHMMSS_NNN_description.sql` in `supabase/migrations/`.

Use the next sequential `NNN` number. Include a header comment explaining the migration's purpose.

### RLS & RPCs

- Enable RLS on all tables.
- Direct table access scoped to own rows: `auth.uid() = user_id`.
- Prefer RPCs for mutations with business rules.
- Use `security definer` when the function needs elevated access; `security invoker` when RLS alone suffices.
- Always `set search_path = ''` on functions.
- `revoke execute from anon, public` + `grant execute to authenticated` on RPCs.
- Errors via `raise exception 'error_code'` — client parses exception codes from error strings.

### iOS ↔ Supabase mapping

- `SupabaseService.client` — shared singleton.
- Table queries: `.from("profiles").select()...`
- Use `PostgresTimestamp` for fractional-second ISO8601 wire format.
- `CodingKeys` for snake_case columns on remote types.

### Adding a Supabase feature

1. Add migration with next sequence number.
2. Enable RLS, write policies, prefer RPC for mutations.
3. Add Swift `CodingKeys` for snake_case.
4. Add or extend a store — do not call Supabase from views.
5. Use `PostgresTimestamp` for timestamps.

---

## Adding new code — checklists

### Local persistence

1. Define storage-agnostic DTO + protocol in `Persistence/`.
2. Add `@Model` class + `Local*Repository`.
3. Register model in `ModelContainer(for:)` in `StickerTrackerApp.swift`.
4. Wire through an `@Observable` store.

### New view

1. Place under `Views/<Feature>/`.
2. Use `@Environment` for stores; `@AppStorage` for preferences.
3. Add `#Preview` with preview repositories (see `RootTabView.swift`).
4. Use `Text(verbatim:)` for sticker/country codes.
5. Add Turkish translations for new UI strings.

### New store method

1. Apply optimistic in-memory update first.
2. Persist via repository in a `Task`.
3. Invoke `onEntriesChanged` (or equivalent) after mutations.
4. Keep query helpers as pure reads on `entries`.

---

## Testing & previews

No XCTest target exists. Use `#Preview` blocks with in-memory `PreviewRepository` / `PreviewAchievementRepository` defined in `RootTabView.swift`. Previews must inject the full environment:

```swift
#Preview {
    HomeView()
        .environment(CollectionStore(repository: PreviewRepository()))
        .environment(AchievementStore(repository: PreviewAchievementRepository()))
}
```

Only add a test target if explicitly requested.

---

## Git commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <imperative summary>

Optional body with details or bullet points.
```

### Types

| Type | When |
|------|------|
| `feat:` | New user-facing feature |
| `fix:` | Bug fix |
| `chore:` | Build, config, version bumps, app icon |
| `refactor:` | Code restructuring without behavior change |
| `docs:` | Documentation only |

### Rules

- Lowercase type prefix, imperative mood, no scope parentheses, no ticket IDs.
- One logical change per commit.
- Body is optional; use it for non-obvious context or bullet lists.
- Do **not** word wrap commit messages. Keep each line on a single line — subject, body paragraphs, and bullet items should not be broken mid-sentence to fit a column width.

### Examples

```
feat: add duplicate count steppers to the duplicates page

fix: stop camera when leaving Trade tab while scanning

chore: bump project version to 1.1 (build 2)

docs: add AGENTS.md with project conventions
```

---

## What to avoid

- Do not bypass stores from views (no direct `ModelContext`, no direct Supabase calls).
- Do not hardcode sticker/country lists outside `AlbumDefinition`.
- Do not use `ObservableObject` / `@Published` — use `@Observable`.
- Do not sync achievements to Supabase.
- Do not add unrelated changes or drive-by refactors.
- Do not create commits unless explicitly asked.
- Do not add markdown files the user did not request (except this file).
- Do not add tests unless requested.
- Do not edit `pbxproj` manually when adding files under `StickerTracker/`.
- Do not use "Panini" in user-facing strings or bundle identifiers (trademark).

---

## Error handling

- **Network:** silent fail + retry on next trigger (sync, friends refresh).
- **User actions:** `LocalizedError` enums with `errorDescription`, or `errorMessage` on `AccountStore`.
- **Supabase RPC errors:** parse by substring matching on exception codes (e.g. `username_taken`).
