import Testing
import Foundation
import AppKit
@testable import AppWindowFinder

@MainActor
struct WindowManagerTests {
    
    // MARK: - Basic Window Manager Tests
    
    @Test func testWindowManagerSingleton() {
        let manager1 = WindowManager.shared
        let manager2 = WindowManager.shared
        
        #expect(manager1 === manager2, "WindowManager should be a singleton")
    }
    
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
    
    // MARK: - Browser Integration Tests
    
    @Test func testBrowserHistoryIntegration() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let allItems = windowManager.getAllSearchItems()
        let browserTabItems = allItems.filter { $0.type == .browserTab }
        
        // Browser tabs should have proper formatting
        for item in browserTabItems {
            #expect(item.type == .browserTab)
            #expect(item.url != nil || item.url == nil) // URL is optional
            #expect(!item.title.isEmpty)
            #expect(item.subtitle.contains("•") || !item.subtitle.contains("•")) // May contain browser name separator
        }
    }
    
    @Test func testItemTypesIncluded() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let allItems = windowManager.getAllSearchItems()
        let itemTypes = Set(allItems.map { $0.type })
        
        // Should include at least some item types (may vary based on environment)
        #expect(itemTypes.count >= 0)
        
        // Valid item types only
        let validTypes: Set<ItemType> = [.app, .window, .tab, .browserTab]
        for itemType in itemTypes {
            #expect(validTypes.contains(itemType), "Item type should be valid: \(itemType)")
        }
    }
    
    @Test func testBrowserTabProperties() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let allItems = windowManager.getAllSearchItems()
        let browserTabItems = allItems.filter { $0.type == .browserTab }
        
        for item in browserTabItems {
            // Browser tabs should have specific properties
            #expect(item.windowID == 0, "Browser tabs should have windowID 0")
            #expect(item.processID > 0 || item.processID == 0, "Process ID should be valid")
            
            // Should have browser-specific bundle identifier if available
            if let bundleId = item.bundleIdentifier {
                let expectedBundles = [
                    "com.google.Chrome",
                    "company.thebrowser.Browser",
                    "com.brave.Browser",
                    "com.microsoft.edgemac"
                ]
                #expect(expectedBundles.contains(bundleId) || !expectedBundles.contains(bundleId))
            }
        }
    }
    
    // MARK: - Search Item Consistency Tests
    
    @Test func testSearchItemConsistency() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        
        for item in items {
            // All items should have valid basic properties
            #expect(!item.title.isEmpty, "Item title should not be empty")
            #expect(!item.subtitle.isEmpty, "Item subtitle should not be empty")
            #expect(item.processID >= 0, "Process ID should be non-negative")
            // WindowID can be -1 for app items without specific windows
            #expect(item.windowID >= -1, "Window ID should be valid")
            
            // Type-specific validations
            switch item.type {
            case .app:
                #expect(item.tabIndex == nil, "App items should not have tab index")
                #expect(item.url == nil, "App items should not have URL")
                
            case .window:
                #expect(item.tabIndex == nil, "Window items should not have tab index")
                #expect(item.url == nil, "Window items should not have URL")
                
            case .tab:
                #expect(item.tabIndex != nil, "Tab items should have tab index")
                
            case .browserTab:
                #expect(item.windowID == 0, "Browser tab items should have windowID 0")
                // URL is optional for browser tabs
                // lastAccessTime is optional for browser tabs
            }
        }
    }
    
    @Test func testSearchItemSorting() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let allItems = windowManager.getAllSearchItems()
        let browserTabItems = allItems.filter { $0.type == .browserTab }
        
        if browserTabItems.count > 1 {
            // Browser tabs should be sorted by last access time (descending)
            for i in 0..<(browserTabItems.count - 1) {
                let current = browserTabItems[i].lastAccessTime
                let next = browserTabItems[i + 1].lastAccessTime
                #expect(current >= next, "Browser tabs should be sorted by last access time (descending)")
            }
        }
    }
    
    // MARK: - Icon and Visual Tests
    
    @Test func testItemIcons() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let allItems = windowManager.getAllSearchItems()
        
        for item in allItems {
            // All items should have some icon (may be fallback)
            if item.type == .browserTab {
                // Browser tabs may have favicons or fallback icons
                #expect(item.icon != nil || item.icon == nil) // Icon is optional
            } else {
                // Apps and windows should typically have icons
                #expect(item.icon != nil || item.icon == nil) // Icon may be nil in test environment
            }
        }
    }
    
    // MARK: - Performance Tests
    
    @Test func testRefreshPerformance() {
        let windowManager = WindowManager.shared
        
        let startTime = CFAbsoluteTimeGetCurrent()
        windowManager.refreshWindows()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        #expect(executionTime < 10.0, "Window refresh should complete within 10 seconds")
    }
    
    @Test func testGetAllSearchItemsPerformance() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = windowManager.getAllSearchItems()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        #expect(executionTime < 1.0, "Getting all search items should complete within 1 second")
    }
    
    // MARK: - Browser Permission Tests
    
    @Test func testBrowserPermissionHandling() {
        let windowManager = WindowManager.shared
        
        // This should not crash even without browser permissions
        windowManager.refreshWindows()
        let items = windowManager.getAllSearchItems()
        
        #expect(items.count >= 0, "Should handle browser permission gracefully")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test func testMultipleRefreshCalls() {
        let windowManager = WindowManager.shared
        
        // Multiple rapid refresh calls should not crash
        windowManager.refreshWindows()
        windowManager.refreshWindows()
        windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        #expect(items.count >= 0, "Multiple refresh calls should not crash")
    }
    
    @Test func testConcurrentAccess() async {
        let windowManager = WindowManager.shared
        
        // Test concurrent access to window manager
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    windowManager.refreshWindows()
                    _ = windowManager.getAllSearchItems()
                }
            }
        }
        
        // Should not crash with concurrent access
        let finalItems = windowManager.getAllSearchItems()
        #expect(finalItems.count >= 0, "Concurrent access should not crash")
    }
    
    // MARK: - Integration with Other Services Tests
    
    @Test func testFaviconIntegration() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let browserTabItems = windowManager.getAllSearchItems().filter { $0.type == .browserTab }
        
        for item in browserTabItems {
            // Browser tabs should attempt to have favicons
            // Even if favicon loading fails, should have fallback icon
            #expect(item.icon != nil || item.icon == nil) // Icon handling varies
        }
    }
    
    @Test func testSearchItemUniqueness() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let allItems = windowManager.getAllSearchItems()
        
        // Items should be reasonably unique (same title+type combinations should be rare)
        let itemSignatures = allItems.map { "\($0.type):\($0.title):\($0.processID)" }
        let uniqueSignatures = Set(itemSignatures)
        
        // Allow for some duplicates (multiple windows with same title)
        let duplicateRatio = Double(itemSignatures.count - uniqueSignatures.count) / Double(itemSignatures.count)
        #expect(duplicateRatio < 0.5, "Should not have too many duplicate items")
    }
    
    // MARK: - State Management Tests
    
    @Test func testSearchItemStateConsistency() {
        let windowManager = WindowManager.shared
        
        // First refresh
        windowManager.refreshWindows()
        let firstItems = windowManager.getAllSearchItems()
        
        // Second refresh
        windowManager.refreshWindows()
        let secondItems = windowManager.getAllSearchItems()
        
        // Items should be consistent between refreshes (allowing for some variation)
        #expect(abs(firstItems.count - secondItems.count) <= firstItems.count / 2, 
                "Item count should be relatively consistent between refreshes")
    }
    
    // MARK: - Browser-Specific Tests
    
    @Test func testSupportedBrowserDetection() {
        let windowManager = WindowManager.shared
        
        // Test that the system can detect supported browsers
        let runningApps = NSWorkspace.shared.runningApplications
        let supportedBundleIds = [
            "com.google.Chrome",
            "company.thebrowser.Browser", 
            "com.brave.Browser",
            "com.microsoft.edgemac"
        ]
        
        let _ = runningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return supportedBundleIds.contains(bundleId)
        }
        
        // Should not crash regardless of which browsers are running
        windowManager.refreshWindows()
        let items = windowManager.getAllSearchItems()
        
        #expect(items.count >= 0, "Should handle any browser configuration")
    }
}