import Cocoa
import ApplicationServices

@MainActor
public class AccessibilityHelper {
    static let shared = AccessibilityHelper()
    
    private init() {}
    
    /// Check if the app has accessibility permissions
    public func hasAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Request accessibility permissions with explanation
    public func requestAccessibilityPermission() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Accessibility Permission Required", comment: "Permission alert title")
        alert.informativeText = NSLocalizedString("This app needs accessibility permission to switch between windows.", comment: "Permission alert message")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Open System Preferences", comment: "Open settings button"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel button"))
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open accessibility preferences
            let promptKey = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
            let options: NSDictionary = [promptKey: true]
            AXIsProcessTrustedWithOptions(options)
        }
    }
    
    /// Check permissions and request if needed, returns true if permissions are granted
    public func checkAndRequestPermissionsIfNeeded() -> Bool {
        if !hasAccessibilityPermission() {
            requestAccessibilityPermission()
            return false
        }
        return true
    }
    
    /// Get a user-friendly description of why the permission is needed
    public func getPermissionDescription() -> String {
        return NSLocalizedString("This app needs accessibility permission to switch between windows.", comment: "Permission description")
    }
}