import SwiftUI

/// Text size choices. "Use iPhone setting" follows Settings > Accessibility > Display and Text Size.
enum TextSizeOption: String, CaseIterable, Identifiable {
    case system, xSmall, small, medium, large, xLarge, xxLarge, xxxLarge,
         accessibility1, accessibility2, accessibility3, accessibility4, accessibility5

    static let storageKey = "atguide.textSize"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Use iPhone setting"
        case .xSmall: return "Extra small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large (iPhone default)"
        case .xLarge: return "Extra large"
        case .xxLarge: return "Extra extra large"
        case .xxxLarge: return "Extra extra extra large"
        case .accessibility1: return "Accessibility size 1"
        case .accessibility2: return "Accessibility size 2"
        case .accessibility3: return "Accessibility size 3"
        case .accessibility4: return "Accessibility size 4"
        case .accessibility5: return "Accessibility size 5, largest"
        }
    }

    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .system: return nil
        case .xSmall: return .xSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .xLarge
        case .xxLarge: return .xxLarge
        case .xxxLarge: return .xxxLarge
        case .accessibility1: return .accessibility1
        case .accessibility2: return .accessibility2
        case .accessibility3: return .accessibility3
        case .accessibility4: return .accessibility4
        case .accessibility5: return .accessibility5
        }
    }
}

struct SettingsView: View {
    @AppStorage(TextSizeOption.storageKey) private var textSize: TextSizeOption = .system
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var recents: RecentsStore
    @EnvironmentObject private var compare: CompareStore
    @State private var confirmFavorites = false

    var body: some View {
        Form {
            Section {
                Picker("Text size", selection: $textSize) {
                    ForEach(TextSizeOption.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.navigationLink)
                Text("Sample: The Braille 'n Speak was introduced at the 1987 NFB convention.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Text size sample. The Braille 'n Speak was introduced at the 1987 NFB convention.")
            } header: {
                SectionHeader("Text")
            } footer: {
                Text("Every screen uses Dynamic Type. Use iPhone setting follows Settings, Accessibility, Display and Text Size.")
                    .foregroundStyle(.primary)
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
                        .foregroundStyle(Color.destructiveText)
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
                        .foregroundStyle(Color.destructiveText)
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
                        .foregroundStyle(Color.destructiveText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                SectionHeader("Saved on This Device")
            } footer: {
                Text("Favorites, recently viewed entries and the comparison are stored only on this iPhone. Nothing is sent anywhere.")
                    .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Settings")
        .padding(.bottom, 80)
        .confirmationDialog("Remove all \(favorites.keys.count) favorites?", isPresented: $confirmFavorites, titleVisibility: .visible) {
            Button("Remove All Favorites", role: .destructive) { favorites.removeAll() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
