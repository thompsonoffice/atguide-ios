import SwiftUI

/// Trivia grouped Easy, Medium, Hard. Facts about one device link to it.
struct TriviaView: View {
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        List {
            ForEach(TriviaLevel.allCases) { level in
                let facts = store.data.trivia.filter { $0.level == level }
                Section {
                    ForEach(facts) { fact in
                        TriviaRow(fact: fact)
                    }
                } header: {
                    SectionHeader("\(level.rawValue) (\(facts.count) facts)")
                }
            }
        }
        .navigationTitle("Trivia")
    }
}

struct TriviaRow: View {
    let fact: TriviaFact
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        if let id = fact.device, let device = store.device(id) {
            NavigationLink(value: Route.device(device.id)) {
                VStack(alignment: .leading, spacing: 4) {
                    BodyText(fact.text)
                    Text("About \(device.name)")
                        .font(.footnote)
                        .foregroundStyle(Color.supportingText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
        } else {
            BodyText(fact.text)
                .padding(.vertical, 2)
        }
    }
}
