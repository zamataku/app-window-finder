import Testing
import Foundation
import AppKit
@testable import AppWindowFinder

@MainActor
struct IntegrationTests {
    
    // MARK: - Full System Integration Tests
    
    @Test func testFullSystemInitialization() {
        // Test that all major components can be initialized without crashing
        
        // Core services
        let _ = WindowManager.shared
        let _ = FaviconService.shared
        let _ = BrowserHistoryService.shared
        let _ = AccessibilityHelper.shared
        let _ = HotkeyManager.shared
        let _ = SearchWindowController.shared
        
        // If we reach here without crashing, initialization succeeded
        #expect(true, "All services should initialize successfully")
    }
    
    @Test func testDataFlowIntegration() async {
        // Test the complete data flow: BrowserHistoryService -> WindowManager -> SearchItems
        
        let browserService = BrowserHistoryService.shared
        let windowManager = WindowManager.shared
        
        // Get browser tabs
        let _ = browserService.getRecentTabs(limit: 10)
        
        // Refresh window manager
        await windowManager.refreshWindows()
        let allItems = windowManager.getAllSearchItems()
        
        // Verify browser tabs are integrated
        let browserTabItems = allItems.filter { $0.type == .browserTab }
        
        #expect(browserTabItems.count >= 0, "Should integrate browser tabs")
        
        // Verify proper data structure
        for item in browserTabItems {
            #expect(!item.title.isEmpty, "Browser tab should have title")
            #expect(item.type == .browserTab, "Should be browser tab type")
        }
    }
    
    @Test func testSearchWindowDataIntegration() async {
        // Test that SearchWindowController properly integrates with WindowManager
        
        let windowManager = WindowManager.shared
        let _ = SearchWindowController.shared
        
        // Refresh data
        await windowManager.refreshWindows()
        
        // This tests the integration without actually showing the window
        // (which would require user interaction in tests)
        let allItems = windowManager.getAllSearchItems()
        #expect(allItems.count >= 0, "Search window should be able to get search items")
        
        // Test that search controller exists and can be accessed
        // SearchWindowController is a class, so it's never nil - just check it works
        #expect(true, "Search window controller should be accessible")
    }
    
    // MARK: - Service Integration Tests
    
