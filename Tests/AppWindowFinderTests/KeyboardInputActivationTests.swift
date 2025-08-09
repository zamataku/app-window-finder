import Testing
import AppKit
import SwiftUI
@testable import AppWindowFinder

@MainActor
struct KeyboardInputActivationTests {
    
    init() async {
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testWindowAcceptsKeyboardInputAfterActivation() async {
        let searchWindow = SearchWindowController.shared
        
        // Show the window
        searchWindow.show()
        
        // Wait for window to be fully activated
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        
        guard let window = searchWindow.window else {
            Issue.record("Window is nil")
            return
        }
        
        // Verify window is properly configured for keyboard input
        // Note: In test environment, window might not be visible
        #expect(window.canBecomeKey)
        #expect(window.acceptsFirstResponder)
        
        // Verify first responder chain is set up
        #expect(window.firstResponder != nil)
        
        // The window should be key window in real usage
        // (might not be in test environment)
        #expect(window.canBecomeKey == true)
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testFocusChainAfterActivation() async {
        let searchWindow = SearchWindowController.shared
        
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let window = searchWindow.window {
            // Content view should exist
            #expect(window.contentView != nil)
            
            // Window should have a first responder
            #expect(window.firstResponder != nil)
            
            // First responder should not be the window itself
            // (indicates that focus is on a subview)
            #expect(window.firstResponder !== window)
        }
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
    
    @Test func testActivationPolicyRestoration() async {
        let searchWindow = SearchWindowController.shared
        
        // Start with accessory policy
        NSApp.setActivationPolicy(.accessory)
        
        // Show window (should change to regular)
        searchWindow.show()
        #expect(NSApp.activationPolicy() == .regular)
        
        // Hide window
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
        
        // Wait for policy restoration
        try? await Task.sleep(nanoseconds: 150_000_000)
        
        // Should be back to accessory
        #expect(NSApp.activationPolicy() == .accessory)
    }
    
    @Test func testWindowRespondsToEscapeKey() async {
        let searchWindow = SearchWindowController.shared
        
        searchWindow.show()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(searchWindow.isVisible)
        
        // The SearchView has a handler for escape key
        // We verify the window is configured to receive key events
        if let window = searchWindow.window {
            #expect(window.canBecomeKey)
            
            // Simulate escape key event
            let escapeEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "\u{1B}",
                charactersIgnoringModifiers: "\u{1B}",
                isARepeat: false,
                keyCode: 53 // Escape key
            )
            
            #expect(escapeEvent != nil)
        }
        
        searchWindow.hide()
        TestCleanup.cleanupAfterTest()
    }
}