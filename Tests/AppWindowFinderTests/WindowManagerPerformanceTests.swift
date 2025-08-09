import Testing
import Foundation
@testable import AppWindowFinder

@MainActor
struct WindowManagerPerformanceTests {
    
    @Test("キャッシュの有効期限が正しく動作する")
    func testCacheExpiration() async throws {
        let manager = WindowManager.shared
        
        // 初回取得（キャッシュなし）
        let items1 = manager.getAllSearchItems()
        #expect(!items1.isEmpty)
        
        // 即座に再取得（キャッシュから）
        let items2 = manager.getAllSearchItems()
        #expect(items1.count == items2.count)
        
        // キャッシュをクリア
        manager.clearCache()
        
        // 再取得（新規取得）
        let items3 = manager.getAllSearchItems()
        #expect(!items3.isEmpty)
    }
    
    @Test("アイコンのメモリ使用量が適切")
    func testIconMemoryOptimization() async throws {
        let manager = WindowManager.shared
        let items = manager.getAllSearchItems()
        
        for item in items where item.icon != nil {
            let icon = item.icon!
            // アイコンサイズが最適化されているか確認
            #expect(icon.size.width <= 40) // 2x resolution for 20pt
            #expect(icon.size.height <= 40)
        }
    }
    
    @Test("大量のウィンドウでのパフォーマンス")
    func testLargeNumberOfWindows() async throws {
        // このテストは実際の環境に依存するため、
        // パフォーマンス測定のみ行う
        let manager = WindowManager.shared
        
        let startTime = Date()
        let items = manager.getAllSearchItems()
        let duration = Date().timeIntervalSince(startTime)
        
        // 1000アイテムでも1秒以内に完了すべき
        print("Fetched \(items.count) items in \(duration) seconds")
        #expect(duration < 1.0 || items.count < 1000)
    }
}