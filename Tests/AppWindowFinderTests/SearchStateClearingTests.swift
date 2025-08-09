import Testing
import SwiftUI
import AppKit
@testable import AppWindowFinder

@MainActor
struct SearchStateClearingTests {
    
    init() async {
        // Ensure clean state before each test
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testViewRecreationClearsState() async {
        let searchWindow = SearchWindowController.shared
        
        // Hide window first
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Show window - this should create fresh view
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify window has content
        #expect(searchWindow.window?.contentViewController != nil)
        
        // Hide window
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Show again - should have fresh view
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Content view should be recreated
        #expect(searchWindow.window?.contentViewController != nil)
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testWindowActivationAndFocus() async {
        let searchWindow = SearchWindowController.shared
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Show window
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        if let window = searchWindow.window {
            // Window should be configured for keyboard input
            #expect(window.canBecomeKey)
            #expect(window.acceptsFirstResponder)
            #expect(window.level == .floating)
            
            // Window should have content
            #expect(window.contentViewController != nil)
            
            // First responder should be set
            #expect(window.firstResponder != nil)
        }
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testActivationPolicyChanges() async {
        let searchWindow = SearchWindowController.shared
        
        // Initial state
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        NSApp.setActivationPolicy(.accessory)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Show window - should change to regular
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(NSApp.activationPolicy() == .regular)
        
        // Hide window - should restore accessory
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(NSApp.activationPolicy() == .accessory)
    }
}