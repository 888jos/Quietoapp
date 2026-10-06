import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    static let completedKey = "quieto.onboarding.completedAt"
    static let answersKey = "quieto.onboarding.answers"
    static let stepKey = "quieto.onboarding.step"
    static let planIDsKey = "quieto.onboarding.plan.ids"
    static let planTitleKey = "quieto.onboarding.plan.title"

    @Published private(set) var isCompleted: Bool
    @Published private(set) var step: OnboardingStep
    @Published var answers: OnboardingAnswers { didSet { persistAnswers() } }
    @Published var louaneDraft = ""
    @Published private(set) var louaneReply: [String] = []
    @Published private(set) var plan: OnboardingPlanBuilder.Plan?
    @Published private(set) var isWorking = false
    @Published var message: String?

    let subscriptions: QuietoSuperwallService
    private let defaults: UserDefaults
    private let catalog: SessionCatalog
    private var history: [OnboardingStep] = []
    private var crisisFlagged = false
    private var cancellables = Set<AnyCancellable>()

    init(defaults: UserDefaults = .standard, catalog: SessionCatalog = SessionCatalog(), subscriptions: QuietoSuperwallService? = nil) {
        self.defaults = defaults
        self.catalog = catalog
        self.subscriptions = subscriptions ?? .shared
        var completed = defaults.object(forKey: Self.completedKey) != nil
        #if DEBUG
        if ProcessInfo.processInfo.environment["QUIETO_FORCE_ONBOARDING"] == "1" { completed = false }
        if let forced = ProcessInfo.processInfo.environment["QUIETO_ONBOARDING_STEP"], let value = OnboardingStep(rawValue: forced) {
            defaults.set(value.rawValue, forKey: Self.stepKey)
        }
        #endif
        isCompleted = completed
        answers = (defaults.data(forKey: Self.answersKey)).flatMap { try? JSONDecoder().decode(OnboardingAnswers.self, from: $0) } ?? OnboardingAnswers()
        // Resuming after the app was killed: questions are kept, but the plan
        // is rebuilt and never resumed in the middle of a system prompt.
        let saved = defaults.string(forKey: Self.stepKey).flatMap(OnboardingStep.init(rawValue:)) ?? .splash
        step = Self.resumeStep(for: saved)
        if [.profileSummary, .plan, .projection, .included, .trialTimeline, .paywall, .relaunch, .welcome].contains(step) {
            plan = OnboardingPlanBuilder.build(from: answers, catalog: catalog)
        }
        self.subscriptions.$access
            .removeDuplicates()
            .sink { [weak self] access in self?.accessChanged(access) }
            .store(in: &cancellables)
    }

    private static func resumeStep(for step: OnboardingStep) -> OnboardingStep {
        switch step {
        case .breathing, .breathResult, .stressAfter: return .breathIntro
        case .building: return .building
        case .relaunch: return .paywall
        default: return step
        }
    }

    // MARK: Navigation

    var visibleSteps: [OnboardingStep] {
        OnboardingStep.allCases.filter { step in
            switch step {
            case .crisisSupport: return crisisFlagged || self.step == .crisisSupport
            case .health: return QuietoHealthService.shared.isAvailable
            case .relaunch: return answers.relaunchShown || self.step == .relaunch
            case .account: return QuietoSupabaseService.shared.client != nil
            default: return true
            }
        }
    }

    var progress: Double {
        let steps = visibleSteps
        guard let index = steps.firstIndex(of: step) else { return 0 }
        return Double(index + 1) / Double(steps.count)
    }

    var canGoBack: Bool { !step.isLocked && !history.isEmpty }

    func next() {
        let steps = visibleSteps
        guard let index = steps.firstIndex(of: step) else { return }
        var target = index + 1 < steps.count ? steps[index + 1] : .welcome
        if target == .crisisSupport && !crisisFlagged { target = .breathIntro }
        if target == .relaunch { target = .welcome }
        if subscriptions.access == .subscribed, [.trialTimeline, .paywall, .relaunch].contains(target) { target = .welcome }
        go(to: target)
    }

    func back() {
        guard canGoBack, let previous = history.popLast() else { return }
        setStep(previous, record: false)
    }

    private func go(to target: OnboardingStep) {
        history.append(step)
        setStep(target, record: true)
    }

    private func setStep(_ target: OnboardingStep, record: Bool) {
        step = target
        defaults.set(target.rawValue, forKey: Self.stepKey)
        if record {
            var properties = ["step": target.rawValue]
            if let index = visibleSteps.firstIndex(of: target) { properties["index"] = String(index + 1) }
            Task { await QuietoSupabaseService.shared.track("onboarding_step", properties: properties) }
        }
    }

    // MARK: Answers

    func select(_ option: OnboardingOption, for step: OnboardingStep, multiple: Bool) {
        var current = answers.choices[step.rawValue] ?? []
        if multiple {
            if current.contains(option.id) { current.removeAll { $0 == option.id } } else { current.append(option.id) }
            answers.choices[step.rawValue] = current
            return
        }
        answers.choices[step.rawValue] = [option.id]
        if step == .moment {
            let reminder = OnboardingContent.defaultReminder(for: option.id)
            answers.reminderHour = reminder.hour
            answers.reminderMinute = reminder.minute
        }
        if step == .safety {
            crisisFlagged = option.id != "no"
            Task { await QuietoSupabaseService.shared.track("onboarding_safety_answered", properties: [:]) }
        }
        // Single choice moves on by itself, after the selection is visible.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            if self.step == step { self.next() }
        }
    }

    func isSelected(_ option: OnboardingOption, for step: OnboardingStep) -> Bool {
        answers.choices[step.rawValue]?.contains(option.id) == true
    }

    func hasAnswer(for step: OnboardingStep) -> Bool { !(answers.choices[step.rawValue] ?? []).isEmpty }

    func submitLouane() {
        let text = String(louaneDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600))
        if OnboardingSafety.containsCrisisSignal(text) {
            crisisFlagged = true
            go(to: .crisisSupport)
            return
        }
        if !text.isEmpty {
            // Kept on this iPhone only, in Louane's protected memory.
            let memory = LouaneMemoryStore()
            let line = "À l’inscription, elle a écrit : « \(text) »"
            memory.update(memory.text.isEmpty ? line : memory.text + "\n" + line)
        }
        let firstSession = OnboardingPlanBuilder.build(from: answers, catalog: catalog).sessions.first
        louaneReply = OnboardingLouaneScript.reply(to: text, answers: answers, firstSession: firstSession)
        next()
    }

    func continueAfterCrisis() {
        go(to: .breathIntro)
    }

    // MARK: Permissions

    func requestHealth() {
        isWorking = true
        Task {
            answers.healthAuthorized = await QuietoHealthService.shared.requestAuthorization()
            isWorking = false
            next()
        }
    }

    func requestReminders() {
        isWorking = true
        Task {
            let granted = await QuietoReminderScheduler.requestAuthorization()
            answers.remindersAuthorized = granted
            if granted {
                QuietoReminderScheduler.schedule(hour: answers.reminderHour, minute: answers.reminderMinute, weekdays: Array(1...7), firstName: answers.firstName)
                defaults.set(true, forKey: "quieto.profile.remindersEnabled")
                defaults.set(answers.reminderHour, forKey: "quieto.profile.reminderHour")
                defaults.set(answers.reminderMinute, forKey: "quieto.profile.reminderMinute")
                defaults.set(Array(1...7), forKey: "quieto.profile.reminderDays")
            }
            isWorking = false
            next()
        }
    }

    func signInWithApple() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await QuietoSupabaseService.shared.signInWithApple()
                next()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    // MARK: Plan

    /// Called by the building screen when it appears (also after a relaunch).
    func buildPlan() {
        let built = OnboardingPlanBuilder.build(from: answers, catalog: catalog)
        plan = built
        defaults.set(built.sessions.map(\.id), forKey: Self.planIDsKey)
        defaults.set(built.title, forKey: Self.planTitleKey)
        if !answers.firstName.isEmpty { defaults.set(answers.firstName, forKey: "quieto.profile.firstName") }
        subscriptions.setAttributes([
            "firstName": answers.firstName.isEmpty ? nil : answers.firstName,
            "goal": answers.single(.goal),
            "minutes": answers.single(.minutes),
            "planTitle": built.title
        ])
        Task {
            // The animation is part of the experience: at least ~4 s.
            try? await Task.sleep(nanoseconds: 4_200_000_000)
            if step == .building { next() }
        }
    }

    var stressDrop: Int {
        guard let after = answers.stressAfter else { return 0 }
        return max(0, Int((answers.stressBefore - after).rounded()))
    }

    // MARK: Paywall

    func presentPaywall() {
        guard step == .paywall || step == .relaunch else { return }
        subscriptions.presentOnboardingPaywall { [weak self] in
            guard let self else { return }
            if !self.answers.relaunchShown {
                self.answers.relaunchShown = true
                self.go(to: .relaunch)
            }
        }
    }

    func restore() {
        subscriptions.restorePurchases()
        message = subscriptions.lastMessage ?? "Restauration en cours…"
    }

    private func accessChanged(_ access: QuietoAccessState) {
        guard !isCompleted, access == .subscribed else { return }
        switch step {
        case .splash, .promise, .offer:
            // Already a subscriber (reinstall, former Flutter user): no questionnaire.
            finish(playFirstSession: false)
        case .welcome:
            break
        default:
            if plan == nil { plan = OnboardingPlanBuilder.build(from: answers, catalog: catalog) }
            if [.trialTimeline, .paywall, .relaunch].contains(step) { go(to: .welcome) }
        }
    }

    // MARK: Completion

    private(set) var onFinish: ((QuietoSession?) -> Void)?
    func setFinishHandler(_ handler: @escaping (QuietoSession?) -> Void) { onFinish = handler }

    func finish(playFirstSession: Bool) {
        guard !isCompleted else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: Self.completedKey)
        defaults.removeObject(forKey: Self.stepKey)
        isCompleted = true
        let snapshot = answers
        let currentPlan = plan
        Task { await Self.synchronise(answers: snapshot, plan: currentPlan) }
        onFinish?(playFirstSession ? currentPlan?.sessions.first : nil)
    }

    /// Sends the questionnaire, preferences and programme to Supabase. Best
    /// effort: everything also lives on the device.
    private static func synchronise(answers: OnboardingAnswers, plan: OnboardingPlanBuilder.Plan?) async {
        let backend = QuietoSupabaseService.shared
        guard backend.client != nil else { return }
        if !answers.firstName.isEmpty { try? await backend.updateProfile(firstName: answers.firstName) }
        try? await backend.saveOnboarding(answers: answers)
        try? await backend.savePreferences(QuietoRemotePreferences(
            reminderEnabled: answers.remindersAuthorized,
            reminderDays: Array(1...7),
            reminderHour: answers.reminderHour,
            reminderMinute: answers.reminderMinute,
            reminderTimezone: TimeZone.autoupdatingCurrent.identifier,
            ambientLevel: 0,
            reduceMotion: false,
            largerText: false
        ))
        if let plan, (try? await backend.loadActiveProgram()) == nil {
            _ = try? await backend.createProgram(title: plan.title, sessionIDs: plan.sessions.map(\.id), rhythm: "Soutenu")
        }
        await backend.track("onboarding_completed", properties: [
            "goal": answers.single(.goal) ?? "",
            "minutes": answers.single(.minutes) ?? "",
            "experience": answers.single(.experience) ?? "",
            "health": answers.healthAuthorized ? "1" : "0",
            "reminders": answers.remindersAuthorized ? "1" : "0"
        ])
    }

    private func persistAnswers() {
        if let data = try? JSONEncoder().encode(answers) { defaults.set(data, forKey: Self.answersKey) }
    }

    /// Profile sent to Louane once subscribed (see LouaneServices).
    nonisolated static func storedServerProfile(defaults: UserDefaults = .standard) -> [String: String] {
        guard let data = defaults.data(forKey: answersKey),
              let answers = try? JSONDecoder().decode(OnboardingAnswers.self, from: data) else { return [:] }
        return answers.serverProfile
    }
}
