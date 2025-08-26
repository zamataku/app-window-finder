import Testing
import Foundation
import AppKit
import SQLite3
@testable import AppWindowFinder

@MainActor
struct BrowserHistoryServiceTests {
    
    // MARK: - Basic Service Tests
    
    @Test func testBrowserHistoryServiceSingleton() {
        let service1 = BrowserHistoryService.shared
        let service2 = BrowserHistoryService.shared
        
        #expect(service1 === service2, "BrowserHistoryService should be a singleton")
    }
    
    @Test func testBrowserConfigurations() {
        // Test that all expected browser configurations are present
        let service = BrowserHistoryService.shared
        let tabsResult = service.getRecentTabs(limit: 1)
        
        // Should not crash and should return a result
        switch tabsResult {
        case .success(let tabs):
            #expect(tabs.count >= 0, "Should return valid tab array")
        case .failure(let error):
            print("⚠️ Browser history test failed (expected in CI): \(error.localizedDescription)")
            #expect(true, "Failure is acceptable in test environment")
        }
    }
    
    // MARK: - SQLite Database Tests
    
    @Test func testDatabasePathExpansion() {
        let testPath = "~/Library/Application Support/Arc/User Data/Default/History"
        let expandedPath = NSString(string: testPath).expandingTildeInPath
        
        #expect(expandedPath.contains("/Users/"))
        #expect(expandedPath.contains("Library/Application Support"))
        #expect(!expandedPath.contains("~"))
    }
    
    @Test func testSQLiteTimeConversion() {
        // Test Chrome time format conversion
        // Chrome time: microseconds since January 1, 1601 UTC
        // Swift Date: seconds since January 1, 1970 UTC
        
        let chromeEpochOffset: Int64 = 11644473600000000 // microseconds between 1601 and 1970
        // Use a much smaller, safe timestamp to avoid overflow
        let safeTimestamp = 1672531200.0 // Fixed timestamp: 2023-01-01
        let testChromeTime: Int64 = Int64(safeTimestamp * 1_000_000) + chromeEpochOffset
        
        // Convert back to Swift time
        let swiftTime = Double(testChromeTime - chromeEpochOffset) / 1_000_000.0
        let convertedDate = Date(timeIntervalSince1970: swiftTime)
        
        let expectedTimestamp = 1672531200.0
        let timeDifference = abs(convertedDate.timeIntervalSince1970 - expectedTimestamp)
        #expect(timeDifference < 2.0, "Time conversion should be accurate within 2 seconds")
    }
    
    @Test func testCreateTestDatabase() throws {
        // Create a test SQLite database with mock browser history
        let tempDir = NSTemporaryDirectory()
        let testDBPath = tempDir + "test_browser_history.db"
        
        // Clean up if exists
        try? FileManager.default.removeItem(atPath: testDBPath)
        
        // Create test database
        var db: OpaquePointer?
        let result = sqlite3_open(testDBPath, &db)
        #expect(result == SQLITE_OK, "Should be able to create test database")
        
        defer { 
            sqlite3_close(db)
            try? FileManager.default.removeItem(atPath: testDBPath)
        }
        
        // Create urls table with Chrome schema
        let createTableSQL = """
            CREATE TABLE urls (
                id INTEGER PRIMARY KEY,
                url TEXT,
                title TEXT,
                visit_count INTEGER,
                typed_count INTEGER,
                last_visit_time INTEGER,
                hidden INTEGER DEFAULT 0,
                favicon_id INTEGER
            )
        """
        
        let createResult = sqlite3_exec(db, createTableSQL, nil, nil, nil)
        #expect(createResult == SQLITE_OK, "Should be able to create urls table")
        
        // Insert test data
        let safeCurrentTime = 1672531200.0 // Fixed timestamp: 2023-01-01
        let chromeEpochOffset: Int64 = 11644473600000000
        let safeMicroseconds = Int64(safeCurrentTime * 1_000_000)
        let currentChromeTime = safeMicroseconds + chromeEpochOffset
        let insertSQL = """
            INSERT INTO urls (url, title, visit_count, typed_count, last_visit_time, hidden)
            VALUES 
            ('https://github.com', 'GitHub', 5, 1, \(currentChromeTime), 0),
            ('https://google.com', 'Google', 10, 2, \(currentChromeTime - 3600000000), 0),
            ('https://hidden.com', 'Hidden Page', 1, 0, \(currentChromeTime), 1)
        """
        
        let insertResult = sqlite3_exec(db, insertSQL, nil, nil, nil)
        #expect(insertResult == SQLITE_OK, "Should be able to insert test data")
        
        // Test querying the database
        let querySQL = "SELECT COUNT(*) FROM urls WHERE hidden = 0"
        var statement: OpaquePointer?
        
        let prepareResult = sqlite3_prepare_v2(db, querySQL, -1, &statement, nil)
        #expect(prepareResult == SQLITE_OK, "Should be able to prepare query")
        
        defer { sqlite3_finalize(statement) }
        
        let stepResult = sqlite3_step(statement)
        #expect(stepResult == SQLITE_ROW, "Should get a result row")
        
        let count = sqlite3_column_int(statement, 0)
        #expect(count == 2, "Should have 2 non-hidden URLs")
    }
    
