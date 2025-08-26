import Testing
import Foundation
import AppKit
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
    
    // MARK: - Browser Tab Type Tests
    
    @Test func testBrowserTabSearchItemCreation() {
        let testURL = "https://github.com/example/repo"
        let testTitle = "Example Repository - GitHub"
        let testDate = Date()
        let testIcon = NSImage(systemSymbolName: "globe", accessibilityDescription: "Web")
        
        let item = SearchItem(
            title: testTitle,
            subtitle: "Arc • \(testURL)",
            icon: testIcon,
            type: .browserTab,
            windowID: 0,
            processID: 12345,
            bundleIdentifier: "company.thebrowser.Browser",
            url: testURL,
            lastAccessTime: testDate
        )
        
        #expect(item.title == testTitle)
        #expect(item.subtitle.contains("Arc"))
        #expect(item.subtitle.contains(testURL))
        #expect(item.type == .browserTab)
        #expect(item.url == testURL)
        #expect(item.lastAccessTime == testDate)
        #expect(item.bundleIdentifier == "company.thebrowser.Browser")
        #expect(item.icon != nil)
        #expect(item.windowID == 0)
        #expect(item.processID == 12345)
    }
    
    @Test func testBrowserTabWithoutOptionalProperties() {
        let item = SearchItem(
            title: "Test Page",
            subtitle: "Chrome • https://example.com",
            type: .browserTab,
            appName: "Chrome",
            windowID: 0,
            processID: 12345,
            icon: nil,
            bundleIdentifier: nil,
            url: nil
        )
        
        #expect(item.type == .browserTab)
        #expect(item.url == nil)
        #expect(item.bundleIdentifier == nil)
        #expect(item.icon == nil)
        // lastAccessTime has default value, so it's never nil
        #expect(item.lastAccessTime <= Date(), "lastAccessTime should not be in future")
    }
    
    @Test func testAllItemTypes() {
        let itemTypes: [ItemType] = [.app, .window, .tab, .browserTab]
        
        for itemType in itemTypes {
            let item = SearchItem(
                title: "Test \(itemType)",
                subtitle: "Test Subtitle",
                type: itemType,
                appName: "TestApp",
                windowID: 1,
                processID: 123
            )
            
            #expect(item.type == itemType)
            #expect(item.title.contains("Test"))
        }
    }
    
    // MARK: - URL and Time Properties Tests
    
    @Test func testURLProperty() {
        let testURL = "https://docs.swift.org/swift-book/"
        
        let browserTabItem = SearchItem(
            title: "Swift Documentation",
            subtitle: "Safari • \(testURL)",
            type: .browserTab,
            appName: "Safari",
            windowID: 0,
            processID: 123,
            url: testURL
        )
        
        let regularTabItem = SearchItem(
            title: "Swift Documentation",
            subtitle: "Safari",
            type: .tab,
            appName: "Safari",
            windowID: 1,
            tabIndex: 0,
            processID: 123
        )
        
        #expect(browserTabItem.url == testURL)
        #expect(regularTabItem.url == nil)
    }
    
    @Test func testLastAccessTimeProperty() {
        let testDate = Date()
        
        let item = SearchItem(
            title: "Recent Page",
            subtitle: "Chrome • https://example.com",
            type: .browserTab,
            appName: "Chrome",
            windowID: 0,
            processID: 123,
            lastAccessTime: testDate
        )
        
        #expect(item.lastAccessTime == testDate)
    }
    
    @Test func testBundleIdentifierProperty() {
        let testBundleId = "com.google.Chrome"
        
        let item = SearchItem(
            title: "Test Page",
            subtitle: "Chrome • https://example.com",
            type: .browserTab,
            appName: "Chrome",
            windowID: 0,
            processID: 123,
            bundleIdentifier: testBundleId
        )
        
        #expect(item.bundleIdentifier == testBundleId)
    }
    
    // MARK: - Icon Handling Tests
    
    @Test func testIconProperty() {
        let testIcon = NSImage(systemSymbolName: "globe", accessibilityDescription: "Web icon")
        
        let itemWithIcon = SearchItem(
            title: "Test Page",
            subtitle: "Chrome • https://example.com",
            type: .browserTab,
            appName: "Chrome",
            windowID: 0,
            processID: 123,
            icon: testIcon,
            bundleIdentifier: "com.google.Chrome",
            url: "https://example.com"
        )
        
        let itemWithoutIcon = SearchItem(
            title: "Test Page",
            subtitle: "Chrome • https://example.com",
            type: .browserTab,
            appName: "Chrome",
            windowID: 0,
            processID: 123,
            icon: nil,
            bundleIdentifier: nil,
            url: nil
        )
        
        #expect(itemWithIcon.icon != nil)
        #expect(itemWithoutIcon.icon == nil)
    }
    
    // MARK: - Browser-Specific Tests
    
    @Test func testSupportedBrowserBundles() {
        let browserConfigs = [
            ("Google Chrome", "com.google.Chrome"),
            ("Arc", "company.thebrowser.Browser"),
            ("Brave Browser", "com.brave.Browser"),
            ("Microsoft Edge", "com.microsoft.edgemac")
        ]
        
        for (browserName, bundleId) in browserConfigs {
            let item = SearchItem(
                title: "Test Page",
                subtitle: "\(browserName) • https://example.com",
                type: .browserTab,
                appName: browserName,
                windowID: 0,
                processID: 123,
                bundleIdentifier: bundleId
            )
            
            #expect(item.appName == browserName)
            #expect(item.bundleIdentifier == bundleId)
            #expect(item.type == .browserTab)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test func testValidURLFormats() {
        let validURLs = [
            "https://github.com",
            "http://example.com",
            "https://docs.swift.org/swift-book/",
            "https://developer.apple.com/documentation/",
            "https://www.google.com/search?q=swift"
        ]
        
        for url in validURLs {
            let item = SearchItem(
                title: "Test Page",
                subtitle: "Browser • \(url)",
                type: .browserTab,
                appName: "Browser",
                windowID: 0,
                processID: 123,
                url: url
            )
            
            #expect(item.url == url)
            #expect(URL(string: url) != nil, "URL should be valid: \(url)")
        }
    }
    
    @Test func testItemSorting() {
        let now = Date()
        let safeNowTimestamp = min(now.timeIntervalSince1970, 1893456000.0) // Cap at 2030-01-01
        let oneHourAgo = Date(timeIntervalSince1970: safeNowTimestamp - 3600)
        let twoHoursAgo = Date(timeIntervalSince1970: safeNowTimestamp - 7200)
        
        let items = [
            SearchItem(title: "Old Page", subtitle: "Browser", type: .browserTab, appName: "Browser", windowID: 0, processID: 1, lastAccessTime: twoHoursAgo),
            SearchItem(title: "Recent Page", subtitle: "Browser", type: .browserTab, appName: "Browser", windowID: 0, processID: 2, lastAccessTime: now),
            SearchItem(title: "Middle Page", subtitle: "Browser", type: .browserTab, appName: "Browser", windowID: 0, processID: 3, lastAccessTime: oneHourAgo)
        ]
        
        let sortedItems = items.sorted { 
            $0.lastAccessTime > $1.lastAccessTime 
        }
        
        #expect(sortedItems[0].title == "Recent Page")
        #expect(sortedItems[1].title == "Middle Page")
        #expect(sortedItems[2].title == "Old Page")
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
    
    // MARK: - Edge Case Tests
    
    @Test func testEmptyValues() {
        let item = SearchItem(
            title: "",
            subtitle: "",
            type: .browserTab,
            appName: "",
            windowID: 0,
            processID: 0,
            url: ""
        )
        
        #expect(item.title == "")
        #expect(item.subtitle == "")
        #expect(item.appName == "")
        #expect(item.url == "")
        #expect(item.processID == 0)
    }
    
    @Test func testNilOptionalValues() {
        let item = SearchItem(
            title: "Test Page",
            subtitle: "Browser",
            type: .browserTab,
            appName: "Browser",
            windowID: 0,
            processID: 123,
            icon: nil,
            bundleIdentifier: nil,
            url: nil
            // lastAccessTime has default value, not nil
        )
        
        #expect(item.icon == nil)
        #expect(item.bundleIdentifier == nil)
        #expect(item.url == nil)
        // lastAccessTime is non-optional, so it always has a value
        #expect(item.lastAccessTime <= Date(), "lastAccessTime should not be in the future")
    }
}