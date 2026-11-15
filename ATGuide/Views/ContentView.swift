import SwiftUI
import UIKit

enum AppTab: String {
    case browse, search, favorites, compare, more
}

/// Five tabs so every tab stays visible on iPhone (a sixth would be hidden under a system "More").
struct ContentView: View {
    @SceneStorage("ATGuide.selectedTab") private var tab: AppTab = .browse
    @EnvironmentObject private var compare: CompareStore

    var body: some View {
        TabView(selection: $tab) {
            BrowseView()
                .tabItem { Label("Browse", systemImage: "books.vertical") }
                .tag(AppTab.browse)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "star") }
                .tag(AppTab.favorites)
            CompareView()
                .tabItem { Label("Compare", systemImage: "rectangle.split.3x1") }
                .tag(AppTab.compare)
                .badge(compare.ids.count)
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(AppTab.more)
        }
        .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(value: Route.settings) {
                        Label("Settings", systemImage: "gearshape")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    NavigationLink(value: Route.recents) {
                        Label("Recently Viewed", systemImage: "clock")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Section {
                    NavigationLink(value: Route.about) {
                        Label("About ATGuide", systemImage: "info.circle")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    NavigationLink(value: Route.privacy) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle("More")
            .clearOfTabBar()
            .atguideDestinations()
        }
    }
}
