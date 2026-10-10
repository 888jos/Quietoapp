import Foundation

/// What the end of a session shows under « Bien joué »: the streak that
/// grows, the plan step done, the badges earned. Filled live while the screen
/// is open, as the journal, the plan and the badges catch up.
struct SessionOutcome: Equatable {
    struct PlanStep: Equatable {
        let planTitle: String
        let number: Int
        let total: Int
        /// « la suite demain », nil when the plan is finished.
        let waitLabel: String?
    }

    /// First practice of the day: the streak goes from `streakBefore` to `streak.current`.
    var dayAdded = false
    var streakBefore = 0
    var streak = StreakStatus.empty
    var week: [WeekDayStatus] = []
    var planStep: PlanStep?
    var badges: [Badge] = []
}

/// A full-screen celebration. Shown one at a time, after the end of session,
/// in priority order (`priority`, lowest first).
enum CelebrationMoment: Identifiable, Equatable {
    /// 3, 7, 14, 30, 60, 100 or 365 days; the streak badge goes with it.
    case streakMilestone(days: Int, best: Int, badge: Badge?)
    /// Badges worth a full screen (first badge, programme, surprises); several at once are paged.
    case badges([BadgeState])
    case planWeekDone(PlanWeekRecap)
    case planFinished(PlanRecap)
    /// Back after the streak ended.
    case welcomeBack(best: Int, daysAway: Int)

    var id: String {
        switch self {
        case .streakMilestone(let days, _, _): "streak-\(days)"
        case .badges(let badges): "badges-" + badges.map(\.id).joined(separator: ",")
        case .planWeekDone(let recap): "week-\(recap.week)"
        case .planFinished(let recap): "plan-\(recap.planTitle)"
        case .welcomeBack(let best, let days): "back-\(best)-\(days)"
        }
    }

    var priority: Int {
        switch self {
        case .planFinished: 0
        case .welcomeBack: 1
        case .streakMilestone: 2
        case .planWeekDone: 3
        case .badges: 4
        }
    }

    var analyticsName: String {
        switch self {
        case .streakMilestone: "streak_milestone"
        case .badges: "badges"
        case .planWeekDone: "plan_week_done"
        case .planFinished: "plan_finished"
        case .welcomeBack: "welcome_back"
        }
    }
}

struct PlanWeekRecap: Equatable {
    let planTitle: String
    /// The week just finished (1-4, or 0 for the discovery week).
    let week: Int
    let sessions: [QuietoSession]
    let nextPhase: QuietoPlanPhase?
    /// Weeks of the plan, finished ones first, for the strip of four.
    let weeksDone: Int
    let weeksTotal: Int
}

struct PlanRecap: Equatable {
    let planID: QuietoPlanID
    let planTitle: String
    let days: Int
    let minutes: Int
    let sessions: Int
    let favourite: QuietoSession?
    /// Stress 0-10 at the checkpoints the person answered (start, middle, end).
    let stress: [Int]
}

/// Light messages on the home, never a full screen.
enum HomeNotice: Identifiable, Equatable {
    /// Yesterday was forgiven: the streak still holds.
    case restDayUsed(streak: Int)
    /// The rest day of the week is spent and nothing was done today.
    case streakAtRisk(streak: Int, quick: QuietoSession?)
    /// Sunday evening: the week in a card.
    case weeklyRecap(week: [WeekDayStatus], minutes: Int, practices: Int, next: BadgeState?)

    var id: String {
        switch self {
        case .restDayUsed: "rest"
        case .streakAtRisk: "risk"
        case .weeklyRecap: "recap"
        }
    }
}

enum StreakMilestones {
    static let days: Set<Int> = [3, 7, 14, 30, 60, 100, 365]

    static func next(after days: Int) -> Int? { Self.days.sorted().first { $0 > days } }

    /// The sentence under the number.
    static func line(for days: Int) -> String {
        switch days {
        case 3: "Trois jours de suite. Un rythme commence à naître."
        case 7: "Une semaine entière. Tu as fait de la place pour toi."
        case 14: "Deux semaines. Ce n’est plus un essai, c’est une habitude."
        case 30: "Un mois de pauses. Ton calme a de la mémoire."
        case 60: "Deux mois. Revenir à toi est devenu naturel."
        case 100: "Cent jours. Peu de gens vont aussi loin."
        default: "Une année entière de pauses. Merci de t’être choisi·e."
        }
    }
}

extension Badge {
    /// Earned through the streak: celebrated by the milestone screen instead.
    var streakDays: Int? {
        if case .streak(let days) = requirement { return days }
        return nil
    }

    /// Worth a full screen; the other badges keep the discreet banner.
    var isMajor: Bool { category == .program || category == .hidden || id == "first_meditation" || id == "full_week" }
}
