import Foundation

/// Builds the plain text (TXT) version of an entry. The layout matches the
/// ATGuide website's TXT downloads so a shared file reads the same everywhere.
struct TextExporter {
    let store: ATGuideStore
    var newline: String = "\r\n"
    static let footer = "From the ATGuide app by Hunter Thompson"

    /// Removes markdown-like symbols so screen readers do not read them aloud.
    static func clean(_ s: String) -> String {
        var out = s.unicodeScalars.filter { !"*_`#|\u{2605}\u{2606}".unicodeScalars.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return out
    }

    private func section(_ title: String, _ lines: [String]) -> String {
        ([title + ":"] + (lines.isEmpty ? [notDocumented] : lines.map(TextExporter.clean)))
            .joined(separator: newline)
    }

    private func ref(_ id: String) -> String {
        guard let d = store.device(id) else { return id }
        return d.name + " (" + store.companyName(d.company) + ", " + (d.released ?? "") + ")"
    }

    private func sources(_ list: [String]?) -> [String] {
        (list ?? []).enumerated().map { "Source \($0.offset + 1): \($0.element)" }
    }

    func text(for d: Device) -> String {
        var specs = (store.specRows(for: d) + store.moreSpecRows(for: d)).map { $0.label + ": " + TextExporter.clean($0.value) }
        if let vo = d.voices, !vo.isEmpty {
            specs.append("Voices: " + store.voices(of: d).map(\.name).joined(separator: "; "))
        }
        let users = store.usedBy(voice: d.id)
        if !users.isEmpty {
            specs.append("Shipped with or used by: " + users.map(\.name).joined(separator: "; "))
        }
        var hist = [d.history.nonEmpty ?? notDocumented]
        if let p = d.predecessors, !p.isEmpty { hist.append("Predecessors: " + p.map(ref).joined(separator: "; ")) }
        if let s = d.successors, !s.isEmpty { hist.append("Successors: " + s.map(ref).joined(separator: "; ")) }
        var os = [store.operatingSystemText(d)]
        for o in store.osHistories(forDevice: d.id) { os.append("Operating system history: " + o.name) }
        let header = [TextExporter.clean(d.name), "Company: " + store.companyName(d.company),
                      "Category: " + d.category, "Released: " + TextExporter.clean(d.released ?? "")]
        let parts = [header.joined(separator: newline),
                     section("Overview", [d.overview.nonEmpty ?? notDocumented]),
                     section("Specs", specs),
                     section("Physical Description", [store.physicalText(d)]),
                     (d.details ?? []).isEmpty ? "" : section("Detailed Description", d.details ?? []),
                     section("Features", d.features ?? []),
                     section("History", hist),
                     section("Ports", [store.portsText(d)]),
                     section("Operating System", os),
                     section("System Requirements", d.requirements ?? []),
                     section("Sources", sources(d.sources)),
                     TextExporter.footer]
        return parts.filter { !$0.isEmpty }.joined(separator: newline + newline) + newline
    }

    func text(for o: OSHistory) -> String {
        let vers = o.versions.enumerated().map { i, v in
            "Version \(i + 1): " + TextExporter.clean(v.name) + newline
                + "Released: " + TextExporter.clean(v.released.nonEmpty ?? notDocumented) + newline
                + "Notes: " + TextExporter.clean(v.notes.nonEmpty ?? notDocumented)
        }
        let header = [TextExporter.clean(o.name), "Company: " + store.companyName(o.company),
                      "Category: Operating system or software version history",
                      "Versions listed: \(o.versions.count)"]
        let parts = [header.joined(separator: newline),
                     section("Overview", [o.overview.nonEmpty ?? notDocumented]),
                     (["Version History:"] + (vers.isEmpty ? [notDocumented] : vers)).joined(separator: newline + newline),
                     section("Devices and Software That Ran It", (o.devices ?? []).filter { store.device($0) != nil }.map(ref)),
                     section("System Requirements", o.requirements ?? []),
                     section("Sources", sources(o.sources)),
                     TextExporter.footer]
        return parts.joined(separator: newline + newline) + newline
    }

    func text(for c: Company) -> String {
        let prods = store.devices(of: c.id)
        let oses = store.osHistories(of: c.id)
        let header = [TextExporter.clean(c.name), "Type: Company profile",
                      "Founded: " + TextExporter.clean(c.founded.nonEmpty ?? notDocumented),
                      "Products listed: \(prods.count)"]
        let parts = [header.joined(separator: newline),
                     section("History", [c.history.nonEmpty ?? notDocumented]),
                     section("Products", prods.map { $0.name + " (" + $0.category + ", " + ($0.released ?? "") + ")" }),
                     section("Operating System and Software Histories", oses.map(\.name)),
                     section("Sources", sources(c.sources)),
                     TextExporter.footer]
        return parts.joined(separator: newline + newline) + newline
    }

    /// A file name that is safe on every platform, for example "Braille n Speak.txt".
    static func fileName(_ title: String) -> String {
        var s = title.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US"))
        let map: [Character: String] = ["/": "-", "\\": "-", ":": " ", "*": " ", "?": " ", "\"": " ",
                                        "<": " ", ">": " ", "|": " ", "\u{2018}": "'", "\u{2019}": "'",
                                        "\u{2013}": "-", "\u{2014}": "-"]
        s = String(s.flatMap { ch -> [Character] in
            if let r = map[ch] { return Array(r) }
            return ch.isASCII && !(ch.asciiValue! < 0x20) ? [ch] : []
        })
        let words = s.split(whereSeparator: { $0 == " " }).joined(separator: " ")
        var name = words.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        if name.count > 100 { name = String(name.prefix(100)) }
        return (name.isEmpty ? "Untitled" : name) + ".txt"
    }
}
