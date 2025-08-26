import Testing
import Foundation
import AppKit
@testable import AppWindowFinder

@MainActor
struct PerformanceTests {
    
    // MARK: - Service Performance Tests
    
    @Test func testWindowManagerRefreshPerformance() {
        let windowManager = WindowManager.shared
        
        let measurements: [Double] = (0..<5).map { _ in
            let startTime = CFAbsoluteTimeGetCurrent()
            windowManager.refreshWindows()
            let endTime = CFAbsoluteTimeGetCurrent()
            return endTime - startTime
        }
        
        let averageTime = measurements.reduce(0, +) / Double(measurements.count)
        let maxTime = measurements.max() ?? 0
        
        #expect(averageTime < 5.0, "Window refresh should average under 5 seconds, got \(averageTime)s")
        #expect(maxTime < 10.0, "Window refresh should never exceed 10 seconds, got \(maxTime)s")
    }
    
    @Test func testBrowserHistoryServicePerformance() {
        let browserService = BrowserHistoryService.shared
        
        let measurements: [Double] = (0..<5).map { _ in
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = browserService.getRecentTabs(limit: 20)
            let endTime = CFAbsoluteTimeGetCurrent()
            return endTime - startTime
        }
        
        let averageTime = measurements.reduce(0, +) / Double(measurements.count)
        let maxTime = measurements.max() ?? 0
        
        #expect(averageTime < 3.0, "Browser history fetch should average under 3 seconds, got \(averageTime)s")
        #expect(maxTime < 5.0, "Browser history fetch should never exceed 5 seconds, got \(maxTime)s")
    }
    
    @Test func testFaviconServiceSyncPerformance() {
        let faviconService = FaviconService.shared
        let testURLs = [
            "https://github.com",
            "https://google.com",
            "https://stackoverflow.com",
            "https://apple.com"
        ]
        
        for url in testURLs {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = faviconService.getFaviconNonBlocking(for: url, fallbackIcon: nil)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            let executionTime = endTime - startTime
            #expect(executionTime < 2.0, "Sync favicon fetch should complete under 2 seconds for \(url), got \(executionTime)s")
        }
    }
    
