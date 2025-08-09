import Testing
import AppKit
@testable import AppWindowFinder

@MainActor
struct WindowActivationVerificationTests {
    
    init() async {
        // Ensure clean state before each test
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testWindowActivationSequence() async {
        let searchWindow = SearchWindowController.shared
        
        // Start with window hidden
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Show the window
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 200_000_000) // Give more time for activation
        
        // Verify window properties
        if let window = searchWindow.window {
            #expect(window.isVisible)
            #expect(window.canBecomeKey)
            #expect(window.canBecomeMain)
            #expect(window.level == .floating)
            #expect(window.styleMask.contains(.borderless))
            #expect(window is CustomPanel)
            
            // Verify panel specific properties
            if let panel = window as? NSPanel {
                #expect(!panel.hidesOnDeactivate)
                #expect(panel.acceptsMouseMovedEvents)
            }
        }
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testActivationPolicyHandling() async {
        let searchWindow = SearchWindowController.shared
        
        // Hide window
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Show window - should change to regular policy
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When shown, app should have regular policy
        #expect(NSApp.activationPolicy() == .regular)
        
        // Hide window - should restore accessory policy
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(NSApp.activationPolicy() == .accessory)
    }
    
    @Test func testFocusChainSetup() async {
        let searchWindow = SearchWindowController.shared
        
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        if let window = searchWindow.window {
            // Window should have a first responder
            #expect(window.firstResponder != nil)
            
            // Content view should exist
            #expect(window.contentView != nil)
            
            // Window should accept first responder
            #expect(window.acceptsFirstResponder)
        }
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testHotkeyTriggersProperActivation() async {
        let searchWindow = SearchWindowController.shared
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        
        // Simulate hotkey trigger
        WindowManager.shared.refreshWindows()
        searchWindow.toggle()
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify window is shown
        #expect(searchWindow.isVisible)
        
        // Verify proper activation
        #expect(NSApp.activationPolicy() == .regular)
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
}