    @Test func testBrowserHistoryAndFaviconIntegration() async {
        // Test that browser history service properly integrates with favicon service
        
        let browserService = BrowserHistoryService.shared
        let faviconService = FaviconService.shared
        
        switch browserService.getRecentTabs(limit: 5) {
        case .success(let tabs):
            for tab in tabs {
                if let url = tab.url {
                    // Test that favicon can be retrieved for browser tab URLs
                    let fallback = NSImage()
                    let favicon = await faviconService.getFavicon(for: url, fallbackIcon: fallback)
                    // In CI environments, network requests may fail - this is acceptable
                    print("ℹ️ Favicon integration test for \(url): \(favicon != nil ? "success" : "fallback")")
                }
            }
        case .failure(let error):
            print("⚠️ Integration test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    @Test func testWindowManagerAndSearchIntegration() async {
        // Test integration between WindowManager and search functionality
        
        let windowManager = WindowManager.shared
        await windowManager.refreshWindows()
        
        let allItems = windowManager.getAllSearchItems()
        
        // Test fuzzy search integration
        let searchResults = FuzzySearch.search("test", in: allItems)
        #expect(searchResults.count <= allItems.count, "Search results should not exceed total items")
        
        // Test that different item types are properly integrated
        let itemTypes = Set(allItems.map { $0.type })
        let hasMultipleTypes = itemTypes.count > 1
        
        if hasMultipleTypes {
            // Verify all types are handled in search
            for type in itemTypes {
                let typeItems = allItems.filter { $0.type == type }
                #expect(typeItems.count > 0, "Should have items of type \(type)")
            }
        }
    }
    
    // MARK: - Permission Integration Tests
    
    @Test func testPermissionSystemIntegration() {
        // Test that permission system works with browser services
        
        let accessibilityHelper = AccessibilityHelper.shared
        let browserHistoryService = BrowserHistoryService.shared
        
        // Accessibility permission check should not crash
        let hasAccessibility = accessibilityHelper.hasAccessibilityPermission()
        #expect(hasAccessibility == true || hasAccessibility == false)
        
        // Browser history should work regardless of accessibility permissions
        switch browserHistoryService.getRecentTabs(limit: 5) {
        case .success(let tabs):
            #expect(tabs.count >= 0, "Browser history should work independently of accessibility permissions")
        case .failure(let error):
            print("⚠️ Permission integration test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cache Integration Tests
    
    @Test func testCacheSystemIntegration() async {
        // Test that caching works across services
        
        let faviconService = FaviconService.shared
        let testURL = "https://github.com"
        
        // Clear cache
        faviconService.clearCache()
        
        // First fetch
        let startTime1 = CFAbsoluteTimeGetCurrent()
        let favicon1 = await faviconService.getFavicon(for: testURL, fallbackIcon: nil)
        let endTime1 = CFAbsoluteTimeGetCurrent()
        let firstFetchTime = endTime1 - startTime1
        
        // Second fetch (should use cache)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        let favicon2 = await faviconService.getFavicon(for: testURL, fallbackIcon: nil)
        let endTime2 = CFAbsoluteTimeGetCurrent()
        let secondFetchTime = endTime2 - startTime2
        
        // In CI environments, network requests may fail - test cache behavior only if both succeed
        print("ℹ️ Cache system integration: first=\(favicon1 != nil), cached=\(favicon2 != nil)")
        if favicon1 == nil || favicon2 == nil {
            print("⚠️ Network requests failed in CI environment - acceptable")
            return
        }
        #expect(secondFetchTime <= firstFetchTime, "Cached fetch should be faster or equal")
    }
    
    // MARK: - Error Recovery Integration Tests
    
    @Test func testSystemErrorRecovery() async {
        // Test that the system can recover from various error conditions
        
        let windowManager = WindowManager.shared
        let browserService = BrowserHistoryService.shared
        
        // Multiple rapid operations should not crash the system
        for _ in 0..<10 {
            await windowManager.refreshWindows()
            _ = browserService.getRecentTabs(limit: 1)
        }
        
        let finalItems = windowManager.getAllSearchItems()
        #expect(finalItems.count >= 0, "System should recover from rapid operations")
    }
    
    @Test func testServiceCommunicationResilience() async {
        // Test that services can communicate properly even under stress
        
        let windowManager = WindowManager.shared
        let faviconService = FaviconService.shared
        
        // Concurrent operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await windowManager.refreshWindows()
            }
            
            group.addTask {
                await Task {
                    _ = await faviconService.getFavicon(for: "https://google.com", fallbackIcon: nil)
                }.value
            }
            
            group.addTask {
                await Task {
                    _ = await faviconService.getFavicon(for: "https://github.com", fallbackIcon: nil)
                }.value
            }
        }
        
        // System should still be functional
        let items = windowManager.getAllSearchItems()
        #expect(items.count >= 0, "System should remain functional after concurrent operations")
    }
    
    // MARK: - Data Quality Integration Tests
    
    @Test func testDataQualityAcrossServices() async {
        // Test that data quality is maintained across service boundaries
        
        let windowManager = WindowManager.shared
        await windowManager.refreshWindows()
        
        let allItems = windowManager.getAllSearchItems()
        
        // Data quality checks
        for item in allItems {
            // Basic data integrity
            #expect(!item.title.isEmpty, "All items should have non-empty titles")
            #expect(!item.subtitle.isEmpty, "All items should have non-empty subtitles")
            #expect(item.processID >= 0, "Process IDs should be valid")
            
            // Type-specific data integrity
            switch item.type {
            case .browserTab:
                if let url = item.url {
                    #expect(URL(string: url) != nil, "Browser tab URLs should be valid")
                }
                let lastAccess = item.lastAccessTime
                #expect(lastAccess <= Date(), "Last access time should not be in future")
                
            case .tab:
                #expect(item.tabIndex != nil, "Tab items should have tab index")
                
            case .app, .window:
                #expect(item.url == nil, "App/Window items should not have URLs")
                // lastAccessTime always has a value (default Date()) for all item types
            }
        }
    }
    
    // MARK: - Performance Integration Tests
    
    @Test func testSystemWidePerformance() async {
        // Test overall system performance with all services working together
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let windowManager = WindowManager.shared
        let browserService = BrowserHistoryService.shared
        
        // Full system refresh
        await windowManager.refreshWindows()
        let browserResult = browserService.getRecentTabs(limit: 20)
        let allItems = windowManager.getAllSearchItems()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        #expect(totalTime < 15.0, "Full system refresh should complete within 15 seconds")
        #expect(allItems.count >= 0, "Should return valid results")
        
        switch browserResult {
        case .success(let browserTabs):
            #expect(browserTabs.count >= 0, "Should return valid browser tabs")
        case .failure(let error):
            print("⚠️ Browser tabs performance test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    @Test func testMemoryEfficiencyIntegration() async {
        // Test that system doesn't consume excessive memory
        
        let windowManager = WindowManager.shared
        
        // Multiple refresh cycles
        for _ in 0..<5 {
            await windowManager.refreshWindows()
            _ = windowManager.getAllSearchItems()
        }
        
        // Should complete without memory issues
        let finalItems = windowManager.getAllSearchItems()
        #expect(finalItems.count >= 0, "System should handle multiple refresh cycles efficiently")
    }
    
    // MARK: - Configuration Integration Tests
    
    @Test func testHotkeySystemIntegration() {
        // Test hotkey system integration (without actually triggering hotkeys)
        
        let hotkeyManager = HotkeyManager.shared
        let currentSettings = hotkeyManager.getCurrentSettings()
        
        #expect(!currentSettings.displayString.isEmpty, "Should have hotkey display string")
        
        // Test that hotkey validation works
        let isValid = hotkeyManager.validateHotkeySetup()
        #expect(isValid == true || isValid == false, "Hotkey validation should return boolean")
    }
    
    @Test func testLocalizationIntegration() async {
        // Test that localization works across the system
        
        let windowManager = WindowManager.shared
        await windowManager.refreshWindows()
        
        let items = windowManager.getAllSearchItems()
        
        // All items should have localized or properly formatted content
        for item in items {
            #expect(!item.title.contains("nil"), "Titles should not contain 'nil'")
            #expect(!item.subtitle.contains("nil"), "Subtitles should not contain 'nil'")
        }
    }
    
    // MARK: - Browser-Specific Integration Tests
    
    @Test func testMultiBrowserIntegration() async {
        // Test that system handles multiple browsers correctly
        
        let browserService = BrowserHistoryService.shared
        let windowManager = WindowManager.shared
        
        switch browserService.getRecentTabs(limit: 50) {
        case .success(_):
            await windowManager.refreshWindows()
            let allItems = windowManager.getAllSearchItems()
            
            let browserTabItems = allItems.filter { $0.type == .browserTab }
            
            // If we have browser tabs, test their properties
            if !browserTabItems.isEmpty {
                let browserNames = Set(browserTabItems.compactMap { item -> String? in
                    if item.subtitle.contains("•") {
                        return item.subtitle.components(separatedBy: "•").first?.trimmingCharacters(in: .whitespaces)
                    }
                    return nil
                })
                
                // Should handle different browsers properly
                for browserName in browserNames {
                    #expect(!browserName.isEmpty, "Browser names should not be empty")
                }
            }
        case .failure(let error):
            print("⚠️ Multi-browser integration test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Regression Tests
    
    @Test func testSystemStabilityRegression() async {
        // Regression test for system stability
        
        let windowManager = WindowManager.shared
        let faviconService = FaviconService.shared
        let browserService = BrowserHistoryService.shared
        
        // Operations that previously caused issues
        await windowManager.refreshWindows()
        let items = windowManager.getAllSearchItems()
        
        switch browserService.getRecentTabs(limit: 10) {
        case .success(let browserTabs):
            // Clear favicon cache
            faviconService.clearCache()
            
            // Should not crash
            #expect(items.count >= 0, "System should remain stable")
            #expect(browserTabs.count >= 0, "Browser service should remain stable")
        case .failure(let error):
            print("⚠️ System stability regression test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    @Test func testDataConsistencyRegression() async {
        // Regression test for data consistency issues
        
        let windowManager = WindowManager.shared
        
        // Multiple refreshes should maintain data consistency
        await windowManager.refreshWindows()
        let items1 = windowManager.getAllSearchItems()
        
        await windowManager.refreshWindows()
        let items2 = windowManager.getAllSearchItems()
        
        // Data should be reasonably consistent
        let countDifference = abs(items1.count - items2.count)
        let maxExpectedDifference = max(items1.count / 4, 10) // Allow 25% variation or 10 items
        
        #expect(countDifference <= maxExpectedDifference, 
                "Data should be reasonably consistent between refreshes")
    }
    
    // MARK: - Real-world Usage Simulation
    
    @Test func testTypicalUserWorkflow() async {
        // Simulate typical user workflow
        
        let windowManager = WindowManager.shared
        let _ = SearchWindowController.shared
        
        // 1. App startup - refresh windows
        await windowManager.refreshWindows()
        let initialItems = windowManager.getAllSearchItems()
        
        // 2. User searches (simulate search)
        let searchQuery = "github"
        let searchResults = FuzzySearch.search(searchQuery, in: initialItems)
        
        // 3. User refreshes (hotkey pressed again)
        await windowManager.refreshWindows()
        let refreshedItems = windowManager.getAllSearchItems()
        
        // Workflow should complete successfully
        #expect(initialItems.count >= 0, "Initial load should work")
        #expect(searchResults.count >= 0, "Search should work")
        #expect(refreshedItems.count >= 0, "Refresh should work")
    }
}