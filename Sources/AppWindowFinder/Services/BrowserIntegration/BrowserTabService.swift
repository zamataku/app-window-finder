import Foundation
import AppKit

actor AsyncAppleScriptExecutor {
    func execute(_ source: String) async throws -> NSAppleEventDescriptor? {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(throwing: AppleScriptError.scriptCreationFailed)
                    return
                }
                
                let result = script.executeAndReturnError(&error)
                
                if let error = error {
                    let nsError = NSError(domain: "com.apple.AppleScript", 
                                         code: error["NSAppleScriptErrorNumber"] as? Int ?? -1,
                                         userInfo: error as? [String: Any])
                    continuation.resume(throwing: nsError)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

enum AppleScriptError: Error {
    case scriptCreationFailed
    case executionFailed(String)
}