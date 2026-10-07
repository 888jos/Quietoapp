import Combine
import XCTest
@testable import QuietoNative

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testProgramProgressUsesData() {
        let model = HomeViewModel()
        XCTAssertEqual(model.snapshot.program?.completedDays.count, 2)
        XCTAssertEqual(model.snapshot.program?.totalDays, 7)
    }

    // MARK: Real home

    private func makeHome(plan: QuietoPlanID?, completedDays: [Int: Date] = [:], listened: [(String, Date)], now: Date = .now) -> (LocalHomeService, ProgramViewModel) {
        let defaults = makeTestDefaults()
        let preferences = QuietoPreferences(defaults: defaults)
        preferences.firstName = "Camille"
        if let plan {
            var state = QuietoPlanState(planID: plan, startedAt: now.addingTimeInterval(-5 * 86_400), rhythm: .sustained, prefersShort: false, includesDiscovery: false)
            state.completions = completedDays
            preferences.planState = state
        }
        let activity = ActivityStore(defaults: defaults)
        let journal = PracticeJournal(defaults: defaults)
        for (id, date) in listened {
            activity.record(sessionID: id, seconds: 300, at: date)
            journal.record(kind: .meditation, contentID: id, seconds: 300, at: date)
        }
        let program = ProgramViewModel(catalog: SessionCatalog(), preferences: preferences, activity: activity, repository: nil, completions: Empty().eraseToAnyPublisher(), now: { now })
        return (LocalHomeService(program: program, journal: journal, preferences: preferences, catalog: SessionCatalog()), program)
    }

    func testHomeShowsTheStepOfTheDayAndTheLastListening() {
        let yesterday = Date().addingTimeInterval(-86_400)
        let (home, _) = makeHome(plan: .sleep, completedDays: [1: yesterday], listened: [("screen_off", yesterday)])

        let snapshot = home.localSnapshot()

        XCTAssertEqual(snapshot.firstName, "Camille")
        XCTAssertEqual(snapshot.program?.title, "Mieux dormir")
        XCTAssertEqual(snapshot.program?.completedDays, [1])
        XCTAssertEqual(snapshot.program?.totalDays, 28)
        XCTAssertEqual(snapshot.nextSession?.id, "express_4")
        XCTAssertEqual(snapshot.nextStep, 2)
        XCTAssertNil(snapshot.program?.opensOn)
        XCTAssertEqual(snapshot.progress.lastListened?.id, "screen_off")
        XCTAssertEqual(snapshot.progress.lastListenedAt, yesterday)
    }

    func testHomeSaysWhenTodaysStepIsDone() {
        let (home, _) = makeHome(plan: .sleep, completedDays: [1: .now], listened: [])
        XCTAssertNotNil(home.localSnapshot().program?.opensOn)
    }

    func testHomeHasNoDemoValuesForANewPerson() {
        let (home, _) = makeHome(plan: nil, listened: [])
        let snapshot = home.localSnapshot()
        XCTAssertNil(snapshot.progress.lastListened)
        XCTAssertNil(snapshot.program)
        XCTAssertNotEqual(snapshot.firstName, "Léa")
    }
}
