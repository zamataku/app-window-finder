import Foundation
import AppKit

public enum ItemType {
    case app
    case window
    case tab
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
        appPath: String? = nil
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
    }
    
    public static func == (lhs: SearchItem, rhs: SearchItem) -> Bool {
        return lhs.id == rhs.id
    }
}