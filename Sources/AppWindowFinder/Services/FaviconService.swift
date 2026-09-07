import Foundation
import AppKit

@MainActor
public class FaviconService: FaviconProviding {
    public static let shared = FaviconService()
    /// Favicons are per host, so every cache below is keyed by hostname
    private var faviconCache: [String: NSImage] = [:]
    private var failedHosts: [String: Date] = [:]
    private var loadingTasks: [String: (token: UUID, task: Task<Void, Never>)] = [:]
    private let defaultFaviconSize = NSSize(width: 16, height: 16)

    /// How long a host that failed every lookup is left alone before retrying
    private static let failureRetryInterval: TimeInterval = 10 * 60

    // Notification for favicon updates
    public static let faviconDidUpdateNotification = Notification.Name("FaviconDidUpdate")

    private init() {}

    public func getFavicon(for urlString: String, fallbackIcon: NSImage? = nil) async -> NSImage? {
        guard let host = URL(string: urlString)?.host else {
            return fallbackIcon
        }
        if let cached = faviconCache[host] {
            return cached
        }
        if hasRecentlyFailed(host) {
            return fallbackIcon
        }

        await loadingTask(for: host).value
        return faviconCache[host] ?? fallbackIcon
    }

    // Non-blocking version - returns cached or generic icon immediately, loads in background
    public func getFaviconNonBlocking(for urlString: String, fallbackIcon: NSImage? = nil) -> NSImage? {
        guard let host = URL(string: urlString)?.host else {
            return fallbackIcon ?? createGenericWebIcon()
        }
        if let cached = faviconCache[host] {
            return cached
        }

        if loadingTasks[host] == nil, !hasRecentlyFailed(host) {
            let task = loadingTask(for: host)
            Task {
                await task.value
                if let favicon = faviconCache[host] {
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

    private func hasRecentlyFailed(_ host: String) -> Bool {
        guard let failedAt = failedHosts[host] else { return false }
        if Date().timeIntervalSince(failedAt) < Self.failureRetryInterval {
            return true
        }
        failedHosts.removeValue(forKey: host)
        return false
    }

    /// Returns the in-flight download for `host`, starting one if needed.
    /// Concurrent callers share a single task so each host is fetched at most once.
    private func loadingTask(for host: String) -> Task<Void, Never> {
        if let entry = loadingTasks[host] {
            return entry.task
        }

        let token = UUID()
        let task = Task {
            defer {
                // A task cancelled by clearCache() must not evict a newer task registered under the same key
                if loadingTasks[host]?.token == token {
                    loadingTasks.removeValue(forKey: host)
                }
            }
            for faviconURL in Self.faviconCandidates(for: host) {
                if Task.isCancelled { return }
                AppLogger.log("Trying favicon URL: \(faviconURL)", level: .debug, category: .general)
                if let favicon = await downloadFavicon(from: faviconURL) {
                    if Task.isCancelled { return }
                    AppLogger.log("Successfully downloaded favicon from \(faviconURL)", level: .debug, category: .general)
                    faviconCache[host] = favicon
                    return
                }
                AppLogger.log("Failed to download favicon from \(faviconURL)", level: .debug, category: .general)
            }
            if !Task.isCancelled {
                failedHosts[host] = Date()
            }
        }
        loadingTasks[host] = (token, task)
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
        failedHosts.removeAll()
        for entry in loadingTasks.values {
            entry.task.cancel()
        }
        loadingTasks.removeAll()
    }
}
