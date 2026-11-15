import SwiftUI

/// Home tab: recently viewed entries, every category, and other ways to browse.
struct BrowseView: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        let recentKeys = Array(recents.keys.filter { store.title(forKey: $0) != nil }.prefix(3))
        NavigationStack {
            List {
                if !recentKeys.isEmpty {
                    Section {
                        ForEach(recentKeys, id: \.self) { SavedKeyRow(key: $0) }
                        if recents.keys.count > recentKeys.count {
                            NavigationLink("All recently viewed (\(recents.keys.count))", value: Route.recents)
                        }
                    } header: {
                        SectionHeader("Recently Viewed")
                    }
                }
                Section {
                    ForEach(store.categoryGroups) { group in
                        NavigationLink(value: Route.category(group.category)) {
                            LabeledCountRow(title: group.category, count: group.devices.count, noun: "entry", plural: "entries")
                        }
                    }
                } header: {
                    SectionHeader("Categories")
                }
                Section {
                    NavigationLink(value: Route.companies) {
                        LabeledCountRow(title: "Companies", count: store.companies.count, noun: "company", plural: "companies")
                    }
                    NavigationLink(value: Route.timeline) {
                        LabeledCountRow(title: "Timeline by year", count: store.devices.count, noun: "entry", plural: "entries")
                    }
                    NavigationLink(value: Route.osList) {
                        LabeledCountRow(title: "Operating System History", count: store.osHistories.count, noun: "history", plural: "histories")
                    }
                    NavigationLink(value: Route.trivia) {
                        LabeledCountRow(title: "Trivia", count: store.data.trivia.count, noun: "fact", plural: "facts")
                    }
                } header: {
                    SectionHeader("More Ways to Browse")
                }
            }
            .navigationTitle("ATGuide")
            .atguideDestinations()
        }
    }
}

/// A title with a count underneath, read by VoiceOver as one element: "Notetakers, 28 entries".
struct LabeledCountRow: View {
    let title: String
    let count: Int
    let noun: String
    let plural: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body.weight(.semibold))
            Text("\(count) \(count == 1 ? noun : plural)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Every entry in one category, oldest first.
struct CategoryView: View {
    let category: String
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        let list = store.devices(inCategory: category)
        List {
            Section {
                ForEach(list) { DeviceRow(device: $0) }
            } header: {
                Text("\(list.count) \(list.count == 1 ? "entry" : "entries"), oldest first.")
                    .textCase(nil)
            }
        }
        .navigationTitle(category)
    }
}

struct CompaniesListView: View {
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        List {
            Section {
                ForEach(store.companies) { CompanyRow(company: $0) }
            } header: {
                Text("\(store.companies.count) companies. Choose one to see its history and product catalog.")
                    .textCase(nil)
            }
        }
        .navigationTitle("Companies")
    }
}

/// A row for any saved key (device, company or OS history), used by Recently Viewed.
struct SavedKeyRow: View {
    let key: String
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        if let parsed = FavoriteKey.parse(key) {
            switch parsed.kind {
            case .device:
                if let d = store.device(parsed.id) { DeviceRow(device: d) }
            case .company:
                if let c = store.company(parsed.id) { CompanyRow(company: c) }
            case .os:
                if let o = store.os(parsed.id) { OSRow(os: o) }
            }
        }
    }
}

struct RecentsView: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        let keys = recents.keys.filter { store.title(forKey: $0) != nil }
        List {
            if keys.isEmpty {
                Text("Nothing viewed yet. Entries you open appear here, newest first.")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(keys, id: \.self) { key in
                        SavedKeyRow(key: key)
                            .swipeActions {
                                Button(role: .destructive) {
                                    recents.remove(key)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text("\(keys.count) entries, newest first. Kept on this device only.").textCase(nil)
                }
                Section {
                    Button("Clear Recently Viewed", role: .destructive) { recents.removeAll() }
                }
            }
        }
        .navigationTitle("Recently Viewed")
    }
}
