import AppKit
import SwiftUI

extension Color {
    /// Destructive actions need a red that still clears 4.5:1 contrast.
    static let macDestructiveText = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 1, green: 0.55, blue: 0.48, alpha: 1)
        }
        return NSColor(red: 0.55, green: 0.0, blue: 0.05, alpha: 1)
    })
}

/// A List section header that VoiceOver lists in its headings rotor.
struct MacSectionHeader: View {
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

/// A title with a count underneath, read by VoiceOver as one element.
struct MacLabeledCountRow: View {
    let title: String
    let count: Int
    let noun: String
    let plural: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(count) \(count == 1 ? noun : plural)")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Device row for a selectable list (no NavigationLink; selection fills the detail column).
struct MacDeviceRow: View {
    let device: Device
    var showYearFirst = false
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
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
                    MacFavoriteMark()
                }
            }
            Text([device.category, store.companyName(device.company), device.releasedText].joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if showYearFirst {
            parts.append((device.year ?? 0) == 0 ? "Year not documented" : String(device.year!))
        }
        parts.append(device.name)
        if favorites.contains(FavoriteKey.device(device.id)) { parts.append("Favorite") }
        parts.append(contentsOf: [device.category, store.companyName(device.company), device.releasedText])
        return parts.joined(separator: ", ")
    }
}

struct MacCompanyRow: View {
    let company: Company
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        let count = store.productCount(of: company.id)
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(company.name)
                    .font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if favorites.contains(FavoriteKey.company(company.id)) {
                    MacFavoriteMark()
                }
            }
            Text("Founded \(company.founded.nonEmpty ?? notDocumented), \(count) \(count == 1 ? "product" : "products")")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct MacOSRow: View {
    let os: OSHistory
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(os.name)
                    .font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if favorites.contains(FavoriteKey.os(os.id)) {
                    MacFavoriteMark()
                }
            }
            Text("\(store.companyName(os.company)), \(os.versions.count) versions listed")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct MacFavoriteMark: View {
    var body: some View {
        Image(systemName: "star.fill")
            .font(.body)
            .accessibilityLabel("Favorite")
    }
}

struct MacFavoriteButton: View {
    let key: String
    let name: String
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        let isOn = favorites.contains(key)
        Button {
            favorites.toggle(key)
        } label: {
            Text(isOn ? "★ Favorite" : "☆ Favorite")
                .font(.body)
        }
        .accessibilityLabel("Favorite")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .buttonStyle(.plain)
        .accessibilityHint(isOn ? "Removes \(name) from Favorites." : "Adds \(name) to Favorites.")
    }
}

struct MacCompareButton: View {
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
            Text(isIn ? "Remove from Compare" : "Add to Compare")
                .font(.body)
        }
        .disabled(!isIn && compare.isFull)
        .accessibilityHint(!isIn && compare.isFull
                           ? "Compare already has three devices. Remove one in Compare first."
                           : (isIn ? "Takes \(device.name) out of the comparison." : "Puts \(device.name) in Compare, next to up to two other devices."))
        .buttonStyle(.plain)
    }
}

struct MacShareTextButton: View {
    let title: String
    let text: String

    private var fileName: String {
        let trimmed = title.replacingOccurrences(of: "/", with: "-")
        return trimmed.hasSuffix(".txt") ? trimmed : trimmed + ".txt"
    }

    var body: some View {
        ShareLink(
            item: TextFileExport(fileName: fileName, text: text),
            preview: SharePreview(title)
        ) {
            Text("Share as TXT")
                .font(.body)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shares or saves this entry as a plain text file.")
    }
}

struct MacDetailSection<Content: View>: View {
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

struct MacBodyText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}

/// Label above value so long values wrap cleanly at large text sizes.
struct MacLabeledFact: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    private var ink: Color { colorScheme == .dark ? .white : .black }
    private var paper: Color { colorScheme == .dark ? .black : .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundColor(ink)
                .padding(2)
                .background(paper)
            Text(value)
                .font(.body)
                .foregroundColor(ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(2)
                .background(paper)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct MacBulletList: View {
    let items: [String]

    var body: some View {
        if items.isEmpty {
            MacBodyText(notDocumented)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\u{2022}").accessibilityHidden(true)
                        MacBodyText(item)
                    }
                }
            }
        }
    }
}

struct MacEntryLinks: View {
    let title: String
    let devices: [Device]
    @EnvironmentObject private var store: ATGuideStore
    @EnvironmentObject private var nav: MacNavState

    var body: some View {
        if !devices.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(devices) { d in
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
        }
    }
}

struct MacSourceList: View {
    let sources: [String]

    var body: some View {
        if sources.isEmpty {
            MacBodyText(notDocumented)
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
                    } else {
                        MacBodyText("Source \(i + 1): \(source)")
                    }
                }
            }
        }
    }
}

struct MacSavedKeyRow: View {
    let key: String
    @EnvironmentObject private var store: ATGuideStore

    var body: some View {
        if let parsed = FavoriteKey.parse(key) {
            switch parsed.kind {
            case .device:
                if let d = store.device(parsed.id) { MacDeviceRow(device: d) }
            case .company:
                if let c = store.company(parsed.id) { MacCompanyRow(company: c) }
            case .os:
                if let o = store.os(parsed.id) { MacOSRow(os: o) }
            }
        }
    }
}

func macRoute(forSavedKey key: String) -> Route? {
    guard let parsed = FavoriteKey.parse(key) else { return nil }
    switch parsed.kind {
    case .device: return .device(parsed.id)
    case .company: return .company(parsed.id)
    case .os: return .os(parsed.id)
    }
}
