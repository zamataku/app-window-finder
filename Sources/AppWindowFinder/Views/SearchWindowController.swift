import SwiftUI
import AppKit

@MainActor
public class SearchWindowController: NSWindowController {
    public static let shared = SearchWindowController()
    
    public var isVisible: Bool {
        window?.isVisible ?? false
    }
    
    private override init(window: NSWindow?) {
        // Create initial window without content
        let window = CustomPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.hidesOnDeactivate = false
        window.acceptsMouseMovedEvents = true
        
        super.init(window: window)
        
        window.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show() {
        guard let window = window else { return }
        
        // Create fresh view each time to ensure state is reset
        let searchView = SearchView(
            onDismiss: { [weak self] in
                self?.hide()
            },
            onSelect: { [weak self] item in
                WindowManager.shared.activateItem(item)
                self?.hide()
            }
        )
        
        let hostingController = NSHostingController(rootView: searchView)
        window.contentViewController = hostingController
        
        // Don't change activation policy - keep it as configured in AppDelegate
        // NSApp.setActivationPolicy(.regular)
        
        // Center the window
        window.center()
        
        // Activate the app first
        NSApp.activate(ignoringOtherApps: true)
        
        // Make window key and visible
        window.makeKeyAndOrderFront(nil)
        
        // Force window to become key
        window.makeKey()
        
        // Set initial responder to content view
        if let contentView = window.contentView {
            window.makeFirstResponder(contentView)
        }
    }
    
    public func hide() {
        window?.orderOut(nil)
        // Hide the app to allow the previously active app to become active again
        NSApp.hide(nil)
        // Don't change activation policy - keep app running normally
        // NSApp.setActivationPolicy(.accessory)
    }
    
    public func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
}