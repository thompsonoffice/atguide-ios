import SwiftUI
import UIKit

extension Color {
    /// Supporting text that stays at least 4.5:1 against system backgrounds.
    /// The system secondary label is about 2.8:1, which fails the contrast audit.
    static let supportingText = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(white: 0.80, alpha: 1)
        }
        return UIColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 1)
    })
}

extension View {
    /// Interactive controls need a 44 by 44 point target.
    func minimumTapTarget() -> some View {
        frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
    }
}

// MARK: Navigation

extension View {
    /// Adds every ATGuide destination to a NavigationStack.
    func atguideDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            RouteView(route: route)
        }
    }

    /// Inline navigation titles, so long entry names do not take half the screen.
    func inlineTitle() -> some View {
        navigationBarTitleDisplayMode(.inline)
    }
}

struct RouteView: View {
    let route: Route
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        switch route {
        case .company(let id):
            if let company = store.company(id) { CompanyDetailView(company: company) } else { MissingEntryView() }
        case .device(let id):
            if let device = store.device(id) { DeviceDetailView(device: device) } else { MissingEntryView() }
        case .os(let id):
            if let os = store.os(id) { OSDetailView(os: os) } else { MissingEntryView() }
        case .category(let name):
            CategoryView(category: name)
        case .companies:
            CompaniesListView()
        case .timeline:
            TimelineBrowseView()
        case .osList:
            OSHistoryListView()
        case .trivia:
            TriviaView()
        case .recents:
            RecentsView()
        case .settings:
            SettingsView()
        case .about:
            AboutView()
        case .privacy:
            PrivacyPolicyView()
        }
    }
}

struct MissingEntryView: View {
    var body: some View {
        Text("This entry is not in ATGuide.")
            .font(.body)
            .padding()
    }
}

// MARK: Rows

/// One device, voice or software row. VoiceOver reads it as a single element,
/// for example: "Braille 'n Speak (original), Notetakers, Blazie Engineering, 1987 to 1990s, Favorite".
struct DeviceRow: View {
    let device: Device
    var showYearFirst = false
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        NavigationLink(value: Route.device(device.id)) {
            VStack(alignment: .leading, spacing: 3) {
                if showYearFirst {
                    Text((device.year ?? 0) == 0 ? "Year not documented" : String(device.year!))
                        .font(.subheadline.weight(.semibold))
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(device.name)
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if favorites.contains(FavoriteKey.device(device.id)) {
                        FavoriteMark()
                    }
                }
                Text([device.category, store.companyName(device.company), device.releasedText].joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(Color.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
    }
}

struct CompanyRow: View {
    let company: Company
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        let count = store.productCount(of: company.id)
        NavigationLink(value: Route.company(company.id)) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(company.name)
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if favorites.contains(FavoriteKey.company(company.id)) {
                        FavoriteMark()
                    }
                }
                Text("Founded \(company.founded.nonEmpty ?? notDocumented), \(count) \(count == 1 ? "product" : "products")")
                    .font(.subheadline)
                    .foregroundStyle(Color.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
    }
}

struct OSRow: View {
    let os: OSHistory
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        NavigationLink(value: Route.os(os.id)) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(os.name)
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if favorites.contains(FavoriteKey.os(os.id)) {
                        FavoriteMark()
                    }
                }
                Text("\(store.companyName(os.company)), \(os.versions.count) versions listed")
                    .font(.subheadline)
                    .foregroundStyle(Color.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
    }
}

/// A filled star plus the spoken word "Favorite". The shape, not a color, carries the meaning.
struct FavoriteMark: View {
    var body: some View {
        Image(systemName: "star.fill")
            .font(.body)
            .accessibilityLabel("Favorite")
    }
}

// MARK: Actions

/// Favorite toggle. VoiceOver reads "Favorite, button" and adds "Selected" when it is on.
/// Sighted users see an outlined star (off) or a filled star (on): a shape change, not a color change.
struct FavoriteButton: View {
    let key: String
    let name: String
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        let isOn = favorites.contains(key)
        Button {
            favorites.toggle(key)
        } label: {
            Label("Favorite", systemImage: isOn ? "star.fill" : "star")
        }
        .accessibilityLabel("Favorite")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(isOn ? "Removes \(name) from Favorites." : "Adds \(name) to Favorites.")
        .minimumTapTarget()
    }
}

/// Adds or removes a device from the comparison (up to three devices).
/// VoiceOver reads "Add to Compare, button" or "Remove from Compare, button".
struct CompareButton: View {
    let device: Device
    @EnvironmentObject private var compare: CompareStore

    var body: some View {
        let isIn = compare.contains(device.id)
        Button {
            if isIn { compare.remove(device.id) } else { compare.add(device.id) }
            let message = isIn ? "Removed \(device.name) from Compare."
                : "Added \(device.name) to Compare. \(compare.ids.count) of \(CompareStore.capacity) picked."
            AccessibilityNotification.Announcement(message).post()
        } label: {
            Label(isIn ? "Remove from Compare" : "Add to Compare",
                  systemImage: isIn ? "minus.circle" : "plus.circle")
        }
        .disabled(!isIn && compare.isFull)
        .accessibilityHint(!isIn && compare.isFull
                           ? "Compare already has three devices. Remove one in the Compare tab first."
                           : (isIn ? "Takes \(device.name) out of the comparison." : "Puts \(device.name) in the Compare tab, next to up to two other devices."))
        .minimumTapTarget()
    }
}

/// Shares the entry as a .txt file (or plain text) through the system share sheet.
struct ShareTextButton: View {
    let title: String
    let text: String

    var body: some View {
        ShareLink(item: TextFileExport(fileName: TextExporter.fileName(title), text: text),
                  preview: SharePreview("\(title), plain text")) {
            Label("Share as TXT", systemImage: "square.and.arrow.up")
        }
        .accessibilityHint("Shares or saves this entry as a plain text file.")
        .minimumTapTarget()
    }
}

// MARK: Detail building blocks

/// A titled section. The title is marked as a heading for VoiceOver's headings rotor.
struct DetailSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BodyText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Label above value so long values wrap cleanly at large Dynamic Type sizes.
/// VoiceOver reads the pair together, for example "Processor, Motorola 68000".
struct LabeledFact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            Text(value).font(.body).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct BulletList: View {
    let items: [String]

    var body: some View {
        if items.isEmpty {
            BodyText(notDocumented)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\u{2022}").accessibilityHidden(true)
                        BodyText(item)
                    }
                }
            }
        }
    }
}

/// Links to other entries, for example predecessors or the voices a device shipped with.
struct EntryLinks: View {
    let title: String
    let devices: [Device]
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        if !devices.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                ForEach(devices) { d in
                    NavigationLink(value: Route.device(d.id)) {
                        Text("\(d.name) (\(store.companyName(d.company)), \(d.releasedText))")
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .minimumTapTarget()
                }
            }
        }
    }
}

struct SourceList: View {
    let sources: [String]

    var body: some View {
        if sources.isEmpty {
            BodyText(notDocumented)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(sources.enumerated()), id: \.offset) { i, source in
                    if let url = URL(string: source), url.scheme?.hasPrefix("http") == true {
                        Link(destination: url) {
                            Text("Source \(i + 1): \(url.host ?? source)")
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityHint("Opens \(source) in your web browser.")
                        .minimumTapTarget()
                    } else {
                        BodyText("Source \(i + 1): \(source)")
                    }
                }
            }
        }
    }
}
