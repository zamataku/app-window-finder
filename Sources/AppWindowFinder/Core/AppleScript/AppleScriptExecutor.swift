import Foundation
import AppKit

/// AppleScript execution abstraction with timeout and error handling
@MainActor
public class AppleScriptExecutor: AppleScriptExecuting {
    public static let shared = AppleScriptExecutor()
    
    private init() {}
    
    public func execute(_ script: String) async throws -> String? {
        return try await executeWithTimeout(script, timeout: 10.0)
    }
    
    public func executeWithTimeout(_ script: String, timeout: TimeInterval) async throws -> String? {
        return try await withThrowingTaskGroup(of: String?.self) { group in
            // Add the script execution task
            group.addTask {
                return try await self.executeScriptInternal(script)
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AppWindowFinderError.appleScriptTimeout
            }
            
            // Return the first result (either success or timeout)
            if let result = try await group.next() {
                group.cancelAll()
                return result
            }
            
            throw AppWindowFinderError.appleScriptTimeout
        }
    }
    
    private func executeScriptInternal(_ script: String) async throws -> String? {
        return try await Task.detached {
            var error: NSDictionary?
            
            guard let scriptObject = NSAppleScript(source: script) else {
                throw AppWindowFinderError.appleScriptCompilationFailed(script: script)
            }
            
            let result = scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                let errorDescription = error.description
                AppLogger.log("AppleScript execution failed: \(errorDescription)", level: .error, category: .general)
                throw AppWindowFinderError.appleScriptExecutionFailed(script: script, error: NSError(domain: "AppleScript", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDescription]))
            }
            
            return result.stringValue
        }.value
    }
    
    // MARK: - Convenience Methods for Common Operations
    
    public func activateApplication(_ bundleIdentifier: String) async throws {
        let script = """
        tell application id "\(bundleIdentifier)"
            activate
        end tell
        """
        
        _ = try await execute(script)
    }
    
    public func activateWindowByPID(_ pid: pid_t) async throws {
        let script = """
        tell application "System Events"
            set frontmost of first process whose unix id is \(pid) to true
        end tell
        """
        
        _ = try await execute(script)
    }
    
    public func getSafariTabs() async throws -> [(title: String, url: String, tabIndex: Int)] {
        let script = """
        tell application "Safari"
            set tabList to {}
            repeat with w from 1 to count of windows
                repeat with t from 1 to count of tabs of window w
                    set tabTitle to name of tab t of window w
                    set tabURL to URL of tab t of window w
                    set end of tabList to {tabTitle, tabURL, t}
                end repeat
            end repeat
            return tabList
        end tell
        """
        
        guard let result = try await execute(script) else {
            return []
        }
        
        return parseSafariTabsResult(result)
    }
    
    public func getChromeTabs(appName: String = "Google Chrome") async throws -> [(title: String, url: String, tabIndex: Int)] {
        let script = """
        tell application "\(appName)"
            set tabList to {}
            repeat with w from 1 to count of windows
                repeat with t from 1 to count of tabs of window w
                    set tabTitle to title of tab t of window w
                    set tabURL to URL of tab t of window w
                    set end of tabList to {tabTitle, tabURL, t}
                end repeat
            end repeat
            return tabList
        end tell
        """
        
        guard let result = try await execute(script) else {
            return []
        }
        
        return parseChromiumTabsResult(result)
    }
    
    public func activateSafariTab(tabIndex: Int, windowIndex: Int = 1) async throws {
        let script = """
        tell application "Safari"
            activate
            set current tab of window \(windowIndex) to tab \(tabIndex) of window \(windowIndex)
        end tell
        """
        
        _ = try await execute(script)
    }
    
    public func activateChromeTab(tabIndex: Int, windowIndex: Int = 1, appName: String = "Google Chrome") async throws {
        let script = """
        tell application "\(appName)"
            activate
            set active tab index of window \(windowIndex) to \(tabIndex)
        end tell
        """
        
        _ = try await execute(script)
    }
    
    public func requestAutomationPermission(for bundleIdentifier: String) async -> Bool {
        let script = """
        tell application id "\(bundleIdentifier)"
            try
                get name
                return true
            on error
                return false
            end try
        end tell
        """
        
        do {
            let result = try await execute(script)
            return result?.contains("true") == true
        } catch {
            return false
        }
    }
    
    // MARK: - Private Parsing Methods
    
    private func parseSafariTabsResult(_ result: String) -> [(title: String, url: String, tabIndex: Int)] {
        var tabs: [(title: String, url: String, tabIndex: Int)] = []
        
        // Simple parsing - in production you might want more robust parsing
        let lines = result.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // Parse format: "title, url, index"
                let components = trimmed.components(separatedBy: ", ")
                if components.count >= 3,
                   let tabIndex = Int(components[2]) {
                    tabs.append((
                        title: components[0],
                        url: components[1],
                        tabIndex: tabIndex
                    ))
                }
            }
        }
        
        return tabs
    }
    
    private func parseChromiumTabsResult(_ result: String) -> [(title: String, url: String, tabIndex: Int)] {
        // Similar to Safari parsing but might have different format
        return parseSafariTabsResult(result)
    }
}

// MARK: - Result-based API for non-async contexts

extension AppleScriptExecutor {
    public func executeSync(_ script: String) -> AWFResult<String?> {
        var error: NSDictionary?
        
        guard let scriptObject = NSAppleScript(source: script) else {
            return .failure(.appleScriptCompilationFailed(script: script))
        }
        
        let result = scriptObject.executeAndReturnError(&error)
        
        if let error = error {
            let errorDescription = error.description
            AppLogger.log("AppleScript execution failed: \(errorDescription)", level: .error, category: .general)
            return .failure(.appleScriptExecutionFailed(script: script, error: NSError(domain: "AppleScript", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDescription])))
        }
        
        return .success(result.stringValue)
    }
}