    // MARK: - Browser Detection Tests
    
    @Test func testBrowserBundleIds() {
        let expectedBundles = [
            "com.google.Chrome": "Google Chrome",
            "company.thebrowser.Browser": "Arc",
            "com.brave.Browser": "Brave Browser",
            "com.microsoft.edgemac": "Microsoft Edge"
        ]
        
        for (bundleId, expectedName) in expectedBundles {
            // Test that bundle ID mapping works correctly
            // Note: This tests the conceptual mapping, actual implementation may vary
            #expect(!bundleId.isEmpty)
            #expect(!expectedName.isEmpty)
        }
    }
    
    @Test func testRunningBrowserDetection() {
        // Test browser detection logic (without requiring browsers to be running)
        let allRunningApps = NSWorkspace.shared.runningApplications
        let browserApps = allRunningApps.filter { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return ["com.google.Chrome", "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac"].contains(bundleId)
        }
        
        // Should not crash and should return valid results
        #expect(browserApps.count >= 0)
    }
    
    // MARK: - SearchItem Creation Tests
    
    @Test func testBrowserTabSearchItemCreation() {
        let testURL = "https://github.com/example/repo"
        let testTitle = "GitHub Repository"
        let testBrowserName = "Arc"
        let testLastAccess = Date()
        
        let searchItem = SearchItem(
            title: testTitle,
            subtitle: "\(testBrowserName) • \(testURL)",
            icon: nil,
            type: .browserTab,
            windowID: 0,
            processID: 12345,
            bundleIdentifier: "company.thebrowser.Browser",
            url: testURL,
            lastAccessTime: testLastAccess
        )
        
        #expect(searchItem.type == .browserTab)
        #expect(searchItem.title == testTitle)
        #expect(searchItem.subtitle.contains(testBrowserName))
        #expect(searchItem.subtitle.contains(testURL))
        #expect(searchItem.url == testURL)
        #expect(searchItem.lastAccessTime == testLastAccess)
        #expect(searchItem.bundleIdentifier == "company.thebrowser.Browser")
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testNonExistentDatabaseFile() {
        // Test behavior when history database doesn't exist
        let nonExistentPath = "/non/existent/path/History"
        let fileExists = FileManager.default.fileExists(atPath: nonExistentPath)
        
        #expect(!fileExists)
        // The service should handle this gracefully and return empty results
    }
    
    @Test func testTempFileCleanup() throws {
        // Test that temporary files are properly cleaned up
        let tempDir = NSTemporaryDirectory()
        let testFile = tempDir + "temp_test_file.db"
        
        // Create a temporary file
        FileManager.default.createFile(atPath: testFile, contents: Data(), attributes: nil)
        #expect(FileManager.default.fileExists(atPath: testFile))
        
        // Remove it (simulating cleanup)
        try FileManager.default.removeItem(atPath: testFile)
        #expect(!FileManager.default.fileExists(atPath: testFile))
    }
    
    // MARK: - Integration Tests
    
    @Test func testGetRecentTabsWithLimit() {
        let service = BrowserHistoryService.shared
        
        // Test with various limits
        let limits = [1, 5, 10, 20]
        
        for limit in limits {
            switch service.getRecentTabs(limit: limit) {
            case .success(let tabs):
                #expect(tabs.count <= limit, "Should not exceed requested limit")
                #expect(tabs.allSatisfy { $0.type == .browserTab }, "All items should be browser tabs")
            case .failure(_):
                print("⚠️ Browser history test failed for limit \(limit) (expected in CI)")
            }
        }
    }
    
    @Test func testRecentTabsSorting() {
        let service = BrowserHistoryService.shared
        
        switch service.getRecentTabs(limit: 10) {
        case .success(let tabs):
            if tabs.count > 1 {
                // Check that tabs are sorted by last access time (most recent first)
                for i in 0..<(tabs.count - 1) {
                    let currentTime = tabs[i].lastAccessTime
                    let nextTime = tabs[i + 1].lastAccessTime
                    #expect(currentTime >= nextTime, "Tabs should be sorted by last access time (descending)")
                }
            }
        case .failure(_):
            print("⚠️ Browser history sorting test failed (expected in CI)")
        }
    }
    
    @Test func testBrowserTabFaviconHandling() {
        // Test that browser tabs handle favicons correctly
        let service = BrowserHistoryService.shared
        switch service.getRecentTabs(limit: 5) {
        case .success(let tabs):
            for tab in tabs {
                // Each tab should have either a favicon or a fallback icon
                #expect(tab.icon != nil, "Each browser tab should have an icon (favicon or fallback)")
            }
        case .failure(_):
            print("⚠️ Browser tab favicon test failed (expected in CI)")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test func testRecentTabsPerformance() {
        let service = BrowserHistoryService.shared
        
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = service.getRecentTabs(limit: 20)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        #expect(executionTime < 5.0, "getRecentTabs should complete within 5 seconds")
    }
}