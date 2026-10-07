import Combine
import XCTest
@testable import QuietoNative

/// Streak, badges and the practice journal, with fixed dates.
@MainActor
final class GamificationTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }()

    /// 2026-10-07 is a Wednesday.
    private func day(_ day: Int, month: Int = 10, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func days(_ values: [Int]) -> Set<Date> { Set(values.map { day($0) }) }

    // MARK: Streak

    func testStreakCountsConsecutiveDaysAndTodayIsNotMissedYet() {
        let status = StreakCalculator.status(practiceDays: days([5, 6]), today: day(7), calendar: calendar)
        XCTAssertEqual(status.current, 2)
        XCTAssertFalse(status.practicedToday)
        XCTAssertFalse(status.isAtRisk)

        let practiced = StreakCalculator.status(practiceDays: days([5, 6, 7]), today: day(7), calendar: calendar)
        XCTAssertEqual(practiced.current, 3)
        XCTAssertTrue(practiced.practicedToday)
    }

    func testOneMissedDayPerWeekIsForgiven() {
        // Monday 5, (Tuesday 6 missed), Wednesday 7.
        let status = StreakCalculator.status(practiceDays: days([5, 7]), today: day(7), calendar: calendar)
        XCTAssertEqual(status.current, 2)
        XCTAssertEqual(status.restDaysBridged, 1)
        XCTAssertTrue(status.restDayUsedThisWeek)
    }

    func testSecondMissedDayInTheSameWeekEndsTheStreak() {
        // Monday 5, Tuesday 6 and Wednesday 7 missed, Thursday 8.
        let status = StreakCalculator.status(practiceDays: days([5, 8]), today: day(8), calendar: calendar)
        XCTAssertEqual(status.current, 1)
        XCTAssertEqual(status.best, 1)
    }

    func testStreakIsAtRiskOnceTheRestDayIsSpent() {
        // Sunday 4 and Monday 5 practised, Tuesday 6 missed (rest day), Wednesday 7 not yet.
        let status = StreakCalculator.status(practiceDays: days([4, 5]), today: day(7), calendar: calendar)
        XCTAssertEqual(status.current, 2)
        XCTAssertTrue(status.isAtRisk)
    }

    func testRestDayComesBackEachWeek() {
        // Missed Tuesday 29/09 and Tuesday 06/10: two different weeks.
        let practiced = days([1, 2, 3, 4, 5, 7]).union([day(28, month: 9), day(30, month: 9)])
        let status = StreakCalculator.status(practiceDays: practiced, today: day(7), calendar: calendar)
        XCTAssertEqual(status.current, 8)
        XCTAssertEqual(status.restDaysBridged, 2)
    }

    func testBestStreakSurvivesABreak() {
        let status = StreakCalculator.status(practiceDays: days([1, 2, 3, 4, 10]), today: day(10), calendar: calendar)
        XCTAssertEqual(status.current, 1)
        XCTAssertEqual(status.best, 4)
    }

    func testEmptyHistoryHasNoStreak() {
        XCTAssertEqual(StreakCalculator.status(practiceDays: [], today: day(7), calendar: calendar), .empty)
    }

    // MARK: Statistics and badges

    private func entry(_ kind: PracticeKind, _ id: String, seconds: Int = 300, at date: Date) -> PracticeEntry {
        PracticeEntry(id: UUID(), kind: kind, contentID: id, seconds: seconds, date: date)
    }

    private func stats(_ entries: [PracticeEntry], program: [String] = []) -> PracticeStats {
        PracticeStats.make(entries: entries, catalog: SessionCatalog(), programSessionIDs: program, now: day(7), calendar: calendar)
    }

    func testStatisticsCountEachKindAndIgnoreCheckInsForTheStreak() {
        let value = stats([
            entry(.meditation, "decouverte_1", at: day(6)),
            entry(.breathing, "breathing_1", seconds: 120, at: day(6)),
            entry(.sound, "rain", seconds: 600, at: day(7, hour: 7)),
            entry(.checkIn, "racingThoughts", seconds: 0, at: day(5))
        ])
        XCTAssertEqual(value.count(.meditation), 1)
        XCTAssertEqual(value.count(.checkIn), 1)
        XCTAssertEqual(value.practiceCount, 3)
        XCTAssertEqual(value.totalMinutes, 17)
        XCTAssertEqual(value.streak.current, 2)
        XCTAssertEqual(value.earlySessions, 1)
        XCTAssertEqual(value.distinctAmbiences, ["rain"])
    }

    func testFirstStepsBadgesUnlockFromTheFirstPractices() {
        let value = stats([
            entry(.meditation, "decouverte_1", at: day(6)),
            entry(.breathing, "breathing_1", at: day(7))
        ])
        let met = Set(AchievementEngine.newlyMet(stats: value, unlocked: [:]).map(\.id))
        XCTAssertTrue(met.isSuperset(of: ["first_meditation", "first_breathing"]))
        XCTAssertFalse(met.contains("explorer"))
        XCTAssertFalse(met.contains("streak_3"))
    }

    func testAlreadyUnlockedBadgesAreNotAnnouncedAgain() {
        let value = stats([entry(.meditation, "decouverte_1", at: day(6))])
        let met = AchievementEngine.newlyMet(stats: value, unlocked: ["first_meditation": day(6)])
        XCTAssertFalse(met.contains { $0.id == "first_meditation" })
    }

    func testProgramBadgesFollowTheProgramSessions() {
        let program = ["decouverte_1", "breathing_1", "decouverte_2", "meditation_05"]
        let value = stats([
            entry(.meditation, "decouverte_1", at: day(5)),
            entry(.breathing, "breathing_1", at: day(6))
        ], program: program)
        let met = Set(AchievementEngine.newlyMet(stats: value, unlocked: [:]).map(\.id))
        XCTAssertTrue(met.contains("program_started"))
        XCTAssertTrue(met.contains("program_half"))
        XCTAssertFalse(met.contains("program_finished"))
    }

    func testComebackAfterAWeekIsCelebrated() {
        let value = stats([
            entry(.meditation, "decouverte_1", at: day(20, month: 9)),
            entry(.meditation, "decouverte_2", at: day(7))
        ])
        XCTAssertEqual(value.comebacks, 1)
        XCTAssertTrue(AchievementEngine.newlyMet(stats: value, unlocked: [:]).contains { $0.id == "comeback" })
    }

    func testNextBadgeIsTheVisibleOneClosestToCompletion() {
        let value = stats((0..<4).map { entry(.meditation, "decouverte_1", at: day(7, hour: 9 + $0)) })
        let summary = AchievementEngine.summary(stats: value, unlocked: ["first_meditation": day(7)])
        XCTAssertEqual(summary.nextBadge?.badge.id, "meditation_5")
        XCTAssertEqual(summary.nextBadge?.current, 4)
    }

    func testBadgeIdsAreUnique() {
        XCTAssertEqual(Set(Badge.all.map(\.id)).count, Badge.all.count)
    }

    // MARK: Journal

    func testJournalPersistsEntriesAndTracksPendingUploads() {
        let defaults = makeTestDefaults()
        let journal = PracticeJournal(defaults: defaults)
        let recorded = journal.record(kind: .sound, contentID: "rain", seconds: 90, at: day(7))

        let reopened = PracticeJournal(defaults: defaults)
        XCTAssertEqual(reopened.entries.map(\.id), [recorded.id])
        XCTAssertEqual(reopened.pendingUpload.map(\.id), [recorded.id])
        reopened.markUploaded([recorded.id])
        XCTAssertTrue(reopened.pendingUpload.isEmpty)
    }

    func testJournalMergesRemoteEntriesWithoutDuplicates() {
        let journal = PracticeJournal(defaults: makeTestDefaults())
        let local = journal.record(kind: .meditation, contentID: "decouverte_1", seconds: 300, at: day(7))
        let remote = entry(.breathing, "breathing_1", at: day(5))

        XCTAssertTrue(journal.merge([local, remote]))
        XCTAssertFalse(journal.merge([remote]))
        XCTAssertEqual(journal.entries.map(\.id), [remote.id, local.id])
    }

    func testLegacyActivityIsImportedOnce() {
        let journal = PracticeJournal(defaults: makeTestDefaults())
        let events = [ActivityEvent(sessionID: "breathing_1", seconds: 120, date: day(6))]
        journal.importLegacyActivity(events, catalog: SessionCatalog())
        journal.importLegacyActivity(events, catalog: SessionCatalog())
        XCTAssertEqual(journal.entries.count, 1)
        XCTAssertEqual(journal.entries.first?.kind, .breathing)
    }

    // MARK: Center

    private func makeCenter(
        defaults: UserDefaults = makeTestDefaults(),
        analytics: FakeAnalytics = FakeAnalytics(),
        sync: FakePracticeSync? = nil,
        reminders: FakeReminders? = nil
    ) -> AchievementCenter {
        let date = day(7)
        return AchievementCenter(
            journal: PracticeJournal(defaults: defaults),
            defaults: defaults,
            catalog: SessionCatalog(),
            analytics: analytics,
            sync: sync,
            reminders: reminders,
            calendar: calendar,
            now: { date }
        )
    }

    private var meditation: QuietoSession { SessionCatalog().sessions.first { $0.id == "decouverte_1" }! }

    func testRecordingASessionAnnouncesNewBadgesOnce() {
        let analytics = FakeAnalytics()
        let center = makeCenter(analytics: analytics)
        center.start()
        var announced: [[String]] = []
        let subscription = center.unlocks.sink { announced.append($0.map(\.id)) }

        center.recordSession(meditation, seconds: 300)
        center.recordSession(meditation, seconds: 300)

        XCTAssertEqual(announced.count, 1)
        XCTAssertTrue(announced[0].contains("first_meditation"))
        XCTAssertEqual(center.summary.streak.current, 1)
        XCTAssertTrue(analytics.events.contains("badge_unlocked"))
        XCTAssertEqual(analytics.events.filter { $0 == "streak_day" }.count, 1)
        subscription.cancel()
    }

    func testShortBackgroundSoundsAreNotCountedAndLongOnesAreCapped() {
        let center = makeCenter()
        center.start()
        let rain = QuietoAmbience.all.first { $0.id == "rain" }!
        center.recordAmbience(rain, seconds: 20)
        XCTAssertEqual(center.summary.stats.count(.sound), 0)
        center.recordAmbience(rain, seconds: 8 * 3_600)
        XCTAssertEqual(center.summary.stats.count(.sound), 1)
        XCTAssertEqual(center.summary.stats.totalSeconds, AchievementCenter.maximumSoundSeconds)
    }

    func testPastPracticeUnlocksBadgesSilentlyAtLaunch() {
        let center = makeCenter()
        var announced = 0
        let subscription = center.unlocks.sink { _ in announced += 1 }
        center.start(legacyActivity: [ActivityEvent(sessionID: "decouverte_1", seconds: 300, date: day(6))])
        XCTAssertEqual(announced, 0)
        XCTAssertEqual(center.summary.badges.first { $0.id == "first_meditation" }?.isUnlocked, true)
        subscription.cancel()
    }

    func testSynchronizeRestoresRemotePracticeAndUploadsLocalOne() async {
        let sync = FakePracticeSync()
        sync.remote = [entry(.breathing, "breathing_1", at: day(6))]
        let center = makeCenter(sync: sync)
        center.start(legacyActivity: [ActivityEvent(sessionID: "decouverte_1", seconds: 300, date: day(7))])

        await center.synchronize()

        XCTAssertEqual(center.summary.stats.practiceCount, 2)
        XCTAssertEqual(center.summary.streak.current, 2)
        XCTAssertEqual(sync.uploaded.map(\.contentID), ["decouverte_1"])
    }

    func testTrialReminderSummarisesWhatWasBuilt() async {
        let reminders = FakeReminders()
        let center = makeCenter(reminders: reminders)
        center.start()
        XCTAssertNil(center.trialReminderBody)
        center.recordSession(meditation, seconds: 300)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(reminders.trialReminderBodies.count, 1)
        XCTAssertNotNil(center.trialReminderBody)
    }

    func testWipeForgetsThePractice() {
        let defaults = makeTestDefaults()
        let center = makeCenter(defaults: defaults)
        center.start()
        center.recordCheckIn(.overwhelmed)
        XCTAssertEqual(center.summary.stats.count(.checkIn), 1)
        QuietoPreferences(defaults: defaults).removeAll()
        center.reloadAfterWipe()
        XCTAssertEqual(center.summary.stats.count(.checkIn), 0)
        XCTAssertEqual(center.summary.unlockedCount, 0)
    }

    // MARK: ViewModels

    func testJourneyCalendarAlignsTheMonthOnTheFirstWeekday() {
        let center = makeCenter()
        center.start(legacyActivity: [ActivityEvent(sessionID: "decouverte_1", seconds: 600, date: day(1))])
        let now = day(7)
        let model = AchievementsViewModel(center: center, calendar: calendar, now: { now })

        // 1 October 2026 is a Thursday: three empty cells from Monday.
        XCTAssertEqual(model.monthDays.prefix(3).filter { $0 == nil }.count, 3)
        XCTAssertEqual(model.monthDays[3]?.dayNumber, 1)
        XCTAssertEqual(model.monthDays[3]?.isPracticed, true)
        XCTAssertEqual(model.monthDays[3]?.minutes, 10)
        XCTAssertEqual(model.practiceDaysThisMonth, 1)
        XCTAssertFalse(model.canShowNextMonth)
        XCTAssertFalse(model.canShowPreviousMonth)
    }

    func testJourneyWeekFiguresComeFromTheJournal() {
        let center = makeCenter()
        center.start(legacyActivity: [
            ActivityEvent(sessionID: "decouverte_1", seconds: 600, date: day(1)), // previous week
            ActivityEvent(sessionID: "decouverte_1", seconds: 600, date: day(5)),
            ActivityEvent(sessionID: "sleep_1", seconds: 300, date: day(6)),
            ActivityEvent(sessionID: "breathing_1", seconds: 120, date: day(6, hour: 21))
        ])
        let now = day(7)
        let model = AchievementsViewModel(center: center, calendar: calendar, now: { now })

        XCTAssertEqual(model.weekPracticeCount, 3)
        XCTAssertEqual(model.weekMinutes, 17)
        XCTAssertEqual(model.weekPracticeDays, 2)
    }

    func testWeekStripMarksDoneMissedTodayAndUpcomingDays() {
        let center = makeCenter()
        center.start(legacyActivity: [
            ActivityEvent(sessionID: "decouverte_1", seconds: 300, date: day(5)) // Monday
        ])
        let now = day(7) // Wednesday, nothing yet today
        let model = AchievementsViewModel(center: center, calendar: calendar, now: { now })
        let states = model.weekStatuses.map(\.state)
        XCTAssertEqual(states, [.done, .missed, .today, .upcoming, .upcoming, .upcoming, .upcoming])
        // Letters follow the app language, not the iPhone's.
        var display = calendar
        display.locale = QuietoLocalization.locale
        XCTAssertEqual(model.weekStatuses.first?.letter, display.veryShortStandaloneWeekdaySymbols[1], "The week starts on Monday")
        XCTAssertTrue(model.weekStatuses[2].isToday)
    }

    func testCelebrationShowsBadgesOneAtATime() async {
        let subject = PassthroughSubject<[Badge], Never>()
        let model = BadgeCelebrationViewModel(unlocks: subject.eraseToAnyPublisher(), displayDuration: 60)
        var shown: [String] = []
        model.onShow = { shown.append($0.id) }

        model.enqueue([Badge.all[0], Badge.all[1]])
        XCTAssertEqual(model.current?.id, Badge.all[0].id)
        model.dismiss()
        XCTAssertNil(model.current)
        try? await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(model.current?.id, Badge.all[1].id)
        XCTAssertEqual(shown, [Badge.all[0].id, Badge.all[1].id])
    }

    func testCheckInFromHomeIsRecorded() {
        let center = makeCenter()
        center.start()
        let home = HomeViewModel(achievements: center)
        home.checkIn(.racingThoughts)
        XCTAssertEqual(center.summary.stats.count(.checkIn), 1)
        XCTAssertEqual(center.summary.badges.first { $0.id == "first_check_in" }?.isUnlocked, true)
    }
}
