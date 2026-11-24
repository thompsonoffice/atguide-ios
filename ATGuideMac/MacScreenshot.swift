import AppKit
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Launch arguments used only by the screenshot helper on the Mac build runner.
enum ScreenshotLaunch {
    static var scene: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-ATGuideScreenshot") else { return nil }
        if args.indices.contains(index + 1), !args[index + 1].hasPrefix("-") {
            return args[index + 1]
        }
        return "browse"
    }

    static var outputPath: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-ATGuideScreenshotPath"),
              args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    static var isRequested: Bool { outputPath != nil || scene != nil }

    /// Puts the sidebar, selection, search, compare and favorites into the
    /// state for one App Store screenshot scene.
    static func apply(_ scene: String, nav: MacNavState, store: ATGuideStore,
                      compare: CompareStore, favorites: FavoritesStore,
                      recents: RecentsStore) {
        switch scene {
        case "notetakers":
            nav.sidebar = .browse
            nav.openCategory = "Notetakers"
            nav.selection = nil
        case "device":
            nav.sidebar = .browse
            nav.openCategory = "Notetakers"
            nav.selection = .device("bntouch")
            recents.record(FavoriteKey.device("bntouch"))
        case "search":
            nav.searchQuery = "BrailleNote"
            nav.open(.search)
        case "compare":
            compare.removeAll()
            for id in ["bntouch", "bns", "bnapex"] {
                if store.device(id) != nil { compare.add(id) }
            }
            if compare.ids.count < 2 {
                for device in store.devices(inCategory: "Notetakers").prefix(3) {
                    compare.add(device.id)
                }
            }
            nav.open(.compare)
            nav.selection = nil
        case "favorites":
            if store.device("bntouch") != nil {
                if !favorites.contains(FavoriteKey.device("bntouch")) {
                    favorites.toggle(FavoriteKey.device("bntouch"))
                }
            }
            if let humanware = store.companies.first(where: { $0.id == "hw" || $0.name == "HumanWare" }) {
                if !favorites.contains(FavoriteKey.company(humanware.id)) {
                    favorites.toggle(FavoriteKey.company(humanware.id))
                }
            }
            nav.open(.favorites)
        case "about":
            nav.open(.about)
        default:
            nav.sidebar = .browse
            nav.openCategory = nil
            nav.selection = nil
        }
    }
}

/// Sets the window to an App Store screenshot size, writes a PNG of the real
/// window (including the title bar), then quits. Used only when
/// `-ATGuideScreenshotPath` is passed on the command line.
enum MacScreenshot {
    static func captureIfRequested() {
        guard let path = ScreenshotLaunch.outputPath else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            capture(to: path)
        }
    }

    private static func capture(to path: String) {
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey })
                ?? NSApplication.shared.windows.first else {
            fputs("ATGuide screenshots: no window\n", stderr)
            NSApp.terminate(nil)
            return
        }
        let width: CGFloat = 1280
        let height: CGFloat = 800
        if let screen = window.screen ?? NSScreen.main {
            let originY = screen.frame.maxY - height
            window.setFrame(NSRect(x: screen.frame.minX, y: originY, width: width, height: height), display: true, animate: false)
        } else {
            window.setFrame(NSRect(x: 0, y: 0, width: width, height: height), display: true, animate: false)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if writeViewSnapshot(of: window, to: url) {
                fputs("ATGuide screenshots: wrote view snapshot \(url.path)\n", stderr)
            } else if writeWindowListImage(of: window, to: url) {
                fputs("ATGuide screenshots: wrote window-list image \(url.path)\n", stderr)
            } else if writeScreenCapture(of: window, to: url) {
                fputs("ATGuide screenshots: wrote screencapture \(url.path)\n", stderr)
            } else {
                fputs("ATGuide screenshots: failed to capture \(url.path)\n", stderr)
            }
            NSApp.terminate(nil)
        }
    }

    /// Captures the window's own views, including the title bar, without a
    /// screen-recording permission. This is the method that worked for Access Mastery.
    @discardableResult
    private static func writeViewSnapshot(of window: NSWindow, to url: URL) -> Bool {
        guard let view = window.contentView?.superview ?? window.contentView else { return false }
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return false }
        view.cacheDisplay(in: bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try data.write(to: url)
            return FileManager.default.fileExists(atPath: url.path)
        } catch {
            return false
        }
    }

    @discardableResult
    private static func writeWindowListImage(of window: NSWindow, to url: URL) -> Bool {
        let windowID = CGWindowID(window.windowNumber)
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else { return false }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }

    /// Last-resort capture of the real window via /usr/sbin/screencapture.
    @discardableResult
    private static func writeScreenCapture(of window: NSWindow, to url: URL) -> Bool {
        let windowID = window.windowNumber
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-l", String(windowID), "-o", "-x", url.path]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0 && FileManager.default.fileExists(atPath: url.path)
        } catch {
            return false
        }
    }
}
