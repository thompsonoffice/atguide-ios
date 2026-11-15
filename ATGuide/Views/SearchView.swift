import SwiftUI

/// Full-text search over every field of every entry. Every word typed must appear in the entry.
struct SearchView: View {
    @EnvironmentObject private var store: ATGuideStore
    @State private var query = ""
    @State private var category = SearchView.allCategories
    @State private var announceTask: Task<Void, Never>?

    private static let allCategories = "All categories"

    private var categoryFilter: String? { category == SearchView.allCategories ? nil : category }
    private var isIdle: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && categoryFilter == nil
    }

    var body: some View {
        let devices = isIdle ? [] : store.searchDevices(query, category: categoryFilter)
        let companies = categoryFilter == nil ? store.searchCompanies(query) : []
        let oses = categoryFilter == nil ? store.searchOS(query) : []
        let total = devices.count + companies.count + oses.count
        NavigationStack {
            List {
                Section {
                    Picker("Category", selection: $category) {
                        Text("All")
                            .accessibilityLabel(SearchView.allCategories)
                            .tag(SearchView.allCategories)
                        ForEach(store.categories, id: \.self) { Text($0).tag($0) }
                    }
                }
                if isIdle {
                    Text("Search every device, company, voice and operating system, including specs, history and features. For example: BrailleNote, Eloquence, refreshable braille, Echo Show.")
                        .foregroundStyle(Color.supportingText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Section {
                        Text(total == 1 ? "1 result" : "\(total) results")
                            .accessibilityIdentifier("resultCount")
                    }
                    if !devices.isEmpty {
                        Section {
                            ForEach(devices) { DeviceRow(device: $0) }
                        } header: {
                            SectionHeader("Devices and software (\(devices.count))")
                        }
                    }
                    if !companies.isEmpty {
                        Section {
                            ForEach(companies) { CompanyRow(company: $0) }
                        } header: {
                            SectionHeader("Companies (\(companies.count))")
                        }
                    }
                    if !oses.isEmpty {
                        Section {
                            ForEach(oses) { OSRow(os: $0) }
                        } header: {
                            SectionHeader("Operating systems (\(oses.count))")
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .navigationTitle("Search")
            .headerProminence(.increased)
            .clearOfTabBar()
            .atguideDestinations()
            .onChange(of: query) { _, _ in announceCount() }
            .onChange(of: category) { _, _ in announceCount() }
        }
    }

    /// Speaks the result count once typing pauses, so VoiceOver users know without leaving the field.
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
