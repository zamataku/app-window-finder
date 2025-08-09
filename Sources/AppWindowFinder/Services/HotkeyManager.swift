import Foundation
import AppKit
import ApplicationServices

@MainActor
public class HotkeyManager {
    public static let shared = HotkeyManager()
    private var monitor: Any?
    private var isRegistered = false
    private var currentSettings: HotkeySettings = .default
    
    private init() {
        // Load saved settings
        currentSettings = HotkeySettings.load()
    }
    
    public func registerHotkey(handler: @escaping () -> Void) {
        // Note: Accessibility permissions should be checked before calling this method
        AppLogger.log("Starting hotkey registration process", level: .info, category: .hotkeyManager)
        AppLogger.log("Hotkey settings: keyCode=\(currentSettings.keyCode), modifiers=\(currentSettings.modifierFlags.rawValue), display=\(currentSettings.displayString)", level: .info, category: .hotkeyManager)
        
        // Unregister existing hotkey if any
        unregisterHotkey()
        
        AppLogger.log("Registering global hotkey: \(currentSettings.displayString)", level: .info, category: .hotkeyManager)
        
        // Use both local and global monitors for better reliability
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            AppLogger.log("Local key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)", level: .debug, category: .hotkeyManager)
            if event.modifierFlags.contains(self.currentSettings.modifierFlags) && event.keyCode == self.currentSettings.keyCode {
                AppLogger.log("Local hotkey MATCHED - triggering handler", level: .info, category: .hotkeyManager)
                handler()
                return nil // Consume the event
            }
            return event
        }
        
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            AppLogger.log("Global key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)", level: .debug, category: .hotkeyManager)
            if event.modifierFlags.contains(self.currentSettings.modifierFlags) && event.keyCode == self.currentSettings.keyCode {
                AppLogger.log("Global hotkey MATCHED - triggering handler", level: .info, category: .hotkeyManager)
                DispatchQueue.main.async {
                    handler()
                }
            }
        }
        
        // Store both monitors
        monitor = (localMonitor, globalMonitor)
        isRegistered = true
        
        AppLogger.log("Hotkey registration completed successfully", level: .info, category: .hotkeyManager)
        AppLogger.log("Registration status: isRegistered = \(isRegistered)", level: .info, category: .hotkeyManager)
    }
    
    public func unregisterHotkey() {
        if let monitors = monitor as? (Any, Any) {
            NSEvent.removeMonitor(monitors.0)
            NSEvent.removeMonitor(monitors.1)
            self.monitor = nil
            isRegistered = false
            AppLogger.log("Hotkey unregistered", level: .info, category: .hotkeyManager)
        }
    }
    
    // MARK: - Accessibility Permissions
    
    public func checkAccessibilityPermissions() -> Bool {
        let isAccessibilityEnabled = AXIsProcessTrusted()
        
        AppLogger.log("Accessibility permissions check: \(isAccessibilityEnabled ? "granted" : "denied")", 
                     level: isAccessibilityEnabled ? .info : .warning, 
                     category: .hotkeyManager)
        
        return isAccessibilityEnabled
    }
    
    public func requestAccessibilityPermissions() {
        AppLogger.log("Requesting accessibility permissions", level: .info, category: .hotkeyManager)
        
        // Show system dialog for accessibility permissions
        _ = AXIsProcessTrusted()  // This will trigger the system dialog if needed
        
        // Show user guidance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showPermissionAlert()
        }
    }
    
    @MainActor
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        AppWindowFinder needs accessibility access to register global hotkeys.
        
        Steps to enable:
        1. Open System Preferences
        2. Go to Security & Privacy > Privacy > Accessibility
        3. Click the lock to make changes
        4. Add AppWindowFinder to the list
        5. Restart the app
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
    
    // MARK: - Debug Information
    
    public func getDebugInfo() -> [String: Any] {
        return [
            "isRegistered": isRegistered,
            "hasAccessibilityPermissions": checkAccessibilityPermissions(),
            "monitorActive": monitor != nil
        ]
    }
    
    // MARK: - Status Check
    
    public func validateHotkeySetup() -> Bool {
        let hasPermissions = checkAccessibilityPermissions()
        let isMonitorActive = monitor != nil
        
        AppLogger.log("Hotkey setup validation - Permissions: \(hasPermissions), Monitor: \(isMonitorActive)", 
                     level: .info, category: .hotkeyManager)
        
        return hasPermissions && isMonitorActive
    }
    
    // MARK: - Hotkey Settings Management
    
    /// Get current hotkey settings
    public func getCurrentSettings() -> HotkeySettings {
        return currentSettings
    }
    
    /// Update hotkey settings
    public func updateSettings(_ newSettings: HotkeySettings, handler: @escaping () -> Void) {
        AppLogger.log("Updating hotkey settings from \(currentSettings.displayString) to \(newSettings.displayString)", 
                     level: .info, category: .hotkeyManager)
        
        // Update settings
        currentSettings = newSettings
        currentSettings.save()
        
        // Re-register hotkey
        if isRegistered {
            registerHotkey(handler: handler)
        }
    }
    
    /// Reset to default settings
    public func resetToDefault(handler: @escaping () -> Void) {
        updateSettings(.default, handler: handler)
    }
}