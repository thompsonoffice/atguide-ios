import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var store: ATGuideStore

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
                    .accessibilityAddTraits(.isHeader)
                DetailSection("What this is") {
                    BodyText("ATGuide is a reference to blindness and low-vision assistive technology from the 1970s to today: notetakers, braille displays, speech synthesizers, text-to-speech voices, screen readers, magnifiers, wearables, embossers, and smart speakers and home devices.")
                    BodyText("Entries are written summaries with listed sources. Facts that could not be found in a source read Not documented. Nothing here is a buying recommendation, and ATGuide does not claim any product works for every person or setup.")
                    BodyText("Product names and trademarks belong to their owners. ATGuide is not affiliated with any company it describes.")
                }
                DetailSection("What is included") {
                    LabeledFact(label: "Edition", value: store.data.edition ?? "ATGuide")
                    LabeledFact(label: "Devices, software and voices", value: String(store.devices.count))
                    LabeledFact(label: "Companies", value: String(store.companies.count))
                    LabeledFact(label: "Categories", value: String(store.categoryGroups.count))
                    LabeledFact(label: "Operating system histories", value: String(store.osHistories.count))
                    LabeledFact(label: "Trivia facts", value: String(store.data.trivia.count))
                    LabeledFact(label: "Research date", value: store.data.generated)
                }
                DetailSection("Privacy") {
                    BodyText("ATGuide works offline and collects no data. Favorites, recently viewed entries and comparisons stay on this device.")
                    NavigationLink("Read the privacy policy", value: Route.privacy)
                }
                LabeledFact(label: "Developer", value: "Hunter Thompson")
                LabeledFact(label: "Version", value: version)
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("About")
        .inlineTitle()
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ATGuide Privacy Policy")
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                BodyText("Effective \(PrivacyPolicy.effectiveDate)")
                ForEach(PrivacyPolicy.paragraphs) { item in
                    DetailSection(item.heading) { BodyText(item.body) }
                }
            }
            .padding()
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Privacy Policy")
        .inlineTitle()
    }
}
