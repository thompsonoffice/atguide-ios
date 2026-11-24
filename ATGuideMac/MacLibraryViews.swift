import SwiftUI

struct MacBrowseList: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore
    @EnvironmentObject private var nav: MacNavState
    @State private var selectedCategory: String?

    var body: some View {
        let recentKeys = Array(recents.keys.filter { store.title(forKey: $0) != nil }.prefix(3))
        List(selection: browseSelection) {
            if !recentKeys.isEmpty {
                Section {
                    ForEach(recentKeys, id: \.self) { key in
                        MacSavedKeyRow(key: key)
                            .tag(key)
                    }
                    if recents.keys.count > recentKeys.count {
                        Button("All recently viewed (\(recents.keys.count))") {
                            nav.open(.recents)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    MacSectionHeader("Recently Viewed")
                }
            }
            Section {
                ForEach(store.categoryGroups) { group in
                    MacLabeledCountRow(title: group.category, count: group.devices.count, noun: "entry", plural: "entries")
                        .tag("cat:" + group.category)
                }
            } header: {
                MacSectionHeader("Categories")
            }
            Section {
                Button {
                    nav.open(.companies)
                } label: {
                    MacLabeledCountRow(title: "Companies", count: store.companies.count, noun: "company", plural: "companies")
                }
                .buttonStyle(.plain)
                Button {
                    nav.open(.timeline)
                } label: {
                    MacLabeledCountRow(title: "Timeline by year", count: store.devices.count, noun: "entry", plural: "entries")
                }
                .buttonStyle(.plain)
                Button {
                    nav.open(.osHistory)
                } label: {
                    MacLabeledCountRow(title: "Operating System History", count: store.osHistories.count, noun: "history", plural: "histories")
                }
                .buttonStyle(.plain)
                Button {
                    nav.open(.trivia)
                } label: {
                    MacLabeledCountRow(title: "Trivia", count: store.data.trivia.count, noun: "fact", plural: "facts")
                }
                .buttonStyle(.plain)
            } header: {
                MacSectionHeader("More Ways to Browse")
            }
        }
        .navigationTitle("ATGuide")
        .onChange(of: selectedCategory) { _, name in
            if let name { nav.sidebar = .browse }
        }
    }

    /// Selection is either a saved-key or "cat:CategoryName".
    private var browseSelection: Binding<String?> {
        Binding(
            get: {
                if let name = nav.openCategory { return "cat:" + name }
                if case .device(let id)? = nav.selection { return FavoriteKey.device(id) }
                if case .company(let id)? = nav.selection { return FavoriteKey.company(id) }
                if case .os(let id)? = nav.selection { return FavoriteKey.os(id) }
                return nil
            },
            set: { value in
                guard let value else { return }
                if value.hasPrefix("cat:") {
                    let name = String(value.dropFirst(4))
                    selectedCategory = name
                    nav.sidebar = .browse
                    nav.openCategory = name
                    nav.selection = nil
                } else if let route = macRoute(forSavedKey: value) {
                    nav.selection = route
                }
            }
        )
    }
}

/// When a category is selected from Browse, the content column shows its entries.
/// This view is also used when nav.selection is a category — see MacCategoryOrBrowse.
struct MacCategoryList: View {
    let category: String
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        let list = store.devices(inCategory: category)
        List(selection: deviceSelection) {
            Section {
                ForEach(list) { device in
                    MacDeviceRow(device: device)
                        .tag(device.id)
                }
            } header: {
                Text("\(list.count) \(list.count == 1 ? "entry" : "entries"), oldest first.")
                    .textCase(nil)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .navigationTitle(category)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("All Categories") {
                    nav.openCategory = nil
                    nav.selection = nil
                }
                .accessibilityLabel("Back to all categories")
            }
        }
    }

    private var deviceSelection: Binding<String?> {
        Binding(
            get: {
                if case .device(let id)? = nav.selection { return id }
                return nil
            },
            set: { if let id = $0 { nav.selection = .device(id) } }
        )
    }
}

