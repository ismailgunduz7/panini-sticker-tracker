import SwiftUI

struct SettingsView: View {
    @Environment(CollectionStore.self) private var store
    @Environment(AchievementStore.self) private var achievements
    @AppStorage("includeExtrasInStats") private var includeExtras = true
    @AppStorage("appearancePreference") private var appearanceRaw = AppearancePreference.system.rawValue
    @AppStorage("homeSortField") private var homeSortFieldRaw = CountrySortField.albumOrder.rawValue
    @AppStorage("homeSortAscending") private var homeSortAscending = true
    @AppStorage("duplicatesSortField") private var duplicatesSortFieldRaw = DuplicateSortField.albumOrder.rawValue
    @AppStorage("duplicatesSortAscending") private var duplicatesSortAscending = true
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                AccountSectionView()

                Section {
                    Toggle("Include Coca-Cola & Special Stickers", isOn: $includeExtras)
                } header: {
                    Text("Stats")
                } footer: {
                    Text("When off, the 00 and Coca-Cola stickers are excluded from all statistics.")
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceRaw) {
                        Text("System").tag(AppearancePreference.system.rawValue)
                        Text("Light").tag(AppearancePreference.light.rawValue)
                        Text("Dark").tag(AppearancePreference.dark.rawValue)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Album Sorting") {
                    Picker("Sort By", selection: $homeSortFieldRaw) {
                        ForEach(CountrySortField.allCases) { field in
                            Text(field.label).tag(field.rawValue)
                        }
                    }
                    Picker("Direction", selection: $homeSortAscending) {
                        Text("Ascending").tag(true)
                        Text("Descending").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Duplicates Sorting") {
                    Picker("Sort By", selection: $duplicatesSortFieldRaw) {
                        ForEach(DuplicateSortField.allCases) { field in
                            Text(field.label).tag(field.rawValue)
                        }
                    }
                    Picker("Direction", selection: $duplicatesSortAscending) {
                        Text("Ascending").tag(true)
                        Text("Descending").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Reset All Data", role: .destructive) {
                        showingResetConfirmation = true
                    }
                } footer: {
                    Text("FIFA World Cup 2026™ sticker album · 992 stickers")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                Text("Delete all collection data? This cannot be undone."),
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset All Data", role: .destructive) {
                    store.resetAll()
                    achievements.resetAll()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(CollectionStore(repository: PreviewRepository()))
        .environment(AchievementStore(repository: PreviewAchievementRepository()))
        .environment(AccountStore(client: SupabaseService.client))
}
