import SwiftUI

struct MacSettingsView: View {
    @AppStorage(TextSizeOption.storageKey) private var textSize: TextSizeOption = .system
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var recents: RecentsStore
    @EnvironmentObject private var compare: CompareStore
    @State private var confirmFavorites = false

    var body: some View {
        Form {
            Section {
                Picker("Text size", selection: $textSize) {
                    ForEach(TextSizeOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                Text("Sample: The Braille 'n Speak was introduced at the 1987 NFB convention.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Text size sample. The Braille 'n Speak was introduced at the 1987 NFB convention.")
            } header: {
                MacSectionHeader("Text")
            } footer: {
                Text("Every screen uses Dynamic Type. Use system setting follows System Settings, Accessibility, Display, Text Size.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                if recents.keys.isEmpty {
                    Text("No recently viewed entries.")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button("Clear Recently Viewed (\(recents.keys.count))", role: .destructive) { recents.removeAll() }
                        .font(.body)
                        .foregroundStyle(Color.macDestructiveText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if compare.ids.isEmpty {
                    Text("Nothing picked for comparison.")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button("Clear Comparison (\(compare.ids.count))", role: .destructive) { compare.removeAll() }
                        .font(.body)
                        .foregroundStyle(Color.macDestructiveText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if favorites.keys.isEmpty {
                    Text("No favorites yet.")
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button("Remove All Favorites (\(favorites.keys.count))", role: .destructive) { confirmFavorites = true }
                        .font(.body)
                        .foregroundStyle(Color.macDestructiveText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                MacSectionHeader("Saved on This Device")
            } footer: {
                Text("Favorites, recently viewed entries and the comparison are stored only on this Mac. Nothing is sent anywhere.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .font(.body)
        .confirmationDialog("Remove all \(favorites.keys.count) favorites?", isPresented: $confirmFavorites, titleVisibility: .visible) {
            Button("Remove All Favorites", role: .destructive) { favorites.removeAll() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
