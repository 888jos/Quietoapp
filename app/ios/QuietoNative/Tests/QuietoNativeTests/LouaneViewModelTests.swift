import XCTest
@testable import QuietoNative

final class LouaneViewModelTests: XCTestCase {
    @MainActor
    func testRecommendationOnlyResolvesKnownCatalogueSession() {
        let model = LouaneViewModel(audioPlayer: QuietoAudioPlayer())
        let known = LouaneRecommendation(id: "sleep_1", sessionID: "sleep_1", reason: "Une pause douce.")
        let unknown = LouaneRecommendation(id: "unknown", sessionID: "unknown", reason: "")
        XCTAssertNotNil(model.session(for: known))
        XCTAssertNil(model.session(for: unknown))
    }

    func testUnavailableBackendDoesNotPretendToReply() async {
        do {
            _ = try await UnavailableLouaneBackend().send(message: "test", history: [], temporary: false)
            XCTFail("Le backend absent ne doit pas produire de réponse simulée.")
        } catch { XCTAssertTrue(true) }
    }
}