/// Browse shows either the home list or a category list when one is open.
struct MacBrowseSwitcher: View {
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        if let name = nav.openCategory {
            MacCategoryList(category: name)
        } else {
            MacBrowseList()
        }
    }
}

struct MacCompaniesList: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        List(selection: companySelection) {
            Section {
                ForEach(store.companies) { company in
                    MacCompanyRow(company: company)
                        .tag(company.id)
                }
            } header: {
                Text("\(store.companies.count) companies. Choose one to see its history and product catalog.")
                    .textCase(nil)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .navigationTitle("Companies")
    }

    private var companySelection: Binding<String?> {
        Binding(
            get: {
                if case .company(let id)? = nav.selection { return id }
                return nil
            },
            set: { if let id = $0 { nav.selection = .company(id) } }
        )
    }
}

struct MacOSHistoryList: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        List(selection: osSelection) {
            Section {
                ForEach(store.osHistories) { os in
                    MacOSRow(os: os)
                        .tag(os.id)
                }
            } header: {
                Text("\(store.osHistories.count) operating system and software version histories.")
                    .textCase(nil)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .navigationTitle("OS History")
    }

    private var osSelection: Binding<String?> {
        Binding(
            get: {
                if case .os(let id)? = nav.selection { return id }
                return nil
            },
            set: { if let id = $0 { nav.selection = .os(id) } }
        )
    }
}

struct MacTimelineList: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var nav: MacNavState
    @State private var companyID = MacTimelineList.all
    @State private var category = MacTimelineList.all
    private static let all = "All"

    private var entries: [Device] {
        store.devices.filter {
            (companyID == MacTimelineList.all || $0.company == companyID)
                && (category == MacTimelineList.all || $0.category == category)
        }
    }

    private func decade(_ d: Device) -> Int {
        let y = d.year ?? 0
        return y == 0 ? 0 : (y / 10) * 10
    }

    var body: some View {
        let list = entries
        let decades = Array(Set(list.map(decade))).sorted { ($0 == 0 ? 99999 : $0) < ($1 == 0 ? 99999 : $1) }
        List(selection: deviceSelection) {
            Section {
                Picker("Company", selection: $companyID) {
                    Text("All companies").tag(MacTimelineList.all)
                    ForEach(store.companies) { Text($0.name).tag($0.id) }
                }
                Picker("Category", selection: $category) {
                    Text("All categories").tag(MacTimelineList.all)
                    ForEach(store.categories, id: \.self) { Text($0).tag($0) }
                }
            } footer: {
                Text("\(list.count) entries, grouped by decade and year.")
                    .foregroundStyle(.primary)
            }
            ForEach(decades, id: \.self) { dec in
                let inDecade = list.filter { decade($0) == dec }
                Section {
                    ForEach(inDecade) { device in
                        MacDeviceRow(device: device, showYearFirst: true)
                            .tag(device.id)
                    }
                } header: {
                    MacSectionHeader(dec == 0 ? "Year not documented (\(inDecade.count))" : "\(String(dec))s (\(inDecade.count))")
                }
            }
        }
        .navigationTitle("Timeline")
    }

    private var deviceSelection: Binding<String?> {
        Binding(
            get: {
                if case .device(let id)? = nav.selection { return id }
                return nil
            },
            set: { if let id = $0 { nav.selection = .device(id) } }
        )
    }
}

