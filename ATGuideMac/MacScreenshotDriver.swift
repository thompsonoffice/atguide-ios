import AppKit
import SwiftUI

/// Walks the main screens and writes 1280×800 (or another accepted Mac size) PNGs
/// when the app is launched with -ATGuideScreenshots and -ATGuideScreenshotDir <path>.
/// This runs from app init and uses ImageRenderer, so it does not need a visible window.
enum MacScreenshotRunner {
    @MainActor
    static func schedule(nav: MacNavState, store: ATGuideStore, compare: CompareStore,
                         favorites: FavoritesStore, recents: RecentsStore) {
        guard let dir = screenshotDirectory() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? "started".write(to: dir.appendingPathComponent("STARTED.txt"), atomically: true, encoding: .utf8)
        fputs("ATGuide screenshots: scheduled, writing to \(dir.path)\n", stderr)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await run(nav: nav, store: store, compare: compare, favorites: favorites, recents: recents, dir: dir)
        }
    }

    @MainActor
    static func scheduleFailedLaunch() {
        guard let dir = screenshotDirectory() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? "data load failed".write(to: dir.appendingPathComponent("ERROR.txt"), atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }

    private static func screenshotDirectory() -> URL? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ATGuideScreenshots") else { return nil }
        guard let index = args.firstIndex(of: "-ATGuideScreenshotDir"),
              args.indices.contains(index + 1) else {
            fputs("ATGuide screenshots: missing -ATGuideScreenshotDir\n", stderr)
            return nil
        }
        return URL(fileURLWithPath: args[index + 1], isDirectory: true)
    }

    @MainActor
    private static func run(nav: MacNavState, store: ATGuideStore, compare: CompareStore,
                            favorites: FavoritesStore, recents: RecentsStore, dir: URL) async {
        func shot(_ name: String) {
            do {
                try render(view: wrapped(MacSplitView(), nav: nav, store: store, compare: compare, favorites: favorites, recents: recents),
                           to: dir.appendingPathComponent(name))
            } catch {
                fputs("ATGuide screenshots: failed \(name): \(error)\n", stderr)
            }
        }

        nav.open(.browse)
        shot("01-browse.png")

        nav.openCategory = "Notetakers"
        nav.selection = nil
        shot("02-notetakers.png")

        nav.selection = .device("bntouch")
        shot("03-braillenote-touch.png")

        compare.removeAll()
        for id in ["bntouch", "bns", "bnapex"] {
            if store.device(id) != nil { compare.add(id) }
        }
        if compare.ids.count < 2 {
            for d in store.devices(inCategory: "Notetakers").prefix(3) {
                compare.add(d.id)
            }
        }
        nav.searchQuery = "BrailleNote"
        nav.open(.search)
        shot("04-search.png")

        nav.open(.compare)
        nav.selection = nil
        shot("05-compare.png")

        nav.open(.about)
        shot("06-about.png")

        try? "ok".write(to: dir.appendingPathComponent("DONE.txt"), atomically: true, encoding: .utf8)
        fputs("ATGuide screenshots: done\n", stderr)
        NSApp.terminate(nil)
    }

    @MainActor
    private static func wrapped<V: View>(_ view: V, nav: MacNavState, store: ATGuideStore,
                                         compare: CompareStore, favorites: FavoritesStore,
                                         recents: RecentsStore) -> some View {
        view
            .environmentObject(store)
            .environmentObject(favorites)
            .environmentObject(recents)
            .environmentObject(compare)
            .environmentObject(nav)
            .frame(width: 1280, height: 800)
    }

    @MainActor
    private static func render(view: some View, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 1280, height: 800)
        renderer.scale = 1
        guard let cgImage = renderer.cgImage else {
            throw CocoaError(.fileWriteUnknown)
        }
        let final = normalizedImage(cgImage)
        let rep = NSBitmapImageRep(cgImage: final)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
        fputs("ATGuide screenshots: wrote \(url.lastPathComponent) \(final.width)x\(final.height)\n", stderr)
    }

    /// Accepted Mac App Store sizes: 1280×800, 1440×900, 2560×1600, 2880×1800.
    private static let accepted: Set<[Int]> = [
        [1280, 800], [1440, 900], [2560, 1600], [2880, 1800]
    ]

    private static func normalizedImage(_ image: CGImage) -> CGImage {
        let w = image.width
        let h = image.height
        if accepted.contains([w, h]) { return image }
        let target = (w >= 2000 || h >= 1400)
            ? (width: 2560, height: 1600)
            : (width: 1280, height: 800)
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: target.width,
            height: target.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: target.width, height: target.height))
        return ctx.makeImage() ?? image
    }
}
