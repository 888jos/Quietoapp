import Combine
import XCTest
@testable import QuietoNative

/// What gets celebrated, when, and in which order.
@MainActor
final class CelebrationTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.firstWeekday = 2
        return calendar
    }()

    /// 2026-10-05 is a Monday.
    private func day(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private var meditation: QuietoSession { SessionCatalog().sessions.first { $0.id == "decouverte_1" }! }

    private func make(today: Int, practised: [Int] = [], unlocked: [String] = []) -> (AchievementCenter, CelebrationCenter, Box) {
        let defaults = makeTestDefaults()
        let journal = PracticeJournal(defaults: defaults)
        for value in practised { _ = journal.record(kind: .meditation, contentID: "sleep_1", seconds: 300, at: day(value)) }
        let date = day(today)
        let achievements = AchievementCenter(journal: journal, defaults: defaults, catalog: SessionCatalog(), analytics: FakeAnalytics(), calendar: calendar, now: { date })
        achievements.start()
        let program = ProgramViewModel(catalog: SessionCatalog(), preferences: QuietoPreferences(defaults: defaults), activity: ActivityStore(defaults: defaults), repository: nil, completions: Empty().eraseToAnyPublisher())
        let center = CelebrationCenter(achievements: achievements, program: program, defaults: defaults, analytics: FakeAnalytics(), calendar: calendar, now: { date })
        center.delayScale = 0.01
        let box = Box()
        center.present = { moment, done in box.shown.append(moment); done() }
        return (achievements, center, box)
    }

    final class Box { var shown: [CelebrationMoment] = [] }

    private func settle() async { try? await Task.sleep(nanoseconds: 150_000_000) }

    func testFirstSessionFillsTheEndOfSessionAndShowsTheFirstBadgeAfterIt() async {
        let (achievements, center, box) = make(today: 7)
        center.hold()
        achievements.recordSession(meditation, seconds: 300)
        await settle()

        let outcome = center.recentOutcome
        XCTAssertEqual(outcome?.dayAdded, true)
        XCTAssertEqual(outcome?.streakBefore, 0)
        XCTAssertEqual(outcome?.streak.current, 1)
        XCTAssertEqual(outcome?.badges.map(\.id), ["first_meditation"])
        XCTAssertTrue(box.shown.isEmpty, "Rien ne s’affiche par-dessus la fin de séance.")

        center.release()
        await settle()
        XCTAssertEqual(box.shown.map(\.analyticsName), ["badges"])
        XCTAssertNil(center.recentOutcome?.badges.first, "La fin de séance repart de zéro.")
    }

    func testStreakMilestoneCarriesItsBadgeInsteadOfASecondScreen() async {
        let (achievements, center, box) = make(today: 7, practised: [5, 6])
        center.hold()
        achievements.recordSession(meditation, seconds: 300)
        center.release()
        await settle()

        guard case .streakMilestone(let days, _, let badge) = box.shown.first else { return XCTFail("\(box.shown)") }
        XCTAssertEqual(days, 3)
        XCTAssertEqual(badge?.id, "streak_3")
        XCTAssertFalse(box.shown.contains { if case .badges(let list) = $0 { return list.contains { $0.badge.id == "streak_3" } }; return false })
    }

    func testMinorBadgesKeepTheBanner() async {
        let (achievements, center, box) = make(today: 7, practised: [1, 2, 3])
        var banner: [String] = []
        let subscription = center.minorUnlocks.sink { banner += $0.map(\.id) }
        achievements.recordAmbience(QuietoAmbience.all[0], seconds: 120)
        await settle()
        XCTAssertTrue(banner.contains("first_sound"))
        XCTAssertFalse(box.shown.contains { if case .badges(let list) = $0 { return list.contains { $0.badge.id == "first_sound" } }; return false })
        subscription.cancel()
    }

    func testComingBackAfterABreakIsWelcomedWithoutAZero() async {
        let (achievements, center, box) = make(today: 20, practised: [5, 6, 7, 8])
        achievements.recordSession(meditation, seconds: 300)
        await settle()
        guard case .welcomeBack(let best, let away) = box.shown.first else { return XCTFail("\(box.shown)") }
        XCTAssertEqual(best, 4)
        XCTAssertEqual(away, 12)
    }

    func testRestDayNoticeComesBeforeTheRiskAndOnlyOnce() {
        // Monday 5 and Tuesday 6 practised, Wednesday 7 forgiven, Thursday 8 nothing yet.
        let (_, center, _) = make(today: 8, practised: [5, 6])
        XCTAssertEqual(center.notice, .restDayUsed(streak: 2))
        center.dismissNotice()
        guard case .streakAtRisk(let streak, _) = center.notice else { return XCTFail("\(String(describing: center.notice))") }
        XCTAssertEqual(streak, 2)
        center.dismissNotice()
        XCTAssertNil(center.notice)
    }

    func testWeeklyRecapOnSundayEvening() {
        let (_, center, _) = make(today: 11, practised: [6, 8, 9])
        XCTAssertNil(center.notice, "Dimanche midi : pas encore.")
        let (_, evening, _) = makeEvening()
        guard case .weeklyRecap(_, _, let practices, _) = evening.notice else { return XCTFail("\(String(describing: evening.notice))") }
        XCTAssertEqual(practices, 3)
    }

    private func makeEvening() -> (AchievementCenter, CelebrationCenter, Box) {
        let defaults = makeTestDefaults()
        let journal = PracticeJournal(defaults: defaults)
        for value in [6, 8, 9] { _ = journal.record(kind: .meditation, contentID: "sleep_1", seconds: 300, at: day(value)) }
        let date = day(11, hour: 19)
        let achievements = AchievementCenter(journal: journal, defaults: defaults, catalog: SessionCatalog(), analytics: FakeAnalytics(), calendar: calendar, now: { date })
        achievements.start()
        let program = ProgramViewModel(catalog: SessionCatalog(), preferences: QuietoPreferences(defaults: defaults), activity: ActivityStore(defaults: defaults), repository: nil, completions: Empty().eraseToAnyPublisher())
        return (achievements, CelebrationCenter(achievements: achievements, program: program, defaults: defaults, analytics: FakeAnalytics(), calendar: calendar, now: { date }), Box())
    }

    func testMomentsComeOutInPriorityOrder() {
        let moments: [CelebrationMoment] = [.badges([]), .streakMilestone(days: 7, best: 7, badge: nil), .planFinished(PlanRecap(planID: .sleep, planTitle: "", days: 20, minutes: 0, sessions: 0, favourite: nil, stress: []))]
        XCTAssertEqual(moments.sorted { $0.priority < $1.priority }.map(\.analyticsName), ["plan_finished", "streak_milestone", "badges"])
    }
}
