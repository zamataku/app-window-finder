#!/usr/bin/env swift

import Cocoa
import ApplicationServices

// アクセシビリティ権限チェック
let hasPermission = AXIsProcessTrusted()
print("アクセシビリティ権限: \(hasPermission ? "✅ 有効" : "❌ 無効")")

if !hasPermission {
    print("\n⚠️ アクセシビリティ権限が必要です")
    print("システム設定 > プライバシーとセキュリティ > アクセシビリティ から権限を付与してください")
    
    // 権限要求ダイアログを表示
    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
    exit(1)
}

// ホットキー登録のテスト
print("\n🔧 ホットキー登録テスト開始...")
print("⌨️ Command+Shift+Space (⌘⇧Space) を押してテストしてください")
print("終了するには Control+C を押してください\n")

var eventCount = 0

// デバッグ用: モディファイヤフラグの値を表示
let cmdFlag = NSEvent.ModifierFlags.command.rawValue
let shiftFlag = NSEvent.ModifierFlags.shift.rawValue
let cmdShiftFlag = NSEvent.ModifierFlags([.command, .shift]).rawValue

print("📊 モディファイヤフラグ値:")
print("   Command: \(String(format: "0x%X", cmdFlag))")
print("   Shift: \(String(format: "0x%X", shiftFlag))")
print("   Command+Shift: \(String(format: "0x%X", cmdShiftFlag))")
print("")

// ローカルイベントモニター（アプリがフォアグラウンドの場合）
let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let isCmd = modifiers.contains(.command)
    let isShift = modifiers.contains(.shift)
    let isSpace = event.keyCode == 49 // Space key
    
    // すべてのキーダウンイベントをログ
    if event.keyCode == 49 || isCmd || isShift {
        print("📍 ローカル: keyCode=\(event.keyCode), Cmd=\(isCmd), Shift=\(isShift), modifiers=\(String(format: "0x%X", modifiers.rawValue))")
    }
    
    // Command+Shift+Space の判定
    if isCmd && isShift && isSpace {
        eventCount += 1
        print("✅ ホットキー検出！ (ローカル) 回数: \(eventCount)")
        return nil // イベントを消費
    }
    return event
}

// グローバルイベントモニター（他のアプリがフォアグラウンドの場合）
let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let isCmd = modifiers.contains(.command)
    let isShift = modifiers.contains(.shift)
    let isSpace = event.keyCode == 49 // Space key
    
    // すべてのキーダウンイベントをログ
    if event.keyCode == 49 || isCmd || isShift {
        print("🌍 グローバル: keyCode=\(event.keyCode), Cmd=\(isCmd), Shift=\(isShift), modifiers=\(String(format: "0x%X", modifiers.rawValue))")
    }
    
    // Command+Shift+Space の判定
    if isCmd && isShift && isSpace {
        eventCount += 1
        print("✅ ホットキー検出！ (グローバル) 回数: \(eventCount)")
    }
}

print("📢 モニター登録完了")
print("   - ローカルモニター: \(localMonitor != nil ? "✅" : "❌")")
print("   - グローバルモニター: \(globalMonitor != nil ? "✅" : "❌")")
print("\n待機中... Command+Shift+Space を押してください\n")

// メインループを実行
RunLoop.current.run()

