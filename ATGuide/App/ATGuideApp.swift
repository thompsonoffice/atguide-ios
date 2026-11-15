import SwiftUI

/// The data store never changes after launch, so it only needs to be
/// an ObservableObject to travel through the SwiftUI environment.
extension ATGuideStore: ObservableObject {}

@main
struct ATGuideApp: App {
    @StateObject private var favorites: FavoritesStore
    @StateObject private var recents: RecentsStore
    @StateObject private var compare: CompareStore
    private let defaults: UserDefaults
    private let loaded: Result<ATGuideStore, Error>

    init() {
        let defaults = ATGuideApp.makeDefaults()
        self.defaults = defaults
        _favorites = StateObject(wrappedValue: FavoritesStore(defaults: defaults))
        _recents = StateObject(wrappedValue: RecentsStore(defaults: defaults))
        _compare = StateObject(wrappedValue: CompareStore(defaults: defaults))
        loaded = Result { try ATGuideStore.loadBundled() }
    }

    /// UI tests launch with -ATGuideUITesting so they start from a clean, separate store
    /// and never touch real favorites.
    private static func makeDefaults() -> UserDefaults {
        guard ProcessInfo.processInfo.arguments.contains("-ATGuideUITesting"),
              let suite = UserDefaults(suiteName: "ATGuideUITesting") else { return .standard }
        suite.removePersistentDomain(forName: "ATGuideUITesting")
        return suite
    }

    var body: some Scene {
        WindowGroup {
            switch loaded {
            case .success(let store):
                RootView()
                    .environmentObject(store)
                    .environmentObject(favorites)
                    .environmentObject(recents)
                    .environmentObject(compare)
                    .defaultAppStorage(defaults)
            case .failure(let error):
                Text("ATGuide could not load its data. \(error.localizedDescription)")
                    .padding()
            }
        }
    }
}

/// Applies the text size chosen in Settings. "Use iPhone setting" leaves Dynamic Type alone.
struct RootView: View {
    @AppStorage(TextSizeOption.storageKey) private var textSize: TextSizeOption = .system

    var body: some View {
        if let size = textSize.dynamicTypeSize {
            ContentView().dynamicTypeSize(size)
        } else {
            ContentView()
        }
    }
}
