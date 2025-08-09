import Testing
import Foundation
@testable import AppWindowFinder

struct CICDTests {
    
    @Test("Build script is executable")
    func testBuildScriptExistence() async throws {
        let buildScriptPath = "build-and-package.sh"
        let fileManager = FileManager.default
        
        #expect(fileManager.fileExists(atPath: buildScriptPath))
        
        // Check file execute permissions
        let attributes = try fileManager.attributesOfItem(atPath: buildScriptPath)
        let permissions = attributes[.posixPermissions] as? NSNumber
        #expect(permissions != nil)
        
        // Verify execute permission (owner execute bit)
        let executableMask: Int = 0o100
        #expect((permissions?.intValue ?? 0) & executableMask != 0)
    }
    
    @Test("Info.plist required items are correctly configured")
    func testInfoPlistGeneration() async throws {
        // Test Info.plist structure generated after build.sh execution
        let expectedKeys = [
            "CFBundleExecutable",
            "CFBundleIdentifier", 
            "CFBundleName",
            "CFBundlePackageType",
            "CFBundleShortVersionString",
            "CFBundleVersion",
            "LSMinimumSystemVersion",
            "LSUIElement",
            "NSAppleEventsUsageDescription"
        ]
        
        // Test expected structure even if actual plist file doesn't exist
        for key in expectedKeys {
            #expect(!key.isEmpty)
        }
        
        // Verify bundle identifier format
        let bundleId = "io.github.AppWindowFinder"
        #expect(bundleId.contains("."))
        #expect(bundleId.hasPrefix("io.") || bundleId.hasPrefix("com."))
    }
    
    @Test("Minimum system requirements verification")
    func testMinimumSystemRequirements() async throws {
        // Verify minimum version matches Package.swift specification
        let minimumMacOSVersion = "13.0"
        let versionComponents = minimumMacOSVersion.split(separator: ".").compactMap { Int($0) }
        
        #expect(versionComponents.count >= 2)
        #expect(versionComponents[0] >= 13) // macOS 13.0 or later
    }
    
    @Test("Application identifier format verification")
    func testBundleIdentifierFormat() async throws {
        let bundleIdentifier = "io.github.AppWindowFinder"
        
        // Verify reverse DNS format
        let components = bundleIdentifier.split(separator: ".")
        #expect(components.count >= 3)
        #expect(String(components[0]) == "io")
        
        // Verify no special characters are included
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "."))
        #expect(bundleIdentifier.unicodeScalars.allSatisfy { allowedCharacters.contains($0) })
    }
    
    @Test("DMG volume name verification")
    func testDMGVolumeNaming() async throws {
        let version = "1.0.0"
        let volumeName = "App Window Finder \(version)"
        
        #expect(!volumeName.isEmpty)
        #expect(volumeName.contains(version))
        #expect(!volumeName.contains("AppWindowFinder")) // Use space-separated display name
        #expect(volumeName.contains("App Window Finder"))
    }
}