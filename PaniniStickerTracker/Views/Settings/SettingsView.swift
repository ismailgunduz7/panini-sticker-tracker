import SwiftUI

struct SettingsView: View {
    @Environment(CollectionStore.self) private var store
    @AppStorage("includeExtrasInStats") private var includeExtras = true
    @AppStorage("appearancePreference") private var appearanceRaw = AppearancePreference.system.rawValue
    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
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

                Section {
                    Button("Reset All Data", role: .destructive) {
                        showingResetConfirmation = true
                    }
                } footer: {
                    Text("FIFA World Cup 2026™ Panini sticker album · 992 stickers")
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
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(CollectionStore(repository: PreviewRepository()))
}
