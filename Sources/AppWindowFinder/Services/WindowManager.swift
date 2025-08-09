import Foundation
import AppKit
import CoreGraphics
import os.log

@MainActor
public class WindowManager {
    public static let shared = WindowManager()
    private var cachedItems: [SearchItem]?
    private var lastCacheTime: Date?
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    public func refreshWindows() {
        let items = fetchAllSearchItems()
        cachedItems = items
        lastCacheTime = Date()
    }
    
    public func getAllSearchItems() -> [SearchItem] {
        // Check cache validity
        if let cachedItems = cachedItems,
           let lastCacheTime = lastCacheTime,
           Date().timeIntervalSince(lastCacheTime) < cacheExpirationInterval {
            return cachedItems
        }
        
        // Fetch new items
        let items = fetchAllSearchItems()
        cachedItems = items
        lastCacheTime = Date()
        return items
    }
    
    public func clearCache() {
        cachedItems = nil
        lastCacheTime = nil
    }
    
    private func fetchAllSearchItems() -> [SearchItem] {
        var items: [SearchItem] = []
        AppLogger.log("Starting to fetch all search items", level: .info, category: .windowManager)
        
        // First, get all running windows
        let windows = getWindows()
        var runningAppNames = Set<String>()
        
        for window in windows {
            guard let appName = window["kCGWindowOwnerName"] as? String,
                  let windowID = window["kCGWindowNumber"] as? Int,
                  let processID = window["kCGWindowOwnerPID"] as? pid_t else {
                continue
            }
            
            runningAppNames.insert(appName)
            
            let windowTitle = window["kCGWindowName"] as? String ?? ""
            
            // Skip windows without any content
            if windowTitle.isEmpty && appName.isEmpty {
                continue
            }
            
            // Get application icon and optimize
            let app = NSRunningApplication(processIdentifier: processID)
            let icon = ImageOptimizer.optimizeIcon(app?.icon)
            
            // Determine title and subtitle based on window title availability
            let itemTitle: String
            let itemSubtitle: String
            
            if windowTitle.isEmpty || windowTitle == "Untitled Window" || windowTitle == " " {
                // Use app name as title for untitled windows
                itemTitle = appName
                
                // For browsers, show a more meaningful subtitle
                let supportedBrowsers = ["Safari", "Google Chrome", "Firefox", "Arc", "Brave Browser", "Microsoft Edge"]
                if supportedBrowsers.contains(appName) {
                    itemSubtitle = "Browser Window"
                } else {
                    itemSubtitle = "Window"
                }
            } else {
                // Use app name as title and window title as subtitle
                itemTitle = appName
                itemSubtitle = windowTitle
            }
            
            let windowItem = SearchItem(
                title: itemTitle,
                subtitle: itemSubtitle,
                type: .window,
                appName: appName,
                windowID: windowID,
                processID: processID,
                icon: icon
            )
            items.append(windowItem)
            
            if let tabs = getTabsForWindow(appName: appName, windowID: windowID, processID: processID) {
                AppLogger.log("Found \(tabs.count) tabs for \(appName) window \(windowID)", level: .info, category: .windowManager)
                items.append(contentsOf: tabs)
            } else {
                AppLogger.log("No tabs found for \(appName) window \(windowID)", level: .debug, category: .windowManager)
            }
        }
        
        // Then, add non-running applications
        let applications = getApplications()
        for app in applications {
            // Skip if this app is already running
            if runningAppNames.contains(app.appName) {
                continue
            }
            items.append(app)
        }
        
        AppLogger.log("Fetch complete. Total items: \(items.count), Windows: \(items.filter { $0.type == .window }.count), Apps: \(items.filter { $0.type == .app }.count), Tabs: \(items.filter { $0.type == .tab }.count)", level: .info, category: .windowManager)
        return items
    }
    
    private func getApplications() -> [SearchItem] {
        var applications: [SearchItem] = []
        let workspace = NSWorkspace.shared
        
        // Get applications from /Applications and subdirectories
        let applicationDirectories = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities"
        ]
        
        for directory in applicationDirectories {
            let directoryURL = URL(fileURLWithPath: directory)
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [.isApplicationKey],
                    options: [.skipsHiddenFiles]
                )
                
