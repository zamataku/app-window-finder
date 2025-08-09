import Foundation
import os.log

public enum LogLevel {
    case debug
    case info
    case warning
    case error
}

struct AppLogger {
    private static let subsystem = "io.github.AppWindowFinder"
    
    private static let windowManager = OSLog(subsystem: subsystem, category: "WindowManager")
    private static let hotkeyManager = OSLog(subsystem: subsystem, category: "HotkeyManager")
    private static let general = OSLog(subsystem: subsystem, category: "General")
    
    static func log(_ message: String, level: LogLevel = .info, category: LogCategory = .general) {
        let osLogType: OSLogType
        switch level {
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warning:
            osLogType = .default
        case .error:
            osLogType = .error
        }
        
        let logger: OSLog
        switch category {
        case .windowManager:
            logger = windowManager
        case .hotkeyManager:
            logger = hotkeyManager
        case .general:
            logger = general
        }
        
        os_log("%{public}@", log: logger, type: osLogType, message)
    }
    
    static func logError(_ error: Error, context: String, category: LogCategory = .general) {
        let errorMessage = "\(context): \(error.localizedDescription)"
        log(errorMessage, level: .error, category: category)
    }
}

public enum LogCategory {
    case windowManager
    case hotkeyManager
    case general
}