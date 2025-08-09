import Foundation
import AppKit
import CoreGraphics
import os.log

@MainActor
public class WindowManager: WindowManaging {
    public static let shared = WindowManager()
    
    // Dependencies
    private let browserHistoryService: BrowserHistoryProviding
    private let faviconService: FaviconProviding
    private let appleScriptExecutor: AppleScriptExecuting
    private let container: ServiceContainer
    
    private var cachedItems: [SearchItem]?
    private var lastCacheTime: Date?
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    private var permissionCache: [String: Bool] = [:]  // Cache for automation permissions
    
    public var searchItems: [SearchItem] {
        return cachedItems ?? []
    }
    
    // Default initializer for shared instance  
    private convenience init() {
        self.init(container: ServiceContainer.shared)
    }
    
    // Dependency injection initializer
    public init(container: ServiceContainer = ServiceContainer.shared) {
        self.container = container
        self.browserHistoryService = container.getBrowserHistoryService()
        self.faviconService = container.getFaviconService()
        self.appleScriptExecutor = container.getAppleScriptExecutor()
        
        // アプリ起動時にブラウザ権限をプリエンプティブにチェック
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.preemptivelyRequestBrowserPermissions()
        }
    }
    
    public func refreshWindows() {
        let items = fetchAllSearchItems()
        cachedItems = items
        lastCacheTime = Date()
    }
    
    public func refreshWindows() async {
        let items = fetchAllSearchItems()
        cachedItems = items
        lastCacheTime = Date()
    }
    
    public func activateWindow(_ item: SearchItem) async -> Bool {
        switch item.type {
        case .window:
            activateWindow(windowID: item.windowID)
            return true
        case .app:
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == item.bundleIdentifier }) {
                app.activate(options: [])
            }
            return true
        case .tab:
            activateTab(appName: item.appName, tabIndex: 0) // Simplified for now
            return true
        case .browserTab:
            // For browser tabs, we could open the URL in a new tab
            if let urlString = item.url, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }
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
        permissionCache.removeAll()  // Also clear permission cache
    }
    
    private func fetchAllSearchItems() -> [SearchItem] {
        var items: [SearchItem] = []
        AppLogger.log("Starting to fetch all search items", level: .info, category: .windowManager)
        
        // First, get all running windows
        let windows = getWindows()
        AppLogger.log("Found \(windows.count) total windows", level: .debug, category: .windowManager)
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
                AppLogger.log("No tabs found for \(appName) window \(windowID) - app may not support tab retrieval or access denied", level: .info, category: .windowManager)
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
        
        // Add recent browser tabs from history (more comprehensive than AppleScript)
        switch browserHistoryService.getRecentTabs(limit: 30) {
        case .success(let historyTabs):
            items.append(contentsOf: historyTabs)
        case .failure(let error):
            AppLogger.logError(error, context: "Failed to get browser history tabs", category: .windowManager)
        }
        
        AppLogger.log("Fetch complete. Total items: \(items.count), Windows: \(items.filter { $0.type == .window }.count), Apps: \(items.filter { $0.type == .app }.count), Tabs: \(items.filter { $0.type == .tab }.count), Browser Tabs: \(items.filter { $0.type == .browserTab }.count)", level: .info, category: .windowManager)
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
        // Arc currently has limited AppleScript support for tab access
        let supportedBrowsers = ["Safari", "Google Chrome", "Firefox", "Brave Browser", "Microsoft Edge"]
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
            // Arc, Firefox and others not implemented yet
            return []
        }
        
        return tabs.isEmpty ? nil : tabs
    }
    
    private func getSafariTabs(windowID: Int, processID: pid_t, icon: NSImage) -> [SearchItem] {
        // Request permission explicitly for better user experience
        if !requestAutomationPermission(for: "Safari") {
            return []
        }
        
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
            
            let favicon = faviconService.getFaviconNonBlocking(for: tabURL, fallbackIcon: icon)
            let tab = SearchItem(
                title: tabTitle.isEmpty ? "Untitled Tab" : tabTitle,
                subtitle: "Safari - \(tabURL)",
                type: .tab,
                appName: "Safari",
                windowID: windowID,
                tabIndex: Int(tabIndex) - 1,
                processID: processID,
                icon: favicon,
                tabURL: tabURL
            )
            tabs.append(tab)
        }
        
        return tabs
    }
    
    private func getArcTabs(windowID: Int, processID: pid_t, icon: NSImage) -> [SearchItem] {
        // Get window index based on windowID
        let windowIndex = getWindowIndex(for: windowID, processID: processID, appName: "Arc") ?? 1
        
        AppLogger.log("Getting Arc tabs for windowID: \(windowID), windowIndex: \(windowIndex)", level: .debug, category: .windowManager)
        
        let script = """
        tell application "Arc"
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
            AppLogger.log("Failed to create AppleScript object for Arc tabs", level: .error, category: .windowManager)
            return []
        }
        
        let result = scriptObject.executeAndReturnError(&error)
        if let error = error {
            handleAppleScriptError(error as? NSError, browser: "Arc")
            return []
        }
        
        var tabs: [SearchItem] = []
        let count = result.numberOfItems
        
        AppLogger.log("Got \(count) tabs from Arc window \(windowIndex)", level: .debug, category: .windowManager)
        
        for i in 1...count {
            guard let tabInfo = result.atIndex(i),
                  tabInfo.numberOfItems >= 3,
                  let tabIndex = tabInfo.atIndex(1)?.int32Value,
                  let tabTitle = tabInfo.atIndex(2)?.stringValue,
                  let tabURL = tabInfo.atIndex(3)?.stringValue else {
                continue
            }
            
            let favicon = faviconService.getFaviconNonBlocking(for: tabURL, fallbackIcon: icon)
            let tab = SearchItem(
                title: tabTitle.isEmpty ? "Untitled Tab" : tabTitle,
                subtitle: "Arc - \(tabURL)",
                type: .tab,
                appName: "Arc",
                windowID: windowID,
                tabIndex: Int(tabIndex) - 1,
                processID: processID,
                icon: favicon,
                tabURL: tabURL
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
        
        var scriptError: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            AppLogger.log("Failed to create AppleScript object for \(appName) tabs", level: .error, category: .windowManager)
            return []
        }
        
        let result = scriptObject.executeAndReturnError(&scriptError)
        if let scriptError = scriptError {
            handleAppleScriptError(scriptError as? NSError, browser: appName)
            return []
        }
        
        var tabs: [SearchItem] = []
        let count = result.numberOfItems
        
        AppLogger.log("Got \(count) tabs from \(appName) window \(windowIndex) (windowID: \(windowID))", level: .debug, category: .windowManager)
        
        if count == 0 {
            AppLogger.log("No tabs returned from AppleScript for \(appName)", level: .warning, category: .windowManager)
            return []
        }
        
        for i in 1...count {
            guard let tabInfo = result.atIndex(i),
                  tabInfo.numberOfItems >= 3,
                  let tabIndex = tabInfo.atIndex(1)?.int32Value,
                  let tabTitle = tabInfo.atIndex(2)?.stringValue,
                  let tabURL = tabInfo.atIndex(3)?.stringValue else {
                continue
            }
            
            let favicon = faviconService.getFaviconNonBlocking(for: tabURL, fallbackIcon: icon)
            let tab = SearchItem(
                title: tabTitle.isEmpty ? "Untitled Tab" : tabTitle,
                subtitle: "\(appName) - \(tabURL)",
                type: .tab,
                appName: appName,
                windowID: windowID,
                tabIndex: Int(tabIndex) - 1,
                processID: processID,
                icon: favicon,
                tabURL: tabURL
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
            
            // Use async delay instead of blocking Thread.sleep
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if item.type == .window || item.type == .tab {
                    self?.activateWindow(windowID: item.windowID)
                }
                
                if item.type == .tab, let tabIndex = item.tabIndex {
                    self?.activateTab(appName: item.appName, tabIndex: tabIndex)
                }
                
                if item.type == .browserTab, let url = item.url {
                    self?.openURLInBrowser(url: url, bundleIdentifier: item.bundleIdentifier)
                }
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
    
    // MARK: - Permission Management
    
    private func preemptivelyRequestBrowserPermissions() {
        AppLogger.log("Preemptively checking browser automation permissions", level: .info, category: .windowManager)
        
        let supportedBrowsers = ["Safari", "Google Chrome", "Microsoft Edge", "Brave Browser"]
        let runningApps = NSWorkspace.shared.runningApplications
        
        // 実行中のブラウザに対してのみ権限をリクエスト
        for app in runningApps {
            if let appName = app.localizedName,
               supportedBrowsers.contains(appName) {
                AppLogger.log("Found running browser: \(appName), requesting permission", level: .info, category: .windowManager)
                // メインスレッドで同期的に実行して権限プロンプトを確実に表示
                DispatchQueue.main.async {
                    _ = self.requestAutomationPermissionSynchronously(for: appName)
                }
            }
        }
    }
    
    public func checkAutomationPermission(for appName: String) -> Bool {
        return requestAutomationPermission(for: appName)
    }
    
    public func requestBrowserPermissions() {
        preemptivelyRequestBrowserPermissions()
    }
    
    private func requestAutomationPermission(for appName: String) -> Bool {
        // Check cache first
        if let cachedPermission = permissionCache[appName] {
            return cachedPermission
        }
        
        AppLogger.log("Checking automation permission for \(appName)", level: .info, category: .windowManager)
        
        // Create a simple permission check script
        let permissionScript = """
        tell application "\(appName)"
            get name
        end tell
        """
        
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: permissionScript) else {
            AppLogger.log("Failed to create permission check script for \(appName)", level: .error, category: .windowManager)
            permissionCache[appName] = false
            return false
        }
        
        // Execute synchronously to check permission
        _ = scriptObject.executeAndReturnError(&error)
        
        if let error = error {
            let errorCode = error["NSAppleScriptErrorNumber"] as? Int ?? 0
            AppLogger.log("Permission check failed for \(appName): error code \(errorCode)", level: .warning, category: .windowManager)
            
            // If it's a permission error, cache as denied
            if errorCode == -1743 {
                permissionCache[appName] = false
                AppLogger.log("Automation permission denied for \(appName). User needs to grant access in System Preferences.", level: .warning, category: .windowManager)
                return false
            }
            
            // Other errors (app not running, etc.) - don't cache, try again next time
            return false
        }
        
        AppLogger.log("Automation permission granted for \(appName)", level: .info, category: .windowManager)
        permissionCache[appName] = true
        return true
    }
    
    private func requestAutomationPermissionSynchronously(for appName: String) -> Bool {
        AppLogger.log("Synchronously requesting automation permission for \(appName)", level: .info, category: .windowManager)
        
        // より明示的な権限リクエストスクリプト
        let permissionScript = """
        tell application "\(appName)"
            activate
            get name
        end tell
        """
        
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: permissionScript) else {
            AppLogger.log("Failed to create permission check script for \(appName)", level: .error, category: .windowManager)
            return false
        }
        
        // メインスレッドで同期実行
        _ = scriptObject.executeAndReturnError(&error)
        
        if let error = error {
            AppLogger.log("Synchronous permission request failed for \(appName): \(error)", level: .warning, category: .windowManager)
            
            // If it's a permission error, show user-friendly message
            if let errorCode = error["NSAppleScriptErrorNumber"] as? Int, errorCode == -1743 {
                showAutomationPermissionAlert(for: appName)
            }
            return false
        }
        
        AppLogger.log("Automation permission granted for \(appName)", level: .info, category: .windowManager)
        return true
    }
    
    private func showAutomationPermissionAlert(for appName: String) {
        let alert = NSAlert()
        alert.messageText = "Automation Permission Required"
        alert.informativeText = "AppWindowFinder needs permission to access \(appName) tabs. Please go to System Preferences > Security & Privacy > Privacy > Automation and enable AppWindowFinder to control \(appName)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Preferences to Automation settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
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
        
        AppLogger.log("Found \(windows.count) windows for \(appName) with PID \(processID)", level: .debug, category: .windowManager)
        
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
                AppLogger.log("Window ID \(windowID) maps to index \(index + 1) for \(appName)", level: .debug, category: .windowManager)
                return index + 1 // AppleScript uses 1-based indexing
            }
        }
        
        AppLogger.log("Window ID \(windowID) not found in \(appName) windows, using default index 1", level: .debug, category: .windowManager)
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
            AppLogger.log("⚠️ PERMISSION DENIED: \(browser) requires automation permission. Go to System Preferences > Security & Privacy > Privacy > Automation and enable AppWindowFinder to control \(browser)", level: .error, category: .windowManager)
        case -2700: // Application not found
            AppLogger.log("\(browser) application not found or not running", level: .warning, category: .windowManager)
        case -1728: // Script execution error
            AppLogger.log("Script execution error for \(browser). The application might not support the requested operation", level: .warning, category: .windowManager)
        case -600: // Application not running
            AppLogger.log("\(browser) is not running", level: .info, category: .windowManager)
        default:
            AppLogger.log("Unknown AppleScript error for \(browser): Code \(errorCode) - \(errorDescription)", level: .error, category: .windowManager)
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
    
    // MARK: - Browser URL Opening
    
    private func openURLInBrowser(url: String, bundleIdentifier: String?) {
        guard let urlToOpen = URL(string: url) else {
            AppLogger.log("Invalid URL: \(url)", level: .error, category: .windowManager)
            return
        }
        
        if let bundleId = bundleIdentifier, !bundleId.isEmpty {
            // Try to open in specific browser
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = false
            
            // Try to get browser application path
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            if let browserApp = runningApps.first, let appURL = browserApp.bundleURL {
                NSWorkspace.shared.open([urlToOpen], 
                                      withApplicationAt: appURL,
                                      configuration: configuration) { [weak self] app, error in
                    if let error = error {
                        AppLogger.log("Failed to open URL \(url) in specific browser: \(error)", level: .warning, category: .windowManager)
                        // Fallback to default browser
                        self?.openURLInDefaultBrowser(url: urlToOpen)
                    } else {
                        AppLogger.log("Successfully opened URL \(url) in browser", level: .info, category: .windowManager)
                    }
                }
            } else {
                // Browser not found, fallback to default
                openURLInDefaultBrowser(url: urlToOpen)
            }
        } else {
            // Open in default browser
            openURLInDefaultBrowser(url: urlToOpen)
        }
    }
    
    private func openURLInDefaultBrowser(url: URL) {
        NSWorkspace.shared.open(url)
        AppLogger.log("Opened URL \(url) in default browser", level: .info, category: .windowManager)
    }
}