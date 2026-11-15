import SwiftUI

struct OSHistoryListView: View {
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        List {
            Section {
                ForEach(store.osHistories) { OSRow(os: $0) }
            } header: {
                Text("\(store.osHistories.count) operating system and software version histories.")
                    .textCase(nil)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .navigationTitle("OS History")
    }
}

struct OSDetailView: View {
    let os: OSHistory
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        let companyName = store.companyName(os.company)
        let ran = (os.devices ?? []).compactMap { store.device($0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(os.name)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(companyName), \(os.versions.count) versions listed")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    NavigationLink(value: Route.company(os.company)) {
                        Text("About \(companyName)")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .minimumTapTarget()
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { actionButtons }
                        VStack(alignment: .leading, spacing: 12) { actionButtons }
                    }
                    .padding(.top, 4)
                }

                DetailSection("Overview") {
                    BodyText(os.overview.nonEmpty ?? notDocumented)
                }

                DetailSection("Version History") {
                    if os.versions.isEmpty {
                        BodyText(notDocumented)
                    }
                    ForEach(Array(os.versions.enumerated()), id: \.offset) { _, v in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(v.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                                .accessibilityAddTraits(.isHeader)
                            LabeledFact(label: "Released", value: v.released.nonEmpty ?? notDocumented)
                            LabeledFact(label: "Notes", value: v.notes.nonEmpty ?? notDocumented)
                        }
                        .padding(.bottom, 6)
                    }
                }

                DetailSection("Devices and Software That Ran It") {
                    if ran.isEmpty {
                        BodyText(notDocumented)
                    }
                    ForEach(ran) { d in
                        NavigationLink(value: Route.device(d.id)) {
                            Text("\(d.name) (\(store.companyName(d.company)), \(d.releasedText))")
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .minimumTapTarget()
                    }
                }

                DetailSection("System Requirements") {
                    BulletList(items: os.requirements ?? [])
                }

                DetailSection("Sources") {
                    SourceList(sources: os.sources ?? [])
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
        .aboveTabBar()
        .navigationTitle(os.name)
        .inlineTitle()
        .onAppear { recents.record(FavoriteKey.os(os.id)) }
    }

    @ViewBuilder private var actionButtons: some View {
        FavoriteButton(key: FavoriteKey.os(os.id), name: os.name)
        ShareTextButton(title: os.name + " (version history)", text: TextExporter(store: store).text(for: os))
    }
}
