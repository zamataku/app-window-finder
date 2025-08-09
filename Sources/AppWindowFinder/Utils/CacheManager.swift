import Foundation

actor CacheManager<T> {
    private var cache: T?
    private var lastFetchTime: Date?
    private let expirationInterval: TimeInterval
    
    init(expirationInterval: TimeInterval = 300) { // Default 5 minutes
        self.expirationInterval = expirationInterval
    }
    
    func get() -> T? {
        guard let cache = cache,
              let lastFetchTime = lastFetchTime,
              Date().timeIntervalSince(lastFetchTime) < expirationInterval else {
            return nil
        }
        return cache
    }
    
    func set(_ value: T) {
        self.cache = value
        self.lastFetchTime = Date()
    }
    
    func clear() {
        self.cache = nil
        self.lastFetchTime = nil
    }
    
    func isExpired() -> Bool {
        guard let lastFetchTime = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetchTime) >= expirationInterval
    }
}