                for url in contents {
                    guard url.pathExtension == "app" else { continue }
                    
                    if let bundle = Bundle(url: url),
                       let bundleIdentifier = bundle.bundleIdentifier,
                       let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? 
                                    bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                                    url.deletingPathExtension().lastPathComponent as String? {
                        
                        // Get app icon and optimize
                        let icon = ImageOptimizer.optimizeIcon(workspace.icon(forFile: url.path))
                        
                        // Create application item
                        let appItem = SearchItem(
                            title: appName,
                            subtitle: "Application",
                            type: .app,
                            appName: appName,
                            windowID: -1,
                            processID: 0,
                            icon: icon,
                            bundleIdentifier: bundleIdentifier,
                            appPath: url.path
                        )
                        applications.append(appItem)
                    }
                }
            } catch {
                // Skip directories that can't be read
                continue
            }
        }
        
        // Sort applications by name
        applications.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        
        return applications
    }
    
    private func getWindows() -> [[String: Any]] {
        let options = CGWindowListOption([.excludeDesktopElements, .optionOnScreenOnly])
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        return windowList.filter { window in
            guard let layer = window["kCGWindowLayer"] as? Int,
                  layer == 0 else { return false }
            return true
        }
    }
    
    private func getTabsForWindow(appName: String, windowID: Int, processID: pid_t) -> [SearchItem]? {
        let supportedBrowsers = ["Safari", "Google Chrome", "Firefox", "Arc", "Brave Browser", "Microsoft Edge"]
        guard supportedBrowsers.contains(appName) else { 
            AppLogger.log("App \(appName) not supported for tab retrieval", level: .debug, category: .windowManager)
            return nil 
        }
        
        AppLogger.log("Getting tabs for \(appName) window \(windowID)", level: .debug, category: .windowManager)
        
        let app = NSRunningApplication(processIdentifier: processID)
        guard let originalIcon = app?.icon else { return nil }
        let appIcon = ImageOptimizer.optimizeIcon(originalIcon) ?? originalIcon
        
        var tabs: [SearchItem] = []
        
        switch appName {
        case "Safari":
            tabs = getSafariTabs(windowID: windowID, processID: processID, icon: appIcon)
        case "Google Chrome", "Brave Browser", "Microsoft Edge":
            tabs = getChromiumTabs(appName: appName, windowID: windowID, processID: processID, icon: appIcon)
        default:
            // Firefox, Arc, and others not implemented yet
            return []
        }
        
        return tabs.isEmpty ? nil : tabs
    }
    
    private func getSafariTabs(windowID: Int, processID: pid_t, icon: NSImage) -> [SearchItem] {
        // Get window index based on windowID
        let windowIndex = getWindowIndex(for: windowID, processID: processID, appName: "Safari") ?? 1
        
        let script = """
        tell application "Safari"
            set tabList to {}
            if (count of windows) >= \(windowIndex) then
                set w to window \(windowIndex)
                set tabCount to count of tabs of w
                repeat with i from 1 to tabCount
                    set t to tab i of w
                    set tabTitle to name of t
                    set tabURL to URL of t
                    set end of tabList to {i, tabTitle, tabURL}
                end repeat
            end if
            return tabList
        end tell
        """
        
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            AppLogger.log("Failed to create AppleScript object for Safari tabs", level: .error, category: .windowManager)
            return []
        }
        
        let result = scriptObject.executeAndReturnError(&error)
        if let error = error {
            handleAppleScriptError(error as? NSError, browser: "Safari")
            return []
        }
        
        var tabs: [SearchItem] = []
        let count = result.numberOfItems
        
        for i in 1...count {
            guard let tabInfo = result.atIndex(i),
                  tabInfo.numberOfItems >= 3,
                  let tabIndex = tabInfo.atIndex(1)?.int32Value,
                  let tabTitle = tabInfo.atIndex(2)?.stringValue,
                  let tabURL = tabInfo.atIndex(3)?.stringValue else {
                continue
            }
            
            let tab = SearchItem(
                title: tabTitle.isEmpty ? "Untitled Tab" : tabTitle,
                subtitle: "Safari - \(tabURL)",
                type: .tab,
                appName: "Safari",
                windowID: windowID,
                tabIndex: Int(tabIndex) - 1,
                processID: processID,
                icon: icon
            )
            tabs.append(tab)
        }
        
        return tabs
    }
    
    private func getChromiumTabs(appName: String, windowID: Int, processID: pid_t, icon: NSImage) -> [SearchItem] {
        // Get window index based on windowID
        let windowIndex = getWindowIndex(for: windowID, processID: processID, appName: appName) ?? 1
        
        AppLogger.log("Getting Chromium tabs for \(appName), windowID: \(windowID), windowIndex: \(windowIndex)", level: .debug, category: .windowManager)
        
        let script = """
        tell application "\(appName)"
            set tabList to {}
            if (count of windows) >= \(windowIndex) then
                set w to window \(windowIndex)
                set tabCount to count of tabs of w
                repeat with i from 1 to tabCount
                    set t to tab i of w
                    set tabTitle to title of t
                    set tabURL to URL of t
                    set end of tabList to {i, tabTitle, tabURL}
                end repeat
            end if
            return tabList
        end tell
        """
        
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            AppLogger.log("Failed to create AppleScript object for \(appName) tabs", level: .error, category: .windowManager)
            return []
        }
        
        let result = scriptObject.executeAndReturnError(&error)
        if let error = error {
            handleAppleScriptError(error as? NSError, browser: appName)
            return []
        }
        
        var tabs: [SearchItem] = []
        let count = result.numberOfItems
        
        AppLogger.log("Got \(count) tabs from \(appName) window \(windowIndex)", level: .debug, category: .windowManager)
        
        for i in 1...count {
            guard let tabInfo = result.atIndex(i),
                  tabInfo.numberOfItems >= 3,
                  let tabIndex = tabInfo.atIndex(1)?.int32Value,
                  let tabTitle = tabInfo.atIndex(2)?.stringValue,
                  let tabURL = tabInfo.atIndex(3)?.stringValue else {
                continue
            }
            
            let tab = SearchItem(
                title: tabTitle.isEmpty ? "Untitled Tab" : tabTitle,
                subtitle: "\(appName) - \(tabURL)",
                type: .tab,
                appName: appName,
                windowID: windowID,
                tabIndex: Int(tabIndex) - 1,
                processID: processID,
                icon: icon
            )
            tabs.append(tab)
        }
        
        return tabs
    }
    
    public func activateItem(_ item: SearchItem) {
        if item.type == .app {
            // Launch the application
            if let appPath = item.appPath {
                let url = URL(fileURLWithPath: appPath)
                // Use synchronous API to avoid threading issues
                NSWorkspace.shared.open(url)
            } else if let bundleIdentifier = item.bundleIdentifier {
                // Try to launch by bundle identifier
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            // Existing window/tab activation logic
            let app = NSRunningApplication(processIdentifier: item.processID)
            app?.activate(options: .activateIgnoringOtherApps)
            
            Thread.sleep(forTimeInterval: 0.1)
            
            if item.type == .window || item.type == .tab {
                activateWindow(windowID: item.windowID)
            }
            
            if item.type == .tab, let tabIndex = item.tabIndex {
                activateTab(appName: item.appName, tabIndex: tabIndex)
            }
        }
    }
    
    private func activateWindow(windowID: Int) {
        let windowRef = CGWindowListCreateDescriptionFromArray([windowID] as CFArray) as? [[String: Any]]
        guard let window = windowRef?.first else { return }
        
        let script = """
        tell application "System Events"
            set frontmost of first process whose unix id is \(window["kCGWindowOwnerPID"] as? Int ?? 0) to true
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            _ = scriptObject.executeAndReturnError(&error)
            if let error = error {
                AppLogger.log("Failed to activate window: \(error)", level: .error, category: .windowManager)
            }
        }
    }
    
    private func activateTab(appName: String, tabIndex: Int) {
        var script = ""
        
        switch appName {
        case "Safari":
            script = """
            tell application "Safari"
                activate
                tell front window
                    set current tab to tab \(tabIndex + 1)
                end tell
            end tell
            """
        case "Google Chrome", "Brave Browser", "Microsoft Edge":
            script = """
            tell application "\(appName)"
                activate
                tell front window
                    set active tab index to \(tabIndex + 1)
                end tell
            end tell
            """
        default:
            return
        }
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            _ = scriptObject.executeAndReturnError(&error)
            if let error = error {
                AppLogger.log("Failed to activate tab in \(appName): \(error)", level: .error, category: .windowManager)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getWindowIndex(for windowID: Int, processID: pid_t, appName: String) -> Int? {
        let windows = getWindows().filter { window in
            guard let appName_window = window["kCGWindowOwnerName"] as? String,
                  let processID_window = window["kCGWindowOwnerPID"] as? pid_t else {
                return false
            }
            return appName_window == appName && processID_window == processID
        }
        
        // Sort windows by creation order (or ID) to match AppleScript window order
        let sortedWindows = windows.sorted { window1, window2 in
            guard let id1 = window1["kCGWindowNumber"] as? Int,
                  let id2 = window2["kCGWindowNumber"] as? Int else {
                return false
            }
            return id1 < id2
        }
        
        // Find the index (1-based for AppleScript)
        for (index, window) in sortedWindows.enumerated() {
            if let id = window["kCGWindowNumber"] as? Int, id == windowID {
                return index + 1 // AppleScript uses 1-based indexing
            }
        }
        
        return nil
    }
    
    // MARK: - Error Handling
    
    private func handleAppleScriptError(_ error: NSError?, browser: String) {
        guard let error = error else { return }
        
        let errorCode = error.code
        let errorDescription = error.localizedDescription
        
        AppLogger.log("AppleScript error for \(browser): Code \(errorCode) - \(errorDescription)", level: .error, category: .windowManager)
        
        // Common error codes
        switch errorCode {
        case -1743: // User denied permission
            AppLogger.log("User denied permission to access \(browser). Please grant access in System Preferences > Security & Privacy > Privacy > Automation", level: .warning, category: .windowManager)
        case -2700: // Application not found
            AppLogger.log("\(browser) application not found or not running", level: .warning, category: .windowManager)
        case -1728: // Script execution error
            AppLogger.log("Script execution error for \(browser). The application might not support the requested operation", level: .warning, category: .windowManager)
        default:
            AppLogger.log("Unknown AppleScript error for \(browser): \(errorDescription)", level: .error, category: .windowManager)
        }
    }
    
    public static func formatAppleScriptError(_ error: NSError) -> String {
        let code = error.code
        let description = error.localizedDescription
        
        switch code {
        case -1743:
            return "Permission denied. Please grant access in System Preferences > Security & Privacy > Privacy > Automation"
        case -2700:
            return "Application not found or not running"
        case -1728:
            return "Script execution error. The application might not support this operation"
        default:
            return "Error (\(code)): \(description)"
        }
    }
}