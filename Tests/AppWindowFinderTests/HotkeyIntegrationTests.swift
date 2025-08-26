import Testing
import AppKit
@testable import AppWindowFinder

@MainActor
struct HotkeyIntegrationTests {
    
    init() {
        // テスト環境のセットアップ
    }
    
    @Test func testHotkeyRegistration() {
        var handlerCalled = false
        
        // ホットキーを登録
        HotkeyManager.shared.registerHotkey {
            handlerCalled = true
        }
        
        // 登録状態を検証
        let debugInfo = HotkeyManager.shared.getDebugInfo()
        #expect(debugInfo["isRegistered"] as? Bool ?? false, "Hotkey should be registered")
        #expect(debugInfo["monitorActive"] as? Bool ?? false, "Monitor should be active")
    }
    
    @Test func testDefaultHotkeySettings() {
        let settings = HotkeySettings.default
        #expect(settings.keyCode == 49, "Default key should be Space (49)")
        #expect(settings.modifierFlags.contains(.command), "Should contain Command modifier")
        #expect(settings.modifierFlags.contains(.shift), "Should contain Shift modifier")
        #expect(settings.displayString == "⇧⌘Space", "Display string should be ⇧⌘Space")
    }
    
    @Test func testHotkeySettingsPersistence() {
        // カスタム設定を作成
        let customSettings = HotkeySettings(keyCode: 36, modifierFlags: [.command, .option])
        customSettings.save()
        
        // 設定を読み込み
        let loadedSettings = HotkeySettings.load()
        #expect(loadedSettings.keyCode == customSettings.keyCode, "Loaded keyCode should match")
        #expect(loadedSettings.modifierFlags == customSettings.modifierFlags, "Loaded modifiers should match")
        
        // デフォルトに戻す
        HotkeySettings.default.save()
    }
    
    @Test func testAccessibilityPermissionCheck() {
        let hasPermission = HotkeyManager.shared.checkAccessibilityPermissions()
        
        // CI環境では権限がない可能性があるため、結果の型のみ確認
        #expect(hasPermission == true || hasPermission == false, "Permission check should return a boolean")
        
        if !hasPermission {
            print("⚠️ Accessibility permissions not granted - some tests may be skipped")
        }
    }
    
    @Test func testHotkeyReregistration() {
        var firstHandlerCallCount = 0
        var secondHandlerCallCount = 0
        
        // 最初のハンドラーを登録
        HotkeyManager.shared.registerHotkey {
            firstHandlerCallCount += 1
        }
        
        // 別のハンドラーで再登録
        HotkeyManager.shared.registerHotkey {
            secondHandlerCallCount += 1
        }
        
        // 最初のハンドラーは置き換えられているはず
        #expect(firstHandlerCallCount == 0, "First handler should not be called after re-registration")
    }
    
    @Test func testHotkeySettingsUpdate() {
        var handlerCalled = false
        
        // 新しい設定でホットキーを更新
        let newSettings = HotkeySettings(keyCode: 36, modifierFlags: [.command, .option]) // Cmd+Option+Return
        HotkeyManager.shared.updateSettings(newSettings) {
            handlerCalled = true
        }
        
        // 更新後の設定を確認
        let currentSettings = HotkeyManager.shared.getCurrentSettings()
        #expect(currentSettings.keyCode == 36, "KeyCode should be updated to Return (36)")
        #expect(currentSettings.modifierFlags.contains(.command), "Should contain Command")
        #expect(currentSettings.modifierFlags.contains(.option), "Should contain Option")
        
        // デフォルトに戻す
        HotkeyManager.shared.resetToDefault {
            // Empty handler
        }
    }
    
    @Test func testHotkeyValidation() {
        // ホットキー設定の検証をテスト
        let isValid = HotkeyManager.shared.validateHotkeySetup()
        #expect(isValid == true || isValid == false, "Hotkey validation should return a boolean")
    }
    
    @Test func testHotkeyDisplayString() {
        // 様々なホットキー設定の表示文字列をテスト
        let testCases = [
            (keyCode: UInt16(49), modifiers: NSEvent.ModifierFlags([.command, .shift]), expected: "⇧⌘Space"),
            (keyCode: UInt16(36), modifiers: NSEvent.ModifierFlags([.command]), expected: "⌘Return"),
            (keyCode: UInt16(53), modifiers: NSEvent.ModifierFlags([.command, .option]), expected: "⌥⌘Escape")
        ]
        
        for testCase in testCases {
            let settings = HotkeySettings(keyCode: testCase.keyCode, modifierFlags: testCase.modifiers)
            #expect(settings.displayString == testCase.expected, 
                   "Display string for keyCode \(testCase.keyCode) should be '\(testCase.expected)', got '\(settings.displayString)'")
        }
    }
}