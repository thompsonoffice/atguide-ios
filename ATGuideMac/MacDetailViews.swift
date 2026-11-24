import SwiftUI

struct MacDeviceDetailView: View {
    let device: Device
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        let companyName = store.companyName(device.company)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(device.name)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(device.category), \(companyName), \(device.releasedText)")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("About \(companyName)") {
                        nav.push(.company(device.company))
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 12) { actionButtons }
                        .padding(.top, 4)
                }

                MacDetailSection("Overview") {
                    MacBodyText(device.overview.nonEmpty ?? notDocumented)
                }

                MacDetailSection("Specs") {
                    ForEach(store.specRows(for: device)) { row in
                        MacLabeledFact(label: row.label, value: row.value)
                    }
                    let more = store.moreSpecRows(for: device)
                    if !more.isEmpty {
                        Text("More specs")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(more) { row in
                            MacLabeledFact(label: row.label, value: row.value)
                        }
                    }
                    MacEntryLinks(title: "Voices", devices: store.voices(of: device))
                    MacEntryLinks(title: "Shipped with or used by", devices: store.usedBy(voice: device.id))
                }

                MacDetailSection("Physical Description") {
                    MacBodyText(store.physicalText(device))
                }

                if let details = device.details, !details.isEmpty {
                    MacDetailSection("Detailed Description") {
                        ForEach(Array(details.enumerated()), id: \.offset) { _, paragraph in
                            MacBodyText(paragraph)
                        }
                    }
                }

                MacDetailSection("Features") {
                    MacBulletList(items: device.features ?? [])
                }

                MacDetailSection("History") {
                    MacBodyText(device.history.nonEmpty ?? notDocumented)
                    MacEntryLinks(title: "Predecessors", devices: store.predecessors(of: device))
                    MacEntryLinks(title: "Successors", devices: store.successors(of: device))
                }

                MacDetailSection("Ports") {
                    MacBodyText(store.portsText(device))
                }

                MacDetailSection("Operating System") {
                    MacBodyText(store.operatingSystemText(device))
                    let histories = store.osHistories(forDevice: device.id)
                    if !histories.isEmpty {
                        Text("Operating system history")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(histories) { os in
                            Button(os.name) { nav.push(.os(os.id)) }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                MacDetailSection("System Requirements") {
                    MacBulletList(items: device.requirements ?? [])
                }

                MacDetailSection("Sources") {
                    MacSourceList(sources: device.sources ?? [])
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
        .navigationTitle(device.name)
        .onAppear { recents.record(FavoriteKey.device(device.id)) }
    }

    @ViewBuilder private var actionButtons: some View {
        MacFavoriteButton(key: FavoriteKey.device(device.id), name: device.name)
        MacCompareButton(device: device)
        MacShareTextButton(title: device.name, text: TextExporter(store: store).text(for: device))
    }
}

struct MacCompanyDetailView: View {
    let company: Company
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        let catalog = store.catalog(of: company.id)
        let oses = store.osHistories(of: company.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(company.name)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityAddTraits(.isHeader)
                    MacLabeledFact(label: "Founded", value: company.founded.nonEmpty ?? notDocumented)
                    MacLabeledFact(label: "Products listed", value: String(store.productCount(of: company.id)))
                    VStack(alignment: .leading, spacing: 12) {
                        MacFavoriteButton(key: FavoriteKey.company(company.id), name: company.name)
                        MacShareTextButton(title: "About " + company.name, text: TextExporter(store: store).text(for: company))
                    }
                    .padding(.top, 4)
                }

                MacDetailSection("History") {
                    MacBodyText(company.history.nonEmpty ?? notDocumented)
                }

                if !oses.isEmpty {
                    MacDetailSection("Operating System and Software Histories") {
                        ForEach(oses) { os in
                            Button {
                                nav.push(.os(os.id))
                            } label: {
                                MacOSRow(os: os)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                ForEach(catalog) { group in
                    MacDetailSection("\(group.category) (\(group.devices.count))") {
                        ForEach(group.devices) { device in
                            Button {
                                nav.push(.device(device.id))
                            } label: {
                                MacDeviceRow(device: device)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                MacDetailSection("Sources") {
                    MacSourceList(sources: company.sources ?? [])
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
        .navigationTitle(company.name)
        .onAppear { recents.record(FavoriteKey.company(company.id)) }
    }
}

struct MacOSDetailView: View {
    let os: OSHistory
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var recents: RecentsStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        let companyName = store.companyName(os.company)
        let ran = (os.devices ?? []).compactMap { store.device($0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(os.name)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(companyName), \(os.versions.count) versions listed")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("About \(companyName)") { nav.push(.company(os.company)) }
                        .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 12) { actionButtons }
                        .padding(.top, 4)
                }

                MacDetailSection("Overview") {
                    MacBodyText(os.overview.nonEmpty ?? notDocumented)
                }

                MacDetailSection("Version History") {
                    if os.versions.isEmpty {
                        MacBodyText(notDocumented)
                    }
                    ForEach(Array(os.versions.enumerated()), id: \.offset) { _, v in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(v.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                                .accessibilityAddTraits(.isHeader)
                            MacLabeledFact(label: "Released", value: v.released.nonEmpty ?? notDocumented)
                            MacLabeledFact(label: "Notes", value: v.notes.nonEmpty ?? notDocumented)
                        }
                        .padding(.bottom, 6)
                    }
                }

                MacDetailSection("Devices and Software That Ran It") {
                    if ran.isEmpty {
                        MacBodyText(notDocumented)
                    }
                    ForEach(ran) { d in
                        Button {
                            nav.push(.device(d.id))
                        } label: {
                            Text("\(d.name) (\(store.companyName(d.company)), \(d.releasedText))")
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }

                MacDetailSection("System Requirements") {
                    MacBulletList(items: os.requirements ?? [])
                }

                MacDetailSection("Sources") {
                    MacSourceList(sources: os.sources ?? [])
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
        .navigationTitle(os.name)
        .onAppear { recents.record(FavoriteKey.os(os.id)) }
    }

    @ViewBuilder private var actionButtons: some View {
        MacFavoriteButton(key: FavoriteKey.os(os.id), name: os.name)
        MacShareTextButton(title: os.name + " (version history)", text: TextExporter(store: store).text(for: os))
    }
}

struct MacAboutView: View {
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var nav: MacNavState

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("About ATGuide")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                MacDetailSection("What this is") {
                    MacBodyText("ATGuide is a reference to blindness and low-vision assistive technology from the 1970s to today: notetakers, braille displays, speech synthesizers, text-to-speech voices, screen readers, magnifiers, wearables, embossers, and smart speakers and home devices.")
                    MacBodyText("Entries are written summaries with listed sources. Facts that could not be found in a source read Not documented. Nothing here is a buying recommendation, and ATGuide does not claim any product works for every person or setup.")
                    MacBodyText("Product names and trademarks belong to their owners. ATGuide is not affiliated with any company it describes.")
                }
                MacDetailSection("What is included") {
                    MacLabeledFact(label: "Edition", value: store.data.edition ?? "ATGuide")
                    MacLabeledFact(label: "Devices, software and voices", value: String(store.devices.count))
                    MacLabeledFact(label: "Companies", value: String(store.companies.count))
                    MacLabeledFact(label: "Categories", value: String(store.categoryGroups.count))
                    MacLabeledFact(label: "Operating system histories", value: String(store.osHistories.count))
                    MacLabeledFact(label: "Trivia facts", value: String(store.data.trivia.count))
                    MacLabeledFact(label: "Research date", value: store.data.generated)
                }
                MacDetailSection("Privacy") {
                    MacBodyText("ATGuide works offline and collects no data. Favorites, recently viewed entries and comparisons stay on this device.")
                    Button("Read the privacy policy") { nav.show(.privacy) }
                        .buttonStyle(.plain)
                }
                MacShareTextButton(title: "About ATGuide", text: aboutText)
                MacLabeledFact(label: "Developer", value: "Hunter Thompson")
                MacLabeledFact(label: "Version", value: version)
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
        .navigationTitle("About")
    }

    private var aboutText: String {
        """
        About ATGuide

        Edition: \(store.data.edition ?? "ATGuide")
        Devices, software and voices: \(store.devices.count)
        Companies: \(store.companies.count)
        Categories: \(store.categoryGroups.count)
        Operating system histories: \(store.osHistories.count)
        Trivia facts: \(store.data.trivia.count)
        Research date: \(store.data.generated)
        Developer: Hunter Thompson
        Version: \(version)
        """
    }
}

struct MacPrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ATGuide Privacy Policy")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                MacBodyText("Effective \(PrivacyPolicy.effectiveDate)")
                ForEach(PrivacyPolicy.paragraphs) { item in
                    MacDetailSection(item.heading) { MacBodyText(item.body) }
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
        .navigationTitle("Privacy Policy")
    }
}
