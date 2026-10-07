import XCTest
@testable import QuietoNative

final class OnboardingTests: XCTestCase {
    private func answers(_ choices: [OnboardingStep: [String]]) -> OnboardingAnswers {
        var value = OnboardingAnswers()
        for (step, ids) in choices { value.choices[step.rawValue] = ids }
        return value
    }

    func testPlanAlwaysHasSevenDistinctCatalogueSessions() {
        let catalog = SessionCatalog()
        let combinations: [[OnboardingStep: [String]]] = [
            [:],
            [.reasons: ["sleep"], .goal: ["sleep"], .minutes: ["2"], .experience: ["never"]],
            [.reasons: ["stress", "anxiety"], .goal: ["anxiety"], .minutes: ["15"], .formats: ["breathing"]],
            [.reasons: ["focus"], .goal: ["focus"], .minutes: ["5"], .experience: ["regular"]]
        ]
        for choices in combinations {
            let plan = OnboardingPlanBuilder.build(from: answers(choices), catalog: catalog)
            XCTAssertEqual(plan.sessions.count, 7, "\(choices)")
            XCTAssertEqual(Set(plan.sessions.map(\.id)).count, 7, "\(choices)")
            XCTAssertTrue(plan.sessions.allSatisfy { session in catalog.sessions.contains { $0.id == session.id } })
        }
    }

    func testBeginnerStartsGentleAndShortTimeKeepsSessionsShort() {
        let plan = OnboardingPlanBuilder.build(from: answers([.experience: ["never"], .minutes: ["2"], .reasons: ["stress"]]))
        XCTAssertEqual(plan.sessions.first?.id, "decouverte_1")
        XCTAssertTrue(plan.sessions.dropFirst().filter { $0.durationMinutes <= 6 }.count >= 4)
    }

    func testSleepGoalBuildsASleepProgramme() {
        let plan = OnboardingPlanBuilder.build(from: answers([.reasons: ["sleep"], .goal: ["sleep"], .minutes: ["10"], .experience: ["regular"]]))
        XCTAssertTrue(plan.title.contains("sommeil"))
        XCTAssertGreaterThanOrEqual(plan.sessions.filter { $0.pillar == .sleep }.count, 3)
    }

    func testCrisisWordsAreDetectedWithoutAccentsOrCase() {
        XCTAssertTrue(OnboardingSafety.containsCrisisSignal("j'ai PLUS ENVIE DE VIVRE"))
        XCTAssertTrue(OnboardingSafety.containsCrisisSignal("je pense au Suicide"))
        XCTAssertTrue(OnboardingSafety.containsCrisisSignal("j’ai envie d’en finir"))
        XCTAssertFalse(OnboardingSafety.containsCrisisSignal("le boulot me fatigue"))
    }

    func testServerProfileUsesOnlyKeysLouaneAccepts() {
        let profile = answers([.reasons: ["sleep", "stress"], .goal: ["sleep"], .stressSources: ["work"], .experience: ["never"], .moment: ["bedtime"], .minutes: ["5"], .safety: ["yes"]]).serverProfile
        XCTAssertEqual(Set(profile.keys), ["goals", "q1", "q_focus", "q2", "q4", "q_minutes"])
        XCTAssertEqual(profile["goals"], "Le sommeil|Le stress au quotidien")
        XCTAssertFalse(profile.values.contains("Oui"), "La réponse de sécurité ne part jamais au serveur.")
    }

    @MainActor
    func testEveryScreenIsTrackedFromStartToCompletion() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        let analytics = FakeAnalytics()
        let model = makeOnboardingViewModel(preferences: preferences, analytics: analytics)
        XCTAssertEqual(analytics.events, ["onboarding_started", "onboarding_step"])
        XCTAssertEqual(analytics.properties[1]["step"], "splash")
        XCTAssertEqual(analytics.properties[1]["direction"], "start")
        XCTAssertEqual(analytics.properties[1]["index"], "1")

