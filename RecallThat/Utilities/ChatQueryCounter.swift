import Foundation

enum ChatQueryCounter {
    static let limitPerMonth = 30

    private static var monthKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return "chatQueries_\(f.string(from: Date()))"
    }

    static var queriesUsed: Int {
        UserDefaults.standard.integer(forKey: monthKey)
    }

    static var queriesRemaining: Int {
        max(0, limitPerMonth - queriesUsed)
    }

    static var hasQueriesRemaining: Bool {
        queriesUsed < limitPerMonth
    }

    static func recordQuery() {
        UserDefaults.standard.set(queriesUsed + 1, forKey: monthKey)
    }
}
