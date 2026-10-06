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

extension LouaneViewModelTests {
    @MainActor
    func testStoppingAResponseIsNotAnErrorAndDropsTheLateReply() async {
        let model = LouaneViewModel(backend: SlowBackend(), audioPlayer: QuietoAudioPlayer())
        model.draft = "Bonjour"
        model.send()
        model.cancelResponse()
        XCTAssertEqual(model.status, .idle)
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(model.status, .idle)
        XCTAssertEqual(model.messages.map(\.author), [.user])
    }

    @MainActor
    func testMissingSubscriptionIsALimitNotARetryableFailure() async {
        let model = LouaneViewModel(backend: FailingBackend(error: LouaneServiceError.premiumRequired), audioPlayer: QuietoAudioPlayer())
        model.draft = "Bonjour"
        model.send()
        try? await Task.sleep(nanoseconds: 80_000_000)
        guard case .limited = model.status else { return XCTFail("Attendu : .limited, obtenu \(model.status)") }
    }

    @MainActor
    func testDailyLimitAlwaysMentionsTheCrisisLine() {
        XCTAssertTrue(LouaneServiceError.dailyLimit.localizedDescription.contains("3114"))
    }

    @MainActor
    func testHistorySentToLouaneDoesNotRepeatTheCurrentMessage() async {
        let backend = RecordingBackend()
        let model = LouaneViewModel(backend: backend, audioPlayer: QuietoAudioPlayer())
        model.draft = "Premier"
        model.send()
        try? await Task.sleep(nanoseconds: 80_000_000)
        model.draft = "Second"
        model.send()
        try? await Task.sleep(nanoseconds: 80_000_000)
        let histories = await backend.histories
        XCTAssertEqual(histories.first?.count, 0)
        XCTAssertEqual(histories.last?.map(\.text), ["Premier", "Réponse"])
    }
}

private struct SlowBackend: LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        try? await Task.sleep(nanoseconds: 150_000_000)
        return LouaneBackendReply(text: "Réponse tardive", recommendation: nil)
    }
}

private struct FailingBackend: LouaneBackendProviding {
    let error: Error
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply { throw error }
}

private actor RecordingBackend: LouaneBackendProviding {
    private(set) var histories: [[LouaneMessage]] = []
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        histories.append(history)
        return LouaneBackendReply(text: "Réponse", recommendation: nil)
    }
}

private struct InvalidRecommendationBackend: LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        LouaneBackendReply(text: "Voici une réponse valide sans carte inventée.", recommendation: .init(id: "missing", sessionID: "missing", reason: ""))
    }
}
