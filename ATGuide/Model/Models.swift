import Foundation

/// Text shown when a fact could not be found in a source.
let notDocumented = "Not documented"

/// Categories that describe software rather than hardware.
let softwareCategories: Set<String> = ["Screen Readers", "Accessible Linux"]

struct ATGuideData: Codable {
    var version: Int
    var edition: String?
    var generated: String
    var categories: [String]
    var companies: [Company]
    var devices: [Device]
    var osHistories: [OSHistory]
    var trivia: [TriviaFact]
}

struct Company: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var founded: String?
    var history: String?
    var sources: [String]?
}

struct DeviceSpecs: Codable, Hashable {
    var processor: String?
    var memory: String?
    var storage: String?
    var operatingSystem: String?
    var speech: String?
    var battery: String?
    var display: String?
    var price: String?
    var synthesis: String?
    var platforms: String?
    var defaultOn: String?
    var synthesizersAvailable: String?
    var usedPrice: String?

    var allValues: [String] {
        [processor, memory, storage, operatingSystem, speech, battery, display,
         price, synthesis, platforms, defaultOn, synthesizersAvailable, usedPrice].compactMap { $0 }
    }
}

/// A spec that is not part of the standard Specs table, for example Dimensions or Weight.
struct ExtraSpec: Codable, Hashable {
    var label: String
    var value: String
}

struct Device: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var company: String
    var category: String
    var year: Int?
    var released: String?
    var overview: String?
    var physical: String?
    var details: [String]?
    var features: [String]?
    var history: String?
    var ports: String?
    var specs: DeviceSpecs?
    var moreSpecs: [ExtraSpec]?
    var requirements: [String]?
    var predecessors: [String]?
    var successors: [String]?
    var voices: [String]?
    var sources: [String]?

    var isVoice: Bool { category == "TTS Voices" }
    var isSoftware: Bool { softwareCategories.contains(category) }
    /// Year used for sorting. Missing or zero years sort last.
    var sortYear: Int {
        guard let y = year, y != 0 else { return 9999 }
        return y
    }
    var releasedText: String { released.nonEmpty ?? notDocumented }
}

struct OSVersion: Codable, Hashable {
    var name: String
    var released: String?
    var notes: String?
}

struct OSHistory: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var company: String
    var overview: String?
    var versions: [OSVersion]
    var devices: [String]?
    var requirements: [String]?
    var sources: [String]?
}

enum TriviaLevel: String, Codable, CaseIterable, Identifiable {
    case easy = "Easy", medium = "Medium", hard = "Hard"
    var id: String { rawValue }
}

struct TriviaFact: Codable, Hashable, Identifiable {
    var text: String
    var device: String?
    var level: TriviaLevel
    var id: String { text }
}

/// A labeled fact row, used for the Specs section, the comparison view and the TXT export.
struct SpecRow: Hashable, Identifiable {
    var label: String
    var value: String
    var id: String { label }
}

/// One category of a company's catalog, or one category in Browse.
struct CatalogGroup: Identifiable, Hashable {
    var category: String
    var devices: [Device]
    var id: String { category }
}

/// Navigation destinations shared by every tab.
enum Route: Hashable {
    case company(String)
    case device(String)
    case os(String)
    case category(String)
    case companies
    case timeline
    case osList
    case trivia
    case recents
    case settings
    case about
    case privacy
}

/// A saved-item key such as "dev:bns", "co:blazie" or "os:keysoft". Matches the web app's favorites.
enum FavoriteKey {
    static func device(_ id: String) -> String { "dev:" + id }
    static func company(_ id: String) -> String { "co:" + id }
    static func os(_ id: String) -> String { "os:" + id }

    enum Kind { case device, company, os }

    /// Splits "dev:bns" into (.device, "bns"). Returns nil for unknown prefixes.
    static func parse(_ key: String) -> (kind: Kind, id: String)? {
        if key.hasPrefix("dev:") { return (.device, String(key.dropFirst(4))) }
        if key.hasPrefix("co:") { return (.company, String(key.dropFirst(3))) }
        if key.hasPrefix("os:") { return (.os, String(key.dropFirst(3))) }
        return nil
    }
}

extension Optional where Wrapped == String {
    /// The string, or nil when it is missing or empty.
    var nonEmpty: String? {
        switch self {
        case .some(let s) where !s.isEmpty: return s
        default: return nil
        }
    }
}
