import SwiftUI

/// Sidebar sections in a Mac-conventional library app.
enum SidebarItem: String, Hashable, CaseIterable, Identifiable {
    case browse, search, favorites, compare, recents
    case companies, timeline, osHistory, trivia
    case settings, about, privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .browse: return "Browse"
        case .search: return "Search"
        case .favorites: return "Favorites"
        case .compare: return "Compare"
        case .recents: return "Recently Viewed"
        case .companies: return "Companies"
        case .timeline: return "Timeline"
        case .osHistory: return "OS History"
        case .trivia: return "Trivia"
        case .settings: return "Settings"
        case .about: return "About ATGuide"
        case .privacy: return "Privacy Policy"
        }
    }

    var systemImage: String {
        switch self {
        case .browse: return "books.vertical"
        case .search: return "magnifyingglass"
        case .favorites: return "star"
        case .compare: return "rectangle.split.3x1"
        case .recents: return "clock"
        case .companies: return "building.2"
        case .timeline: return "calendar"
        case .osHistory: return "square.stack.3d.up"
        case .trivia: return "questionmark.circle"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        case .privacy: return "hand.raised"
        }
    }

    /// Command-1 through Command-9.
    static var shortcutItems: [SidebarItem] {
        [.browse, .search, .favorites, .compare, .recents, .companies, .timeline, .osHistory, .trivia]
    }
}

/// Navigation for the split view and the Go menu.
final class MacNavState: ObservableObject {
    @Published var sidebar: SidebarItem = .browse
    @Published var path = NavigationPath()
    /// Selected entry shown in the detail column (device, company, OS, settings, about, privacy).
    @Published var selection: Route?
    /// When set, Browse shows this category's entries in the content column.
    @Published var openCategory: String?
    /// Used by screenshot and UI tests to fill the Search field.
    @Published var searchQuery: String = ""

    func open(_ item: SidebarItem) {
        sidebar = item
        path = NavigationPath()
        openCategory = nil
        switch item {
        case .settings: selection = .settings
        case .about: selection = .about
        case .privacy: selection = .privacy
        default:
            if selection == .settings || selection == .about || selection == .privacy {
                selection = nil
            }
        }
    }

    func show(_ route: Route) {
        switch route {
        case .device, .company, .os, .settings, .about, .privacy:
            path = NavigationPath()
            selection = route
        case .category, .companies, .timeline, .osList, .trivia, .recents:
            path = NavigationPath()
            selection = nil
            sidebar = sidebarItem(for: route)
        }
    }

    func push(_ route: Route) {
        path.append(route)
    }

    private func sidebarItem(for route: Route) -> SidebarItem {
        switch route {
        case .companies: return .companies
        case .timeline: return .timeline
        case .osList: return .osHistory
        case .trivia: return .trivia
        case .recents: return .recents
        default: return .browse
        }
    }
}

struct MacSplitView: View {
    @EnvironmentObject private var nav: MacNavState
    @EnvironmentObject private var compare: CompareStore

    var body: some View {
        NavigationSplitView {
            List(selection: sidebarBinding) {
                Section("Library") {
                    sidebarRow(.browse)
                    sidebarRow(.search)
                    sidebarRow(.favorites)
                    sidebarRow(.compare)
                        .badge(compare.ids.count)
                    sidebarRow(.recents)
                }
                Section("Catalog") {
                    sidebarRow(.companies)
                    sidebarRow(.timeline)
                    sidebarRow(.osHistory)
                    sidebarRow(.trivia)
                }
                Section("ATGuide") {
                    sidebarRow(.settings)
                    sidebarRow(.about)
                    sidebarRow(.privacy)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("ATGuide")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
            .accessibilityLabel("ATGuide sidebar")
        } content: {
            MacContentColumn()
                .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 520)
        } detail: {
            NavigationStack(path: $nav.path) {
                MacDetailColumn()
                    .navigationDestination(for: Route.self) { route in
                        MacRouteView(route: route)
                    }
            }
        }
        .onChange(of: nav.sidebar) { _, item in
            nav.path = NavigationPath()
            switch item {
            case .settings: nav.selection = .settings
            case .about: nav.selection = .about
            case .privacy: nav.selection = .privacy
            default:
                if nav.selection == .settings || nav.selection == .about || nav.selection == .privacy {
                    nav.selection = nil
                }
            }
        }
    }

    private var sidebarBinding: Binding<SidebarItem?> {
        Binding(
            get: { nav.sidebar },
            set: { if let item = $0 { nav.open(item) } }
        )
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        Label(item.title, systemImage: item.systemImage)
            .tag(item)
            .accessibilityLabel(item.title)
    }
}

struct MacContentColumn: View {
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        Group {
            switch nav.sidebar {
            case .browse: MacBrowseSwitcher()
            case .search: MacSearchList()
            case .favorites: MacFavoritesList()
            case .compare: MacCompareList()
            case .recents: MacRecentsList()
            case .companies: MacCompaniesList()
            case .timeline: MacTimelineList()
            case .osHistory: MacOSHistoryList()
            case .trivia: MacTriviaList()
            case .settings, .about, .privacy:
                Text("This section opens in the pane on the right.")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .navigationTitle(nav.sidebar.title)
            }
        }
        .font(.body)
    }
}

struct MacDetailColumn: View {
    @EnvironmentObject private var nav: MacNavState
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        Group {
            if let route = nav.selection {
                MacRouteView(route: route)
            } else if nav.sidebar == .compare {
                MacCompareDetail()
            } else {
                Text("Select an entry to read it.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Select an entry to read it.")
            }
        }
        .font(.body)
    }
}

struct MacRouteView: View {
    let route: Route
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        switch route {
        case .company(let id):
            if let company = store.company(id) { MacCompanyDetailView(company: company) } else { MacMissingEntryView() }
        case .device(let id):
            if let device = store.device(id) { MacDeviceDetailView(device: device) } else { MacMissingEntryView() }
        case .os(let id):
            if let os = store.os(id) { MacOSDetailView(os: os) } else { MacMissingEntryView() }
        case .category(let name):
            // Category lists belong in the content column; show a short note if pushed.
            Text(name).navigationTitle(name)
        case .companies:
            Text("Companies").navigationTitle("Companies")
        case .timeline:
            Text("Timeline").navigationTitle("Timeline")
        case .osList:
            Text("OS History").navigationTitle("OS History")
        case .trivia:
            Text("Trivia").navigationTitle("Trivia")
        case .recents:
            Text("Recently Viewed").navigationTitle("Recently Viewed")
        case .settings:
            MacSettingsView()
        case .about:
            MacAboutView()
        case .privacy:
            MacPrivacyPolicyView()
        }
    }
}

struct MacMissingEntryView: View {
    var body: some View {
        Text("This entry is not in ATGuide.")
            .font(.body)
            .padding()
    }
}
