import Foundation

/// Everything the badges look at, derived once from the journal.
struct PracticeStats: Equatable {
    var counts: [PracticeKind: Int] = [:]
    var totalSeconds = 0
    var streak = StreakStatus.empty
    /// Start of every day with at least one practice.
    var practiceDays: Set<Date> = []
    /// Practised seconds for each of those days.
    var secondsByDay: [Date: Int] = [:]
    /// Number of practices (sessions, breathings, sounds) for each of those days.
    var practicesByDay: [Date: Int] = [:]
    /// Calendar weeks with a practice on each of the seven days.
    var fullWeeks = 0
    var earlySessions = 0
    var lateSessions = 0
    var shortSessions = 0
    var sleepSessions = 0
    var situationsCovered: Set<QuietoSituation> = []
    var distinctAmbiences: Set<String> = []
    var programCompleted = 0
    var programTotal = 0
    /// Returns after at least a week without practice.
    var comebacks = 0

    func count(_ kind: PracticeKind) -> Int { counts[kind, default: 0] }
    var practiceCount: Int { PracticeKind.allCases.filter(\.countsAsPractice).reduce(0) { $0 + count($1) } }
    var totalMinutes: Int { totalSeconds / 60 }

    static let earlyHour = 8
    static let lateHour = 22
    static let comebackGapDays = 7

    static func make(
        entries: [PracticeEntry],
        catalog: QuietoSessionCatalogProviding,
        programSessionIDs: [String],
        now: Date,
        calendar: Calendar
    ) -> PracticeStats {
        var stats = PracticeStats()
        let sessions = Dictionary(catalog.sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var completedSessionIDs = Set<String>()
        var previousPracticeDay: Date?

        for entry in entries.sorted(by: { $0.date < $1.date }) {
            stats.counts[entry.kind, default: 0] += 1
            guard entry.kind.countsAsPractice else { continue }

            let day = calendar.startOfDay(for: entry.date)
            if let previousPracticeDay,
               let gap = calendar.dateComponents([.day], from: previousPracticeDay, to: day).day,
               gap >= comebackGapDays {
                stats.comebacks += 1
            }
            previousPracticeDay = day
            stats.practiceDays.insert(day)
            stats.secondsByDay[day, default: 0] += entry.seconds
            stats.practicesByDay[day, default: 0] += 1
            stats.totalSeconds += entry.seconds

            let hour = calendar.component(.hour, from: entry.date)
            if hour >= 4, hour < earlyHour { stats.earlySessions += 1 }
            if hour >= lateHour || hour < 4 { stats.lateSessions += 1 }

            switch entry.kind {
            case .sound:
                stats.distinctAmbiences.insert(entry.contentID)
            case .meditation, .breathing:
                completedSessionIDs.insert(entry.contentID)
                guard let session = sessions[entry.contentID] else { continue }
                if session.durationMinutes <= 5 { stats.shortSessions += 1 }
                if session.themes.contains(.sleep) { stats.sleepSessions += 1 }
                stats.situationsCovered.formUnion(session.situations)
            case .checkIn:
                break
            }
        }

        stats.streak = StreakCalculator.status(practiceDays: stats.practiceDays, today: now, calendar: calendar)
        stats.fullWeeks = Dictionary(grouping: stats.practiceDays) { StreakCalculator.weekStart(of: $0, calendar: calendar) }
            .values.filter { $0.count >= 7 }.count
        stats.programTotal = programSessionIDs.count
        stats.programCompleted = programSessionIDs.filter(completedSessionIDs.contains).count
        return stats
    }
}
