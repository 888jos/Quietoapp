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

    private func makeHome(planIDs: [String], listened: [(String, Date)]) -> (LocalHomeService, ProgramViewModel) {
        let defaults = makeTestDefaults()
        let preferences = QuietoPreferences(defaults: defaults)
        preferences.firstName = "Camille"
        preferences.onboardingPlanIDs = planIDs
        preferences.onboardingPlanTitle = "Retrouver le sommeil en 7 jours"
        let activity = ActivityStore(defaults: defaults)
        let journal = PracticeJournal(defaults: defaults)
        for (id, date) in listened {
            activity.record(sessionID: id, seconds: 300, at: date)
            journal.record(kind: .meditation, contentID: id, seconds: 300, at: date)
        }
        let program = ProgramViewModel(catalog: SessionCatalog(), preferences: preferences, activity: activity, repository: nil, completions: Empty().eraseToAnyPublisher())
        return (LocalHomeService(program: program, journal: journal, preferences: preferences, catalog: SessionCatalog()), program)
    }

    func testHomeShowsTheRealProgrammeAndTheLastListening() {
        let yesterday = Date().addingTimeInterval(-86_400)
        let (home, _) = makeHome(planIDs: ["decouverte_1", "screen_off", "sleep_3"], listened: [("decouverte_1", yesterday)])

        let snapshot = home.localSnapshot()

        XCTAssertEqual(snapshot.firstName, "Camille")
        XCTAssertEqual(snapshot.program?.title, "Retrouver le sommeil en 7 jours")
        XCTAssertEqual(snapshot.program?.completedDays, [1])
        XCTAssertEqual(snapshot.program?.totalDays, 3)
        XCTAssertEqual(snapshot.nextSession?.id, "screen_off")
        XCTAssertEqual(snapshot.nextStep, 2)
        XCTAssertEqual(snapshot.progress.lastListened?.id, "decouverte_1")
        XCTAssertEqual(snapshot.progress.lastListenedAt, yesterday)
    }

    func testHomeHasNoDemoValuesForANewPerson() {
        let (home, _) = makeHome(planIDs: ["decouverte_1"], listened: [])
        let snapshot = home.localSnapshot()
        XCTAssertNil(snapshot.progress.lastListened)
        XCTAssertEqual(snapshot.program?.completedDays, [])
        XCTAssertEqual(snapshot.nextStep, 1)
        XCTAssertNotEqual(snapshot.firstName, "Léa")
    }
}
