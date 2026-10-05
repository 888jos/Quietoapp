import XCTest
@testable import QuietoNative

@MainActor
final class HomeViewModelTests: XCTestCase {
    func testCheckInCreatesAnExplainedRecommendationWithoutReplacingNextSession() {
        let model = HomeViewModel()
        let plannedID = model.snapshot.nextSession?.id
        model.feeling = .tired

        XCTAssertNotNil(model.recommendation)
        XCTAssertEqual(model.recommendation?.id, "sleep_1")
        XCTAssertEqual(model.snapshot.nextSession?.id, plannedID)
    }

    func testProgramProgressUsesData() {
        let model = HomeViewModel()
        XCTAssertEqual(model.snapshot.program?.completedDays.count, 2)
        XCTAssertEqual(model.snapshot.program?.totalDays, 7)
    }
}
