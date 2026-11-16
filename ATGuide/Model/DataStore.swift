import Combine
import Foundation

/// One row of the comparison view: a label and one value per compared device, in order.
struct ComparisonRow: Hashable, Identifiable {
    var label: String
    var values: [String]
    var id: String { label }
    /// True when the compared devices do not all have the same value.
    var differs: Bool { Set(values).count > 1 }
}

/// Read-only store for the bundled ATGuide data, with lookup tables, search and the
/// derived links (operating system histories per device, devices per voice).
/// ObservableObject only so SwiftUI can pass it through the environment. The data
/// never changes after launch.
final class ATGuideStore: ObservableObject {
    let data: ATGuideData
    let companies: [Company]          // sorted by name
    let devices: [Device]             // sorted by year, then name
    let osHistories: [OSHistory]      // sorted by name
    let categories: [String]
    private let companyByID: [String: Company]
    private let deviceByID: [String: Device]
    private let osByID: [String: OSHistory]
    private let osIDsByDevice: [String: [String]]
    private let usersByVoice: [String: [String]]
    private let deviceCountByCompany: [String: Int]
    private let deviceIndex: [String: String]   // device id -> folded full text
    private let companyIndex: [String: String]
    private let osIndex: [String: String]

    init(data: ATGuideData) {
        self.data = data
        companies = data.companies.sorted { ATGuideStore.nameOrder($0.name, $1.name) }
        devices = ATGuideStore.sortDevices(data.devices)
        osHistories = data.osHistories.sorted { ATGuideStore.nameOrder($0.name, $1.name) }
        let known = data.categories
        let extra = Set(data.devices.map(\.category)).subtracting(known).sorted()
        categories = known + extra
        let companyMap = Dictionary(data.companies.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        companyByID = companyMap
        deviceByID = Dictionary(data.devices.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        osByID = Dictionary(data.osHistories.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var osMap: [String: [String]] = [:]
        for os in data.osHistories {
            for deviceID in os.devices ?? [] { osMap[deviceID, default: []].append(os.id) }
        }
        osIDsByDevice = osMap
        var voiceMap: [String: [String]] = [:]
        var counts: [String: Int] = [:]
        for device in data.devices {
            for voiceID in device.voices ?? [] { voiceMap[voiceID, default: []].append(device.id) }
            counts[device.company, default: 0] += 1
        }
        usersByVoice = voiceMap
        deviceCountByCompany = counts

        var dIndex: [String: String] = [:]
        for d in data.devices {
            let parts: [String] = [d.name, companyMap[d.company]?.name ?? d.company, d.category, d.released ?? "",
                                   d.overview ?? "", d.physical ?? "", (d.details ?? []).joined(separator: " "),
                                   (d.features ?? []).joined(separator: " "), d.history ?? "", d.ports ?? "",
                                   (d.specs?.allValues ?? []).joined(separator: " "),
                                   (d.moreSpecs ?? []).map { $0.label + " " + $0.value }.joined(separator: " "),
                                   (d.requirements ?? []).joined(separator: " ")]
            dIndex[d.id] = ATGuideStore.fold(parts.joined(separator: " "))
        }
        deviceIndex = dIndex
        companyIndex = Dictionary(data.companies.map { ($0.id, ATGuideStore.fold([$0.name, $0.founded ?? "", $0.history ?? ""].joined(separator: " "))) },
                                  uniquingKeysWith: { a, _ in a })
        osIndex = Dictionary(data.osHistories.map { o in
            let vers = o.versions.map { [$0.name, $0.released ?? "", $0.notes ?? ""].joined(separator: " ") }
            return (o.id, ATGuideStore.fold(([o.name, o.overview ?? ""] + vers + (o.requirements ?? [])).joined(separator: " ")))
        }, uniquingKeysWith: { a, _ in a })
    }

    /// Loads atguide-data.json from the app bundle.
    static func loadBundled(bundle: Bundle = .main) throws -> ATGuideStore {
        guard let url = bundle.url(forResource: "atguide-data", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(url: url)
    }

    static func load(url: URL) throws -> ATGuideStore {
        let raw = try Data(contentsOf: url)
        return ATGuideStore(data: try JSONDecoder().decode(ATGuideData.self, from: raw))
    }

    // MARK: Ordering

    static func nameOrder(_ a: String, _ b: String) -> Bool {
        a.localizedCaseInsensitiveCompare(b) == .orderedAscending
    }

    static func sortDevices(_ list: [Device]) -> [Device] {
        list.sorted { a, b in
            if a.sortYear != b.sortYear { return a.sortYear < b.sortYear }
            return nameOrder(a.name, b.name)
        }
    }

    // MARK: Lookups

    func company(_ id: String) -> Company? { companyByID[id] }
    func device(_ id: String) -> Device? { deviceByID[id] }
    func os(_ id: String) -> OSHistory? { osByID[id] }
    func companyName(_ id: String) -> String { companyByID[id]?.name ?? id }
    func productCount(of companyID: String) -> Int { deviceCountByCompany[companyID] ?? 0 }

    func devices(of companyID: String) -> [Device] { devices.filter { $0.company == companyID } }
    func devices(inCategory category: String) -> [Device] { devices.filter { $0.category == category } }
    func osHistories(of companyID: String) -> [OSHistory] { osHistories.filter { $0.company == companyID } }

    /// Every category with at least one entry, in the standard order, with its entries.
    var categoryGroups: [CatalogGroup] {
        categories.compactMap { cat in
            let list = devices(inCategory: cat)
            return list.isEmpty ? nil : CatalogGroup(category: cat, devices: list)
        }
    }

    /// A company's products grouped by category, in the standard category order.
    func catalog(of companyID: String) -> [CatalogGroup] {
        let mine = devices(of: companyID)
        return categories.compactMap { cat in
            let list = mine.filter { $0.category == cat }
            return list.isEmpty ? nil : CatalogGroup(category: cat, devices: list)
        }
    }

    func osHistories(forDevice id: String) -> [OSHistory] { (osIDsByDevice[id] ?? []).compactMap { osByID[$0] } }
    func usedBy(voice id: String) -> [Device] { (usersByVoice[id] ?? []).compactMap { deviceByID[$0] } }
    func voices(of device: Device) -> [Device] { (device.voices ?? []).compactMap { deviceByID[$0] } }
    func predecessors(of device: Device) -> [Device] { (device.predecessors ?? []).compactMap { deviceByID[$0] } }
    func successors(of device: Device) -> [Device] { (device.successors ?? []).compactMap { deviceByID[$0] } }

    /// Display name for a saved key such as "dev:bns".
    func title(forKey key: String) -> String? {
        guard let parsed = FavoriteKey.parse(key) else { return nil }
        switch parsed.kind {
        case .device: return device(parsed.id)?.name
        case .company: return company(parsed.id)?.name
        case .os: return os(parsed.id)?.name
        }
    }

    // MARK: Specs (same rules as the web app)

    func specRows(for d: Device) -> [SpecRow] {
        let s = d.specs ?? DeviceSpecs()
        func v(_ x: String?) -> String { x.nonEmpty ?? notDocumented }
        var rows: [SpecRow]
        if d.isVoice {
            rows = [SpecRow(label: "Maker", value: companyName(d.company)),
                    SpecRow(label: "First released", value: d.releasedText),
                    SpecRow(label: "Synthesis type", value: v(s.synthesis)),
                    SpecRow(label: "Platforms", value: v(s.platforms)),
                    SpecRow(label: "Default on or shipped with", value: v(s.defaultOn)),
                    SpecRow(label: "Price", value: v(s.price))]
        } else if d.isSoftware {
            rows = [SpecRow(label: "Developer", value: companyName(d.company)),
                    SpecRow(label: "Release years", value: d.releasedText),
                    SpecRow(label: "Runs on", value: v(s.operatingSystem)),
                    SpecRow(label: "Default speech", value: v(s.speech)),
                    SpecRow(label: "Price", value: v(s.price))]
        } else {
            rows = [SpecRow(label: "Released", value: d.releasedText),
                    SpecRow(label: "Processor", value: v(s.processor)),
                    SpecRow(label: "Memory (RAM)", value: v(s.memory)),
                    SpecRow(label: "Storage", value: v(s.storage)),
                    SpecRow(label: "Operating system", value: v(s.operatingSystem)),
                    SpecRow(label: "Default speech synthesizer", value: v(s.speech)),
                    SpecRow(label: "Battery", value: v(s.battery)),
                    SpecRow(label: "Display or braille cells", value: v(s.display)),
                    SpecRow(label: "Speech synthesizers available", value: v(s.synthesizersAvailable)),
                    SpecRow(label: "Price at launch", value: v(s.price)),
                    SpecRow(label: "Used price today (eBay)", value: v(s.usedPrice))]
        }
        if !d.isVoice, let syn = s.synthesis.nonEmpty {
            rows.append(SpecRow(label: "Synthesis type", value: syn))
        }
        return rows
    }

    /// Extra specs such as Dimensions and Weight, with duplicate labels merged.
    func moreSpecRows(for d: Device) -> [SpecRow] {
        var rows: [SpecRow] = []
        for spec in d.moreSpecs ?? [] {
            if let i = rows.firstIndex(where: { $0.label == spec.label }) {
                rows[i].value += "; " + spec.value
            } else {
                rows.append(SpecRow(label: spec.label, value: spec.value))
            }
        }
        return rows
    }

    func physicalText(_ d: Device) -> String {
        (d.isVoice || d.isSoftware) ? "Not applicable (software)" : (d.physical.nonEmpty ?? notDocumented)
    }

    func portsText(_ d: Device) -> String {
        (d.isVoice || d.isSoftware) ? "Not applicable (software)" : (d.ports.nonEmpty ?? notDocumented)
    }

    func operatingSystemText(_ d: Device) -> String {
        if let os = d.specs?.operatingSystem.nonEmpty { return os }
        if d.isVoice { return d.specs?.platforms.nonEmpty ?? notDocumented }
        return notDocumented
    }

    // MARK: Comparison

    /// Side-by-side facts for 2 or 3 devices. Labels are the union of every device's rows,
    /// in first-seen order; a device without that fact reads "Not documented".
    func comparisonRows(for list: [Device]) -> [ComparisonRow] {
        guard !list.isEmpty else { return [] }
        var labels: [String] = ["Company", "Category", "Released"]
        var table: [[String: String]] = list.map { d in
            ["Company": companyName(d.company), "Category": d.category, "Released": d.releasedText]
        }
        for (i, d) in list.enumerated() {
            for row in specRows(for: d) + moreSpecRows(for: d) {
                // Released, Maker and Developer repeat the first rows.
                if ["Released", "First released", "Release years", "Maker", "Developer"].contains(row.label) { continue }
                if !labels.contains(row.label) { labels.append(row.label) }
                table[i][row.label] = row.value
            }
        }
        for (i, d) in list.enumerated() {
            table[i]["Ports"] = portsText(d)
            table[i]["Features"] = (d.features ?? []).isEmpty ? notDocumented : (d.features ?? []).joined(separator: "; ")
            table[i]["Sources listed"] = String((d.sources ?? []).count)
        }
        labels += ["Ports", "Features", "Sources listed"]
        return labels.map { label in
            ComparisonRow(label: label, values: table.map { $0[label] ?? notDocumented })
        }
    }

    // MARK: Search

    /// Lowercases and removes accents, so "Dectalk" matches "DECtalk" and "Andre" matches "André".
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US"))
    }

    /// Search words. Every word must appear somewhere in the entry.
    static func terms(_ query: String) -> [String] {
        fold(query).split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" }).map(String.init)
    }

    /// Full-text device search over every text field. Results whose name matches come first,
    /// then the rest by year.
    func searchDevices(_ query: String, category: String? = nil) -> [Device] {
        let words = ATGuideStore.terms(query)
        let pool = devices.filter { category == nil || $0.category == category }
        guard !words.isEmpty else { return pool }
        let hits = pool.filter { d in
            guard let hay = deviceIndex[d.id] else { return false }
            return words.allSatisfy { hay.contains($0) }
        }
        let folded = ATGuideStore.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        func rank(_ d: Device) -> Int {
            let name = ATGuideStore.fold(d.name)
            if name == folded { return 0 }
            if name.hasPrefix(folded) { return 1 }
            if words.allSatisfy({ name.contains($0) }) { return 2 }
            return 3
        }
        return hits.enumerated().sorted { a, b in
            let ra = rank(a.element), rb = rank(b.element)
            return ra != rb ? ra < rb : a.offset < b.offset
        }.map(\.element)
    }

    func searchCompanies(_ query: String) -> [Company] {
        let words = ATGuideStore.terms(query)
        guard !words.isEmpty else { return [] }
        return companies.filter { c in words.allSatisfy { (companyIndex[c.id] ?? "").contains($0) } }
    }

    func searchOS(_ query: String) -> [OSHistory] {
        let words = ATGuideStore.terms(query)
        guard !words.isEmpty else { return [] }
        return osHistories.filter { o in words.allSatisfy { (osIndex[o.id] ?? "").contains($0) } }
    }
}
