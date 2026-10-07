import Combine
import Foundation

/// The goal plan of the person: which day is open, what is done, the rhythm.
/// The plan lives on the iPhone (`QuietoPreferences.planState`) and is copied
/// to Supabase when possible; the server copy restores it on a new iPhone.
@MainActor
final class ProgramViewModel: ObservableObject {
    typealias ProgramRhythm = QuietoNative.ProgramRhythm

    @Published var feedback: String?
    @Published private(set) var state: QuietoPlanState?
    @Published private(set) var schedule: PlanSchedule?
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published var isPlanPickerPresented = false

    private let preferences: QuietoPreferences
    private let activity: ActivityStore
    private let catalog: SessionCatalog
    /// Nil when the backend is not configured: the plan stays local.
    private let repository: ProgramRepository?
    private let analytics: QuietoAnalyticsProviding
    /// Names the step of the day in the reminders; nil in previews and tests.
    private let reminders: PlanReminderPlanner?
    private let now: () -> Date
    private var cancellables = Set<AnyCancellable>()

    init(catalog: SessionCatalog, preferences: QuietoPreferences, activity: ActivityStore, repository: ProgramRepository?, completions: AnyPublisher<String, Never>, analytics: QuietoAnalyticsProviding = PreviewAnalyticsService(), reminders: PlanReminderPlanner? = nil, now: @escaping () -> Date = Date.init) {
        self.preferences = preferences
        self.activity = activity
        self.catalog = catalog
        self.repository = repository
        self.analytics = analytics
        self.reminders = reminders
        self.now = now
        state = preferences.planState
        rebuild()
        completions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionID in self?.sessionCompleted(sessionID) }
            .store(in: &cancellables)
        // The day changes while the app stays open: the next step may open.
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
    }

    // MARK: Reading

    var hasProgram: Bool { state != nil }
    var plan: QuietoPlan? { state?.plan }
    var title: String { plan?.title ?? "Choisis ton plan" }
    var rhythm: ProgramRhythm { state?.rhythm ?? .regular }
    /// Sessions of the counted steps, in order (a session may come back).
    var sessions: [QuietoSession] { schedule?.steps.map(\.session) ?? [] }
    var steps: [PlanSchedule.Step] { schedule?.steps ?? [] }
    var completedCount: Int { schedule?.completedCount ?? 0 }
    var totalCount: Int { schedule?.steps.count ?? 0 }
    var currentStepNumber: Int? { schedule?.currentStepNumber }
    var nextSession: QuietoSession? { schedule?.nextStep?.session }
    var isFinished: Bool { schedule?.isFinished ?? false }
    var today: PlanSchedule.Today? { schedule?.today }
    /// Session ids already heard, for the « déjà écoutée » marks.
    var completedIDs: Set<String> { Set(steps.filter(\.isCompleted).map(\.session.id)) }

    /// Steps grouped by week, for the list of the Programme tab.
    var weeks: [(number: Int, phase: QuietoPlanPhase, steps: [PlanSchedule.Step])] {
        let grouped = Dictionary(grouping: steps) { ($0.day.number - 1) / 7 }
        return grouped.keys.sorted().map { key in
            let items = grouped[key] ?? []
            return (key + 1, items.first?.day.phase ?? .practice, items)
        }
    }

    /// The plan recommended from the onboarding answers, first in the picker.
    var recommendation: PlanRecommender.Recommendation? {
        preferences.onboardingAnswers.map(PlanRecommender.recommend)
    }

    func refreshLocalProgress() { rebuild() }

    private func rebuild() {
        schedule = state.map { PlanSchedule(state: $0, catalog: catalog.sessions, now: now()) }
    }

    private func save(_ newState: QuietoPlanState?) {
        state = newState
        preferences.planState = newState
        rebuild()
        // A new step, rhythm or session: the reminders name the step of the day.
        reminders?.refresh()
    }

    // MARK: Choosing a plan

    /// Starts a plan from day 1. The previous plan, if any, is abandoned: its
    /// listens and badges stay, only the path changes.
    func start(_ planID: QuietoPlanID, source: String) {
        let previous = state
        let answers = preferences.onboardingAnswers
        let recommendation = answers.map(PlanRecommender.recommend)
        var newState = QuietoPlanState(
            planID: planID,
            startedAt: now(),
            rhythm: previous?.rhythm ?? recommendation?.rhythm ?? .regular,
            prefersShort: previous?.prefersShort ?? recommendation?.prefersShort ?? false,
            // The discovery week is only offered once.
            includesDiscovery: previous == nil && (recommendation?.includesDiscovery ?? false)
        )
        newState.remoteID = nil
        newState.situations = PlanSituations.days(for: planID, sources: answers?.multiple(.stressSources) ?? [])
        save(newState)
        isPlanPickerPresented = false
        if let previous {
            analytics.track("plan_switched", properties: ["from": previous.planID.rawValue, "to": planID.rawValue, "completed_days": String(previous.completions.count)])
        } else {
            analytics.track("plan_started", properties: ["plan": planID.rawValue, "source": source])
        }
        analytics.setUserProperties(["plan_id": planID.rawValue])
        feedback = QuietoLocalization.format("Plan « %@ » commencé.", newState.plan.title.quietoLocalized)
        Task { await pushNewPlan() }
    }

    /// Adopts a plan built elsewhere (the onboarding) without tracking a switch.
    func adopt(_ newState: QuietoPlanState) {
        save(newState)
        Task { await pushNewPlan() }
    }

    func restart() {
        guard let state else { return }
        start(state.planID, source: "restart")
    }

    private func pushNewPlan() async {
        guard let repository, let state, let schedule else { return }
        do {
            let id = try await repository.startPlan(state, days: schedule.allDays, title: state.plan.title)
            if self.state?.startedAt == state.startedAt { self.state?.remoteID = id; preferences.planState = self.state }
        } catch {
            loadError = "Ton plan est enregistré sur cet iPhone ; la synchronisation reprendra plus tard."
        }
    }

    // MARK: Progress

    /// A session ended. It moves the plan only if it is the step open today.
    func sessionCompleted(_ sessionID: String) {
        guard var current = state, let schedule, let step = schedule.step(completedBy: sessionID) else {
            rebuild()
            return
        }
        let date = now()
        current.completions[step.day.number] = date
        save(current)
        analytics.track("plan_day_completed", properties: [
            "plan": current.planID.rawValue,
            "day": String(step.day.number),
            "kind": step.day.kind.rawValue,
            "rhythm": current.rhythm.rawValue
        ])
        let next = self.schedule?.nextStep
        if self.schedule?.isFinished == true {
            analytics.track("plan_completed", properties: ["plan": current.planID.rawValue, "days": String(current.completions.count)])
            feedback = "Plan terminé. Bravo pour ce chemin."
        }
        guard let repository, let remoteID = current.remoteID else { return }
        let opensOn: Date? = {
            if case .locked(_, let opens) = self.schedule?.today { return opens }
            return next == nil ? nil : date
        }()
        Task {
            try? await repository.completePlanStep(programID: remoteID, dayNumber: step.day.number, completedAt: date, nextDayNumber: next?.day.number, nextAvailableOn: opensOn)
        }
    }

    /// Restores the plan from the account on a new iPhone, and merges the days
    /// done on another device.
    func load() async {
        rebuild()
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let remote = try await repository.loadActiveProgram(catalog: catalog)
            loadError = nil
            guard let remotePlan = remote?.plan else {
                // A plan made offline never reached the server: send it now.
                if state != nil, state?.remoteID == nil { await pushNewPlan() }
                return
            }
            if var local = state, local.planID == remotePlan.planID, local.remoteID == nil || local.remoteID == remotePlan.remoteID {
                local.remoteID = remotePlan.remoteID
                local.completions.merge(remotePlan.completions) { mine, _ in mine }
                if local != state { save(local) }
            } else if state == nil {
                save(remotePlan)
            }
        } catch {
            loadError = "Ton plan reste disponible sur cet iPhone ; la synchronisation a échoué."
        }
    }

    func saveRhythm(_ value: ProgramRhythm) {
        preferences.programRhythm = value.rawValue
        guard var current = state else { return }
        current.rhythm = value
        save(current)
        analytics.track("plan_rhythm_changed", properties: ["plan": current.planID.rawValue, "rhythm": value.rawValue])
        // German nouns keep their capital letter.
        let detail = QuietoLocalization.languageCode == "de" ? value.localizedDetail : value.localizedDetail.lowercased(with: QuietoLocalization.locale)
        feedback = QuietoLocalization.format("Rythme enregistré : %@.", detail)
        if let remoteID = current.remoteID, let repository {
            Task {
                do { try await repository.updateProgramRhythm(programID: remoteID, rhythm: value.rawValue) }
                catch { feedback = "Rythme enregistré sur cet iPhone ; la synchronisation reprendra plus tard." }
            }
        }
    }

    /// Short or normal sessions on the long days.
    func setPrefersShort(_ value: Bool) {
        guard var current = state, current.prefersShort != value else { return }
        current.prefersShort = value
        save(current)
    }

    // MARK: Stress check-in

    /// Day 0, day 14 and the end of the plan: the onboarding slider comes back.
    var dueStressCheckpoint: StressCheckpoint? { schedule?.dueStressCheckpoint }
    var stressProgression: [(checkpoint: StressCheckpoint, level: Int)] { schedule?.stressProgression ?? [] }

    /// Kept in the plan on this iPhone only: the value never reaches analytics
    /// nor the server (the plan sent to Supabase has no stress column).
    func recordStress(_ value: Int) {
        guard var current = state, let checkpoint = dueStressCheckpoint else { return }
        current.setStressLevel(value, at: checkpoint)
        save(current)
    }

    /// « 3 points de moins qu’au début », once the plan is over.
    var stressSummary: String? {
        guard let start = state?.stressLevel(at: .start), let end = state?.stressLevel(at: .end) else { return nil }
        switch start - end {
        case 1: return "1 point de moins qu’au départ.".quietoLocalized
        case let drop where drop > 1: return QuietoLocalization.format("%d points de moins qu’au départ.", drop)
        case 0: return "Le même niveau qu’au départ. Chaque plan avance à son rythme.".quietoLocalized
        default: return "Un peu plus qu’au départ. Louane peut t’aider à faire le point.".quietoLocalized
        }
    }

    /// Where the person is in the plan, for Louane.
    var louaneProgramme: LouaneClientContext.Programme? {
        guard let state, let schedule else { return nil }
        let calendar = Calendar.current
        let doneToday = state.completions.values.contains { calendar.isDate($0, inSameDayAs: now()) }
        return LouaneClientContext.Programme(
            title: state.plan.title,
            step: schedule.currentStepNumber ?? schedule.steps.count,
            isActive: !schedule.isFinished,
            isFinished: schedule.isFinished,
            doneToday: doneToday,
            nextSessionID: schedule.nextStep?.session.id,
            planID: state.planID,
            totalSteps: schedule.steps.count,
            phase: schedule.nextStep?.day.phase ?? .anchor
        )
    }

    /// Wiped with the local data on sign-out or account deletion.
    func reset() {
        state = nil
        schedule = nil
    }
}
