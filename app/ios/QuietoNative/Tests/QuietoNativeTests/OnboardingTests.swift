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
    func testOnboardingLengthStaysBetweenThirtyAndFiftyScreens() {
        let model = OnboardingViewModel(defaults: freshDefaults())
        XCTAssertTrue((30...50).contains(model.visibleSteps.count), "\(model.visibleSteps.count) écrans")
        XCTAssertFalse(model.visibleSteps.contains(.crisisSupport))
        XCTAssertFalse(model.visibleSteps.contains(.relaunch))
    }

    @MainActor
    func testSafetyAnswerOpensTheCrisisScreenAndCanContinue() async {
        let defaults = freshDefaults()
        defaults.set(OnboardingStep.safety.rawValue, forKey: OnboardingViewModel.stepKey)
        let model = OnboardingViewModel(defaults: defaults)
        let option = OnboardingContent.question(for: .safety, firstName: "")!.options.first { $0.id == "sometimes" }!
        model.select(option, for: .safety, multiple: false)
        try? await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertEqual(model.step, .crisisSupport)
        model.continueAfterCrisis()
        XCTAssertEqual(model.step, .breathIntro)
    }

    @MainActor
    func testCrisisTextInTheLouaneStepRoutesTo3114() {
        let defaults = freshDefaults()
        defaults.set(OnboardingStep.louaneAsk.rawValue, forKey: OnboardingViewModel.stepKey)
        let model = OnboardingViewModel(defaults: defaults)
        model.louaneDraft = "parfois je veux mourir"
        model.submitLouane()
        XCTAssertEqual(model.step, .crisisSupport)
    }

    @MainActor
    func testProgressIsResumedAfterRelaunchButNeverMidBreathing() {
        let defaults = freshDefaults()
        defaults.set(OnboardingStep.breathing.rawValue, forKey: OnboardingViewModel.stepKey)
        XCTAssertEqual(OnboardingViewModel(defaults: defaults).step, .breathIntro)
        defaults.set(OnboardingStep.goal.rawValue, forKey: OnboardingViewModel.stepKey)
        XCTAssertEqual(OnboardingViewModel(defaults: defaults).step, .goal)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "quieto.tests.onboarding.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
