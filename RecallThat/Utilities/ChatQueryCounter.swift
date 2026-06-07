import Foundation

enum ChatQueryCounter {
    static let limitPerDay = 10

    private static var dayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "chatQueries_\(f.string(from: Date()))"
    }

    static var queriesUsed: Int {
        UserDefaults.standard.integer(forKey: dayKey)
    }

    static var queriesRemaining: Int {
        max(0, limitPerDay - queriesUsed)
    }

    static var hasQueriesRemaining: Bool {
        queriesUsed < limitPerDay
    }

    static func recordQuery() {
        UserDefaults.standard.set(queriesUsed + 1, forKey: dayKey)
    }
}
