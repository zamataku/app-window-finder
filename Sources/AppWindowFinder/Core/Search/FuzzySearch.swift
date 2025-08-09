import Foundation

public struct FuzzySearch {
    @MainActor
    public static func search(_ query: String, in items: [SearchItem]) -> [SearchItem] {
        guard !query.isEmpty else { 
            // クエリが空の場合、使用履歴に基づいてソート
            return sortByUsageHistory(items)
        }
        
        let lowercasedQuery = query.lowercased()
        
        return items
            .map { item -> (item: SearchItem, score: Double) in
                let searchScore = calculateSearchScore(query: lowercasedQuery, item: item)
                let usageScore = SearchHistoryManager.shared.getUsageScoreSync(for: item)
                let totalScore = searchScore + (usageScore * 0.3) // 使用履歴の重み30%
                return (item, totalScore)
            }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map { $0.item }
    }
    
    @MainActor
    private static func sortByUsageHistory(_ items: [SearchItem]) -> [SearchItem] {
        return items.sorted { item1, item2 in
            let score1 = SearchHistoryManager.shared.getUsageScoreSync(for: item1)
            let score2 = SearchHistoryManager.shared.getUsageScoreSync(for: item2)
            return score1 > score2
        }
    }
    
    private static func calculateSearchScore(query: String, item: SearchItem) -> Double {
        let title = item.title.lowercased()
        let subtitle = item.subtitle.lowercased()
        let appName = item.appName.lowercased()
        
        var score: Double = 0
        
        // 完全一致（最高スコア）
        if title == query {
            score += 100
        } else if appName == query {
            score += 90
        } else if subtitle == query {
            score += 80
        }
        
        // プレフィックス一致
        if title.hasPrefix(query) {
            score += 50
        } else if appName.hasPrefix(query) {
            score += 45
        } else if subtitle.hasPrefix(query) {
            score += 40
        }
        
        // 単語境界一致（単語の先頭にマッチ）
        score += wordBoundaryMatch(query: query, text: title) * 30
        score += wordBoundaryMatch(query: query, text: appName) * 25
        score += wordBoundaryMatch(query: query, text: subtitle) * 20
        
        // 略語マッチング（頭文字）
        score += acronymMatch(query: query, text: title) * 25
        score += acronymMatch(query: query, text: appName) * 20
        
        // 部分一致
        if title.contains(query) {
            score += 15
        }
        if appName.contains(query) {
            score += 12
        }
        if subtitle.contains(query) {
            score += 10
        }
        
        // ファジーマッチング
        let titleScore = fuzzyMatch(query: query, text: title)
        let appNameScore = fuzzyMatch(query: query, text: appName)
        let subtitleScore = fuzzyMatch(query: query, text: subtitle)
        
        score += titleScore * 3 + appNameScore * 2 + subtitleScore
        
        return score
    }
    
    private static func fuzzyMatch(query: String, text: String) -> Double {
        var queryIndex = query.startIndex
        var textIndex = text.startIndex
        var matchCount = 0
        var consecutiveMatches = 0
        var score: Double = 0
        
        while queryIndex < query.endIndex && textIndex < text.endIndex {
            if query[queryIndex] == text[textIndex] {
                matchCount += 1
                consecutiveMatches += 1
                score += Double(consecutiveMatches)
                queryIndex = query.index(after: queryIndex)
            } else {
                consecutiveMatches = 0
            }
            textIndex = text.index(after: textIndex)
        }
        
        if queryIndex == query.endIndex {
            return score / Double(query.count)
        } else {
            return 0
        }
    }
    
    /// 単語境界でのマッチングを計算
    private static func wordBoundaryMatch(query: String, text: String) -> Double {
        var separators = CharacterSet.whitespacesAndNewlines
        separators.insert(charactersIn: ".,;:!?-_()[]{}/@#$%^&*+=|\\~`\"'<>")
        let words = text.components(separatedBy: separators)
            .filter { !$0.isEmpty }
        
        var matches = 0
        for word in words {
            if word.lowercased().hasPrefix(query) {
                matches += 1
            }
        }
        
        return matches > 0 ? Double(matches) : 0
    }
    
    /// 略語マッチング（頭文字マッチング）を計算
    private static func acronymMatch(query: String, text: String) -> Double {
        var separators = CharacterSet.whitespacesAndNewlines
        separators.insert(charactersIn: ".,;:!?-_()[]{}/@#$%^&*+=|\\~`\"'<>")
        let words = text.components(separatedBy: separators)
            .filter { !$0.isEmpty }
        
        guard words.count >= query.count else { return 0 }
        
        let acronym = words.compactMap { $0.first?.lowercased() }.joined()
        
        if acronym.hasPrefix(query) {
            return 1.0
        }
        
        // 部分的な略語マッチ
        let queryChars = Array(query)
        var matchCount = 0
        var acronymIndex = 0
        
        for char in queryChars {
            if acronymIndex < acronym.count {
                let acronymChar = Array(acronym)[acronymIndex]
                if char.lowercased() == String(acronymChar) {
                    matchCount += 1
                    acronymIndex += 1
                }
            }
        }
        
        return Double(matchCount) / Double(query.count)
    }
}