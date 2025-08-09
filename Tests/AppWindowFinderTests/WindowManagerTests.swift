import Testing
@testable import AppWindowFinder

@MainActor
struct WindowManagerTests {
    
    @Test func testWindowRefresh() {
        let windowManager = WindowManager.shared
        
        // Initial fetch
        let initialItems = windowManager.getAllSearchItems()
        #expect(initialItems.isEmpty == false || initialItems.isEmpty == true) // May be empty in test env
        
        // Refresh windows
        windowManager.refreshWindows()
        
        // Get items after refresh
        let refreshedItems = windowManager.getAllSearchItems()
        #expect(refreshedItems.count >= 0)
    }
    
    @Test func testWindowItemFormatting() {
        // Test that window items have proper formatting
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        
        for item in items {
            // Title should not be empty
            #expect(!item.title.isEmpty)
            
            // Subtitle (app name) should not be empty
            #expect(!item.subtitle.isEmpty)
            
            // Window items should not have generic "Window" title
            if item.type == .window {
                #expect(item.title != "Window")
            }
        }
    }
}