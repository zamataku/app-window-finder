import Foundation
import AppKit

public enum ItemType {
    case app
    case window
    case tab
    case browserTab  // History-based browser tab
}

public struct SearchItem: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let type: ItemType
    public let appName: String
    public let windowID: Int
    public let tabIndex: Int?
    public let processID: pid_t
    public let icon: NSImage?
    public let bundleIdentifier: String?
    public let appPath: String?
    public let tabURL: String?
    public let url: String?  // For browserTab type
    public let lastAccessTime: Date  // For browserTab sorting
    
    public init(
        title: String,
        subtitle: String,
        type: ItemType,
        appName: String,
        windowID: Int,
        tabIndex: Int? = nil,
        processID: pid_t,
        icon: NSImage? = nil,
        bundleIdentifier: String? = nil,
        appPath: String? = nil,
        tabURL: String? = nil,
        url: String? = nil,
        lastAccessTime: Date = Date(timeIntervalSince1970: min(Date().timeIntervalSince1970, 1893456000.0)) // Cap at 2030-01-01
    ) {
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.appName = appName
        self.windowID = windowID
        self.tabIndex = tabIndex
        self.processID = processID
        self.icon = icon
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
        self.tabURL = tabURL
        self.url = url
        self.lastAccessTime = lastAccessTime
    }
    
    // Convenience initializer for history-based browser tabs
    public init(
        title: String,
        subtitle: String,
        icon: NSImage?,
        type: ItemType,
        windowID: Int,
        processID: pid_t,
        bundleIdentifier: String,
        url: String,
        lastAccessTime: Date
    ) {
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.appName = ""  // Not needed for browserTab
        self.windowID = windowID
        self.tabIndex = nil
        self.processID = processID
        self.icon = icon
        self.bundleIdentifier = bundleIdentifier
        self.appPath = nil
        self.tabURL = url  // Keep compatibility
        self.url = url
        self.lastAccessTime = lastAccessTime
    }
    
    public static func == (lhs: SearchItem, rhs: SearchItem) -> Bool {
        return lhs.id == rhs.id
    }
}