import XCTest
@testable import QuietoNative

final class SessionsViewModelTests: XCTestCase {
    @MainActor
    func testSearchAndGoalFilterUseCatalogData() {
        let model = makeSessionsViewModel()
        model.selectGoal(.sleep)
        model.query = "respiration"
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.goal == .sleep })
        XCTAssertTrue(model.filteredSessions.contains { $0.id == "stress_2" })
    }

    @MainActor
    func testDurationFilterExcludesLongSessions() {
        let model = makeSessionsViewModel()
        model.durationFilter = .underFive
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.durationMinutes <= 5 })
    }

    @MainActor
    func testCategoryAndSituationFiltersUseStructuredMetadata() {
        let model = makeSessionsViewModel()
        model.selectCategory(.work)
        XCTAssertGreaterThanOrEqual(model.filteredSessions.count, 13)
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.category == .work })
        model.selectGoal(.focus)
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.category == .work && $0.goal == .focus })

        model.resetFilters()
        model.selectSituation(.tiredButAwake)
        XCTAssertNil(model.selectedCategory)
        XCTAssertEqual(model.filteredSessions.count, 6)
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.situations.contains(.tiredButAwake) })
    }

    @MainActor
    func testSearchIndexesThemesAndSituations() {
        let model = makeSessionsViewModel()
        model.query = "solitude"
        XCTAssertTrue(model.filteredSessions.contains { $0.id == "lonely_evening" })
    }

    func testOfflineDownloadRequiresPublishedAudioPath() {
        let published = QuietoSession(id: "a", title: "A", durationMinutes: 5, subtitle: "", imageName: "", isPremium: false, audioFile: "fr/a.m4a")
        let unpublished = QuietoSession(id: "b", title: "B", durationMinutes: 5, subtitle: "", imageName: "", isPremium: false)
        XCTAssertTrue(published.isDownloadAvailable)
        XCTAssertFalse(unpublished.isDownloadAvailable)
        XCTAssertTrue(SessionCatalog().sessions.filter { $0.readerMode == .breathing }.allSatisfy { !$0.isDownloadAvailable })
    }

    // MARK: For you now

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.autoupdatingCurrent.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    func testMomentFollowsTheLocalHour() {
        XCTAssertEqual(DayMoment(date: at(7)), .morning)
        XCTAssertEqual(DayMoment(date: at(12)), .midday)
        XCTAssertEqual(DayMoment(date: at(16)), .afternoon)
        XCTAssertEqual(DayMoment(date: at(19)), .evening)
        XCTAssertEqual(DayMoment(date: at(22)), .bedtime)
        XCTAssertEqual(DayMoment(date: at(0, 30)), .bedtime)
        XCTAssertEqual(DayMoment(date: at(3)), .night)
    }

    func testLateEveningSuggestsSleepAndMorningDoesNot() {
        let catalog = SessionCatalog().sessions
        let bedtime = SessionRecommender.recommend(from: catalog, moment: .bedtime)
        XCTAssertEqual(bedtime.count, 6)
        XCTAssertTrue(bedtime.allSatisfy { $0.goal == .sleep || $0.category == .night }, bedtime.map(\.id).description)
        let morning = SessionRecommender.recommend(from: catalog, moment: .morning)
        XCTAssertEqual(morning.count, 6)
        XCTAssertFalse(morning.contains { $0.goal == .sleep })
        XCTAssertLessThanOrEqual(morning.filter { $0.readerMode == .breathing }.count, 2)
    }

    func testJustPlayedSessionMovesDown() {
        let catalog = SessionCatalog().sessions
        let first = SessionRecommender.recommend(from: catalog, moment: .bedtime)[0]
        let again = SessionRecommender.recommend(from: catalog, moment: .bedtime, recentlyPlayed: [first.id])
        XCTAssertNotEqual(again.first?.id, first.id)
    }
}
