import SwiftUI

// MARK: - AchievementStore

final class AchievementStore {
    static let shared = AchievementStore()

    private let key = "achievementStars"

    private var data: [String: Int] {
        get {
            guard let d = UserDefaults.standard.data(forKey: key),
                  let dict = try? JSONDecoder().decode([String: Int].self, from: d)
            else { return [:] }
            return dict
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(d, forKey: key)
            }
        }
    }

    func setStars(activity: String, type: String, stars: Int) {
        var d = data
        d["\(type)_\(activity)"] = stars
        data = d
    }

    func getStars(activity: String, type: String) -> Int {
        data["\(type)_\(activity)"] ?? 0
    }

    func totalStars(type: String) -> Int {
        data.filter { $0.key.hasPrefix("\(type)_") }.values.reduce(0, +)
    }

    // Draw: coverage >= 95% -> 3, >= 91% -> 2, else 1
    static func drawStars(coverage: CGFloat) -> Int {
        if coverage >= 0.95 { return 3 }
        if coverage >= 0.91 { return 2 }
        return 1
    }

    // Fill: 0 wrong -> 3, 1 wrong -> 2, else 1
    static func fillStars(wrongCount: Int) -> Int {
        if wrongCount == 0 { return 3 }
        if wrongCount == 1 { return 2 }
        return 1
    }
}
