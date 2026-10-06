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

    @MainActor
    func testUnknownStructuredRecommendationIsRejected() async {
        let model = LouaneViewModel(backend: InvalidRecommendationBackend(), audioPlayer: QuietoAudioPlayer())
        model.draft = "Une pause"
        model.send()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(model.messages.last?.author, .louane)
        XCTAssertNil(model.messages.last?.recommendation)
    }
}

private struct InvalidRecommendationBackend: LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        LouaneBackendReply(text: "Voici une réponse valide sans carte inventée.", recommendation: .init(id: "missing", sessionID: "missing", reason: ""))
    }
}
