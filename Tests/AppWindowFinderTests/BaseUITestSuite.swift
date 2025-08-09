import Testing
import AppKit
@testable import AppWindowFinder

@MainActor
@Suite("UI Tests")
struct BaseUITestSuite {
    init() async {
        // Ensure clean state before test suite
        TestCleanup.cleanupAfterTest()
    }
}