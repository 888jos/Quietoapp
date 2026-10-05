import XCTest
@testable import QuietoNative

final class SessionsViewModelTests: XCTestCase {
    @MainActor
    func testSearchAndPillarFilterUseCatalogData() {
        let defaults = UserDefaults(suiteName: "quieto.native.tests.search")!
        defaults.removePersistentDomain(forName: "quieto.native.tests.search")
        let model = SessionsViewModel(audioPlayer: QuietoAudioPlayer(), defaults: defaults)
        model.selectedPillar = .stress
        model.query = "respiration"
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.pillar == .stress })
        XCTAssertTrue(model.filteredSessions.contains { $0.title == "Respiration 4-7-8" })
    }

    @MainActor
    func testDurationFilterExcludesLongSessions() {
        let model = SessionsViewModel(audioPlayer: QuietoAudioPlayer())
        model.selectedPillar = nil
        model.durationFilter = .underFive
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.durationMinutes <= 5 })
    }
}
