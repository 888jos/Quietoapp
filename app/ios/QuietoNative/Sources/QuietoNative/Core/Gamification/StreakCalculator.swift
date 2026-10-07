import Foundation

struct StreakStatus: Equatable {
    /// Practice days in the running streak (rest days bridge it but don't count).
    var current = 0
    var best = 0
    var practicedToday = false
    /// The forgiven day of the current week is already spent.
    var restDayUsedThisWeek = false
    /// Rest days that kept the running streak alive.
    var restDaysBridged = 0

    /// Missing today would end the streak.
    var isAtRisk: Bool { current > 0 && !practicedToday && restDayUsedThisWeek }

    static let empty = StreakStatus()
}

/// A gentle streak: one missed day per calendar week is forgiven, and today
/// only counts as missed once it is over. Pure, so it is tested with fixed dates.
enum StreakCalculator {
    static func status(practiceDays: Set<Date>, today: Date, calendar: Calendar) -> StreakStatus {
        let todayStart = calendar.startOfDay(for: today)
        let days = Set(practiceDays.map { calendar.startOfDay(for: $0) }).filter { $0 <= todayStart }
        guard let first = days.min() else { return .empty }

        var run = 0
        var best = 0
        var bridged = 0
        var restWeeks = Set<Date>()
        var day = first
        while day <= todayStart {
            let week = weekStart(of: day, calendar: calendar)
            if days.contains(day) {
                run += 1
                best = max(best, run)
            } else if day == todayStart {
                // The day isn't over yet.
            } else if run > 0, !restWeeks.contains(week) {
                restWeeks.insert(week)
                bridged += 1
            } else {
                run = 0
                bridged = 0
                restWeeks = []
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return StreakStatus(
            current: run,
            best: best,
            practicedToday: days.contains(todayStart),
            restDayUsedThisWeek: restWeeks.contains(weekStart(of: todayStart, calendar: calendar)),
            restDaysBridged: bridged
        )
    }

    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
