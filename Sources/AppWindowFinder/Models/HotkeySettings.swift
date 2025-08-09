import Foundation
import AppKit

/// ホットキー設定を管理する構造体
public struct HotkeySettings: Codable, Equatable, Sendable {
    /// キーコード (例: Space = 49)
    public let keyCode: UInt16
    
    /// Modifier flagsのrawValue
    private let modifierFlagsRawValue: UInt
    
    /// Modifier flags
    public var modifierFlags: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: modifierFlagsRawValue) }
    }
    
    public init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlagsRawValue = modifierFlags.rawValue
    }
    
    /// デフォルトのホットキー (Command+Shift+Space)
    public static let `default` = HotkeySettings(
        keyCode: 49, // Space
        modifierFlags: [.command, .shift]
    )
    
    /// ホットキーの説明文字列
    public var displayString: String {
        var components: [String] = []
        
        if modifierFlags.contains(.control) {
            components.append("⌃")
        }
        if modifierFlags.contains(.option) {
            components.append("⌥")
        }
        if modifierFlags.contains(.shift) {
            components.append("⇧")
        }
        if modifierFlags.contains(.command) {
            components.append("⌘")
        }
        
        components.append(keyCodeToString(keyCode))
        
        return components.joined()
    }
    
    /// キーコードを文字列に変換
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 53: return "Escape"
        case 48: return "Tab"
        case 51: return "Delete"
        case 117: return "Forward Delete"
        case 115: return "Home"
        case 119: return "End"
        case 116: return "Page Up"
        case 121: return "Page Down"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            // A-Z (0-25 + 97)
            if keyCode >= 0 && keyCode <= 25 {
                return String(Character(UnicodeScalar(keyCode + 97) ?? UnicodeScalar(97)!))
            }
            return "Key(\(keyCode))"
        }
    }
}

/// UserDefaultsでホットキー設定を管理するためのヘルパー
extension HotkeySettings {
    private static let userDefaultsKey = "HotkeySettings"
    
    /// UserDefaultsから設定を読み込み
    public static func load() -> HotkeySettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(HotkeySettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    /// UserDefaultsに設定を保存
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}