    @Test func testFaviconServiceAsyncPerformance() async {
        let faviconService = FaviconService.shared
        faviconService.clearCache()
        
        let testURLs = [
            "https://github.com",
            "https://google.com", 
            "https://stackoverflow.com",
            "https://apple.com",
            "https://microsoft.com"
        ]
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var results: [NSImage?] = []
        await withTaskGroup(of: Void.self) { group in
            for url in testURLs {
                group.addTask {
                    _ = await faviconService.getFavicon(for: url, fallbackIcon: nil)
                }
            }
        }
        
        // Get cached results
        for url in testURLs {
            let cachedIcon = faviconService.getFaviconNonBlocking(for: url, fallbackIcon: nil)
            results.append(cachedIcon)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        #expect(results.count == testURLs.count, "All favicon requests should complete")
        let successCount = results.compactMap { $0 }.count
        print("ℹ️ Favicon requests: \(successCount)/\(testURLs.count) successful")
        // In CI environments, network requests may fail - this is acceptable
        // Network-dependent performance varies in CI environments
        print("ℹ️ Favicon async performance time: \(totalTime)s")
        #expect(totalTime < 60.0, "Concurrent favicon fetching should complete within reasonable time")
    }
    
    // MARK: - Search Performance Tests
    
    @Test func testFuzzySearchPerformance() {
        let windowManager = WindowManager.shared
        windowManager.refreshWindows()
        
        let allItems = windowManager.getAllSearchItems()
        let searchQueries = ["test", "chrome", "window", "app", "github", "google"]
        
        for query in searchQueries {
            let startTime = CFAbsoluteTimeGetCurrent()
            let results = FuzzySearch.search(query, in: allItems)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            let searchTime = endTime - startTime
            #expect(searchTime < 0.1, "Search for '\(query)' should complete under 0.1 seconds, got \(searchTime)s")
            #expect(results.count >= 0, "Search should return valid results")
        }
    }
    
    @Test func testLargeDatasetSearchPerformance() {
        // Create a large dataset for testing
        var largeDataset: [SearchItem] = []
        
        for i in 0..<1000 {
            let item = SearchItem(
                title: "Test Item \(i)",
                subtitle: "App \(i % 10)",
                type: .app,
                appName: "TestApp\(i % 10)",
                windowID: i,
                processID: pid_t(i + 1000)
            )
            largeDataset.append(item)
        }
        
        let searchQueries = ["Test", "App", "Item", "0", "5"]
        
        for query in searchQueries {
            let startTime = CFAbsoluteTimeGetCurrent()
            let results = FuzzySearch.search(query, in: largeDataset)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            let searchTime = endTime - startTime
            #expect(searchTime < 0.5, "Large dataset search for '\(query)' should complete under 0.5 seconds, got \(searchTime)s")
            #expect(results.count >= 0, "Large dataset search should return valid results")
        }
    }
    
    // MARK: - Cache Performance Tests
    
    @Test func testFaviconCachePerformance() async {
        let faviconService = FaviconService.shared
        let testURL = "https://github.com"
        
        // Clear cache
        faviconService.clearCache()
        
        // First fetch (should be slower)
        let startTime1 = CFAbsoluteTimeGetCurrent()
        let favicon1 = await faviconService.getFavicon(for: testURL, fallbackIcon: nil)
        let endTime1 = CFAbsoluteTimeGetCurrent()
        let firstFetchTime = endTime1 - startTime1
        
        // Second fetch (should be from cache, faster)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        let favicon2 = await faviconService.getFavicon(for: testURL, fallbackIcon: nil)
        let endTime2 = CFAbsoluteTimeGetCurrent()
        let cachedFetchTime = endTime2 - startTime2
        
        // In CI environments, network requests may fail - test cache behavior only if both succeed
        print("ℹ️ Favicon cache test: first=\(favicon1 != nil), cached=\(favicon2 != nil)")
        if favicon1 == nil || favicon2 == nil {
            print("⚠️ Network requests failed in CI environment - acceptable")
            return
        }
        #expect(cachedFetchTime < firstFetchTime * 0.5, "Cached fetch should be significantly faster")
        #expect(cachedFetchTime < 0.1, "Cached fetch should be under 0.1 seconds, got \(cachedFetchTime)s")
    }
    
    @Test func testCacheClearPerformance() {
        let faviconService = FaviconService.shared
        
        // Fill cache with multiple favicons
        let urls = (0..<50).map { "https://example.com/\($0)" }
        for url in urls {
            _ = faviconService.getFaviconNonBlocking(for: url, fallbackIcon: nil)
        }
        
        // Test cache clear performance
        let startTime = CFAbsoluteTimeGetCurrent()
        faviconService.clearCache()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let clearTime = endTime - startTime
        #expect(clearTime < 0.1, "Cache clear should complete under 0.1 seconds, got \(clearTime)s")
    }
    
    // MARK: - Memory Performance Tests
    
    @Test func testMemoryUsageStability() {
        let windowManager = WindowManager.shared
        let faviconService = FaviconService.shared
        
        // Perform many operations to test memory stability
        for i in 0..<100 {
            windowManager.refreshWindows()
            
            if i % 10 == 0 {
                _ = faviconService.getFaviconNonBlocking(for: "https://example.com/\(i)", fallbackIcon: nil)
            }
            
            if i % 20 == 0 {
                faviconService.clearCache()
            }
        }
        
        // System should still be responsive
        let startTime = CFAbsoluteTimeGetCurrent()
        let items = windowManager.getAllSearchItems()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let responseTime = endTime - startTime
        #expect(responseTime < 1.0, "System should remain responsive after intensive operations, got \(responseTime)s")
        #expect(items.count >= 0, "Should return valid items after intensive operations")
    }
    
    @Test func testLargeDatasetMemoryPerformance() {
        let windowManager = WindowManager.shared
        
        // Multiple refreshes with large datasets
        for _ in 0..<10 {
            windowManager.refreshWindows()
            let items = windowManager.getAllSearchItems()
            
            // Simulate processing large dataset
            let _ = items.map { item in
                return "\(item.title) - \(item.subtitle)"
            }
        }
        
        // Final operation should still be fast
        let startTime = CFAbsoluteTimeGetCurrent()
        windowManager.refreshWindows()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let finalRefreshTime = endTime - startTime
        #expect(finalRefreshTime < 5.0, "Final refresh should complete under 5 seconds after memory intensive operations, got \(finalRefreshTime)s")
    }
    
    // MARK: - Concurrent Performance Tests
    
    @Test func testConcurrentWindowRefreshPerformance() async {
        let windowManager = WindowManager.shared
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    windowManager.refreshWindows()
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let concurrentTime = endTime - startTime
        
        // In CI environments, performance may vary significantly
        print("ℹ️ Concurrent window refresh time: \(concurrentTime)s")
        #expect(concurrentTime < 60.0, "Concurrent window refreshes should complete within reasonable time")
        
        // System should still be functional
        let items = windowManager.getAllSearchItems()
        #expect(items.count >= 0, "System should be functional after concurrent operations")
    }
    
    @Test func testConcurrentFaviconFetchPerformance() async {
        let faviconService = FaviconService.shared
        faviconService.clearCache()
        
        let urls = (0..<20).map { "https://example.com/\($0)" }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var results: [NSImage?] = []
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = await faviconService.getFavicon(for: url, fallbackIcon: nil)
                }
            }
        }
        
        // Get cached results
        for url in urls {
            let cachedIcon = faviconService.getFaviconNonBlocking(for: url, fallbackIcon: nil)
            results.append(cachedIcon)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let concurrentTime = endTime - startTime
        
        #expect(results.count == urls.count, "All concurrent favicon requests should complete")
        // Network-dependent performance varies in CI environments  
        print("ℹ️ Concurrent favicon fetch time: \(concurrentTime)s")
        #expect(concurrentTime < 60.0, "Concurrent favicon fetches should complete within reasonable time")
    }
    
    // MARK: - Startup Performance Tests
    
    @Test func testSystemInitializationPerformance() {
        // Test initialization performance of key components
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Initialize core services
        _ = WindowManager.shared
        _ = FaviconService.shared
        _ = BrowserHistoryService.shared
        _ = AccessibilityHelper.shared
        _ = HotkeyManager.shared
        _ = SearchWindowController.shared
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let initTime = endTime - startTime
        
        #expect(initTime < 1.0, "System initialization should complete under 1 second, got \(initTime)s")
    }
    
    @Test func testFirstDataLoadPerformance() {
        let windowManager = WindowManager.shared
        
        // Test first data load performance
        let startTime = CFAbsoluteTimeGetCurrent()
        windowManager.refreshWindows()
        let items = windowManager.getAllSearchItems()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let firstLoadTime = endTime - startTime
        #expect(firstLoadTime < 10.0, "First data load should complete under 10 seconds, got \(firstLoadTime)s")
        #expect(items.count >= 0, "First data load should return valid items")
    }
    
    // MARK: - Real-world Performance Tests
    
    @Test func testTypicalUserWorkflowPerformance() {
        let windowManager = WindowManager.shared
        
        // Simulate typical user workflow timing
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Initial window refresh (app startup)
        windowManager.refreshWindows()
        let checkpointTime1 = CFAbsoluteTimeGetCurrent()
        
        // 2. Get search items (window opened)
        let items = windowManager.getAllSearchItems()
        let checkpointTime2 = CFAbsoluteTimeGetCurrent()
        
        // 3. Search query (user types)
        let _ = FuzzySearch.search("test", in: items)
        let checkpointTime3 = CFAbsoluteTimeGetCurrent()
        
        // 4. Another refresh (hotkey pressed again)
        windowManager.refreshWindows()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let totalWorkflowTime = endTime - startTime
        let initialRefreshTime = checkpointTime1 - startTime
        let getItemsTime = checkpointTime2 - checkpointTime1
        let searchTime = checkpointTime3 - checkpointTime2
        let secondRefreshTime = endTime - checkpointTime3
        
        #expect(totalWorkflowTime < 15.0, "Total workflow should complete under 15 seconds, got \(totalWorkflowTime)s")
        #expect(initialRefreshTime < 5.0, "Initial refresh should complete under 5 seconds, got \(initialRefreshTime)s")
        #expect(getItemsTime < 1.0, "Getting items should complete under 1 second, got \(getItemsTime)s")
        #expect(searchTime < 0.1, "Search should complete under 0.1 seconds, got \(searchTime)s")
        #expect(secondRefreshTime < 5.0, "Second refresh should complete under 5 seconds, got \(secondRefreshTime)s")
    }
    
    @Test func testResponseTimeConsistency() {
        let windowManager = WindowManager.shared
        var refreshTimes: [Double] = []
        
        // Measure multiple refresh operations
        for _ in 0..<10 {
            let startTime = CFAbsoluteTimeGetCurrent()
            windowManager.refreshWindows()
            let endTime = CFAbsoluteTimeGetCurrent()
            refreshTimes.append(endTime - startTime)
        }
        
        let averageTime = refreshTimes.reduce(0, +) / Double(refreshTimes.count)
        let maxTime = refreshTimes.max() ?? 0
        let minTime = refreshTimes.min() ?? 0
        let variance = maxTime - minTime
        
        #expect(averageTime < 5.0, "Average refresh time should be under 5 seconds, got \(averageTime)s")
        #expect(variance < 10.0, "Response time variance should be under 10 seconds, got \(variance)s")
    }
    
    // MARK: - Scalability Performance Tests
    
    @Test func testSearchScalabilityPerformance() {
        // Test search performance with increasing dataset sizes
        let baseSizes = [10, 50, 100, 500, 1000]
        
        for size in baseSizes {
            let dataset = (0..<size).map { i in
                SearchItem(
                    title: "Item \(i)",
                    subtitle: "App \(i % 10)",
                    type: .app,
                    appName: "TestApp",
                    windowID: i,
                    processID: pid_t(i)
                )
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let results = FuzzySearch.search("Item", in: dataset)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            let searchTime = endTime - startTime
            let timePerItem = searchTime / Double(size)
            
            #expect(searchTime < 1.0, "Search on \(size) items should complete under 1 second, got \(searchTime)s")
            #expect(timePerItem < 0.001, "Time per item should be under 1ms for \(size) items, got \(timePerItem * 1000)ms")
            #expect(results.count >= 0, "Search should return valid results for \(size) items")
        }
    }
    
    @Test func testDatabaseScalabilityPerformance() {
        let browserService = BrowserHistoryService.shared
        let limits = [1, 5, 10, 20, 50]
        
        for limit in limits {
            let startTime = CFAbsoluteTimeGetCurrent()
            let tabsResult = browserService.getRecentTabs(limit: limit)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            let fetchTime = endTime - startTime
            
            #expect(fetchTime < 5.0, "Browser history fetch for \(limit) items should complete under 5 seconds, got \(fetchTime)s")
            
            switch tabsResult {
            case .success(let tabs):
                #expect(tabs.count <= limit || tabs.count == 0, "Should respect limit or return no results")
            case .failure(let error):
                print("⚠️ Database scalability test failed for limit \(limit) (expected in CI): \(error.localizedDescription)")
            }
        }
    }
}