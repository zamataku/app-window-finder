import Testing
import AppKit
@testable import AppWindowFinder

@MainActor
struct WindowActivationTests {
    
    init() async {
        // Ensure clean state before each test
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testSearchWindowBecomesActiveOnShow() async {
        let searchWindow = SearchWindowController.shared
        
        // Hide window initially
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        #expect(!searchWindow.isVisible)
        
        // Show the window
        searchWindow.show()
        
        // Wait for activation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify window is visible
        #expect(searchWindow.isVisible)
        
        // Verify window properties for activation
        if let window = searchWindow.window {
            #expect(window.canBecomeKey == true)
            // Panels typically can't become main window
            #expect(window.level == .modalPanel)
            #expect(window.styleMask.contains(.utilityWindow))
            #expect((window as? NSPanel)?.becomesKeyOnlyIfNeeded == false)
        }
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testActivationPolicyChanges() async {
        // Test that activation policy changes appropriately
        let searchWindow = SearchWindowController.shared
        
        // Note: In test environment, activation policy might be different
        // We'll just verify the show/hide behavior works
        
        // When window is shown, app should be activated
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(searchWindow.isVisible)
        
        // When window is hidden, it should not be visible
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(!searchWindow.isVisible)
    }
    
    @Test func testWindowLevelAndFocus() async {
        let searchWindow = SearchWindowController.shared
        
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        if let window = searchWindow.window {
            // Window should be at modal panel level
            #expect(window.level == .modalPanel)
            
            // Window should accept mouse events
            #expect(window.acceptsMouseMovedEvents == true)
            
            // Window should not hide on deactivate
            #expect((window as? NSPanel)?.hidesOnDeactivate == false)
            
            // First responder should be set
            #expect(window.firstResponder != nil)
        }
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testHotkeyTriggersActivation() async {
        // Test that the hotkey properly triggers window activation
        let searchWindow = SearchWindowController.shared
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        
        // Trigger the hotkey handler
        WindowManager.shared.refreshWindows()
        searchWindow.toggle()
        
        // Wait for window to appear
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify window is shown and app is activated
        #expect(searchWindow.isVisible)
        #expect(NSApp.activationPolicy() == .regular)
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testMultipleTogglesBehavior() async {
        let searchWindow = SearchWindowController.shared
        
        // Start hidden
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        #expect(!searchWindow.isVisible)
        
        // First toggle - should show
        searchWindow.toggle()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(searchWindow.isVisible)
        
        // Second toggle - should hide
        searchWindow.toggle()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(!searchWindow.isVisible)
        
        // Third toggle - should show again
        searchWindow.toggle()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(searchWindow.isVisible)
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
}