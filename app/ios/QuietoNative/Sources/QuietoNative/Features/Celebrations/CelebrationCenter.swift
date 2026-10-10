import Combine
import Foundation

/// Decides what to celebrate and when. It listens to the journal (streak),
/// the badges and the plan, fills the end-of-session block live, queues the
/// full-screen moments and shows them one at a time once the end of session
/// is closed. Never during a session, never two screens on top of each other.
@MainActor
final class CelebrationCenter: ObservableObject {
    /// Read by the end-of-session screen, which UIKit hosts outside the
    /// SwiftUI tree. Set by `AppContainer`.
    static weak var live: CelebrationCenter?

    @Published private(set) var outcome = SessionOutcome()
    @Published private(set) var notice: HomeNotice?
    /// Badges that only deserve the discreet banner.
    let minorUnlocks = PassthroughSubject<[Badge], Never>()

    /// Shows a moment full screen; calls the completion once it is closed.
    var present: ((CelebrationMoment, @escaping () -> Void) -> Void)?
    /// False during the onboarding or behind the paywall.
    var canPresent: () -> Bool = { true }
    /// Multiplies the pauses between screens (tests use a tiny value).
    var delayScale = 1.0

    enum Key {
        static let restDaysSeen = "quieto.celebration.restDaysSeen"
        static let riskDismissedDay = "quieto.celebration.riskDismissedDay"
        static let recapDismissedWeek = "quieto.celebration.recapDismissedWeek"
    }

