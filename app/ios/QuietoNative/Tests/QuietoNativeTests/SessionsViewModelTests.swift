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

    @MainActor
    func testThemeAndSituationFiltersUseStructuredMetadata() {
        let model = SessionsViewModel(audioPlayer: QuietoAudioPlayer())
        model.selectTheme(.work)
        XCTAssertFalse(model.filteredSessions.isEmpty)
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.themes.contains(.work) })

        model.resetFilters()
        model.selectSituation(.tiredButAwake)
        XCTAssertEqual(model.filteredSessions.count, 6)
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.practiceType == .meditation })
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.situations.contains(.tiredButAwake) })
    }

    @MainActor
    func testSearchIndexesThemesAndSituations() {
        let model = SessionsViewModel(audioPlayer: QuietoAudioPlayer())
        model.query = "solitude"
        XCTAssertFalse(model.filteredSessions.isEmpty)
        XCTAssertTrue(model.filteredSessions.allSatisfy { $0.themes.contains(.solitude) })
    }

    func testOfflineDownloadRequiresPublishedAudioPath() throws {
        let sessions = SessionCatalog().sessions.filter { $0.readerMode == .guidedVoice }
        let available = try XCTUnwrap(sessions.first { !$0.audioFile.isEmpty })
        let unavailable = try XCTUnwrap(sessions.first { $0.audioFile.isEmpty })
        XCTAssertTrue(available.isDownloadAvailable)
        XCTAssertFalse(unavailable.isDownloadAvailable)
        XCTAssertTrue(SessionCatalog().sessions.filter { $0.readerMode == .breathing }.allSatisfy { !$0.isDownloadAvailable })
    }
}
