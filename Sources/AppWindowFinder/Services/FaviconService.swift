import Foundation
import AppKit

@MainActor
public class FaviconService: FaviconProviding {
    public static let shared = FaviconService()
    private var faviconCache: [String: NSImage] = [:]
    private nonisolated(unsafe) var loadingTasks: [String: Task<NSImage?, Never>] = [:]
    private let defaultFaviconSize = NSSize(width: 16, height: 16)
    
    // Notification for favicon updates
    public static let faviconDidUpdateNotification = Notification.Name("FaviconDidUpdate")
    
    private init() {}
    
    public func getFavicon(for urlString: String, fallbackIcon: NSImage? = nil) async -> NSImage? {
        // Check cache first
        if let cached = faviconCache[urlString] {
            return cached
        }
        
        // Check if already loading
        if let task = loadingTasks[urlString] {
            return await task.value
        }
        
        guard let url = URL(string: urlString),
              let host = url.host else {
            return fallbackIcon
        }
        
        // Start loading task
        let task = Task { () -> NSImage? in
            // Try Google favicon service first (faster and more reliable)
            let faviconURLs = [
                "https://www.google.com/s2/favicons?domain=\(host)&sz=32",
                "https://icons.duckduckgo.com/ip3/\(host).ico",
                "https://\(host)/favicon.ico"
            ]
            
            for faviconURLString in faviconURLs {
                AppLogger.log("Trying favicon URL: \(faviconURLString)", level: .debug, category: .general)
                if let faviconURL = URL(string: faviconURLString),
                   let favicon = await downloadFavicon(from: faviconURL) {
                    // Cache the favicon
                    AppLogger.log("Successfully downloaded favicon from \(faviconURLString)", level: .debug, category: .general)
                    faviconCache[urlString] = favicon
                    loadingTasks.removeValue(forKey: urlString)
                    return favicon
                } else {
                    AppLogger.log("Failed to download favicon from \(faviconURLString)", level: .debug, category: .general)
                }
            }
            
            loadingTasks.removeValue(forKey: urlString)
            return fallbackIcon
        }
        
        loadingTasks[urlString] = task
        return await task.value
    }
    
    // Non-blocking version - returns cached or generic icon immediately, loads in background
    public func getFaviconNonBlocking(for urlString: String, fallbackIcon: NSImage? = nil) -> NSImage? {
        // Check cache first
        if let cached = faviconCache[urlString] {
            return cached
        }
        
        // Start async loading in background if not already loading
        if loadingTasks[urlString] == nil {
            Task {
                if let favicon = await getFavicon(for: urlString, fallbackIcon: fallbackIcon) {
                    // Post notification when favicon is loaded
                    NotificationCenter.default.post(
                        name: Self.faviconDidUpdateNotification,
                        object: self,
                        userInfo: ["url": urlString, "favicon": favicon]
                    )
                }
            }
        }
        
        // Return fallback or generic icon immediately (non-blocking)
        return fallbackIcon ?? createGenericWebIcon()
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