    private let achievements: AchievementCenter
    private let program: ProgramViewModel
    private let defaults: UserDefaults
    private let analytics: QuietoAnalyticsProviding
    private let calendar: Calendar
    private let now: () -> Date
    private var lastSummary: AchievementSummary
    private var lastPlan: QuietoPlanState?
    private var outcomeUpdatedAt = Date.distantPast
    private var queue: [CelebrationMoment] = []
    private var holds = 0
    private var isPresenting = false
    private var flushTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(achievements: AchievementCenter, program: ProgramViewModel, defaults: UserDefaults = .standard, analytics: QuietoAnalyticsProviding, calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = Date.init) {
        self.achievements = achievements
        self.program = program
        self.defaults = defaults
        self.analytics = analytics
        self.calendar = calendar
        self.now = now
        lastSummary = achievements.summary
        lastPlan = program.state
        achievements.$summary
            .sink { [weak self] in self?.summaryChanged($0) }
            .store(in: &cancellables)
        achievements.unlocks
            .sink { [weak self] in self?.badgesUnlocked($0) }
            .store(in: &cancellables)
        // `state` is published before the schedule is rebuilt: read on the next turn.
        program.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.planChanged($0) }
            .store(in: &cancellables)
        refreshNotice()
    }

    // MARK: End of session

    /// The end-of-session block, if something happened in the last minutes.
    var recentOutcome: SessionOutcome? {
        now().timeIntervalSince(outcomeUpdatedAt) < 5 * 60 ? outcome : nil
    }

    /// The end-of-session screen is open: full screens wait.
    func hold() { holds += 1 }

    func release() {
        holds = max(0, holds - 1)
        if holds == 0 {
            outcome = SessionOutcome()
            outcomeUpdatedAt = .distantPast
        }
        scheduleFlush(after: 0.45)
    }

    private func touchOutcome(_ change: (inout SessionOutcome) -> Void) {
        if now().timeIntervalSince(outcomeUpdatedAt) >= 5 * 60 { outcome = SessionOutcome() }
        change(&outcome)
        outcomeUpdatedAt = now()
    }

    // MARK: Streak

    private func summaryChanged(_ summary: AchievementSummary) {
        let before = lastSummary
        lastSummary = summary
        let streak = summary.streak
        if !before.streak.practicedToday, streak.practicedToday {
            let week = AchievementsViewModel.weekStatuses(practiceDays: summary.stats.practiceDays, now: now(), calendar: calendar)
            touchOutcome {
                $0.dayAdded = true
                $0.streakBefore = before.streak.current
                $0.streak = streak
                $0.week = week
            }
            if before.streak.current == 0, let last = before.stats.practiceDays.max() {
                let away = calendar.dateComponents([.day], from: last, to: calendar.startOfDay(for: now())).day ?? 0
                if away >= 3 { enqueue(.welcomeBack(best: before.streak.best, daysAway: away)) }
            }
            if StreakMilestones.days.contains(streak.current) {
                enqueue(.streakMilestone(days: streak.current, best: streak.best, badge: nil))
            }
        }
        refreshNotice()
    }

    // MARK: Badges

    private func badgesUnlocked(_ badges: [Badge]) {
        touchOutcome { $0.badges.append(contentsOf: badges) }
        let isFirstEver = lastSummary.unlockedCount == badges.count
        var major: [Badge] = []
        var minor: [Badge] = []
        for badge in badges {
            if let days = badge.streakDays {
                attach(badge, toMilestone: days)
            } else if badge.isMajor || isFirstEver {
                major.append(badge)
            } else {
                minor.append(badge)
            }
        }
        if !major.isEmpty {
            let states = major.map { badge in
                lastSummary.badges.first { $0.badge.id == badge.id } ?? BadgeState(badge: badge, unlockedAt: now(), current: 1, target: 1)
            }
            enqueue(.badges(states))
        }
        if !minor.isEmpty { minorUnlocks.send(minor) }
    }

    /// The streak badge is the medal of its milestone screen, not a second screen.
    private func attach(_ badge: Badge, toMilestone days: Int) {
        if let index = queue.firstIndex(where: { if case .streakMilestone(let value, _, _) = $0 { return value == days }; return false }),
           case .streakMilestone(let value, let best, _) = queue[index] {
            queue[index] = .streakMilestone(days: value, best: best, badge: badge)
        } else {
            enqueue(.streakMilestone(days: days, best: lastSummary.streak.best, badge: badge))
        }
    }

    // MARK: Plan

    private func planChanged(_ state: QuietoPlanState?) {
        let before = lastPlan
        lastPlan = state
        guard let state, let before, before.planID == state.planID, before.startedAt == state.startedAt,
              let schedule = program.schedule else { return }
        let added = Set(state.completions.keys).subtracting(before.completions.keys)
        guard let dayNumber = added.max(), let step = schedule.steps.first(where: { $0.day.number == dayNumber }) else { return }

        var wait: String?
        if case .locked(_, let opensOn) = schedule.today { wait = PlanSchedule.waitLabel(until: opensOn, now: now(), calendar: calendar) }
        touchOutcome {
            $0.planStep = .init(planTitle: state.plan.title, number: schedule.completedCount, total: schedule.steps.count, waitLabel: schedule.isFinished ? nil : wait)
        }

        if schedule.isFinished {
            enqueue(.planFinished(Self.recap(state: state, schedule: schedule)))
            return
        }
        // A week ends when its last counted step is done.
        let weekIndex = (step.day.number - 1) / 7
        let weekSteps = schedule.steps.filter { ($0.day.number - 1) / 7 == weekIndex }
        if weekSteps.allSatisfy(\.isCompleted), weekSteps.last?.day.number == step.day.number {
            let weeks = Set(schedule.steps.map { ($0.day.number - 1) / 7 })
            let done = weeks.filter { index in schedule.steps.filter { ($0.day.number - 1) / 7 == index }.allSatisfy(\.isCompleted) }
            let next = schedule.steps.first { ($0.day.number - 1) / 7 == weekIndex + 1 }?.day.phase
            let offset = state.includesDiscovery ? 1 : 0
            enqueue(.planWeekDone(PlanWeekRecap(
                planTitle: state.plan.title,
                week: weekIndex + 1 - offset,
                sessions: weekSteps.map(\.session),
                nextPhase: next,
                weeksDone: done.count,
                weeksTotal: weeks.count
            )))
        }
    }

    static func recap(state: QuietoPlanState, schedule: PlanSchedule) -> PlanRecap {
        let done = schedule.steps.filter(\.isCompleted)
        let counts = Dictionary(grouping: done.map(\.session), by: \.id)
        let favourite = counts.values.max { $0.count < $1.count }?.first
        return PlanRecap(
            planID: state.planID,
            planTitle: state.plan.title,
            days: done.count,
            minutes: done.reduce(0) { $0 + $1.session.durationMinutes },
            sessions: Set(done.map(\.session.id)).count,
            favourite: favourite,
            stress: schedule.stressProgression.map(\.level)
        )
    }

    // MARK: Home notices

    func refreshNotice() {
        let streak = lastSummary.streak
        let today = calendar.startOfDay(for: now())
        if streak.current > 0, streak.restDaysBridged > defaults.integer(forKey: Key.restDaysSeen), !streak.practicedToday {
            notice = .restDayUsed(streak: streak.current)
        } else if streak.isAtRisk, defaults.double(forKey: Key.riskDismissedDay) != today.timeIntervalSince1970 {
            notice = .streakAtRisk(streak: streak.current, quick: SessionCatalog().sessions.first { $0.id == "express_5" })
        } else if let recap = weeklyRecap() {
            notice = recap
        } else {
            notice = nil
        }
        // Once the streak is back on track, the next forgiven day is news again.
        if streak.restDaysBridged < defaults.integer(forKey: Key.restDaysSeen) { defaults.set(streak.restDaysBridged, forKey: Key.restDaysSeen) }
    }

    /// Sunday from 17 h, when the week had at least one practice.
    private func weeklyRecap() -> HomeNotice? {
        let date = now()
        guard calendar.component(.weekday, from: date) == 1, calendar.component(.hour, from: date) >= 17,
              let week = calendar.dateInterval(of: .weekOfYear, for: date),
              defaults.double(forKey: Key.recapDismissedWeek) != week.start.timeIntervalSince1970 else { return nil }
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
        let stats = lastSummary.stats
        let practices = days.reduce(0) { $0 + (stats.practicesByDay[$1] ?? 0) }
        guard practices > 0 else { return nil }
        let minutes = days.reduce(0) { $0 + (stats.secondsByDay[$1] ?? 0) } / 60
        return .weeklyRecap(week: AchievementsViewModel.weekStatuses(practiceDays: stats.practiceDays, now: date, calendar: calendar), minutes: minutes, practices: practices, next: lastSummary.nextBadge)
    }

    func dismissNotice() {
        switch notice {
        case .restDayUsed: defaults.set(lastSummary.streak.restDaysBridged, forKey: Key.restDaysSeen)
        case .streakAtRisk: defaults.set(calendar.startOfDay(for: now()).timeIntervalSince1970, forKey: Key.riskDismissedDay)
        case .weeklyRecap: defaults.set(calendar.dateInterval(of: .weekOfYear, for: now())?.start.timeIntervalSince1970 ?? 0, forKey: Key.recapDismissedWeek)
        case nil: break
        }
        analytics.track("home_notice_dismissed", properties: ["notice": notice?.id ?? ""])
        notice = nil
        refreshNotice()
    }

    // MARK: Queue

    func enqueue(_ moment: CelebrationMoment) {
        guard !queue.contains(where: { $0.id == moment.id }) else { return }
        queue.append(moment)
        queue.sort { $0.priority < $1.priority }
        // Leaves time for the end-of-session screen to appear and hold the queue.
        scheduleFlush(after: 1.2)
    }

    private func scheduleFlush(after seconds: Double) {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * (self?.delayScale ?? 1) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    private func flush() {
        guard holds == 0, !isPresenting, canPresent(), !queue.isEmpty, let present else { return }
        let moment = queue.removeFirst()
        isPresenting = true
        analytics.track("celebration_shown", properties: ["moment": moment.analyticsName])
        present(moment) { [weak self] in
            self?.isPresenting = false
            self?.scheduleFlush(after: 0.5)
        }
    }

    #if DEBUG
    // MARK: Debug gallery

    func debugShow(_ moment: CelebrationMoment) {
        queue.removeAll { $0.id == moment.id }
        queue.insert(moment, at: 0)
        isPresenting = false
        flush()
    }

    func debugSetOutcome(_ value: SessionOutcome) {
        outcome = value
        outcomeUpdatedAt = now()
    }

    func debugSetNotice(_ value: HomeNotice?) { notice = value }

    var debugSummary: AchievementSummary { lastSummary }
    var debugProgram: ProgramViewModel { program }
    #endif
}
