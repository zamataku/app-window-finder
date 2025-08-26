import Foundation

/// Unified error types for AppWindowFinder
public enum AppWindowFinderError: Error, LocalizedError {
    // Window management errors
    case windowAccessDenied
    case windowNotFound(windowID: Int)
    case windowActivationFailed(windowID: Int)
    case applicationNotRunning(appName: String)
    
    // Browser integration errors
    case browserNotSupported(browserName: String)
    case browserHistoryNotFound(browserName: String)
    case historyDatabaseCorrupted(browserName: String, path: String)
    case sqliteError(code: Int32, message: String)
    
    // Network and favicon errors
    case networkUnavailable
    case networkTimeout
    case invalidURL(url: String)
    case faviconDownloadFailed(url: String, underlyingError: Error?)
    
    // Permission errors
    case accessibilityPermissionDenied
    case automationPermissionDenied
    case screenRecordingPermissionDenied
    
    // Cache and storage errors
    case cacheCorrupted
    case storagePermissionDenied
    case diskSpaceExhausted
    
    // AppleScript errors
    case appleScriptExecutionFailed(script: String, error: Error?)
    case appleScriptTimeout
    case appleScriptCompilationFailed(script: String)
    
    // Search and data processing errors
    case searchIndexCorrupted
    case invalidSearchQuery
    case dataProcessingFailed(context: String)
    
    // Memory and resource errors
    case memoryExhausted
    case resourceLimitExceeded(resource: String)
    case concurrencyLimitExceeded
    
    // Generic errors
    case unknown(Error?)
    
