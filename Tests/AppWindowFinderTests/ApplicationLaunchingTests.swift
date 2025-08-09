import Testing
import AppKit
@testable import AppWindowFinder

@MainActor
struct ApplicationLaunchingTests {
    
    @Test func testApplicationItemCreation() {
        let item = SearchItem(
            title: "Safari",
            subtitle: "Web Browser",
            type: .app,
            appName: "Safari",
            windowID: -1,  // Special value for apps
            tabIndex: nil,
            processID: 0,  // Not running
            icon: nil
        )
        
        #expect(item.title == "Safari")
        #expect(item.subtitle == "Web Browser")
        #expect(item.type == .app)
        #expect(item.windowID == -1)
        #expect(item.processID == 0)
    }
    
    @Test func testApplicationListing() {
        // Test that we can list applications from /Applications
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        let appItems = items.filter { $0.type == .app }
        
        // Should find at least some apps (system apps)
        #expect(appItems.count > 0)
        
        // Check that app items have proper structure
        for app in appItems {
            #expect(!app.title.isEmpty)
            #expect(app.windowID == -1)
            #expect(app.processID == 0)
            #expect(app.type == .app)
        }
    }
    
    @Test func testApplicationSearchPriority() {
        // Test that running windows appear before applications
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        
        // Find the first app item and first window item indices
        var firstAppIndex = -1
        var lastWindowIndex = -1
        
        for (index, item) in items.enumerated() {
            if item.type == .window || item.type == .tab {
                lastWindowIndex = index
            } else if item.type == .app && firstAppIndex == -1 {
                firstAppIndex = index
            }
        }
        
        // If both types exist, windows should come before apps
        if firstAppIndex != -1 && lastWindowIndex != -1 {
            #expect(lastWindowIndex < firstAppIndex)
        }
    }
    
    @Test func testApplicationDeduplication() {
        // Test that running applications don't appear in the app list
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        
        // Get running app names
        let runningAppNames = Set(items.filter { $0.type == .window }.map { $0.appName })
        
        // Check that app items don't include running apps
        let appItems = items.filter { $0.type == .app }
        for app in appItems {
            #expect(!runningAppNames.contains(app.appName))
        }
    }
    
    @Test func testApplicationActivation() {
        // Test that app items can be activated
        let testApp = SearchItem(
            title: "TextEdit",
            subtitle: "Text Editor",
            type: .app,
            appName: "TextEdit",
            windowID: -1,
            tabIndex: nil,
            processID: 0,
            icon: nil
        )
        
        // This test verifies the structure is correct
        // Actual launching would require integration testing
        #expect(testApp.type == .app)
        #expect(testApp.windowID == -1)
    }
    
    @Test func testApplicationIcon() {
        // Test that applications have icons
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        let appItems = items.filter { $0.type == .app }
        
        // At least some apps should have icons
        let appsWithIcons = appItems.filter { $0.icon != nil }
        #expect(appsWithIcons.count > 0)
    }
}