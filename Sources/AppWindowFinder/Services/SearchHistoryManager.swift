import Foundation

/// Class that manages search history and item usage frequency
@MainActor
public class SearchHistoryManager: ObservableObject {
    public static let shared = SearchHistoryManager()
    
    private let userDefaults = UserDefaults.standard
    private let itemUsageKey = "ItemUsageHistory"
    private let searchHistoryKey = "SearchHistory"
    private let maxHistoryCount = 50
    
    /// Item usage history
    private var itemUsage: [String: ItemUsageData] = [:]
    
    /// Search query history
    @Published private var searchHistory: [String] = []
    
    private init() {
        loadData()
    }
    
    // MARK: - Item Usage History
    
    /// Record when an item is selected
    public func recordItemUsage(_ item: SearchItem) {
        let key = generateItemKey(item)
        
        if var usage = itemUsage[key] {
            usage.count += 1
            usage.lastUsed = Date()
            itemUsage[key] = usage
        } else {
            itemUsage[key] = ItemUsageData(count: 1, lastUsed: Date())
        }
        
        saveItemUsage()
        AppLogger.log("Recorded usage for item: \(item.title)", level: .debug, category: .general)
    }
    
    /// Get usage frequency score for an item
    public func getUsageScore(for item: SearchItem) -> Double {
        let key = generateItemKey(item)
        guard let usage = itemUsage[key] else { return 0.0 }
        
        // Score based on usage count and recency
        let countScore = Double(usage.count)
        let recencyScore = calculateRecencyScore(usage.lastUsed)
        
        return countScore + recencyScore
    }
    
    /// Thread-safe usage frequency score retrieval (for FuzzySearch)
    public func getUsageScoreSync(for item: SearchItem) -> Double {
        let key = generateItemKey(item)
        guard let usage = itemUsage[key] else { return 0.0 }
        
        // Score based on usage count and recency
        let countScore = Double(usage.count)
        let recencyScore = calculateRecencyScore(usage.lastUsed)
        
        return countScore + recencyScore
    }
    
    // MARK: - Search History
    
    /// Add search query to history
    @MainActor
    public func recordSearchQuery(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Remove existing query (avoid duplicates)
        searchHistory.removeAll { $0 == query }
        
        // Add to beginning
        searchHistory.insert(query, at: 0)
        
        // Limit history to maximum count
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }
        
        saveSearchHistory()
    }
    
    /// Get search history
    public func getSearchHistory() -> [String] {
        return searchHistory
    }
    
    /// Get search suggestions (partial match)
    public func getSearchSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return Array(searchHistory.prefix(5)) }
        
        let lowercaseQuery = query.lowercased()
        return searchHistory
            .filter { $0.lowercased().contains(lowercaseQuery) }
            .prefix(5)
            .map { $0 }
    }
    
    // MARK: - Data Persistence
    
    private func loadData() {
        loadItemUsage()
        loadSearchHistory()
    }
    
    private func loadItemUsage() {
        if let data = userDefaults.data(forKey: itemUsageKey),
           let decoded = try? JSONDecoder().decode([String: ItemUsageData].self, from: data) {
            itemUsage = decoded
        }
    }
    
    private func saveItemUsage() {
        if let encoded = try? JSONEncoder().encode(itemUsage) {
            userDefaults.set(encoded, forKey: itemUsageKey)
        }
    }
    
    private func loadSearchHistory() {
        searchHistory = userDefaults.stringArray(forKey: searchHistoryKey) ?? []
    }
    
    private func saveSearchHistory() {
        userDefaults.set(searchHistory, forKey: searchHistoryKey)
    }
    
    // MARK: - Helper Methods
    
    nonisolated private func generateItemKey(_ item: SearchItem) -> String {
        // Generate unique key for item (title + application name)
        return "\(item.title)|\(item.appName)"
    }
    
    nonisolated private func calculateRecencyScore(_ date: Date) -> Double {
        let now = Date()
        let daysSinceUsed = now.timeIntervalSince(date) / (24 * 60 * 60)
        
        // Higher score for recent usage (max 5 points, decays daily)
        return max(0, 5.0 - daysSinceUsed * 0.5)
    }
    
    // MARK: - Data Clearing (for development/testing)
    
    public func clearAllData() {
        itemUsage.removeAll()
        searchHistory.removeAll()
        userDefaults.removeObject(forKey: itemUsageKey)
        userDefaults.removeObject(forKey: searchHistoryKey)
    }
}

/// Item usage data
private struct ItemUsageData: Codable {
    var count: Int
    var lastUsed: Date
}