import Foundation
import AppKit

/// Sendable wrapper for NSImage to handle Swift 6 concurrency requirements
public struct SendableImage: Sendable {
    private let imageData: Data
    private let _size: NSSize
    
    public var size: NSSize {
        return _size
    }
    
    public init?(_ nsImage: NSImage) {
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        self.imageData = pngData
        self._size = nsImage.size
    }
    
    public init?(data: Data, size: NSSize) {
        self.imageData = data
        self._size = size
    }
    
    @MainActor
    public var nsImage: NSImage? {
        return NSImage(data: imageData)
    }
    
    @MainActor
    public func resized(to newSize: NSSize) -> SendableImage? {
        guard let nsImage = self.nsImage else { return nil }
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        defer { resizedImage.unlockFocus() }
        
        nsImage.draw(in: NSRect(origin: .zero, size: newSize),
                    from: NSRect(origin: .zero, size: nsImage.size),
                    operation: .sourceOver,
                    fraction: 1.0)
        
        return SendableImage(resizedImage)
    }
}

/// Protocol for services that provide images in a Sendable manner
@MainActor
public protocol SendableFaviconProviding {
    func getFavicon(for urlString: String, fallbackIcon: SendableImage?) async -> SendableImage?
    func getFaviconNonBlocking(for urlString: String, fallbackIcon: SendableImage?) -> SendableImage?
    func clearCache()
}

/// Extension to convert between NSImage and SendableImage
extension NSImage {
    @MainActor
    public var sendable: SendableImage? {
        return SendableImage(self)
    }
}

extension SendableImage {
    @MainActor
    public static func from(_ nsImage: NSImage?) -> SendableImage? {
        guard let nsImage = nsImage else { return nil }
        return SendableImage(nsImage)
    }
    
    @MainActor
    public static func systemIcon(name: String) -> SendableImage? {
        guard let nsImage = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }
        return SendableImage(nsImage)
    }
    
    @MainActor
    public static func genericWebIcon() -> SendableImage? {
        let size = NSSize(width: 16, height: 16)
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
        
        return SendableImage(image)
    }
}