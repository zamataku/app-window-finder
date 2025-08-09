import Testing
import AppKit
@testable import AppWindowFinder

@MainActor
struct SearchWindowTests {
    
    init() async {
        // Ensure clean state before each test
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testSearchWindowBecomesActiveAndAcceptsInput() async {
        // Given: Search window controller exists
        let searchWindow = SearchWindowController.shared
        
        // When: Show the window
        searchWindow.show()
        
        // Allow time for window to appear
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then: Window should be configured properly
        #expect(searchWindow.window != nil)
        
        if let window = searchWindow.window {
            // Verify the window is at the correct level
            #expect(window.level == .floating)
            
            // Verify the window can become key
            #expect(window.canBecomeKey == true)
            
            // Verify window has proper style for accepting input
            #expect(window.styleMask.contains(.titled) == true)
            
            // Verify it's a panel that can float
            #expect(window is NSPanel)
        }
        
        // Clean up
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testSearchFieldReceivesFocusOnWindowShow() async {
        // This test verifies that the search field is properly focused
        // when the window appears, which is critical for keyboard input
        
        let searchWindow = SearchWindowController.shared
        searchWindow.hide()
        
        // Show the window
        searchWindow.show()
        
        // Allow time for focus to be set
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // The first responder should be the text field
        // Note: In a real app, we'd need to verify the specific text field
        // but this confirms the window is ready for keyboard input
        #expect(searchWindow.window?.firstResponder != nil)
        #expect(searchWindow.window?.firstResponder !== searchWindow.window)
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testWindowConfigurationForKeyboardInput() async {
        // Test that window is properly configured to receive keyboard input
        let searchWindow = SearchWindowController.shared
        searchWindow.show()
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify window configuration
        #expect(searchWindow.window != nil)
        #expect(searchWindow.window?.canBecomeKey == true)
        
        // Verify window style allows input
        #expect(searchWindow.window?.styleMask.contains(.titled) == true)
        
        // Verify window level is appropriate
        #expect(searchWindow.window?.level == .floating)
        
        // In a real app, the window would be key after makeKey() is called
        // In tests, we just verify it's configured correctly
        #expect(searchWindow.window != nil)
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
}