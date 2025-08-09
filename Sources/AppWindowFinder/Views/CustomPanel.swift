import AppKit

class CustomPanel: NSPanel {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // Configure panel behavior
        self.isFloatingPanel = false
        self.becomesKeyOnlyIfNeeded = false
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func resignKey() {
        super.resignKey()
        // Hide window when it loses key status
        orderOut(nil)
    }
}