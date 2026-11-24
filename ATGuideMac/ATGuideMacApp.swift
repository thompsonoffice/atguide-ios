import AppKit
import SwiftUI

@main
struct ATGuideMacApp: App {
    @StateObject private var favorites: FavoritesStore
    @StateObject private var recents: RecentsStore
    @StateObject private var compare: CompareStore
    @StateObject private var nav: MacNavState
    private let defaults: UserDefaults
    private let loaded: Result<ATGuideStore, Error>

    init() {
        let defaults = ATGuideMacApp.makeDefaults()
        self.defaults = defaults
        let favorites = FavoritesStore(defaults: defaults)
        let recents = RecentsStore(defaults: defaults)
        let compare = CompareStore(defaults: defaults)
        let nav = MacNavState()
        _favorites = StateObject(wrappedValue: favorites)
        _recents = StateObject(wrappedValue: recents)
        _compare = StateObject(wrappedValue: compare)
        _nav = StateObject(wrappedValue: nav)
        let loaded = Result { try ATGuideStore.loadBundled() }
        self.loaded = loaded
        if case .success(let store) = loaded, let scene = ScreenshotLaunch.scene {
            ScreenshotLaunch.apply(scene, nav: nav, store: store, compare: compare,
                                   favorites: favorites, recents: recents)
        }
    }

    /// UI tests and screenshot runs start from a clean, separate store.
    private static func makeDefaults() -> UserDefaults {
        let args = ProcessInfo.processInfo.arguments
        let testing = args.contains("-ATGuideUITesting")
        guard testing || ScreenshotLaunch.isRequested else { return .standard }
        let name = testing ? "ATGuideUITesting" : "ATGuideScreenshot"
        guard let suite = UserDefaults(suiteName: name) else { return .standard }
        suite.removePersistentDomain(forName: name)
        return suite
    }

    var body: some Scene {
        WindowGroup {
            switch loaded {
            case .success(let store):
                MacRootView()
                    .environmentObject(store)
                    .environmentObject(favorites)
                    .environmentObject(recents)
                    .environmentObject(compare)
                    .environmentObject(nav)
                    .defaultAppStorage(defaults)
                    .frame(minWidth: 800, minHeight: 560)
                    .onAppear { MacScreenshot.captureIfRequested() }
            case .failure(let error):
                Text("ATGuide could not load its data. \(error.localizedDescription)")
                    .padding()
                    .frame(minWidth: 480, minHeight: 240)
            }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            MacGoCommands()
        }
    }
}

/// Applies the text size chosen in Settings. "Use system setting" leaves Dynamic Type alone.
struct MacRootView: View {
    @AppStorage(TextSizeOption.storageKey) private var textSize: TextSizeOption = .system
    @Environment(\.dynamicTypeSize) private var systemSize
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        MacSplitView()
            .dynamicTypeSize(textSize.dynamicTypeSize ?? systemSize)
            .focusedSceneObject(nav)
    }
}

/// Keyboard shortcuts that move the sidebar, matching the first nine sections.
struct MacGoCommands: Commands {
    @FocusedObject private var nav: MacNavState?

    var body: some Commands {
        CommandMenu("Go") {
            ForEach(Array(SidebarItem.shortcutItems.enumerated()), id: \.element) { index, item in
                Button(item.title) {
                    nav?.open(item)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command])
            }
        }
    }
}
