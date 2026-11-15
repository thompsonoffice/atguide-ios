import SwiftUI

/// Every entry by decade, then year. Filter by company and category.
struct TimelineBrowseView: View {
    @EnvironmentObject private var store: ATGuideStore
    @State private var companyID = TimelineBrowseView.all
    @State private var category = TimelineBrowseView.all
    private static let all = "All"

    private var entries: [Device] {
        store.devices.filter {
            (companyID == TimelineBrowseView.all || $0.company == companyID)
                && (category == TimelineBrowseView.all || $0.category == category)
        }
    }

    private func decade(_ d: Device) -> Int {
        let y = d.year ?? 0
        return y == 0 ? 0 : (y / 10) * 10
    }

    var body: some View {
        let list = entries
        let decades = Array(Set(list.map(decade))).sorted { ($0 == 0 ? 99999 : $0) < ($1 == 0 ? 99999 : $1) }
            List {
                Section {
                    Picker("Company", selection: $companyID) {
                        Text("All companies").tag(TimelineBrowseView.all)
                        ForEach(store.companies) { Text($0.name).tag($0.id) }
                    }
                    Picker("Category", selection: $category) {
                        Text("All categories").tag(TimelineBrowseView.all)
                        ForEach(store.categories, id: \.self) { Text($0).tag($0) }
                    }
                } footer: {
                    Text("\(list.count) entries, grouped by decade and year.")
                        .foregroundStyle(Color.supportingText)
                }
                ForEach(decades, id: \.self) { dec in
                    let inDecade = list.filter { decade($0) == dec }
                    Section {
                        ForEach(inDecade) { DeviceRow(device: $0, showYearFirst: true) }
                    } header: {
                        SectionHeader(dec == 0 ? "Year not documented (\(inDecade.count))" : "\(String(dec))s (\(inDecade.count))")
                    }
                }
            }
            .navigationTitle("Timeline")
    }
}
