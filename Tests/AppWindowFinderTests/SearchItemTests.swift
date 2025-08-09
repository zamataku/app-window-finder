import Testing
@testable import AppWindowFinder

struct SearchItemTests {
    
    @Test func testSearchItemCreation() {
        let item = SearchItem(
            title: "Test Window",
            subtitle: "Test App",
            type: .window,
            appName: "TestApp",
            windowID: 123,
            tabIndex: nil,
            processID: 456
        )
        
        #expect(item.title == "Test Window")
        #expect(item.subtitle == "Test App")
        #expect(item.type == .window)
        #expect(item.appName == "TestApp")
        #expect(item.windowID == 123)
        #expect(item.tabIndex == nil)
        #expect(item.processID == 456)
    }
    
    @Test func testSearchItemWithTab() {
        let item = SearchItem(
            title: "GitHub - example/repository",
            subtitle: "Safari",
            type: .tab,
            appName: "Safari",
            windowID: 123,
            tabIndex: 2,
            processID: 456
        )
        
        #expect(item.type == .tab)
        #expect(item.tabIndex == 2)
    }
    
    @Test func testSearchItemEquality() {
        let item1 = SearchItem(
            title: "Test",
            subtitle: "App",
            type: .app,
            appName: "TestApp",
            windowID: 1,
            processID: 123
        )
        
        let item2 = SearchItem(
            title: "Test",
            subtitle: "App",
            type: .app,
            appName: "TestApp",
            windowID: 1,
            processID: 123
        )
        
        #expect(item1 != item2)
        #expect(item1 == item1)
    }
}