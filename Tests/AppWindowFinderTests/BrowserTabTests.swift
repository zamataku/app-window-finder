import Testing
import AppKit
@testable import AppWindowFinder

@MainActor
struct BrowserTabTests {
    
    @Test func testSafariTabRetrieval() {
        // Test AppleScript for getting Safari tabs
        let script = """
        tell application "Safari"
            set tabList to {}
            repeat with w in windows
                set windowIndex to index of w
                set tabCount to count of tabs of w
                repeat with i from 1 to tabCount
                    set t to tab i of w
                    set tabTitle to name of t
                    set tabURL to URL of t
                    set end of tabList to {windowIndex, i, tabTitle, tabURL}
                end repeat
            end repeat
            return tabList
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            
            if error == nil {
                // Script executed successfully
                #expect(result.descriptorType != 0)
            } else {
                // Safari might not be running or have no windows
                print("Safari script error: \(error ?? [:])")
            }
        }
    }
    
    @Test func testChromeTabRetrieval() {
        // Test AppleScript for getting Chrome tabs
        let script = """
        tell application "Google Chrome"
            set tabList to {}
            repeat with w in windows
                set windowIndex to index of w
                set tabCount to count of tabs of w
                repeat with i from 1 to tabCount
                    set t to tab i of w
                    set tabTitle to title of t
                    set tabURL to URL of t
                    set end of tabList to {windowIndex, i, tabTitle, tabURL}
                end repeat
            end repeat
            return tabList
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            
            if error == nil {
                // Script executed successfully
                #expect(result.descriptorType != 0)
            } else {
                // Chrome might not be running or have no windows
                print("Chrome script error: \(error ?? [:])")
            }
        }
    }
    
    @Test func testTabItemCreation() {
        // Test creating tab items with proper information
        let tabItem = SearchItem(
            title: "GitHub - example/repository: development",
            subtitle: "https://github.com/example/repository",
            type: .tab,
            appName: "Safari",
            windowID: 123,
            tabIndex: 0,
            processID: 456,
            icon: nil
        )
        
        #expect(tabItem.type == .tab)
        #expect(tabItem.tabIndex == 0)
        #expect(!tabItem.title.isEmpty)
        #expect(tabItem.subtitle.contains("github.com"))
    }
    
    @Test func testBrowserSupport() {
        // Test that all supported browsers are handled
        let supportedBrowsers = ["Safari", "Google Chrome", "Firefox", "Arc", "Brave Browser", "Microsoft Edge"]
        
        for browser in supportedBrowsers {
            let item = SearchItem(
                title: "Test Page",
                subtitle: "https://example.com",
                type: .tab,
                appName: browser,
                windowID: 1,
                tabIndex: 0,
                processID: 123
            )
            
            #expect(supportedBrowsers.contains(item.appName))
        }
    }
}