struct MacRecentsList: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        let keys = recents.keys.filter { store.title(forKey: $0) != nil }
        List(selection: recentSelection) {
            if keys.isEmpty {
                Text("Nothing viewed yet. Entries you open appear here, newest first.")
                    .foregroundStyle(.primary)
            } else {
                Section {
                    ForEach(keys, id: \.self) { key in
                        MacSavedKeyRow(key: key)
                            .tag(key)
                            .contextMenu {
                                Button("Remove", role: .destructive) { recents.remove(key) }
                            }
                    }
                } header: {
                    Text("\(keys.count) entries, newest first. Kept on this device only.")
                        .textCase(nil)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                }
                Section {
                    Button("Clear Recently Viewed", role: .destructive) { recents.removeAll() }
                        .foregroundStyle(Color.macDestructiveText)
                }
            }
        }
        .navigationTitle("Recently Viewed")
    }

    private var recentSelection: Binding<String?> {
        Binding(
            get: {
                guard let sel = nav.selection else { return nil }
                switch sel {
                case .device(let id): return FavoriteKey.device(id)
                case .company(let id): return FavoriteKey.company(id)
                case .os(let id): return FavoriteKey.os(id)
                default: return nil
                }
            },
            set: { if let key = $0, let route = macRoute(forSavedKey: key) { nav.selection = route } }
        )
    }
}

struct MacFavoritesList: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        let keys = favorites.keys.filter { store.title(forKey: $0) != nil }
        let devices = keys.compactMap { key -> Device? in
            guard let parsed = FavoriteKey.parse(key), parsed.kind == .device else { return nil }
            return store.device(parsed.id)
        }
        let companies = keys.compactMap { key -> Company? in
            guard let parsed = FavoriteKey.parse(key), parsed.kind == .company else { return nil }
            return store.company(parsed.id)
        }
        let oses = keys.compactMap { key -> OSHistory? in
            guard let parsed = FavoriteKey.parse(key), parsed.kind == .os else { return nil }
            return store.os(parsed.id)
        }
        List(selection: favoriteSelection) {
            if keys.isEmpty {
                Text("No favorites yet. Use Favorite on any device, company, or operating system history.")
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if !devices.isEmpty {
                    Section {
                        ForEach(devices) { d in
                            MacDeviceRow(device: d)
                                .tag(FavoriteKey.device(d.id))
                                .contextMenu {
                                    Button("Remove from Favorites", role: .destructive) {
                                        favorites.remove(FavoriteKey.device(d.id))
                                    }
                                }
                        }
                    } header: {
                        MacSectionHeader("Devices and software (\(devices.count))")
                    }
                }
                if !companies.isEmpty {
                    Section {
                        ForEach(companies) { c in
                            MacCompanyRow(company: c)
                                .tag(FavoriteKey.company(c.id))
                                .contextMenu {
                                    Button("Remove from Favorites", role: .destructive) {
                                        favorites.remove(FavoriteKey.company(c.id))
                                    }
                                }
                        }
                    } header: {
                        MacSectionHeader("Companies (\(companies.count))")
                    }
                }
                if !oses.isEmpty {
                    Section {
                        ForEach(oses) { o in
                            MacOSRow(os: o)
                                .tag(FavoriteKey.os(o.id))
                                .contextMenu {
                                    Button("Remove from Favorites", role: .destructive) {
                                        favorites.remove(FavoriteKey.os(o.id))
                                    }
                                }
                        }
                    } header: {
                        MacSectionHeader("Operating systems (\(oses.count))")
                    }
                }
            }
        }
        .navigationTitle("Favorites")
    }

    private var favoriteSelection: Binding<String?> {
        Binding(
            get: {
                guard let sel = nav.selection else { return nil }
                switch sel {
                case .device(let id): return FavoriteKey.device(id)
                case .company(let id): return FavoriteKey.company(id)
                case .os(let id): return FavoriteKey.os(id)
                default: return nil
                }
            },
            set: { if let key = $0, let route = macRoute(forSavedKey: key) { nav.selection = route } }
        )
    }
}

struct MacTriviaList: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        List(selection: deviceSelection) {
            ForEach(TriviaLevel.allCases) { level in
                let facts = store.data.trivia.filter { $0.level == level }
                Section {
                    ForEach(facts) { fact in
                        MacTriviaRow(fact: fact)
                    }
                } header: {
                    MacSectionHeader("\(level.rawValue) (\(facts.count) facts)")
                }
            }
        }
        .navigationTitle("Trivia")
    }

    private var deviceSelection: Binding<String?> {
        Binding(
            get: {
                if case .device(let id)? = nav.selection { return id }
                return nil
            },
            set: { if let id = $0 { nav.selection = .device(id) } }
        )
    }
}