        model.next()
        XCTAssertEqual(analytics.events.last, "onboarding_step")
        XCTAssertEqual(analytics.properties.last?["step"], "promise")
        XCTAssertEqual(analytics.properties.last?["previous_step"], "splash")
        XCTAssertNotNil(analytics.properties.last?["previous_step_seconds"])

        model.back()
        XCTAssertEqual(analytics.properties.last?["direction"], "back")

        model.finish(playFirstSession: false)
        XCTAssertEqual(analytics.events.last, "onboarding_completed")
        XCTAssertNotNil(analytics.properties.last?["duration_seconds"])
        XCTAssertNotNil(analytics.properties.last?["active_seconds"])
        XCTAssertEqual(analytics.userProperties["onboarding_completed"], "1")
        XCTAssertNil(preferences.onboardingStartedAt)
    }

    @MainActor
    func testResumedOnboardingIsNotCountedAsANewStart() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        _ = makeOnboardingViewModel(preferences: preferences)
        preferences.onboardingStep = OnboardingStep.goal.rawValue
        let analytics = FakeAnalytics()
        _ = makeOnboardingViewModel(preferences: preferences, analytics: analytics)
        XCTAssertEqual(analytics.events, ["onboarding_step"])
        XCTAssertEqual(analytics.properties.first?["direction"], "resume")
        XCTAssertEqual(analytics.properties.first?["step"], "goal")
    }

    @MainActor
    func testCompletionKeepsSensitiveAnswersOutOfAnalytics() {
        let analytics = FakeAnalytics()
        let model = makeOnboardingViewModel(analytics: analytics)
        model.answers = answers([.reasons: ["anxiety"], .stressSources: ["health"], .safety: ["yes"], .goal: ["sleep"]])
        model.finish(playFirstSession: false)
        let sent = analytics.properties.last ?? [:]
        XCTAssertEqual(sent["goal"], "sleep")
        XCTAssertFalse(sent.keys.contains { ["reasons", "stressSources", "safety", "firstName"].contains($0) })
        XCTAssertFalse(sent.values.contains("anxiety"))
    }

    @MainActor
    func testOnboardingLengthStaysBetweenThirtyAndFiftyScreens() {
        let model = makeOnboardingViewModel()
        XCTAssertTrue((30...50).contains(model.visibleSteps.count), "\(model.visibleSteps.count) écrans")
        XCTAssertFalse(model.visibleSteps.contains(.crisisSupport))
        XCTAssertFalse(model.visibleSteps.contains(.relaunch))
    }

    @MainActor
    func testCrisisScreenNeverReachesAnalytics() async {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.onboardingStep = OnboardingStep.safety.rawValue
        let analytics = FakeAnalytics()
        let model = makeOnboardingViewModel(preferences: preferences, analytics: analytics)
        let totalBefore = analytics.properties.last?["total"]
        let option = OnboardingContent.question(for: .safety, firstName: "")!.options.first { $0.id == "yes" }!
        model.select(option, for: .safety, multiple: false)
        try? await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertEqual(model.step, .crisisSupport)
        model.continueAfterCrisis()

        let sent = analytics.properties.flatMap { $0.values }
        XCTAssertFalse(sent.contains(OnboardingStep.crisisSupport.rawValue), "Le nom de l’écran de crise ne part jamais")
        XCTAssertEqual(Set(analytics.properties.compactMap { $0["total"] }), [totalBefore!], "Le nombre d’écrans ne trahit pas la réponse")
    }

    @MainActor
    func testSafetyAnswerIsNeverWrittenToDisk() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        let model = makeOnboardingViewModel(preferences: preferences)
        model.answers = answers([.safety: ["yes"], .goal: ["sleep"]])
        XCTAssertNil(preferences.onboardingAnswers?.choices[OnboardingStep.safety.rawValue])
        XCTAssertEqual(preferences.onboardingAnswers?.choices[OnboardingStep.goal.rawValue], ["sleep"])
        XCTAssertEqual(model.answers.choices[OnboardingStep.safety.rawValue], ["yes"], "Kept in memory for the current onboarding")
    }

    @MainActor
    func testCrisisWrittenToLouaneDoesNotLoopBackToLouane() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.onboardingStep = OnboardingStep.louaneAsk.rawValue
        let model = makeOnboardingViewModel(preferences: preferences)
        model.louaneDraft = "j’ai envie d’en finir"
        model.submitLouane()
        XCTAssertEqual(model.step, .crisisSupport)
        model.continueAfterCrisis()
        XCTAssertFalse([.breathIntro, .louaneIntro, .louaneAsk, .louaneReply].contains(model.step), "\(model.step)")
    }

    func testCrisisWordsAreRecognisedInEveryLanguageOfTheApp() {
        for text in ["je veux en finir", "I want to die", "quiero morir", "ich will mich umbringen", "死にたい", "죽고 싶어요"] {
            XCTAssertTrue(OnboardingSafety.containsCrisisSignal(text), text)
        }
        XCTAssertFalse(OnboardingSafety.containsCrisisSignal("Le travail me stresse"))
    }

    func testCrisisLineFollowsTheCountry() {
        XCTAssertEqual(CrisisLine.forRegion("FR").hotline, "3114")
        XCTAssertEqual(CrisisLine.forRegion("US").hotline, "988")
        XCTAssertEqual(CrisisLine.forRegion("US").emergency, "911")
        XCTAssertEqual(CrisisLine.forRegion("KR").hotline, "109")
        XCTAssertNil(CrisisLine.forRegion("BR").hotline)
        XCTAssertEqual(CrisisLine.forRegion("BR").primaryURL.absoluteString, "tel:112")
        XCTAssertEqual(CrisisLine.forRegion("DE").hotlineURL?.absoluteString, "tel:08001110111")
    }

    @MainActor
    func testSafetyAnswerOpensTheCrisisScreenAndCanContinue() async {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.onboardingStep = OnboardingStep.safety.rawValue
        let model = makeOnboardingViewModel(preferences: preferences)
        let option = OnboardingContent.question(for: .safety, firstName: "")!.options.first { $0.id == "sometimes" }!
        model.select(option, for: .safety, multiple: false)
        try? await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertEqual(model.step, .crisisSupport)
        model.continueAfterCrisis()
        XCTAssertEqual(model.step, .breathIntro)
    }

    @MainActor
    func testCrisisTextInTheLouaneStepRoutesTo3114() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.onboardingStep = OnboardingStep.louaneAsk.rawValue
        let model = makeOnboardingViewModel(preferences: preferences)
        model.louaneDraft = "parfois je veux mourir"
        model.submitLouane()
        XCTAssertEqual(model.step, .crisisSupport)
    }

    @MainActor
    func testProgressIsResumedAfterRelaunchButNeverMidBreathing() {
        let preferences = QuietoPreferences(defaults: makeTestDefaults())
        preferences.onboardingStep = OnboardingStep.breathing.rawValue
        XCTAssertEqual(makeOnboardingViewModel(preferences: preferences).step, .breathIntro)
        preferences.onboardingStep = OnboardingStep.goal.rawValue
        XCTAssertEqual(makeOnboardingViewModel(preferences: preferences).step, .goal)
    }

    func testGenderAgreesInclusiveCopy() {
        XCTAssertEqual(QuietoGender.feminine.resolve("Je suis fatigué·e, mais je n’arrive pas à dormir"), "Je suis fatiguée, mais je n’arrive pas à dormir")
        XCTAssertEqual(QuietoGender.masculine.resolve("Je me sens seul·e ou déconnecté·e"), "Je me sens seul ou déconnecté")
        XCTAssertEqual(QuietoGender.feminine.resolve("Plus léger·e"), "Plus légère")
        XCTAssertEqual(QuietoGender.masculine.resolve("Plus léger·e"), "Plus léger")
        XCTAssertEqual(QuietoGender.feminine.resolve("Quand tu es prêt ou prête, termine."), "Quand tu es prête, termine.")
        XCTAssertEqual(QuietoGender.feminine.resolve("Aún tenso/a"), "Aún tensa")
        XCTAssertEqual(QuietoGender.masculine.resolve("Sin cambios"), "Sin cambios")
    }
}
