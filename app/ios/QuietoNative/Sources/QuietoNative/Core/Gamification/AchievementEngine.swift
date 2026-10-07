import Foundation

struct BadgeState: Identifiable, Equatable {
    let badge: Badge
    let unlockedAt: Date?
    let current: Int
    let target: Int

    var id: String { badge.id }
    var isUnlocked: Bool { unlockedAt != nil }
    var fraction: Double { isUnlocked ? 1 : Double(current) / Double(max(1, target)) }
}

struct AchievementSummary: Equatable {
    var stats = PracticeStats()
    var badges: [BadgeState] = []

    var streak: StreakStatus { stats.streak }
    var unlockedCount: Int { badges.filter(\.isUnlocked).count }
    var totalCount: Int { badges.count }

    /// The visible locked badge closest to being unlocked: what to aim for next.
    var nextBadge: BadgeState? {
        badges.enumerated()
            .filter { !$0.element.isUnlocked && !$0.element.badge.isHidden }
            .max { lhs, rhs in
                lhs.element.fraction == rhs.element.fraction ? lhs.offset > rhs.offset : lhs.element.fraction < rhs.element.fraction
            }?.element
    }

    var recentlyUnlocked: [BadgeState] {
        Array(badges.filter(\.isUnlocked).sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }.prefix(3))
    }

    func badges(in category: BadgeCategory) -> [BadgeState] {
        badges.filter { $0.badge.category == category }
    }

    static let empty = AchievementSummary()
}

/// Pure rules: which badges are met by some statistics. Unlocks are kept
/// separately, so a badge stays earned even if its condition stops holding.
enum AchievementEngine {
    static func newlyMet(stats: PracticeStats, unlocked: [String: Date], badges: [Badge] = Badge.all) -> [Badge] {
        badges.filter { unlocked[$0.id] == nil && $0.requirement.isMet(by: stats) }
    }

    static func summary(stats: PracticeStats, unlocked: [String: Date], badges: [Badge] = Badge.all) -> AchievementSummary {
        AchievementSummary(stats: stats, badges: badges.map { badge in
            let progress = badge.requirement.progress(in: stats)
            return BadgeState(badge: badge, unlockedAt: unlocked[badge.id], current: progress.current, target: progress.target)
        })
    }
}
