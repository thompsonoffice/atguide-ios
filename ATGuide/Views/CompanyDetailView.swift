import SwiftUI
import UIKit

/// A company's history, then its catalog grouped by type (category).
struct CompanyDetailView: View {
    let company: Company
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        let catalog = store.catalog(of: company.id)
        let oses = store.osHistories(of: company.id)
        List {
            Section {
                Text(company.name)
                    .font(.title.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                LabeledFact(label: "Founded", value: company.founded.nonEmpty ?? notDocumented)
                LabeledFact(label: "Products listed", value: String(store.productCount(of: company.id)))
            }
            Section {
                SectionHeader("History")
                BodyText(company.history.nonEmpty ?? notDocumented)
            }
            if !oses.isEmpty {
                Section {
                    ForEach(oses) { OSRow(os: $0) }
                } header: {
                    SectionHeader("Operating System and Software Histories")
                }
            }
            ForEach(catalog) { group in
                Section {
                    ForEach(group.devices) { DeviceRow(device: $0) }
                } header: {
                    SectionHeader("\(group.category) (\(group.devices.count))")
                }
            }
            Section {
                SourceList(sources: company.sources ?? [])
            } header: {
                SectionHeader("Sources")
            }
        }
        .navigationTitle(company.name)
        .inlineTitle()
        .font(.body)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                FavoriteButton(key: FavoriteKey.company(company.id), name: company.name)
                ShareTextButton(title: "About " + company.name, text: TextExporter(store: store).text(for: company))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(uiColor: .systemBackground))
        }
        .aboveTabBar()
        .onAppear { recents.record(FavoriteKey.company(company.id)) }
    }
}

/// A List section header that VoiceOver lists in its headings rotor.
struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .textCase(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .accessibilityAddTraits(.isHeader)
    }
}
