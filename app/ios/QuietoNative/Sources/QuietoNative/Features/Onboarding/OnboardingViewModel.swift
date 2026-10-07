import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published private(set) var isCompleted: Bool
    @Published private(set) var step: OnboardingStep
    @Published var answers: OnboardingAnswers { didSet { persistAnswers() } }
    @Published var louaneDraft = ""
    @Published private(set) var louaneReply: [String] = []
    @Published private(set) var plan: OnboardingPlanBuilder.Plan?
    @Published private(set) var isWorking = false
    @Published var message: String?

    private let preferences: QuietoPreferences
    private let catalog: SessionCatalog
    private let subscriptions: SubscriptionServicing
    private let auth: AuthServicing
    private let account: AccountDataServicing
    private let programs: ProgramRepository
    private let health: HealthServicing
    private let reminders: ReminderScheduling
    private let analytics: QuietoAnalyticsProviding
    private let louaneMemory: LouaneMemoryProviding
    private var history: [OnboardingStep] = []
    private var crisisFlagged = false
    /// The crisis screen was opened by what the person wrote to Louane (not by
    /// the safety question): leaving it must not lead back to Louane.
    private var crisisFromLouane = false
    private var stepEnteredAt = Date.now
    private var cancellables = Set<AnyCancellable>()

    init(preferences: QuietoPreferences, catalog: SessionCatalog, subscriptions: SubscriptionServicing, auth: AuthServicing, account: AccountDataServicing, programs: ProgramRepository, health: HealthServicing, reminders: ReminderScheduling, analytics: QuietoAnalyticsProviding, louaneMemory: LouaneMemoryProviding) {
        self.preferences = preferences
        self.catalog = catalog
        self.subscriptions = subscriptions
        self.auth = auth
        self.account = account
        self.programs = programs
        self.health = health
        self.reminders = reminders
        self.analytics = analytics
        self.louaneMemory = louaneMemory
        var completed = preferences.isOnboardingCompleted
        #if DEBUG
        // Development builds skip the onboarding (Accueil has a button to replay it).
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] == nil {
            completed = environment["QUIETO_FORCE_ONBOARDING"] != "1"
        }
        if let forced = ProcessInfo.processInfo.environment["QUIETO_ONBOARDING_STEP"], let value = OnboardingStep(rawValue: forced) {
            preferences.onboardingStep = value.rawValue
        }
        #endif
        isCompleted = completed
        answers = preferences.onboardingAnswers ?? OnboardingAnswers()
        // Resuming after the app was killed: questions are kept, but the plan
        // is rebuilt and never resumed in the middle of a system prompt.
        let saved = preferences.onboardingStep.flatMap(OnboardingStep.init(rawValue:)) ?? .splash
        step = Self.resumeStep(for: saved)
        if [.profileSummary, .plan, .projection, .included, .trialTimeline, .paywall, .relaunch, .welcome].contains(step) {
            plan = OnboardingPlanBuilder.build(from: answers, catalog: catalog)
        }
        subscriptions.accessPublisher
            .removeDuplicates()
            .sink { [weak self] access in self?.accessChanged(access) }
            .store(in: &cancellables)
        // `paywallNote` reads the subscription service directly.
        subscriptions.willChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        if !completed { trackEntry() }
        // Installs from before this rule may still hold the safety answer.
        if preferences.onboardingAnswers?.choices[OnboardingStep.safety.rawValue] != nil { persistAnswers() }
    }

    /// Configuration problem worth showing on the paywall step.
    var paywallNote: String? { subscriptions.isConfigured ? nil : subscriptions.lastMessage }

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
            case .health: return health.isAvailable
            case .relaunch: return answers.relaunchShown || self.step == .relaunch
            case .account: return auth.isConfigured
            default: return true
            }
        }
    }

    var progress: Double {
        let steps = visibleSteps
        guard let index = steps.firstIndex(of: step) else { return 0 }
        return Double(index + 1) / Double(steps.count)
    }

    #if DEBUG
    /// Debug button on Accueil: shows the onboarding again from the first screen.
    func replayForDebug() {
        history = []
        preferences.onboardingStep = nil
        step = .splash
        isCompleted = false
    }

    /// Floating debug button: straight to Accueil, without analytics or sync.
    func skipForDebug() {
        guard !isCompleted else { return }
        preferences.markOnboardingCompleted()
        isCompleted = true
        onFinish?(nil)
    }
    #endif

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
        setStep(previous, direction: "back")
    }

    private func go(to target: OnboardingStep) {
        history.append(step)
        setStep(target, direction: "forward")
    }

    private func setStep(_ target: OnboardingStep, direction: String) {
        let previous = step
        let seconds = closeCurrentStep()
        step = target
        preferences.onboardingStep = target.rawValue
        var properties = stepProperties(target)
        properties["direction"] = direction
        properties["previous_step"] = Self.analyticsName(previous)
        properties["previous_step_seconds"] = String(seconds)
        analytics.track("onboarding_step", properties: properties)
    }

    // MARK: Analytics

    /// A screen left open longer than this means the person walked away: the
    /// rest is not counted as time spent on the onboarding.
    private static let maxActiveSecondsPerStep: Double = 300

    /// First screen of this launch: a new onboarding or one resumed after the
    /// app was killed. Every screen, the first included, is one `onboarding_step`.
    private func trackEntry() {
        stepEnteredAt = .now
        let isNew = preferences.onboardingStartedAt == nil
        if isNew {
            preferences.onboardingStartedAt = .now
            analytics.track("onboarding_started", properties: [:])
        }
        var properties = stepProperties(step)
        properties["direction"] = isNew ? "start" : "resume"
        analytics.track("onboarding_step", properties: properties)
    }

    /// The crisis screen is reported as the safety question it belongs to,
    /// and is never counted in `index`/`total`: neither its name nor the number
    /// of screens may reveal how the person answered.
    private static func analyticsName(_ step: OnboardingStep) -> String {
        step == .crisisSupport ? OnboardingStep.safety.rawValue : step.rawValue
    }

    private func stepProperties(_ target: OnboardingStep) -> [String: String] {
        let reported = target == .crisisSupport ? OnboardingStep.safety : target
        var properties = ["step": reported.rawValue, "act": String(reported.act)]
        let steps = visibleSteps.filter { $0 != .crisisSupport }
        if let index = steps.firstIndex(of: reported) {
            properties["index"] = String(index + 1)
            properties["total"] = String(steps.count)
        }
        return properties
    }

    /// Seconds spent on the screen being left, added to the onboarding's active time.
    private func closeCurrentStep() -> Int {
        let seconds = max(0, Date.now.timeIntervalSince(stepEnteredAt))
        stepEnteredAt = .now
        preferences.onboardingActiveSeconds += min(seconds, Self.maxActiveSecondsPerStep)
        return Int(seconds.rounded())
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
        if step == .gender, let gender = QuietoGender(rawValue: option.id) {
            // Applies right away, so the next screens already agree.
            QuietoGender.set(gender)
        }
        if step == .moment {
            let reminder = OnboardingContent.defaultReminder(for: option.id)
            answers.reminderHour = reminder.hour
            answers.reminderMinute = reminder.minute
        }
        if step == .safety {
            crisisFlagged = option.id != "no"
            analytics.track("onboarding_safety_answered", properties: [:])
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
            crisisFromLouane = true
            louaneDraft = ""
            go(to: .crisisSupport)
            return
        }
        if !text.isEmpty {
            // Louane's memory is protected on this iPhone and sent with the
            // conversations once subscribed; the profile lets the person edit it.
            let line = "À l’inscription, elle a écrit : « \(text) »"
            louaneMemory.update(louaneMemory.text.isEmpty ? line : louaneMemory.text + "\n" + line)
        }
        let firstSession = OnboardingPlanBuilder.build(from: answers, catalog: catalog).sessions.first
        louaneReply = OnboardingLouaneScript.reply(to: text, answers: answers, firstSession: firstSession)
        next()
    }

    func continueAfterCrisis() {
        guard crisisFromLouane else { go(to: .breathIntro); return }
        // Coming from Louane: no scripted reply to that message, move on to
        // what follows the conversation instead of asking again.
        crisisFromLouane = false
        let steps = visibleSteps
        let next = steps.firstIndex(of: .louaneReply).flatMap { steps.indices.contains($0 + 1) ? steps[$0 + 1] : nil } ?? .welcome
        go(to: next)
    }

    // MARK: Permissions

    func requestHealth() {
        isWorking = true
        Task {
            answers.healthAuthorized = await health.requestAuthorization()
            isWorking = false
            next()
        }
    }

    func requestReminders() {
        isWorking = true
        Task {
            let granted = await reminders.requestAuthorization()
            answers.remindersAuthorized = granted
            if granted {
                reminders.schedule(hour: answers.reminderHour, minute: answers.reminderMinute, weekdays: Array(1...7), firstName: answers.firstName)
                preferences.reminder = ReminderSettings(isEnabled: true, hour: answers.reminderHour, minute: answers.reminderMinute, weekdays: Set(1...7))
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
                try await auth.signInWithApple()
                analytics.track("onboarding_account_linked", properties: [:])
                next()
            } catch {
                message = error.localizedDescription
                analytics.track("onboarding_account_failed", properties: [:])
            }
        }
    }

    // MARK: Plan

    /// Called by the building screen when it appears (also after a relaunch).
    func buildPlan() {
        let built = OnboardingPlanBuilder.build(from: answers, catalog: catalog)
        plan = built
        preferences.onboardingPlanIDs = built.sessions.map(\.id)
        preferences.onboardingPlanTitle = built.title
        if !answers.firstName.isEmpty { preferences.firstName = answers.firstName }
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

    func scheduleTrialEndingReminder() async {
        await reminders.scheduleTrialEndingReminder(trialDays: OnboardingLinks.trialDays)
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
        trackCompletion(playFirstSession: playFirstSession)
        preferences.markOnboardingCompleted()
        isCompleted = true
        let snapshot = answers
        let currentPlan = plan
        Task { await synchronise(answers: snapshot, plan: currentPlan) }
        onFinish?(playFirstSession ? currentPlan?.sessions.first : nil)
    }

    /// Sends the questionnaire, preferences and programme to Supabase. Best
    /// effort: everything also lives on the device.
    private func synchronise(answers: OnboardingAnswers, plan: OnboardingPlanBuilder.Plan?) async {
        guard auth.isConfigured else { return }
        if !answers.firstName.isEmpty { try? await auth.updateProfile(firstName: answers.firstName) }
        try? await account.saveOnboarding(answers: answers)
        try? await account.savePreferences(QuietoRemotePreferences(
            reminderEnabled: answers.remindersAuthorized,
            reminderDays: Array(1...7),
            reminderHour: answers.reminderHour,
            reminderMinute: answers.reminderMinute,
            reminderTimezone: TimeZone.autoupdatingCurrent.identifier,
            ambientLevel: 0,
            reduceMotion: false,
            largerText: false
        ))
        if let plan, (try? await programs.loadActiveProgram(catalog: catalog)) == nil {
            _ = try? await programs.createProgram(title: plan.title, sessionIDs: plan.sessions.map(\.id), rhythm: "Soutenu")
        }
    }

    /// Sent before the network sync so a slow or missing backend never loses it.
    /// Only practical answers leave the device: reasons, stress, sleep and the
    /// safety question stay out of analytics.
    private func trackCompletion(playFirstSession: Bool) {
        let lastStepSeconds = closeCurrentStep()
        let startedAt = preferences.onboardingStartedAt
        var properties = [
            "goal": answers.single(.goal) ?? "",
            "minutes": answers.single(.minutes) ?? "",
            "experience": answers.single(.experience) ?? "",
            "moment": answers.single(.moment) ?? "",
            "health": answers.healthAuthorized ? "1" : "0",
            "reminders": answers.remindersAuthorized ? "1" : "0",
            "subscribed": subscriptions.access == .subscribed ? "1" : "0",
            "first_session": playFirstSession ? "1" : "0",
            "last_step": Self.analyticsName(step),
            "last_step_seconds": String(lastStepSeconds),
            "active_seconds": String(Int(preferences.onboardingActiveSeconds.rounded()))
        ]
        if let startedAt { properties["duration_seconds"] = String(Int(Date.now.timeIntervalSince(startedAt).rounded())) }
        analytics.track("onboarding_completed", properties: properties)
        analytics.setUserProperties([
            "onboarding_completed": "1",
            "goal": properties["goal"] ?? "",
            "minutes_per_day": properties["minutes"] ?? "",
            "experience": properties["experience"] ?? "",
            "moment": properties["moment"] ?? "",
            "health_connected": properties["health"] ?? "0",
            "reminders_enabled": properties["reminders"] ?? "0"
        ].filter { !$0.value.isEmpty })
    }

    /// The answer to the safety question is never written to disk (UserDefaults
    /// end up in iCloud backups): it only lives in memory during the onboarding.
    private func persistAnswers() {
        var stored = answers
        stored.choices.removeValue(forKey: OnboardingStep.safety.rawValue)
        preferences.onboardingAnswers = stored
    }
}