    public var errorDescription: String? {
        switch self {
        case .windowAccessDenied:
            return NSLocalizedString("Window access denied. Please grant accessibility permissions.", comment: "Window access error")
            
        case .windowNotFound(let windowID):
            return NSLocalizedString("Window with ID \(windowID) not found", comment: "Window not found error")
            
        case .windowActivationFailed(let windowID):
            return NSLocalizedString("Failed to activate window \(windowID)", comment: "Window activation error")
            
        case .applicationNotRunning(let appName):
            return NSLocalizedString("Application '\(appName)' is not running", comment: "Application not running error")
            
        case .browserNotSupported(let browserName):
            return NSLocalizedString("Browser '\(browserName)' is not supported", comment: "Browser not supported error")
            
        case .browserHistoryNotFound(let browserName):
            return NSLocalizedString("History not found for browser '\(browserName)'", comment: "Browser history not found error")
            
        case .historyDatabaseCorrupted(let browserName, let path):
            return NSLocalizedString("History database for '\(browserName)' is corrupted at path: \(path)", comment: "Database corrupted error")
            
        case .sqliteError(let code, let message):
            return NSLocalizedString("SQLite error (code: \(code)): \(message)", comment: "SQLite error")
            
        case .networkUnavailable:
            return NSLocalizedString("Network is unavailable", comment: "Network unavailable error")
            
        case .networkTimeout:
            return NSLocalizedString("Network request timed out", comment: "Network timeout error")
            
        case .invalidURL(let url):
            return NSLocalizedString("Invalid URL: \(url)", comment: "Invalid URL error")
            
        case .faviconDownloadFailed(let url, let underlyingError):
            let baseMessage = NSLocalizedString("Failed to download favicon from: \(url)", comment: "Favicon download error")
            if let error = underlyingError {
                return "\(baseMessage). Reason: \(error.localizedDescription)"
            }
            return baseMessage
            
        case .accessibilityPermissionDenied:
            return NSLocalizedString("Accessibility permission denied. Please enable it in System Preferences.", comment: "Accessibility permission error")
            
        case .automationPermissionDenied:
            return NSLocalizedString("Automation permission denied. Please enable it in System Preferences.", comment: "Automation permission error")
            
        case .screenRecordingPermissionDenied:
            return NSLocalizedString("Screen recording permission denied. Please enable it in System Preferences.", comment: "Screen recording permission error")
            
        case .cacheCorrupted:
            return NSLocalizedString("Cache is corrupted and has been cleared", comment: "Cache corrupted error")
            
        case .storagePermissionDenied:
            return NSLocalizedString("Storage permission denied", comment: "Storage permission error")
            
        case .diskSpaceExhausted:
            return NSLocalizedString("Insufficient disk space", comment: "Disk space error")
            
        case .appleScriptExecutionFailed(_, let error):
            let baseMessage = NSLocalizedString("AppleScript execution failed", comment: "AppleScript execution error")
            if let error = error {
                return "\(baseMessage): \(error.localizedDescription)"
            }
            return baseMessage
            
        case .appleScriptTimeout:
            return NSLocalizedString("AppleScript execution timed out", comment: "AppleScript timeout error")
            
        case .appleScriptCompilationFailed(_):
            return NSLocalizedString("AppleScript compilation failed", comment: "AppleScript compilation error")
            
        case .searchIndexCorrupted:
            return NSLocalizedString("Search index is corrupted", comment: "Search index corrupted error")
            
        case .invalidSearchQuery:
            return NSLocalizedString("Invalid search query", comment: "Invalid search query error")
            
        case .dataProcessingFailed(let context):
            return NSLocalizedString("Data processing failed in context: \(context)", comment: "Data processing error")
            
        case .memoryExhausted:
            return NSLocalizedString("Memory exhausted", comment: "Memory exhausted error")
            
        case .resourceLimitExceeded(let resource):
            return NSLocalizedString("Resource limit exceeded: \(resource)", comment: "Resource limit error")
            
        case .concurrencyLimitExceeded:
            return NSLocalizedString("Concurrency limit exceeded", comment: "Concurrency limit error")
            
        case .unknown(let error):
            let baseMessage = NSLocalizedString("An unknown error occurred", comment: "Unknown error")
            if let error = error {
                return "\(baseMessage): \(error.localizedDescription)"
            }
            return baseMessage
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .windowAccessDenied, .accessibilityPermissionDenied:
            return NSLocalizedString("Missing accessibility permissions", comment: "Accessibility failure reason")
        case .networkUnavailable, .networkTimeout:
            return NSLocalizedString("Network connectivity issue", comment: "Network failure reason")
        case .memoryExhausted:
            return NSLocalizedString("Insufficient system resources", comment: "Memory failure reason")
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .windowAccessDenied, .accessibilityPermissionDenied:
            return NSLocalizedString("Please grant accessibility permissions in System Preferences > Privacy & Security", comment: "Accessibility recovery suggestion")
        case .automationPermissionDenied:
            return NSLocalizedString("Please grant automation permissions in System Preferences > Privacy & Security", comment: "Automation recovery suggestion")
        case .networkUnavailable:
            return NSLocalizedString("Please check your internet connection", comment: "Network recovery suggestion")
        case .networkTimeout:
            return NSLocalizedString("Please try again with a stable internet connection", comment: "Network timeout recovery suggestion")
        case .cacheCorrupted:
            return NSLocalizedString("The cache has been automatically cleared. Please restart the application.", comment: "Cache recovery suggestion")
        case .memoryExhausted:
            return NSLocalizedString("Please close other applications to free up memory", comment: "Memory recovery suggestion")
        default:
            return NSLocalizedString("Please try again or restart the application", comment: "General recovery suggestion")
        }
    }
}

// MARK: - Result Type Extensions

public typealias AWFResult<Success> = Result<Success, AppWindowFinderError>

extension Result where Failure == AppWindowFinderError {
    /// Creates a result from a throwing closure, converting any error to AppWindowFinderError
    public static func catching<T>(_ body: () throws -> T) -> Result<T, AppWindowFinderError> {
        do {
            let value = try body()
            return .success(value)
        } catch let error as AppWindowFinderError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error))
        }
    }
    
    /// Creates a result from an async throwing closure, converting any error to AppWindowFinderError
    public static func catchingAsync<T>(_ body: () async throws -> T) async -> Result<T, AppWindowFinderError> {
        do {
            let value = try await body()
            return .success(value)
        } catch let error as AppWindowFinderError {
            return .failure(error)
        } catch {
            return .failure(.unknown(error))
        }
    }
}