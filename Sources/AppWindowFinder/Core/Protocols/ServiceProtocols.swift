import Foundation
import AppKit

// MARK: - Browser Integration Protocols

@MainActor
public protocol BrowserHistoryProviding {
    func getRecentTabs(limit: Int) -> AWFResult<[SearchItem]>
}

@MainActor
public protocol FaviconProviding {
    func getFavicon(for urlString: String, fallbackIcon: NSImage?) async -> NSImage?
    func getFaviconNonBlocking(for urlString: String, fallbackIcon: NSImage?) -> NSImage?
    func clearCache()
}

// MARK: - Window Management Protocols

@MainActor
public protocol WindowManaging {
    var searchItems: [SearchItem] { get }
    func refreshWindows() async
    func activateWindow(_ item: SearchItem) async -> Bool
}

// MARK: - Search Protocols

@MainActor
public protocol SearchHistoryManaging {
    func recordItemUsage(_ item: SearchItem)
    func getUsageScore(for item: SearchItem) -> Double
    func getUsageScoreSync(for item: SearchItem) -> Double
    func recordSearchQuery(_ query: String)
    func getSearchHistory() -> [String]
    func getSearchSuggestions(for query: String) -> [String]
    func clearAllData()
}

// MARK: - Default Implementations for Protocols

extension BrowserHistoryService: BrowserHistoryProviding {}
extension SearchHistoryManager: SearchHistoryManaging {}

// MARK: - Dependency Injection Container

@MainActor
public class ServiceContainer {
    public static let shared = ServiceContainer()

    private var services: [String: Any] = [:]

    private init() {
        registerDefaultServices()
    }

    // MARK: - Registration

    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        services[key] = factory
    }

    public func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        services[key] = instance
    }

    // MARK: - Resolution

    public func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)

        if let factory = services[key] as? () -> T {
            return factory()
        }

        if let instance = services[key] as? T {
            return instance
        }

        fatalError("Service of type \(type) not registered")
    }

    public func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        if let factory = services[key] as? () -> T {
            return factory()
        }

        if let instance = services[key] as? T {
            return instance
        }

        return nil
    }

    // MARK: - Default Service Registration

    private func registerDefaultServices() {
        // Browser services
        register(BrowserHistoryProviding.self, instance: BrowserHistoryService.shared)
        register(FaviconProviding.self, instance: FaviconService.shared)

        // Search services
        register(SearchHistoryManaging.self, instance: SearchHistoryManager.shared)
    }

    // MARK: - Testing Support

    public func removeAll() {
        services.removeAll()
    }

    public func registerMock<T>(_ type: T.Type, mock: T) {
        register(type, instance: mock)
    }
}

// MARK: - Service Locator Pattern (Alternative to DI)

@MainActor
public protocol ServiceLocating {
    func getBrowserHistoryService() -> BrowserHistoryProviding
    func getFaviconService() -> FaviconProviding
    func getSearchHistoryManager() -> SearchHistoryManaging
}

extension ServiceContainer: ServiceLocating {
    public func getBrowserHistoryService() -> BrowserHistoryProviding {
        return resolve(BrowserHistoryProviding.self)
    }

    public func getFaviconService() -> FaviconProviding {
        return resolve(FaviconProviding.self)
    }

    public func getSearchHistoryManager() -> SearchHistoryManaging {
        return resolve(SearchHistoryManaging.self)
    }
}
