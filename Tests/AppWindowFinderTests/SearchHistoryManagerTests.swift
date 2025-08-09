import Testing
@testable import AppWindowFinder

@Suite("SearchHistoryManager Tests")
@MainActor
struct SearchHistoryManagerTests {
    
    init() {
        // Clear data before tests
        SearchHistoryManager.shared.clearAllData()
    }
    
    @Test("Item usage should be recorded correctly")
    func testItemUsageRecording() {
        let manager = SearchHistoryManager.shared
        let item = SearchItem(
            title: "Test App",
            subtitle: "Test Subtitle",
            type: .app,
            appName: "TestApp",
            windowID: 1,
            processID: 123
        )
        
        // Initial score should be 0
        #expect(manager.getUsageScore(for: item) == 0.0)
        
        // Record usage
        manager.recordItemUsage(item)
        
        // Score should be greater than 0
        #expect(manager.getUsageScore(for: item) > 0.0)
    }
    
    @Test("Multiple usage should increase score")
    func testMultipleUsage() {
        let manager = SearchHistoryManager.shared
        let item = SearchItem(
            title: "Frequent App",
            subtitle: "Used Often",
            type: .app,
            appName: "FrequentApp",
            windowID: 1,
            processID: 123
        )
        
        // Record once
        manager.recordItemUsage(item)
        let firstScore = manager.getUsageScore(for: item)
        
        // Record again
        manager.recordItemUsage(item)
        let secondScore = manager.getUsageScore(for: item)
        
        // Score should increase
        #expect(secondScore > firstScore)
    }
    
    @Test("Search history should be recorded")
    func testSearchHistoryRecording() {
        let manager = SearchHistoryManager.shared
        manager.clearAllData() // Clear at test start
        
        // History should be empty initially
        #expect(manager.getSearchHistory().isEmpty)
        
        // Record search queries
        manager.recordSearchQuery("test query")
        manager.recordSearchQuery("another query")
        
        let history = manager.getSearchHistory()
        #expect(history.count == 2)
        #expect(history.first == "another query") // Most recent first
        #expect(history.last == "test query")
    }
    
    @Test("Duplicate queries should not create duplicates")
    func testDuplicateQueryHandling() {
        let manager = SearchHistoryManager.shared
        manager.clearAllData() // Clear at test start
        
        manager.recordSearchQuery("duplicate query")
        manager.recordSearchQuery("other query")
        manager.recordSearchQuery("duplicate query") // Duplicate
        
        let history = manager.getSearchHistory()
        #expect(history.count == 2)
        #expect(history.first == "duplicate query") // Most recent at top
        #expect(history.last == "other query")
    }
    
    @Test("Search suggestions should work")
    func testSearchSuggestions() {
        let manager = SearchHistoryManager.shared
        
        manager.recordSearchQuery("chrome browser")
        manager.recordSearchQuery("calculator app")
        manager.recordSearchQuery("chrome extension")
        
        let suggestions = manager.getSearchSuggestions(for: "chr")
        
        #expect(suggestions.count == 2)
        #expect(suggestions.contains("chrome extension"))
        #expect(suggestions.contains("chrome browser"))
    }
    
    @Test("Empty query should return recent history")
    func testEmptyQuerySuggestions() {
        let manager = SearchHistoryManager.shared
        
        manager.recordSearchQuery("recent 1")
        manager.recordSearchQuery("recent 2")
        manager.recordSearchQuery("recent 3")
        
        let suggestions = manager.getSearchSuggestions(for: "")
        
        #expect(suggestions.count >= 3)
        #expect(suggestions.first == "recent 3") // Most recent first
    }
    
    @Test("Clear all data should work")
    func testClearAllData() {
        let manager = SearchHistoryManager.shared
        let item = SearchItem(
            title: "Test App",
            subtitle: "Test",
            type: .app,
            appName: "Test",
            windowID: 1,
            processID: 123
        )
        
        // Create test data
        manager.recordItemUsage(item)
        manager.recordSearchQuery("test query")
        
        // Verify data exists
        #expect(manager.getUsageScore(for: item) > 0.0)
        #expect(!manager.getSearchHistory().isEmpty)
        
        // Clear data
        manager.clearAllData()
        
        // Verify data has been cleared
        #expect(manager.getUsageScore(for: item) == 0.0)
        #expect(manager.getSearchHistory().isEmpty)
    }
}