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
print("⌨️ Command+Shift+Space を押してテストしてください")
print("終了するには Control+C を押してください\n")

var eventCount = 0

// ローカルイベントモニター（アプリがフォアグラウンドの場合）
let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    let isCmd = event.modifierFlags.contains(.command)
    let isShift = event.modifierFlags.contains(.shift)
    let isSpace = event.keyCode == 49 // Space key

    print("📍 ローカルキーイベント: keyCode=\(event.keyCode), Cmd=\(isCmd), Shift=\(isShift)")

    if isCmd && isShift && isSpace {
        eventCount += 1
        print("✅ ホットキー検出！ (ローカル) 回数: \(eventCount)")
        return nil // イベントを消費
    }
    return event
}

// グローバルイベントモニター（他のアプリがフォアグラウンドの場合）
let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
    let isCmd = event.modifierFlags.contains(.command)
    let isShift = event.modifierFlags.contains(.shift)
    let isSpace = event.keyCode == 49 // Space key

    print("🌍 グローバルキーイベント: keyCode=\(event.keyCode), Cmd=\(isCmd), Shift=\(isShift)")

    if isCmd && isShift && isSpace {
        eventCount += 1
        print("✅ ホットキー検出！ (グローバル) 回数: \(eventCount)")
    }
}

print("📢 モニター登録完了")
print("   - ローカルモニター: \(localMonitor != nil ? "✅" : "❌")")
print("   - グローバルモニター: \(globalMonitor != nil ? "✅" : "❌")")

// メインループを実行
RunLoop.current.run()
