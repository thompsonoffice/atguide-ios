import AppKit
import SwiftUI

/// Walks the main screens and writes 1280×800 (or another accepted Mac size) PNGs
/// when the app is launched with -ATGuideScreenshots and -ATGuideScreenshotDir <path>.
enum MacScreenshotRunner {
    @MainActor
    static func run(nav: MacNavState, store: ATGuideStore, compare: CompareStore) async {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ATGuideScreenshots") else { return }
        guard let index = args.firstIndex(of: "-ATGuideScreenshotDir"),
              args.indices.contains(index + 1) else {
            NSLog("ATGuide screenshots: missing -ATGuideScreenshotDir")
            return
        }
        let dir = URL(fileURLWithPath: args[index + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? "started".write(to: dir.appendingPathComponent("STARTED.txt"), atomically: true, encoding: .utf8)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Wait for the main window to exist.
        var window: NSWindow?
        for _ in 0..<50 {
            window = NSApp.windows.first { $0.contentView != nil && $0.isVisible }
            if window != nil { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        guard let window else {
            try? "No window".write(to: dir.appendingPathComponent("ERROR.txt"), atomically: true, encoding: .utf8)
            NSApp.terminate(nil)
            return
        }
        window.setContentSize(NSSize(width: 1280, height: 800))
        window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 400_000_000)

        func snap(_ name: String) async {
            await Self.snap(name, window: window, dir: dir)
        }

        nav.open(.browse)
        try? await Task.sleep(nanoseconds: 400_000_000)
        await snap("01-browse.png")

        nav.openCategory = "Notetakers"
        nav.selection = nil
        try? await Task.sleep(nanoseconds: 400_000_000)
        await snap("02-notetakers.png")

        nav.selection = .device("bntouch")
        try? await Task.sleep(nanoseconds: 600_000_000)
        await snap("03-braillenote-touch.png")

        compare.removeAll()
        for id in ["bntouch", "bns", "bnapex"] {
            if store.device(id) != nil { compare.add(id) }
        }
        // If those IDs are missing, pick the first three notetakers.
        if compare.ids.count < 2 {
            for d in store.devices(inCategory: "Notetakers").prefix(3) {
                compare.add(d.id)
            }
        }
        nav.searchQuery = "BrailleNote"
        nav.open(.search)
        try? await Task.sleep(nanoseconds: 700_000_000)
        await snap("04-search.png")

        nav.open(.compare)
        nav.selection = nil
        try? await Task.sleep(nanoseconds: 600_000_000)
        await snap("05-compare.png")

        nav.open(.about)
        try? await Task.sleep(nanoseconds: 400_000_000)
        await snap("06-about.png")

        try? "ok".write(to: dir.appendingPathComponent("DONE.txt"), atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }

    private static func snap(_ name: String, window: NSWindow, dir: URL) async {
        window.setContentSize(NSSize(width: 1280, height: 800))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try? await Task.sleep(nanoseconds: 500_000_000)
        do {
            try capture(window: window, to: dir.appendingPathComponent(name))
        } catch {
            NSLog("ATGuide screenshots: failed \(name): \(error)")
        }
    }

    private static func capture(window: NSWindow, to url: URL) throws {
        guard let view = window.contentView else { throw CocoaError(.fileWriteUnknown) }
        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        guard let cached = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        view.cacheDisplay(in: bounds, to: cached)
        guard let cgImage = cached.cgImage else { throw CocoaError(.fileWriteUnknown) }
        let final = Self.normalizedImage(cgImage)
        let rep = NSBitmapImageRep(cgImage: final)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
        NSLog("ATGuide screenshots: wrote \(url.lastPathComponent) \(final.width)x\(final.height)")
    }

    /// Accepted Mac App Store sizes: 1280×800, 1440×900, 2560×1600, 2880×1800.
    private static let accepted: Set<[Int]> = [
        [1280, 800], [1440, 900], [2560, 1600], [2880, 1800]
    ]

    private static func normalizedImage(_ image: CGImage) -> CGImage {
        let w = image.width
        let h = image.height
        if accepted.contains([w, h]) { return image }
        // Prefer 2560×1600 when the capture is Retina-sized, otherwise 1280×800.
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
