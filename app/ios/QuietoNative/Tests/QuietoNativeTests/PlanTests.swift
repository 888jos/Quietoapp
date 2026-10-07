import XCTest
@testable import QuietoNative

final class PlanTests: XCTestCase {
    private let catalog = SessionCatalog().sessions
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }
    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }
    private func state(_ plan: QuietoPlanID = .stress, rhythm: ProgramRhythm = .sustained, short: Bool = false, discovery: Bool = false, completions: [Int: Date] = [:]) -> QuietoPlanState {
        var value = QuietoPlanState(planID: plan, startedAt: date(1), rhythm: rhythm, prefersShort: short, includesDiscovery: discovery)
        value.completions = completions
        return value
    }

    // MARK: Catalogue

    func testSixPlansOfFourWeeksWithFiveMainDaysAndTwoFreeDays() {
        XCTAssertEqual(PlanCatalog.all.count, 6)
        XCTAssertEqual(Set(PlanCatalog.all.map(\.id)), Set(QuietoPlanID.allCases))
        let byID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        for plan in PlanCatalog.all {
            XCTAssertEqual(plan.days.count, 28, plan.title)
            XCTAssertEqual(plan.days.map(\.number), Array(1...28), plan.title)
            for week in 0..<4 {
                let days = plan.days[(week * 7)..<(week * 7 + 7)]
                XCTAssertEqual(days.filter { $0.kind == .main }.count, 5, "\(plan.title) semaine \(week + 1)")
                XCTAssertEqual(days.filter { $0.kind == .free }.count, 2, "\(plan.title) semaine \(week + 1)")
            }
            for day in plan.days {
                guard let session = byID[day.sessionID] else { return XCTFail("\(plan.title) jour \(day.number) : \(day.sessionID) absente du catalogue") }
                if day.kind == .free { XCTAssertEqual(session.practiceType, .breathing, "\(plan.title) jour \(day.number) : un jour libre est une respiration") }
                else { XCTAssertNotEqual(session.practiceType, .breathing, "\(plan.title) jour \(day.number) : un jour principal est une séance guidée") }
            }
            XCTAssertTrue(plan.shortSessions.allSatisfy { byID[$0].map { $0.durationMinutes <= 7 } ?? false }, plan.title)
            // Enough variety: a key session may come back, not the whole plan.
            XCTAssertGreaterThanOrEqual(Set(plan.days.filter { $0.kind == .main }.map(\.sessionID)).count, 15, plan.title)
            XCTAssertEqual(plan.days.first?.phase, .understand)
            XCTAssertEqual(plan.days.last?.phase, .anchor)
        }
        XCTAssertTrue(PlanCatalog.discoveryWeek.allSatisfy { byID[$0] != nil })
    }

    // MARK: Schedule

    func testRhythmDecidesWhichDaysCount() {
        XCTAssertEqual(PlanSchedule(state: state(rhythm: .sustained), catalog: catalog, now: date(1), calendar: calendar).steps.count, 28)
        XCTAssertEqual(PlanSchedule(state: state(rhythm: .regular), catalog: catalog, now: date(1), calendar: calendar).steps.count, 20)
        XCTAssertEqual(PlanSchedule(state: state(rhythm: .gentle), catalog: catalog, now: date(1), calendar: calendar).steps.count, 20)
        let withDiscovery = PlanSchedule(state: state(rhythm: .regular, discovery: true), catalog: catalog, now: date(1), calendar: calendar)
        XCTAssertEqual(withDiscovery.steps.count, 27)
        XCTAssertEqual(withDiscovery.steps.first?.session.id, "decouverte_1")
        XCTAssertEqual(withDiscovery.steps[7].day.phase, .understand)
    }

    func testNextStepOpensTheNextDayAndMissedDaysDoNotCount() {
        let done = state(completions: [1: date(1, hour: 21)])
        guard case .locked(let next, let opensOn) = PlanSchedule(state: done, catalog: catalog, now: date(1, hour: 23), calendar: calendar).today else {
            return XCTFail("Une étape par jour.")
        }
        XCTAssertEqual(next.day.number, 2)
        XCTAssertEqual(opensOn, calendar.startOfDay(for: date(2)))
        XCTAssertEqual(PlanSchedule(state: done, catalog: catalog, now: date(2, hour: 0), calendar: calendar).today, .available(next))
        // Five days later, the person picks up where they left: day 2, no penalty.
        let later = PlanSchedule(state: done, catalog: catalog, now: date(7), calendar: calendar)
        XCTAssertEqual(later.nextStep?.day.number, 2)
        XCTAssertEqual(later.currentStepNumber, 2)
    }

    func testGentleRhythmWaitsTwoDays() {
        let done = state(rhythm: .gentle, completions: [1: date(3)])
        if case .available = PlanSchedule(state: done, catalog: catalog, now: date(4, hour: 20), calendar: calendar).today { XCTFail("Doux : un jour de repos entre deux étapes.") }
        guard case .available(let step) = PlanSchedule(state: done, catalog: catalog, now: date(5), calendar: calendar).today else { return XCTFail() }
        XCTAssertEqual(step.day.number, 2)
    }

    func testOnlyTheOpenStepCountsForACompletedSession() {
        let schedule = PlanSchedule(state: state(), catalog: catalog, now: date(1), calendar: calendar)
        XCTAssertEqual(schedule.step(completedBy: "express_5")?.day.number, 1)
        XCTAssertNil(schedule.step(completedBy: "between_calls"), "Le jour 2 n’est pas encore ouvert.")
        let locked = PlanSchedule(state: state(completions: [1: date(1)]), catalog: catalog, now: date(1, hour: 22), calendar: calendar)
        XCTAssertNil(locked.step(completedBy: "between_calls"))
    }

    func testShortVariantReplacesOnlyTheLongMainDays() {
        let normal = PlanSchedule(state: state(.sleep), catalog: catalog, now: date(1), calendar: calendar)
        let short = PlanSchedule(state: state(.sleep, short: true), catalog: catalog, now: date(1), calendar: calendar)
        XCTAssertEqual(normal.steps.count, short.steps.count)
        for (long, quick) in zip(normal.steps, short.steps) {
            if long.day.kind == .main && long.session.durationMinutes > 8 {
                XCTAssertLessThanOrEqual(quick.session.durationMinutes, 7, "Jour \(long.day.number)")
            } else {
                XCTAssertEqual(long.session.id, quick.session.id, "Jour \(long.day.number)")
            }
        }
        // Finishing the short version counts for the day.
        var started = state(.sleep, short: true)
        started.completions = Dictionary(uniqueKeysWithValues: (1...4).map { ($0, date(1)) })
        let schedule = PlanSchedule(state: started, catalog: catalog, now: date(3), calendar: calendar)
        guard case .available(let step) = schedule.today else { return XCTFail() }
        XCTAssertEqual(schedule.step(completedBy: step.session.id)?.day.number, step.day.number)
    }

    func testChangingRhythmKeepsTheDaysDone() {
        let done: [Int: Date] = [1: date(1), 2: date(2), 3: date(3)]
        let sustained = PlanSchedule(state: state(rhythm: .sustained, completions: done), catalog: catalog, now: date(5), calendar: calendar)
        let regular = PlanSchedule(state: state(rhythm: .regular, completions: done), catalog: catalog, now: date(5), calendar: calendar)
        XCTAssertEqual(sustained.completedCount, 3)
        XCTAssertEqual(regular.completedCount, 2, "Le jour libre 3 ne compte plus, mais reste fait.")
        XCTAssertEqual(regular.nextStep?.day.number, 4)
    }

    func testPlanEndsAfterTheLastStep() {
        let all = Dictionary(uniqueKeysWithValues: (1...28).map { ($0, date(1)) })
        let schedule = PlanSchedule(state: state(completions: all), catalog: catalog, now: date(2), calendar: calendar)
        XCTAssertTrue(schedule.isFinished)
        XCTAssertNil(schedule.nextStep)
        XCTAssertNil(schedule.step(completedBy: "express_5"))
    }

    func testStateSurvivesStorage() throws {
        let value = state(.relationships, rhythm: .gentle, short: true, discovery: true, completions: [1: date(1), 2: date(2)])
        let decoded = try JSONDecoder().decode(QuietoPlanState.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(decoded, value)
    }

    // MARK: Stress check-in

    func testStressCheckInsComeOnDayZeroDayFourteenAndTheEnd() {
        var value = state(rhythm: .sustained)
        XCTAssertEqual(PlanSchedule(state: value, catalog: catalog, now: date(1), calendar: calendar).dueStressCheckpoint, .start)
        value.setStressLevel(7, at: .start)
        XCTAssertNil(PlanSchedule(state: value, catalog: catalog, now: date(1), calendar: calendar).dueStressCheckpoint)

        value.completions = Dictionary(uniqueKeysWithValues: (1...13).map { ($0, date(1)) })
        XCTAssertNil(PlanSchedule(state: value, catalog: catalog, now: date(20), calendar: calendar).dueStressCheckpoint)
        value.completions[14] = date(1)
        XCTAssertEqual(PlanSchedule(state: value, catalog: catalog, now: date(20), calendar: calendar).dueStressCheckpoint, .middle)
        value.setStressLevel(5, at: .middle)
        XCTAssertNil(PlanSchedule(state: value, catalog: catalog, now: date(20), calendar: calendar).dueStressCheckpoint)

        value.completions = Dictionary(uniqueKeysWithValues: (1...28).map { ($0, date(1)) })
        let finished = PlanSchedule(state: value, catalog: catalog, now: date(30), calendar: calendar)
        XCTAssertEqual(finished.dueStressCheckpoint, .end)
        value.setStressLevel(12, at: .end)
        let answered = PlanSchedule(state: value, catalog: catalog, now: date(30), calendar: calendar)
        XCTAssertNil(answered.dueStressCheckpoint)
        XCTAssertEqual(answered.stressProgression.map(\.level), [7, 5, 10], "Le curseur va de 0 à 10.")
    }

    func testDayFourteenOfThePlanSkipsTheDiscoveryWeek() {
        var value = state(rhythm: .sustained, discovery: true)
        value.setStressLevel(6, at: .start)
        value.completions = Dictionary(uniqueKeysWithValues: (1...14).map { ($0, date(1)) })
        XCTAssertNil(PlanSchedule(state: value, catalog: catalog, now: date(20), calendar: calendar).dueStressCheckpoint, "Jour 7 du plan seulement.")
        value.completions[21] = date(1)
        XCTAssertEqual(PlanSchedule(state: value, catalog: catalog, now: date(20), calendar: calendar).dueStressCheckpoint, .middle)
    }

    func testOnboardingSliderIsDayZero() {
        var answers = OnboardingAnswers()
        answers.stressBefore = 8
        let plan = OnboardingPlanBuilder.build(from: answers, now: date(1))
        XCTAssertEqual(plan.state.stressLevel(at: .start), 8)
        XCTAssertNil(PlanSchedule(state: plan.state, catalog: catalog, now: date(1), calendar: calendar).dueStressCheckpoint)
    }

    func testStressLevelsSurviveStorageAndOlderStatesStillDecode() throws {
        var value = state()
        value.setStressLevel(4, at: .start)
        XCTAssertEqual(try JSONDecoder().decode(QuietoPlanState.self, from: JSONEncoder().encode(value)), value)
        let legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state())) as! [String: Any]
        let decoded = try JSONDecoder().decode(QuietoPlanState.self, from: JSONSerialization.data(withJSONObject: legacy.filter { $0.key != "stressLevels" }))
        XCTAssertNil(decoded.stressLevels)
    }
}
