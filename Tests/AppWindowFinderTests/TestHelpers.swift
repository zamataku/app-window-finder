import AppKit
@testable import AppWindowFinder

@MainActor
struct TestCleanup {
    static func cleanupAfterTest() {
        // First, force hide the search window
        SearchWindowController.shared.hide()
        
        // Force close the window if it's still visible
        if let window = SearchWindowController.shared.window {
            window.orderOut(nil)
            window.contentViewController = nil
        }
        
        // Reset application activation policy to accessory
        NSApp.setActivationPolicy(.accessory)
        
        // Close all windows
        for window in NSApp.windows {
            window.orderOut(nil)
            window.close()
        }
        
        // Force terminate any running AppleScripts
        terminateAppleScriptProcesses()
    }
    
    private static func terminateAppleScriptProcesses() {
        // Find and terminate any osascript processes started by tests
        let task = Process()
        task.launchPath = "/usr/bin/pkill"
        task.arguments = ["-f", "osascript.*MyTabTab"]
        try? task.run()
    }
}