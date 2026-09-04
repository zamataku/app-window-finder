import Foundation
import AppKit

@MainActor
public class FaviconService: FaviconProviding {
    public static let shared = FaviconService()
    private var faviconCache: [String: NSImage] = [:]
    private var loadingTasks: [String: Task<Void, Never>] = [:]
    private let defaultFaviconSize = NSSize(width: 16, height: 16)

    // Notification for favicon updates
    public static let faviconDidUpdateNotification = Notification.Name("FaviconDidUpdate")

    private init() {}

    public func getFavicon(for urlString: String, fallbackIcon: NSImage? = nil) async -> NSImage? {
        if let cached = faviconCache[urlString] {
            return cached
        }

        guard let host = URL(string: urlString)?.host else {
            return fallbackIcon
        }

        await loadingTask(for: urlString, host: host).value
        return faviconCache[urlString] ?? fallbackIcon
    }

    // Non-blocking version - returns cached or generic icon immediately, loads in background
    public func getFaviconNonBlocking(for urlString: String, fallbackIcon: NSImage? = nil) -> NSImage? {
        if let cached = faviconCache[urlString] {
            return cached
        }

        if loadingTasks[urlString] == nil, let host = URL(string: urlString)?.host {
            let task = loadingTask(for: urlString, host: host)
            Task {
                await task.value
                if let favicon = faviconCache[urlString] {
                    NotificationCenter.default.post(
                        name: Self.faviconDidUpdateNotification,
                        object: self,
                        userInfo: ["url": urlString, "favicon": favicon]
                    )
                }
            }
        }

        return fallbackIcon ?? createGenericWebIcon()
    }

    /// Returns the in-flight download for `urlString`, starting one if needed.
    /// Concurrent callers share a single task so each host is fetched at most once.
    private func loadingTask(for urlString: String, host: String) -> Task<Void, Never> {
        if let task = loadingTasks[urlString] {
            return task
        }

        let task = Task {
            defer { loadingTasks.removeValue(forKey: urlString) }
            for faviconURL in Self.faviconCandidates(for: host) {
                if Task.isCancelled { return }
                AppLogger.log("Trying favicon URL: \(faviconURL)", level: .debug, category: .general)
                if let favicon = await downloadFavicon(from: faviconURL) {
                    AppLogger.log("Successfully downloaded favicon from \(faviconURL)", level: .debug, category: .general)
                    faviconCache[urlString] = favicon
                    return
                }
                AppLogger.log("Failed to download favicon from \(faviconURL)", level: .debug, category: .general)
            }
        }
        loadingTasks[urlString] = task
        return task
    }

    /// Lookup order: Google's favicon service, DuckDuckGo's, then the site itself.
    /// Only the hostname leaves the machine, never the full URL.
    private static func faviconCandidates(for host: String) -> [URL] {
        return [
            "https://www.google.com/s2/favicons?domain=\(host)&sz=32",
            "https://icons.duckduckgo.com/ip3/\(host).ico",
            "https://\(host)/favicon.ico"
        ].compactMap(URL.init(string:))
    }

    private func createGenericWebIcon() -> NSImage {
        let size = defaultFaviconSize
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        // Create a simple globe icon
        let rect = NSRect(origin: .zero, size: size)

        // Background circle
        NSColor.systemBlue.setFill()
        let ovalPath = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
        ovalPath.fill()

        // Globe lines
        NSColor.white.setStroke()
        let center = NSPoint(x: size.width/2, y: size.height/2)
        let radius = min(size.width, size.height) / 2 - 3

        // Vertical line
        let verticalPath = NSBezierPath()
        verticalPath.move(to: NSPoint(x: center.x, y: center.y - radius))
        verticalPath.line(to: NSPoint(x: center.x, y: center.y + radius))
        verticalPath.lineWidth = 1.0
        verticalPath.stroke()

        // Horizontal line
        let horizontalPath = NSBezierPath()
        horizontalPath.move(to: NSPoint(x: center.x - radius, y: center.y))
        horizontalPath.line(to: NSPoint(x: center.x + radius, y: center.y))
        horizontalPath.lineWidth = 1.0
        horizontalPath.stroke()

        return image
    }


    private func downloadFavicon(from url: URL) async -> NSImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data) else { return nil }

            // Resize to standard favicon size using modern API
            return resizeImage(image, to: defaultFaviconSize)
        } catch {
            return nil
        }
    }

    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage? {
        // Use modern NSGraphicsContext API instead of lockFocus
        let resizedImage = NSImage(size: size)

        resizedImage.lockFocus()
        defer { resizedImage.unlockFocus() }

        // Clear the background
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Draw the image scaled to fit
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .sourceOver,
                  fraction: 1.0)

        return resizedImage
    }

    public func clearCache() {
        faviconCache.removeAll()
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()
    }
}
