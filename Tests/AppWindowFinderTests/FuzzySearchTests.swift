import Testing
@testable import AppWindowFinder

@Suite("FuzzySearch Tests")
@MainActor
struct FuzzySearchTests {
    
    init() {
        // テスト前に履歴をクリア
        SearchHistoryManager.shared.clearAllData()
    }
    
    @Test func testExactMatch() {
        let items = [
            SearchItem(title: "Safari", subtitle: "Web Browser", type: .app, appName: "Safari", windowID: 1, processID: 123),
            SearchItem(title: "System Preferences", subtitle: "Settings", type: .app, appName: "System Preferences", windowID: 2, processID: 124)
        ]
        
        let results = FuzzySearch.search("Safari", in: items)
        
        #expect(results.count == 1)
        #expect(results.first?.title == "Safari")
    }
    
    @Test func testPartialMatch() {
        let items = [
            SearchItem(title: "Visual Studio Code", subtitle: "Code Editor", type: .app, appName: "Code", windowID: 1, processID: 123),
            SearchItem(title: "Xcode", subtitle: "IDE", type: .app, appName: "Xcode", windowID: 2, processID: 124),
            SearchItem(title: "Terminal", subtitle: "Command Line", type: .app, appName: "Terminal", windowID: 3, processID: 125)
        ]
        
        let results = FuzzySearch.search("code", in: items)
        
        #expect(results.count == 3) // Visual Studio Code, Code Editor (subtitle), and Xcode
        #expect(results.contains { $0.title == "Visual Studio Code" })
        #expect(results.contains { $0.title == "Xcode" })
        #expect(results.contains { $0.title == "Terminal" }) // Command Line contains "co" in fuzzy match
    }
    
    @Test func testFuzzyMatch() {
        let items = [
            SearchItem(title: "GitHub Desktop", subtitle: "Git Client", type: .app, appName: "GitHub Desktop", windowID: 1, processID: 123),
            SearchItem(title: "Google Chrome", subtitle: "Web Browser", type: .app, appName: "Google Chrome", windowID: 2, processID: 124)
        ]
        
        let results = FuzzySearch.search("ghd", in: items)
        
        #expect(results.count == 1)
        #expect(results.first?.title == "GitHub Desktop")
    }
    
    @Test func testEmptyQuery() {
        let items = [
            SearchItem(title: "App1", subtitle: "Test", type: .app, appName: "App1", windowID: 1, processID: 123),
            SearchItem(title: "App2", subtitle: "Test", type: .app, appName: "App2", windowID: 2, processID: 124)
        ]
        
        let results = FuzzySearch.search("", in: items)
        
        #expect(results.count == items.count)
    }
    
    @Test func testCaseInsensitive() {
        let items = [
            SearchItem(title: "Safari", subtitle: "Web Browser", type: .app, appName: "Safari", windowID: 1, processID: 123)
        ]
        
        let results = FuzzySearch.search("SAFARI", in: items)
        
        #expect(results.count == 1)
        #expect(results.first?.title == "Safari")
    }
    
    @Test func testAcronymMatch() {
        let items = [
            SearchItem(title: "Google Chrome", subtitle: "Web Browser", type: .app, appName: "Google Chrome", windowID: 1, processID: 123),
            SearchItem(title: "Visual Studio Code", subtitle: "Code Editor", type: .app, appName: "Visual Studio Code", windowID: 2, processID: 124),
            SearchItem(title: "Activity Monitor", subtitle: "System Monitor", type: .app, appName: "Activity Monitor", windowID: 3, processID: 125)
        ]
        
        let results = FuzzySearch.search("gc", in: items)
        
        #expect(results.count >= 1)
        #expect(results.contains { $0.title == "Google Chrome" })
    }
    
    @Test func testWordBoundaryMatch() {
        let items = [
            SearchItem(title: "Microsoft Word", subtitle: "Document Editor", type: .app, appName: "Microsoft Word", windowID: 1, processID: 123),
            SearchItem(title: "Final Cut Pro", subtitle: "Video Editor", type: .app, appName: "Final Cut Pro", windowID: 2, processID: 124)
        ]
        
        let results = FuzzySearch.search("word", in: items)
        
        #expect(results.count >= 1)
        #expect(results.first?.title == "Microsoft Word")
    }
    
    @Test func testUsageHistoryPriority() {
        let items = [
            SearchItem(title: "App A", subtitle: "Test App", type: .app, appName: "App A", windowID: 1, processID: 123),
            SearchItem(title: "App B", subtitle: "Test App", type: .app, appName: "App B", windowID: 2, processID: 124)
        ]
        
        // App Bの使用履歴を記録
        SearchHistoryManager.shared.recordItemUsage(items[1])
        SearchHistoryManager.shared.recordItemUsage(items[1])
        
        // 空のクエリで検索（使用履歴順）
        let results = FuzzySearch.search("", in: items)
        
        #expect(results.count == 2)
        #expect(results.first?.title == "App B") // 使用頻度が高いので最初に来る
    }
}