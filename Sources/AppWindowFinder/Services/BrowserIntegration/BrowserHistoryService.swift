import Foundation
import AppKit
import SQLite3

@MainActor
public class BrowserHistoryService {
    public static let shared = BrowserHistoryService()

    private init() {}

    // Browser configurations
    private let browserConfigs = [
        BrowserConfig(
            name: "Google Chrome",
            historyPath: "~/Library/Application Support/Google/Chrome/Default/History",
            bundleId: "com.google.Chrome"
        ),
        BrowserConfig(
            name: "Arc",
            historyPath: "~/Library/Application Support/Arc/User Data/Default/History",
            bundleId: "company.thebrowser.Browser"
        ),
        BrowserConfig(
            name: "Brave Browser",
            historyPath: "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/History",
            bundleId: "com.brave.Browser"
        ),
        BrowserConfig(
            name: "Microsoft Edge",
            historyPath: "~/Library/Application Support/Microsoft Edge/Default/History",
            bundleId: "com.microsoft.edgemac"
        )
    ]

    public func getRecentTabs(limit: Int = 20) -> AWFResult<[SearchItem]> {
        var allTabs: [SearchItem] = []
        var lastError: AppWindowFinderError?

        for config in browserConfigs {
            // Check if browser is running
            guard isAppRunning(bundleId: config.bundleId) else { continue }

            switch getRecentTabsFromBrowser(config: config, limit: limit) {
            case .success(let tabs):
                allTabs.append(contentsOf: tabs)
            case .failure(let error):
                lastError = error
                AppLogger.logError(error, context: "Failed to get tabs from \(config.name)", category: .general)
            }
        }

        // Return success even if some browsers failed, as long as we have some tabs
        if !allTabs.isEmpty {
            // Cap limit to prevent overflow issues
            let safeLimit = max(0, min(limit, 10000))
            let sortedTabs = Array(allTabs.sorted { $0.lastAccessTime > $1.lastAccessTime }.prefix(safeLimit))
            return .success(sortedTabs)
        }

        // If no tabs were found and we had an error, return the error
        if let error = lastError {
            return .failure(error)
        }

        // No tabs found but no error either
        return .success([])
    }

    private func getRecentTabsFromBrowser(config: BrowserConfig, limit: Int) -> AWFResult<[SearchItem]> {
        let expandedPath = NSString(string: config.historyPath).expandingTildeInPath
        let historyPath = expandedPath

        // Check if history file exists
        guard FileManager.default.fileExists(atPath: historyPath) else {
            AppLogger.log("History file not found for \(config.name): \(historyPath)", level: .debug, category: .general)
            return .failure(.browserHistoryNotFound(browserName: config.name))
        }

        // Create a temporary copy to avoid lock issues
        let tempPath = NSTemporaryDirectory() + "temp_history_\(UUID().uuidString).db"

        do {
            try FileManager.default.copyItem(atPath: historyPath, toPath: tempPath)
            defer {
                try? FileManager.default.removeItem(atPath: tempPath)
            }

            return queryRecentTabs(from: tempPath, browserName: config.name, limit: limit)
        } catch {
            AppLogger.log("Failed to copy history file for \(config.name): \(error)", level: .warning, category: .general)
            return .failure(.historyDatabaseCorrupted(browserName: config.name, path: historyPath))
        }
    }

    private func queryRecentTabs(from dbPath: String, browserName: String, limit: Int) -> AWFResult<[SearchItem]> {
        var db: OpaquePointer?

        let openResult = sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil)
        guard openResult == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            AppLogger.log("Failed to open database for \(browserName): \(message)", level: .error, category: .general)
            return .failure(.sqliteError(code: openResult, message: message))
        }

        defer { sqlite3_close(db) }

        // Query recent URLs (last 24 hours, most recent first)
        let query = """
            SELECT url, title, last_visit_time
            FROM urls
            WHERE last_visit_time > ? AND hidden = 0 AND title != ''
            ORDER BY last_visit_time DESC
            LIMIT ?
        """

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, query, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            AppLogger.log("Failed to prepare statement for \(browserName): \(message)", level: .error, category: .general)
            return .failure(.sqliteError(code: prepareResult, message: message))
        }

        defer { sqlite3_finalize(statement) }

        // Chrome stores timestamps as microseconds since 1601-01-01 UTC
        let oneDayAgo = Date().addingTimeInterval(-Self.recentWindow)
        sqlite3_bind_int64(statement, 1, Self.chromeTime(from: oneDayAgo))
        sqlite3_bind_int(statement, 2, Int32(clamping: max(0, limit)))

        var results: [SearchItem] = []
        let app = NSRunningApplication.runningApplications(withBundleIdentifier: getBundleId(for: browserName)).first
        let icon = app?.icon ?? NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let urlCString = sqlite3_column_text(statement, 0),
                  let titleCString = sqlite3_column_text(statement, 1) else { continue }

            let url = String(cString: urlCString)
            let title = String(cString: titleCString)
            let lastVisitTime = sqlite3_column_int64(statement, 2)
            let lastAccessTime = Self.date(fromChromeTime: lastVisitTime) ?? Date()

            // Get favicon (non-blocking)
            let favicon = FaviconService.shared.getFaviconNonBlocking(for: url, fallbackIcon: icon)

            let searchItem = SearchItem(
                title: title.isEmpty ? url : title,
                subtitle: "\(browserName) • \(url)",
                icon: favicon ?? icon,
                type: .browserTab,
                windowID: 0,
                processID: app?.processIdentifier ?? 0,
                bundleIdentifier: getBundleId(for: browserName),
                url: url,
                lastAccessTime: lastAccessTime
            )

            results.append(searchItem)
        }

        AppLogger.log("Retrieved \(results.count) recent tabs from \(browserName)", level: .debug, category: .general)
        return .success(results)
    }

    // MARK: - Chrome Timestamp Conversion

    /// Only history visited within this window is surfaced as a recent tab
    private static let recentWindow: TimeInterval = 24 * 60 * 60

    /// Microseconds between 1601-01-01 (Chrome epoch) and 1970-01-01 (Unix epoch)
    private static let chromeEpochOffset: Int64 = 11_644_473_600_000_000

    static func chromeTime(from date: Date) -> Int64 {
        return Int64(date.timeIntervalSince1970 * 1_000_000) + chromeEpochOffset
    }

    static func date(fromChromeTime chromeTime: Int64) -> Date? {
        guard chromeTime > chromeEpochOffset else { return nil }
        return Date(timeIntervalSince1970: Double(chromeTime - chromeEpochOffset) / 1_000_000)
    }

    private func isAppRunning(bundleId: String) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    private func getBundleId(for browserName: String) -> String {
        return browserConfigs.first { $0.name == browserName }?.bundleId ?? ""
    }
}

private struct BrowserConfig {
    let name: String
    let historyPath: String
    let bundleId: String
}
