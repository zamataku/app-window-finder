import AppKit

extension NSImage {
    func resized(to targetSize: NSSize) -> NSImage {
        // すでに目標サイズ以下の場合はそのまま返す
        if size.width <= targetSize.width && size.height <= targetSize.height {
            return self
        }
        
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        
        // アスペクト比を保持してリサイズ
        let aspectRatio = size.width / size.height
        var drawRect = NSRect.zero
        
        if aspectRatio > targetSize.width / targetSize.height {
            drawRect.size.width = targetSize.width
            drawRect.size.height = targetSize.width / aspectRatio
            drawRect.origin.y = (targetSize.height - drawRect.size.height) / 2
        } else {
            drawRect.size.height = targetSize.height
            drawRect.size.width = targetSize.height * aspectRatio
            drawRect.origin.x = (targetSize.width - drawRect.size.width) / 2
        }
        
        self.draw(in: drawRect,
                  from: NSRect(origin: .zero, size: size),
                  operation: .sourceOver,
                  fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
}

struct ImageOptimizer {
    static let iconSize = NSSize(width: 20, height: 20)
    
    static func optimizeIcon(_ icon: NSImage?) -> NSImage? {
        guard let icon = icon else { return nil }
        
        // Retina display考慮して2倍サイズまで許容
        let maxSize = NSSize(width: iconSize.width * 2, height: iconSize.height * 2)
        
        if icon.size.width > maxSize.width || icon.size.height > maxSize.height {
            return icon.resized(to: maxSize)
        }
        
        return icon
    }
}