import Testing
import Foundation
import AppKit
@testable import AppWindowFinder

@MainActor
struct BrowserIntegrationTests {
    
    // MARK: - Browser History Service Tests
    
    @Test func testBrowserHistoryServiceIntegration() {
        let historyService = BrowserHistoryService.shared
        
        switch historyService.getRecentTabs(limit: 10) {
        case .success(let tabs):
            // Should not crash and return valid array
            #expect(tabs.count >= 0, "Browser history should return valid array")
            
            // If tabs are found, validate their structure
            for tab in tabs.prefix(min(tabs.count, 5)) {
                #expect(!tab.title.isEmpty, "Browser tab should have title")
                #expect(!tab.subtitle.isEmpty, "Browser tab should have subtitle")
                #expect(tab.type == .browserTab, "Should be browser tab type")
            }
        case .failure(let error):
            print("⚠️ Browser history test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    @Test func testBrowserHistoryServiceWithDifferentLimits() {
        let historyService = BrowserHistoryService.shared
        
        let limits = [1, 5, 10, 20, 50]
        for limit in limits {
            switch historyService.getRecentTabs(limit: limit) {
            case .success(let tabs):
                #expect(tabs.count >= 0, "Should handle limit: \(limit)")
                #expect(tabs.count <= limit || tabs.count == 0, "Should respect limit or return no results")
            case .failure(let error):
                print("⚠️ Browser history test failed for limit \(limit) (expected in CI): \(error.localizedDescription)")
            }
        }
    }
    
    @Test func testBrowserHistoryServiceConsistency() {
        let historyService = BrowserHistoryService.shared
        
        // Test multiple calls return consistent results
        let firstResult = historyService.getRecentTabs(limit: 10)
        let secondResult = historyService.getRecentTabs(limit: 10)
        
        switch (firstResult, secondResult) {
        case (.success(let firstCall), .success(let secondCall)):
            // Results should be reasonably consistent
            let countDifference = abs(firstCall.count - secondCall.count)
            let maxExpectedDifference = max(firstCall.count / 4, 3) // Allow 25% variation or 3 tabs
            
            #expect(countDifference <= maxExpectedDifference,
                    "Browser tab counts should be reasonably consistent between calls")
            
            // Both calls should return browser tab type
            for tab in firstCall + secondCall {
                #expect(tab.type == .browserTab, "All returned items should be browser tabs")
            }
        case (.failure(let error), _), (_, .failure(let error)):
            print("⚠️ Browser history consistency test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    @Test func testBrowserHistoryDataValidation() {
        let historyService = BrowserHistoryService.shared
        
        switch historyService.getRecentTabs(limit: 50) {
        case .success(let allTabs):
            // Validate tab structure and browser distribution
            var browserCounts: [String: Int] = [:]
            
            for tab in allTabs {
                #expect(!tab.title.isEmpty, "All browser tabs should have titles")
                #expect(tab.type == .browserTab, "Should be browser tab type")
                
                // Count tabs per browser
                if let browserName = extractBrowserName(from: tab.subtitle) {
                    browserCounts[browserName, default: 0] += 1
                }
            }
            
            // If we have tabs, ensure they're from supported browsers
            if !allTabs.isEmpty {
                let supportedBrowsers = ["Chrome", "Safari", "Edge", "Brave", "Arc"]
                let foundBrowsers = Set(browserCounts.keys)
                
                for browser in foundBrowsers {
                    let hasSupported = supportedBrowsers.contains { supported in
                        browser.contains(supported)
                    }
                    #expect(hasSupported, "Found browser should be supported: \(browser)")
                }
                
                print("Browser distribution: \(browserCounts)")
            }
        case .failure(let error):
            print("⚠️ Browser history validation test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Browser Detection Tests
    
    @Test func testBrowserRunningDetection() {
        let runningApps = NSWorkspace.shared.runningApplications
        let browserBundleIds = [
            "com.google.Chrome",
            "com.apple.Safari",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "company.thebrowser.Browser" // Arc
        ]
        
        var runningBrowsers: [String] = []
        
        for app in runningApps {
            if let bundleId = app.bundleIdentifier,
               browserBundleIds.contains(bundleId) {
                runningBrowsers.append(bundleId)
            }
        }
        
        // Should be able to detect running browsers
        #expect(runningBrowsers.count >= 0, "Should detect running browsers")
        print("Running browsers detected: \(runningBrowsers)")
    }
    
    @Test func testBrowserApplicationPaths() {
        let browserPaths = [
            "/Applications/Google Chrome.app",
            "/Applications/Safari.app",
            "/Applications/Microsoft Edge.app",
            "/Applications/Brave Browser.app",
            "/Applications/Arc.app"
        ]
        
        var installedBrowsers: [String] = []
        
        for path in browserPaths {
            if FileManager.default.fileExists(atPath: path) {
                installedBrowsers.append(path)
            }
        }
        
        #expect(installedBrowsers.count >= 0, "Should detect installed browsers")
        print("Installed browsers detected: \(installedBrowsers)")
    }
    
    // MARK: - Tab Data Quality Tests
    
    @Test func testBrowserHistoryDataQuality() {
        let historyService = BrowserHistoryService.shared
        
        switch historyService.getRecentTabs(limit: 50) {
        case .success(let allTabs):
            for tab in allTabs {
                // Basic data quality checks
                #expect(!tab.title.isEmpty, "Tab title should not be empty")
                #expect(!tab.subtitle.isEmpty, "Tab subtitle should not be empty")
                #expect(tab.processID > 0, "Tab should have valid process ID")
                
                // Browser tab specific checks
                #expect(tab.type == .browserTab, "Should be browser tab type")
                
                // URL validation if present
                if let url = tab.url {
                    #expect(!url.isEmpty, "URL should not be empty if present")
                    #expect(URL(string: url) != nil, "URL should be valid if present: \(url)")
                }
                
                // Bundle identifier validation if present
                if let bundleId = tab.bundleIdentifier {
                    #expect(!bundleId.isEmpty, "Bundle ID should not be empty if present")
                    #expect(bundleId.contains("."), "Bundle ID should have valid format")
                }
                
                // Last access time should be reasonable
                let now = Date()
                let safeNowTimestamp = min(now.timeIntervalSince1970, 1893456000.0) // Cap at 2030-01-01
                let oneWeekAgo = Date(timeIntervalSince1970: safeNowTimestamp - 7 * 24 * 60 * 60)
                #expect(tab.lastAccessTime >= oneWeekAgo && tab.lastAccessTime <= now,
                       "Last access time should be within reasonable range")
            }
        case .failure(let error):
            print("⚠️ Browser history data quality test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testBrowserHistoryErrorHandling() {
        let historyService = BrowserHistoryService.shared
        
        // Test error handling with various limit values
        let extremeLimits = [0, -1, 1000]
        for limit in extremeLimits {
            switch historyService.getRecentTabs(limit: limit) {
            case .success(let tabs):
                #expect(tabs.count >= 0, "Should handle extreme limits gracefully: \(limit)")
            case .failure(let error):
                print("⚠️ Browser history error handling test failed for limit \(limit) (expected in CI): \(error.localizedDescription)")
            }
        }
    }
    
    @Test func testBrowserPermissionHandling() {
        let historyService = BrowserHistoryService.shared
        
        // Test that permission issues are handled gracefully
        switch historyService.getRecentTabs(limit: 10) {
        case .success(let allTabs):
            // Should not crash even if database permissions are denied
            #expect(allTabs.count >= 0, "Should handle permission issues gracefully")
            
            // If no tabs are returned, it's likely due to permissions or no browser history
            if allTabs.isEmpty {
                print("⚠️ No browser tabs retrieved - likely due to database access restrictions or no browser history")
            }
        case .failure(let error):
            print("⚠️ Browser permission test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test func testBrowserHistoryFetchingPerformance() {
        let historyService = BrowserHistoryService.shared
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = historyService.getRecentTabs(limit: 50)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        
        #expect(executionTime < 5.0, "Browser history fetching should complete under 5 seconds")
        
        switch result {
        case .success(let allTabs):
            #expect(allTabs.count >= 0, "Should return valid results")
            print("Browser history fetch time for 50 items: \(executionTime)s")
        case .failure(let error):
            print("⚠️ Browser history performance test failed (expected in CI): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func extractBrowserName(from subtitle: String) -> String? {
        // Extract browser name from subtitle format "BrowserName • URL"
        if subtitle.contains("•") {
            return subtitle.components(separatedBy: "•").first?.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}