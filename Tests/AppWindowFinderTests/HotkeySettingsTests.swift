import Testing
import AppKit
@testable import AppWindowFinder

@Suite("HotkeySettings Tests") 
struct HotkeySettingsTests {
    
    @Test("Default settings should be Command+Shift+Space")
    func testDefaultSettings() {
        let defaultSettings = HotkeySettings.default
        
        #expect(defaultSettings.keyCode == 49) // Space key
        #expect(defaultSettings.modifierFlags.contains(.command))
        #expect(defaultSettings.modifierFlags.contains(.shift))
        #expect(!defaultSettings.modifierFlags.contains(.option))
        #expect(!defaultSettings.modifierFlags.contains(.control))
    }
    
    @Test("Display string should format correctly")
    func testDisplayString() {
        let commandShiftSpace = HotkeySettings(keyCode: 49, modifierFlags: [.command, .shift])
        #expect(commandShiftSpace.displayString == "⇧⌘Space")
        
        let controlOptionA = HotkeySettings(keyCode: 0, modifierFlags: [.control, .option])
        #expect(controlOptionA.displayString == "⌃⌥a")
        
        let commandEscape = HotkeySettings(keyCode: 53, modifierFlags: [.command])
        #expect(commandEscape.displayString == "⌘Escape")
    }
    
    @Test("Settings should be encodable and decodable")
    func testCodability() throws {
        let originalSettings = HotkeySettings(keyCode: 123, modifierFlags: [.command, .option, .shift])
        
        let encoded = try JSONEncoder().encode(originalSettings)
        let decodedSettings = try JSONDecoder().decode(HotkeySettings.self, from: encoded)
        
        #expect(decodedSettings == originalSettings)
        #expect(decodedSettings.keyCode == originalSettings.keyCode)
        #expect(decodedSettings.modifierFlags == originalSettings.modifierFlags)
    }
    
    @Test("UserDefaults save and load should work")
    func testUserDefaultsSaveLoad() {
        // Clear any existing settings
        UserDefaults.standard.removeObject(forKey: "HotkeySettings")
        
        // Test loading default when no settings exist
        let loadedDefault = HotkeySettings.load()
        #expect(loadedDefault == .default)
        
        // Test saving and loading custom settings
        let customSettings = HotkeySettings(keyCode: 36, modifierFlags: [.command, .control])
        customSettings.save()
        
        let loadedCustom = HotkeySettings.load()
        #expect(loadedCustom == customSettings)
        #expect(loadedCustom.keyCode == 36)
        #expect(loadedCustom.modifierFlags.contains(.command))
        #expect(loadedCustom.modifierFlags.contains(.control))
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "HotkeySettings")
    }
    
    @Test("Equality should work correctly")
    func testEquality() {
        let settings1 = HotkeySettings(keyCode: 49, modifierFlags: [.command, .shift])
        let settings2 = HotkeySettings(keyCode: 49, modifierFlags: [.command, .shift])
        let settings3 = HotkeySettings(keyCode: 36, modifierFlags: [.command, .shift])
        let settings4 = HotkeySettings(keyCode: 49, modifierFlags: [.command, .option])
        
        #expect(settings1 == settings2)
        #expect(settings1 != settings3)
        #expect(settings1 != settings4)
    }
    
    @Test("Key code to string conversion should work for common keys")
    func testKeyCodeToString() {
        let spaceSettings = HotkeySettings(keyCode: 49, modifierFlags: [])
        #expect(spaceSettings.displayString.contains("Space"))
        
        let returnSettings = HotkeySettings(keyCode: 36, modifierFlags: [])
        #expect(returnSettings.displayString.contains("Return"))
        
        let escapeSettings = HotkeySettings(keyCode: 53, modifierFlags: [])
        #expect(escapeSettings.displayString.contains("Escape"))
        
        let f1Settings = HotkeySettings(keyCode: 122, modifierFlags: [])
        #expect(f1Settings.displayString.contains("F1"))
    }
}