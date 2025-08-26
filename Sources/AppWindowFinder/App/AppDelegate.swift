import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        AppLogger.log("App launched successfully", level: .info, category: .general)
        
        // Setup menu bar first
        setupMenuBar()
        
        // Check accessibility permissions using the new helper
        let hasPermissions = AccessibilityHelper.shared.hasAccessibilityPermission()
        AppLogger.log("Accessibility permissions status: \(hasPermissions)", level: .info, category: .general)
        
        if hasPermissions {
            AppLogger.log("Accessibility permissions granted, registering hotkey", level: .info, category: .general)
            registerHotkeyWithValidation()
        } else {
            AppLogger.log("Accessibility permissions missing, requesting permission", level: .warning, category: .general)
            // Request permissions through the helper
            AccessibilityHelper.shared.requestAccessibilityPermission()
            
            // Schedule periodic permission checks to register hotkey once granted
            startPermissionWatcher()
        }
        
        // アプリ起動後にブラウザ権限もプリエンプティブにリクエスト
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            WindowManager.shared.requestBrowserPermissions()
        }
    }
    
    @MainActor
    private func registerHotkeyWithValidation() {
        // Register hotkey
        HotkeyManager.shared.registerHotkey {
            // Refresh windows before showing
            WindowManager.shared.refreshWindows()
            // Always show the window on hotkey press (don't toggle)
            SearchWindowController.shared.show()
        }
        
        // Validate setup after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let isValid = HotkeyManager.shared.validateHotkeySetup()
            AppLogger.log("Initial setup validation: \(isValid ? "success" : "failed")", 
                         level: isValid ? .info : .error, 
                         category: .general)
            
            if !isValid {
                self.showStartupGuide()
            }
        }
    }
    
    private func startPermissionWatcher() {
        // Check permissions periodically and register hotkey once granted
        _ = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else { 
                    Task { @MainActor in timer.invalidate() }
                    return 
                }
                if AccessibilityHelper.shared.hasAccessibilityPermission() {
                    AppLogger.log("Accessibility permissions granted during runtime, registering hotkey", level: .info, category: .general)
                    self.registerHotkeyWithValidation()
                    Task { @MainActor in
                        timer.invalidate() // Stop checking once permissions are granted
                    }
                }
            }
        }
        
        // Show a more prominent guide if permissions are not granted
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            self?.showPermissionGuide()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregisterHotkey()
    }
    
    @MainActor
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "AppWindowFinder")
            button.toolTip = "AppWindowFinder - Press \(HotkeyManager.shared.getCurrentSettings().displayString) to search"
        }
        
        let menu = NSMenu()
        
        // Current hotkey display
        let hotkeyItem = NSMenuItem(title: "Hotkey: \(HotkeyManager.shared.getCurrentSettings().displayString)", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Browser permissions
        let browserPermissionsItem = NSMenuItem(title: "Request Browser Permissions", action: #selector(requestBrowserPermissions), keyEquivalent: "")
        browserPermissionsItem.target = self
        menu.addItem(browserPermissionsItem)
        
        // Settings
        let settingsItem = NSMenuItem(title: "Hotkey Settings...", action: #selector(showHotkeySettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // About
        let aboutItem = NSMenuItem(title: "About AppWindowFinder", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit AppWindowFinder", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @MainActor
    @objc private func requestBrowserPermissions() {
        // AppDelegate から直接 NSAppleScript で実行
        let supportedBrowsers = ["Google Chrome", "Safari", "Microsoft Edge", "Brave Browser"]
        let runningApps = NSWorkspace.shared.runningApplications
        
        var foundBrowsers: [String] = []
        var permissionRequested = false
        
        for app in runningApps {
            if let appName = app.localizedName,
               supportedBrowsers.contains(appName) {
                foundBrowsers.append(appName)
                
                // NSAppleScript を直接使用して AppWindowFinder からのリクエストとして認識させる
                let script = """
                tell application "\(appName)"
                    get name
                end tell
                """
                
                var error: NSDictionary?
                guard let scriptObject = NSAppleScript(source: script) else {
                    AppLogger.log("Failed to create script for \(appName)", level: .error, category: .general)
                    continue
                }
                
                AppLogger.log("Requesting permission for \(appName) from AppWindowFinder", level: .info, category: .general)
                let result = scriptObject.executeAndReturnError(&error)
                
                if let error = error {
                    AppLogger.log("Permission request error for \(appName): \(error)", level: .warning, category: .general)
                    
                    if let errorCode = error["NSAppleScriptErrorNumber"] as? Int, errorCode == -1743 {
                        permissionRequested = true
                        AppLogger.log("Permission denied for \(appName), user should see prompt", level: .info, category: .general)
                    }
                } else {
                    AppLogger.log("Permission granted for \(appName): \(result)", level: .info, category: .general)
                }
            }
        }
        
        let alert = NSAlert()
        alert.messageText = "Browser Permissions"
        
        if foundBrowsers.isEmpty {
            alert.informativeText = """
            No supported browsers are currently running.
            
            Please start browsers (Chrome, Safari, Edge, or Brave) and try again.
            """
        } else {
            let statusMessage = permissionRequested ? 
                "Permission dialogs should have appeared for some browsers." :
                "All browsers already have permissions granted."
            
            alert.informativeText = """
            Found running browsers: \(foundBrowsers.joined(separator: ", "))
            
            \(statusMessage)
            
            Please check System Preferences > Security & Privacy > Privacy > Automation to verify AppWindowFinder has permission to control browsers.
            """
        }
        
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @MainActor
    @objc private func showHotkeySettings() {
        if settingsWindow == nil {
            let settingsView = HotkeySettingsView(
                currentSettings: HotkeyManager.shared.getCurrentSettings()
            ) { [weak self] newSettings in
                // Update hotkey settings
                HotkeyManager.shared.updateSettings(newSettings) {
                    WindowManager.shared.refreshWindows()
                    // Always show the window on hotkey press (don't toggle)
                    SearchWindowController.shared.show()
                }
                
                // Update menu bar tooltip and display
                self?.updateMenuBarDisplay()
                self?.settingsWindow = nil
            }
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Hotkey Settings"
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.center()
            settingsWindow?.delegate = self
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @MainActor
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "AppWindowFinder"
        alert.informativeText = """
        Version 1.0.0
        
        A powerful macOS app for quickly switching between applications, windows, and browser tabs using intelligent fuzzy search.
        
        Current Hotkey: \(HotkeyManager.shared.getCurrentSettings().displayString)
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @MainActor
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @MainActor
    private func updateMenuBarDisplay() {
        guard let button = statusItem?.button,
              let menu = statusItem?.menu else { return }
        
        let currentSettings = HotkeyManager.shared.getCurrentSettings()
        button.toolTip = "AppWindowFinder - Press \(currentSettings.displayString) to search"
        
        // Update first menu item
        if let firstItem = menu.item(at: 0) {
            firstItem.title = "Hotkey: \(currentSettings.displayString)"
        }
    }
    
    @MainActor
    private func showStartupGuide() {
        let currentHotkey = HotkeyManager.shared.getCurrentSettings().displayString
        let alert = NSAlert()
        alert.messageText = "Welcome to AppWindowFinder!"
        alert.informativeText = """
        To use the global hotkey (\(currentHotkey)), please:

        1. Grant Accessibility permissions in System Preferences
        2. Restart the app after granting permissions

        The app is currently running in the background. You can find it in the menu bar or configure hotkey settings there.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Continue")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    @MainActor
    private func showPermissionGuide() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Accessibility Permission Required", comment: "Permission required title")
        alert.informativeText = """
        AppWindowFinder requires accessibility permissions to:
        • Switch between windows
        • Read window information
        • Activate applications
        
        Please grant permission in System Preferences and restart the app.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Open System Preferences", comment: "Open preferences button"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == settingsWindow {
            settingsWindow = nil
        }
    }
}