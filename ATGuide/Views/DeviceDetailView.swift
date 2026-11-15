import SwiftUI

/// Device, voice or software detail. Sections follow the ATGuide order:
/// Overview, Specs, Physical Description, Detailed Description, Features, History, Ports,
/// Operating System, System Requirements, Sources. Each section title is a VoiceOver heading.
struct DeviceDetailView: View {
    let device: Device
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore

    var body: some View {
        let companyName = store.companyName(device.company)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(device.name)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(device.category), \(companyName), \(device.releasedText)")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    NavigationLink(value: Route.company(device.company)) {
                        Text("About \(companyName)")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .minimumTapTarget()
                    VStack(alignment: .leading, spacing: 12) { actionButtons }
                        .padding(.top, 4)
                }

                DetailSection("Overview") {
                    BodyText(device.overview.nonEmpty ?? notDocumented)
                }

                DetailSection("Specs") {
                    ForEach(store.specRows(for: device)) { row in
                        LabeledFact(label: row.label, value: row.value)
                    }
                    let more = store.moreSpecRows(for: device)
                    if !more.isEmpty {
                        Text("More specs")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(more) { row in
                            LabeledFact(label: row.label, value: row.value)
                        }
                    }
                    EntryLinks(title: "Voices", devices: store.voices(of: device))
                    EntryLinks(title: "Shipped with or used by", devices: store.usedBy(voice: device.id))
                }

                DetailSection("Physical Description") {
                    BodyText(store.physicalText(device))
                }

                if let details = device.details, !details.isEmpty {
                    DetailSection("Detailed Description") {
                        ForEach(Array(details.enumerated()), id: \.offset) { _, paragraph in
                            BodyText(paragraph)
                        }
                    }
                }

                DetailSection("Features") {
                    BulletList(items: device.features ?? [])
                }

                DetailSection("History") {
                    BodyText(device.history.nonEmpty ?? notDocumented)
                    EntryLinks(title: "Predecessors", devices: store.predecessors(of: device))
                    EntryLinks(title: "Successors", devices: store.successors(of: device))
                }

                DetailSection("Ports") {
                    BodyText(store.portsText(device))
                }

                DetailSection("Operating System") {
                    BodyText(store.operatingSystemText(device))
                    let histories = store.osHistories(forDevice: device.id)
                    if !histories.isEmpty {
                        Text("Operating system history")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(histories) { os in
                            NavigationLink(value: Route.os(os.id)) {
                                Text(os.name).fixedSize(horizontal: false, vertical: true)
                            }
                            .minimumTapTarget()
                        }
                    }
                }

                DetailSection("System Requirements") {
                    BulletList(items: device.requirements ?? [])
                }

                DetailSection("Sources") {
                    SourceList(sources: device.sources ?? [])
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
        .navigationTitle(device.name)
        .inlineTitle()
        .onAppear { recents.record(FavoriteKey.device(device.id)) }
    }

    @ViewBuilder private var actionButtons: some View {
        FavoriteButton(key: FavoriteKey.device(device.id), name: device.name)
        CompareButton(device: device)
        ShareTextButton(title: device.name, text: TextExporter(store: store).text(for: device))
    }
}
