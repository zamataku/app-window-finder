import Testing
import AppKit
@testable import AppWindowFinder

@MainActor
struct WindowManagerUITests {
    
    @Test func testWindowDisplaysApplicationNameInsteadOfUntitled() {
        // Test that windows display application name when window title is "Untitled Window"
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        
        for item in items where item.type == .window {
            // No window should have "Untitled Window" as its title
            #expect(item.title != "Untitled Window")
            
            // Window title should be the application name for untitled windows
            if item.subtitle.contains("Untitled") {
                #expect(item.title == item.appName)
            }
        }
    }
    
    @Test func testWindowSubtitleShowsWindowContent() {
        // Test that window subtitle shows meaningful content about the window
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        
        for item in items where item.type == .window {
            // Subtitle should contain window-specific information
            #expect(!item.subtitle.isEmpty)
            
            // For windows with actual titles, subtitle should be the window title
            // For untitled windows, subtitle should be a descriptive text
            if item.title == item.appName {
                #expect(item.subtitle != item.appName || item.subtitle.contains("Untitled"))
            }
        }
    }
    
    @Test func testApplicationIconsAreAvailable() {
        // Test that application icons can be retrieved
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        
        for item in items {
            // Check if we can get an icon for the application
            if let app = NSRunningApplication(processIdentifier: item.processID) {
                let icon = app.icon
                #expect(icon != nil)
            }
        }
    }
    
    @Test func testBrowserTabsAreRetrieved() {
        // Test that browser tabs are properly retrieved for supported browsers
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        let supportedBrowsers = ["Safari", "Google Chrome", "Firefox", "Arc", "Brave Browser", "Microsoft Edge"]
        
        // Check if any browser tabs are found
        let browserItems = items.filter { supportedBrowsers.contains($0.appName) }
        let tabItems = items.filter { $0.type == .tab }
        
        // If we have browser windows, we should have at least some tabs
        if !browserItems.isEmpty {
            print("Found \(browserItems.count) browser windows")
            print("Found \(tabItems.count) tabs")
        }
        
        // Tabs should have proper formatting
        for tab in tabItems {
            #expect(!tab.title.isEmpty)
            #expect(tab.tabIndex != nil)
            #expect(supportedBrowsers.contains(tab.appName))
        }
    }
    
    @Test func testSearchItemIconProperty() {
        // Test the new icon property on SearchItem
        let item = SearchItem(
            title: "Test Window",
            subtitle: "Test content",
            type: .window,
            appName: "TestApp",
            windowID: 123,
            processID: 456,
            icon: nil
        )
        
        #expect(item.icon == nil)
        
        // Test with actual icon
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            let itemWithIcon = SearchItem(
                title: "Finder",
                subtitle: "Desktop",
                type: .window,
                appName: "Finder",
                windowID: 789,
                processID: app.processIdentifier,
                icon: app.icon
            )
            
            #expect(itemWithIcon.icon != nil)
        }
    }
}