struct MacTriviaRow: View {
    let fact: TriviaFact
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        if let id = fact.device, let device = store.device(id) {
            VStack(alignment: .leading, spacing: 4) {
                MacBodyText(fact.text)
                Text("About \(device.name)")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .tag(device.id)
        } else {
            MacBodyText(fact.text)
                .padding(.vertical, 2)
        }
    }
}

struct MacSearchList: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var nav: MacNavState
    @State private var query = ""
    @State private var category = MacSearchList.allCategories
    @State private var announceTask: Task<Void, Never>?

    private static let allCategories = "All categories"

    private var categoryFilter: String? { category == MacSearchList.allCategories ? nil : category }
    private var isIdle: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && categoryFilter == nil
    }

    var body: some View {
        let devices = isIdle ? [] : store.searchDevices(query, category: categoryFilter)
        let companies = categoryFilter == nil && !isIdle ? store.searchCompanies(query) : []
        let oses = categoryFilter == nil && !isIdle ? store.searchOS(query) : []
        let total = devices.count + companies.count + oses.count
        List(selection: searchSelection) {
            Section {
                Picker("Category", selection: $category) {
                    Text("All")
                        .accessibilityLabel(MacSearchList.allCategories)
                        .tag(MacSearchList.allCategories)
                    ForEach(store.categories, id: \.self) { Text($0).tag($0) }
                }
            }
            if isIdle {
                Text("Search every device, company, voice and operating system, including specs, history and features. For example: BrailleNote, Eloquence, refreshable braille, Echo Show.")
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Section {
                    Text(total == 1 ? "1 result" : "\(total) results")
                        .accessibilityIdentifier("resultCount")
                }
                if !devices.isEmpty {
                    Section {
                        ForEach(devices) { device in
                            MacDeviceRow(device: device)
                                .tag(FavoriteKey.device(device.id))
                        }
                    } header: {
                        MacSectionHeader("Devices and software (\(devices.count))")
                    }
                }
                if !companies.isEmpty {
                    Section {
                        ForEach(companies) { company in
                            MacCompanyRow(company: company)
                                .tag(FavoriteKey.company(company.id))
                        }
                    } header: {
                        MacSectionHeader("Companies (\(companies.count))")
                    }
                }
                if !oses.isEmpty {
                    Section {
                        ForEach(oses) { os in
                            MacOSRow(os: os)
                                .tag(FavoriteKey.os(os.id))
                        }
                    } header: {
                        MacSectionHeader("Operating systems (\(oses.count))")
                    }
                }
            }
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Search")
        .autocorrectionDisabled()
        .navigationTitle("Search")
        .onAppear {
            if !nav.searchQuery.isEmpty { query = nav.searchQuery }
        }
        .onChange(of: nav.searchQuery) { _, value in
            if !value.isEmpty { query = value }
        }
        .onChange(of: query) { _, _ in announceCount() }
        .onChange(of: category) { _, _ in announceCount() }
    }

    private var searchSelection: Binding<String?> {
        Binding(
            get: {
                guard let sel = nav.selection else { return nil }
                switch sel {
                case .device(let id): return FavoriteKey.device(id)
                case .company(let id): return FavoriteKey.company(id)
                case .os(let id): return FavoriteKey.os(id)
                default: return nil
                }
            },
            set: { if let key = $0, let route = macRoute(forSavedKey: key) { nav.selection = route } }
        )
    }

    private func announceCount() {
        announceTask?.cancel()
        guard !isIdle else { return }
        announceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            let n = store.searchDevices(query, category: categoryFilter).count
                + (categoryFilter == nil ? store.searchCompanies(query).count + store.searchOS(query).count : 0)
            AccessibilityNotification.Announcement(n == 1 ? "1 result" : "\(n) results").post()
        }
    }
}
