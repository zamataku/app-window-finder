import AppKit

extension NSImage {
    static let optimizedIconSize = NSSize(width: 20, height: 20)
    
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
    
    func optimizedForIcon() -> NSImage {
        // Retina display考慮して2倍サイズまで許容
        let maxSize = NSSize(
            width: NSImage.optimizedIconSize.width * 2,
            height: NSImage.optimizedIconSize.height * 2
        )
        
        if size.width > maxSize.width || size.height > maxSize.height {
            return resized(to: maxSize)
        }
        
        return self
    }
}

// 既存コードとの互換性のため、ImageOptimizer 構造体も残す（非推奨）
@available(*, deprecated, message: "Use NSImage.optimizedForIcon() instead")
struct ImageOptimizer {
    static let iconSize = NSImage.optimizedIconSize
    
    static func optimizeIcon(_ icon: NSImage?) -> NSImage? {
        return icon?.optimizedForIcon()
    }
}