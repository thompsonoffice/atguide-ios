import AppKit
import SwiftUI

@main
struct ATGuideMacApp: App {
    @StateObject private var favorites: FavoritesStore
    @StateObject private var recents: RecentsStore
    @StateObject private var compare: CompareStore
    @StateObject private var nav = MacNavState()
    private let defaults: UserDefaults
    private let loaded: Result<ATGuideStore, Error>

    init() {
        let defaults = ATGuideMacApp.makeDefaults()
        self.defaults = defaults
        _favorites = StateObject(wrappedValue: FavoritesStore(defaults: defaults))
        _recents = StateObject(wrappedValue: RecentsStore(defaults: defaults))
        _compare = StateObject(wrappedValue: CompareStore(defaults: defaults))
        loaded = Result { try ATGuideStore.loadBundled() }
    }

    /// UI tests and screenshot runs start from a clean, separate store.
    private static func makeDefaults() -> UserDefaults {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ATGuideUITesting") || args.contains("-ATGuideScreenshots"),
              let suite = UserDefaults(suiteName: "ATGuideUITesting") else { return .standard }
        suite.removePersistentDomain(forName: "ATGuideUITesting")
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
            .background(MacWindowSizer())
            .background(MacScreenshotDriver())
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

/// Sets a 1280×800 content size when taking App Store screenshots.
private struct MacWindowSizer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard ProcessInfo.processInfo.arguments.contains("-ATGuideScreenshots") else { return }
            guard let window = view.window else { return }
            window.setContentSize(NSSize(width: 1280, height: 800))
            window.center()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard ProcessInfo.processInfo.arguments.contains("-ATGuideScreenshots") else { return }
        if let window = nsView.window, window.contentView?.bounds.size != NSSize(width: 1280, height: 800) {
            window.setContentSize(NSSize(width: 1280, height: 800))
        }
    }
}
