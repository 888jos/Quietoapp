import XCTest
@testable import QuietoNative

final class LouaneViewModelTests: XCTestCase {
    @MainActor
    func testRecommendationOnlyResolvesKnownCatalogueSession() {
        let model = makeLouaneViewModel()
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
        let model = makeLouaneViewModel(backend: InvalidRecommendationBackend())
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
        let model = makeLouaneViewModel(backend: SlowBackend())
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
        let model = makeLouaneViewModel(backend: FailingBackend(error: LouaneServiceError.premiumRequired))
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
        let model = makeLouaneViewModel(backend: backend)
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

extension LouaneViewModelTests {
    @MainActor
    func testCrisisWordsShowTheListeningLineBeforeAnyAnswer() {
        let model = makeLouaneViewModel(backend: SlowBackend())
        model.draft = "J'ai envie d'en finir"
        model.send()
        XCTAssertTrue(model.showsCrisisSupport)
        model.newConversation()
        XCTAssertFalse(model.showsCrisisSupport)
    }

    @MainActor
    func testOrdinaryMessageDoesNotShowTheCrisisCard() {
        let model = makeLouaneViewModel(backend: SlowBackend())
        model.draft = "Je suis un peu fatigué ce soir"
        model.send()
        XCTAssertFalse(model.showsCrisisSupport)
    }

    @MainActor
    func testCrisisSignalNeverReachesAnalytics() async {
        let analytics = FakeAnalytics()
        let model = makeLouaneViewModel(backend: SlowBackend(), analytics: analytics)
        model.draft = "je veux mourir"
        model.send()
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertTrue(analytics.events.allSatisfy { !$0.contains("crisis") && !$0.contains("crise") })
        XCTAssertFalse(analytics.properties.flatMap(\.values).contains { $0.contains("mourir") })
    }

    @MainActor
    func testOpeningAnotherConversationDropsTheReplyOnItsWay() async {
        let model = makeLouaneViewModel(backend: SlowBackend(), repository: FakeBackend())
        model.draft = "Bonjour"
        model.send()
        await model.openConversation(QuietoConversationSummary(id: UUID(), title: "Hier", isTemporary: false, updatedAt: .now))
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertFalse(model.messages.contains { $0.text == "Réponse tardive" })
        XCTAssertEqual(model.status, .idle)
    }

    @MainActor
    func testRateLimitIsAShortPauseNotTheDailyCap() async {
        let model = makeLouaneViewModel(backend: FailingBackend(error: LouaneServiceError.tooFast))
        model.draft = "Bonjour"
        model.send()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(model.status, .limited(LouaneServiceError.tooFast.localizedDescription))
        XCTAssertNotEqual(LouaneServiceError.tooFast.localizedDescription, LouaneServiceError.dailyLimit.localizedDescription)
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

// MARK: - Sounds, launch cards and context sent to Louane

final class LouaneLaunchTests: XCTestCase {
    @MainActor
    func testMeditationWithSoundPlaysBothAndDropsUnknownSound() async {
        let playback = FakePlayback()
        let model = makeLouaneViewModel(backend: FixedReplyBackend(recommendation: .init(id: "x", sessionID: "sleep_1", ambienceID: "rain", reason: "Pour dormir")), playback: playback)
        model.draft = "Je n’arrive pas à dormir"
        model.send()
        try? await Task.sleep(nanoseconds: 80_000_000)
        let rec = try? XCTUnwrap(model.messages.last?.recommendation)
        XCTAssertEqual(rec?.sessionID, "sleep_1")
        XCTAssertEqual(rec?.ambienceID, "rain")
        XCTAssertEqual(rec?.reason, "Pour dormir")
        if let rec { model.play(rec) }
        XCTAssertEqual(playback.played, ["sleep_1"])
        XCTAssertEqual(playback.playedAmbiences, ["rain"])

        let soundOnly = makeLouaneViewModel(backend: FixedReplyBackend(recommendation: .init(id: "y", sessionID: "missing", ambienceID: "cafe")))
        soundOnly.draft = "Un son"
        soundOnly.send()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertNil(soundOnly.messages.last?.recommendation, "Ni la séance inconnue ni le son non inclus ne doivent rester.")
    }

    func testParseReadsSessionSoundAndReason() throws {
        let body = Data(#"{"result":{"bulles":["Installe-toi"],"securite":false,"seance":{"id":"sleep_1","raison":"Pour que le sommeil vienne"},"son":{"id":"rain","raison":""}}}"#.utf8)
        let reply = try URLSessionLouaneBackend.parse(body, temporary: false)
        XCTAssertEqual(reply.text, "Installe-toi")
        XCTAssertEqual(reply.recommendation?.sessionID, "sleep_1")
        XCTAssertEqual(reply.recommendation?.ambienceID, "rain")
        XCTAssertEqual(reply.recommendation?.reason, "Pour que le sommeil vienne")

        let soundOnly = try URLSessionLouaneBackend.parse(Data(#"{"result":{"bulles":["Voilà"],"seance":null,"son":{"id":"ocean","raison":"Pour ralentir"}}}"#.utf8), temporary: false)
        XCTAssertNil(soundOnly.recommendation?.sessionID)
        XCTAssertEqual(soundOnly.recommendation?.reason, "Pour ralentir")

        XCTAssertThrowsError(try URLSessionLouaneBackend.parse(Data(#"{"result":{"bulles":[],"paywall":true}}"#.utf8), temporary: false)) {
            XCTAssertEqual($0 as? LouaneServiceError, .premiumRequired)
        }
    }

    func testContextListsRecentListensAndProgrammeProgress() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let events = [
            ActivityEvent(sessionID: "decouverte_1", seconds: 300, date: now.addingTimeInterval(-3 * 86_400)),
            ActivityEvent(sessionID: "sleep_1", seconds: 600, date: now.addingTimeInterval(-86_400)),
            ActivityEvent(sessionID: "sleep_1", seconds: 600, date: now.addingTimeInterval(-60))
        ]
        let context = LouaneClientContext.make(events: events, programmeTitle: "Mieux dormir", programmeIDs: ["decouverte_1", "breathing_1", "sleep_1"], hasProgram: true, now: now, calendar: calendar)
        XCTAssertEqual(context.listens.first, .init(sessionID: "sleep_1", count: 2, daysAgo: 0))
        XCTAssertEqual(context.listens.last?.daysAgo, 3)
        XCTAssertEqual(context.programme?.step, 3)
        XCTAssertEqual(context.programme?.nextSessionID, "breathing_1")
        XCTAssertEqual(context.programme?.doneToday, true)
        XCTAssertEqual(context.programme?.isActive, true)
        XCTAssertNil(LouaneClientContext.make(events: [], programmeTitle: "", programmeIDs: [], hasProgram: false, now: now, calendar: calendar).programme)
    }
}

private struct FixedReplyBackend: LouaneBackendProviding {
    let recommendation: LouaneRecommendation
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        LouaneBackendReply(text: "Je te la lance.", recommendation: recommendation)
    }
}
