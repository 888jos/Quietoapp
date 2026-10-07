import Combine
import Foundation
@testable import QuietoNative

// Fakes for the service protocols, so every ViewModel can be built without
// Supabase, Superwall, HealthKit or notification permissions.

func makeTestDefaults() -> UserDefaults {
    let name = "quieto.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@MainActor
final class FakeSubscriptions: SubscriptionServicing {
    @Published var access: QuietoAccessState
    var isConfigured = true
    var lastMessage: String?
    private(set) var syncCount = 0
    private(set) var paywallPresentations = 0
    private(set) var restoreCount = 0

    init(access: QuietoAccessState = .locked) { self.access = access }

    var accessPublisher: AnyPublisher<QuietoAccessState, Never> { $access.eraseToAnyPublisher() }
    var willChange: AnyPublisher<Void, Never> { $access.map { _ in () }.eraseToAnyPublisher() }
    func presentPaywall() { paywallPresentations += 1 }
    func presentOnboardingPaywall(onDeclined: @escaping () -> Void) { paywallPresentations += 1 }
    func setAttributes(_ attributes: [String: Any?]) {}
    func restorePurchases() { restoreCount += 1 }
    func syncWithServer() { syncCount += 1 }
    func syncNow() async { syncCount += 1 }
    func showManageSubscriptions() async throws {}
    var details = QuietoSubscriptionDetails.none
    func subscriptionDetails() async -> QuietoSubscriptionDetails { details }
}

@MainActor
final class FakeAuth: AuthServicing {
    @Published var state: QuietoAuthState = .anonymous(userID: "anon")
    var remoteFirstName: String?
    var isConfigured = true
    var signInError: Error?
    private(set) var signOutCount = 0
    private(set) var updatedFirstNames: [String] = []

    var statePublisher: AnyPublisher<QuietoAuthState, Never> { $state.eraseToAnyPublisher() }
    func signInWithApple() async throws {
        if let signInError { throw signInError }
        state = .authenticated(userID: "apple", email: nil)
    }
    var signOutError: Error?
    func signOutToAnonymous() async throws {
        if let signOutError { throw signOutError }
        signOutCount += 1; state = .anonymous(userID: "anon-2")
    }
    func resetAfterAccountDeletion() async { state = .anonymous(userID: "anon-3") }
    func updateProfile(firstName: String) async throws { updatedFirstNames.append(firstName) }
    var appleCode: String?
    func appleAuthorizationCodeForDeletion() async throws -> String? { appleCode }
}

/// Stands in for the whole Supabase data layer.
@MainActor
final class FakeBackend: AccountDataServicing, ProgramRepository, SessionProgressSyncing, LouaneRepository {
    var remoteProgram: QuietoRemoteProgram?
    var programError: Error?
    var remotePreferences: QuietoRemotePreferences?
    var memory = ""
    private(set) var favorites: [(String, Bool)] = []
    private(set) var completions: [(String, Int)] = []
    private(set) var savedPreferences: [QuietoRemotePreferences] = []
    private(set) var savedMessages: [LouaneMessage] = []
    private(set) var deletedConversations: [UUID] = []

    func subscriptionState() async throws -> QuietoSubscriptionState { .inactive }
    func loadPreferences() async throws -> QuietoRemotePreferences? { remotePreferences }
    func savePreferences(_ preferences: QuietoRemotePreferences) async throws { savedPreferences.append(preferences) }
    func saveOnboarding(answers: OnboardingAnswers) async throws {}
    func invokeAccountData(method: String) async throws -> Data { Data("{}".utf8) }
    private(set) var deletions: [String?] = []
    func deleteAccount(appleAuthorizationCode: String?) async throws { deletions.append(appleAuthorizationCode) }

    func loadActiveProgram(catalog: SessionCatalog) async throws -> QuietoRemoteProgram? {
        if let programError { throw programError }
        return remoteProgram
    }
    private(set) var startedPlans: [QuietoPlanState] = []
    private(set) var completedSteps: [(day: Int, next: Int?)] = []
    func startPlan(_ state: QuietoPlanState, days: [QuietoPlanDay], title: String) async throws -> UUID {
        if let programError { throw programError }
        startedPlans.append(state)
        return UUID()
    }
    func updateProgramRhythm(programID: UUID, rhythm: String) async throws {}
    func completePlanStep(programID: UUID, dayNumber: Int, completedAt: Date, nextDayNumber: Int?, nextAvailableOn: Date?) async throws {
        completedSteps.append((dayNumber, nextDayNumber))
    }

    func setFavorite(sessionID: String, favorite: Bool) async throws { favorites.append((sessionID, favorite)) }
    func recordCompletion(sessionID: String, listenedSeconds: Int) async throws { completions.append((sessionID, listenedSeconds)) }

    func saveConversationMessage(conversationID: UUID, title: String, message: LouaneMessage, temporary: Bool) async throws { savedMessages.append(message) }
    func conversationHistory() async throws -> [QuietoConversationSummary] { [] }
    func messages(conversationID: UUID) async throws -> [LouaneMessage] { [] }
    func deleteConversation(_ id: UUID) async throws { deletedConversations.append(id) }
    func loadMemory() async throws -> String { memory }
    func saveMemory(_ value: String) async throws { memory = value }
    func deleteMemory() async throws { memory = "" }
}

@MainActor
final class FakePracticeSync: PracticeSyncing {
    var remote: [PracticeEntry] = []
    var uploadError: Error?
    private(set) var uploaded: [PracticeEntry] = []
    func uploadPractice(_ entries: [PracticeEntry]) async throws {
        if let uploadError { throw uploadError }
        uploaded.append(contentsOf: entries)
    }
    func fetchPractice() async throws -> [PracticeEntry] { remote }
}

@MainActor
final class FakeHealth: HealthServicing {
    var isAvailable = true
    var grants = true
    var isConnected = false
    var asked = false
    var healthSummary = QuietoHealthSummary()
    private(set) var recordedSeconds: [Int] = []
    func wasAsked() async -> Bool { asked }
    func requestAuthorization() async -> Bool { asked = true; isConnected = grants; return grants }
    func summary(now: Date, calendar: Calendar) async -> QuietoHealthSummary { healthSummary }
    func recordMindfulSession(seconds: Int, endingAt end: Date) { recordedSeconds.append(seconds) }
}

final class FakeReminders: ReminderScheduling {
    var grants = true
    private(set) var scheduled: [(hour: Int, minute: Int, weekdays: [Int])] = []
    private(set) var removeCount = 0
    func requestAuthorization() async -> Bool { grants }
    func authorizationStatus() async -> QuietoNotificationStatus { grants ? .allowed : .denied }
    func schedule(hour: Int, minute: Int, weekdays: [Int], firstName: String) { scheduled.append((hour, minute, weekdays)) }
    private(set) var trialReminderBodies: [String] = []
    func scheduleTrialEndingReminder(trialDays: Int) async {}
    func refreshTrialEndingReminder(body: String) async { trialReminderBodies.append(body) }
    func removeAll() { removeCount += 1 }
}

final class FakeAnalytics: QuietoAnalyticsProviding {
    private(set) var events: [String] = []
    private(set) var properties: [[String: String]] = []
    private(set) var userProperties: [String: String] = [:]
    func track(_ event: String, properties: [String: String]) {
        events.append(event)
        self.properties.append(properties)
    }
    func setUserProperties(_ properties: [String: String]) { userProperties.merge(properties) { $1 } }
}

@MainActor
final class FakePlayback: QuietoPlaybackProviding {
    private(set) var played: [String] = []
    private(set) var playedAmbiences: [String] = []
    func play(_ session: QuietoSession) { played.append(session.id) }
    func playAmbience(_ ambience: QuietoAmbience) { playedAmbiences.append(ambience.id) }
}

final class FakeDownloads: QuietoDownloadManaging {
    var downloadedIDs = Set<String>()
    var progress = [String: Double]()
    var occupiedBytes: Int64 = 0
    private(set) var deleteAllCount = 0
    func isDownloaded(_ session: QuietoSession) -> Bool { downloadedIDs.contains(session.id) }
    func start(_ session: QuietoSession) -> Bool { progress[session.id] = 0; return true }
    func cancel(_ session: QuietoSession) { progress[session.id] = nil }
    func delete(_ session: QuietoSession) { downloadedIDs.remove(session.id) }
    func localURL(for session: QuietoSession) -> URL? { nil }
    func deleteAll() { deleteAllCount += 1; downloadedIDs.removeAll() }
}

final class InMemoryLouaneMemory: LouaneMemoryProviding {
    private(set) var text = ""
    func update(_ text: String) { self.text = text }
    func remove() { text = "" }
}

// MARK: ViewModel factories

@MainActor
func makeLouaneViewModel(
    backend: LouaneBackendProviding = LouanePreviewBackend(),
    repository: LouaneRepository? = nil,
    subscriptions: SubscriptionServicing? = nil,
    analytics: QuietoAnalyticsProviding = FakeAnalytics(),
    playback: QuietoPlaybackProviding? = nil,
    ambiences: [QuietoAmbience] = [QuietoAmbience(id: "rain", title: "Pluie sur la fenêtre", subtitle: "")]
) -> LouaneViewModel {
    LouaneViewModel(
        backend: backend,
        memory: InMemoryLouaneMemory(),
        repository: repository,
        playback: playback ?? FakePlayback(),
        subscriptions: subscriptions,
        analytics: analytics,
        catalog: SessionCatalog(),
        preferences: QuietoPreferences(defaults: makeTestDefaults()),
        ambiences: ambiences
    )
}

@MainActor
func makeSessionsViewModel(
    preferences: QuietoPreferences = QuietoPreferences(defaults: makeTestDefaults()),
    downloads: QuietoDownloadManaging = FakeDownloads(),
    progress: SessionProgressSyncing? = nil
) -> SessionsViewModel {
    SessionsViewModel(
        catalog: SessionCatalog(),
        audioPlayer: QuietoAudioPlayer(preferences: preferences),
        downloads: downloads,
        preferences: preferences,
        progress: progress
    )
}

@MainActor
func makeOnboardingViewModel(
    preferences: QuietoPreferences = QuietoPreferences(defaults: makeTestDefaults()),
    subscriptions: FakeSubscriptions? = nil,
    auth: FakeAuth? = nil,
    backend: FakeBackend? = nil,
    health: FakeHealth? = nil,
    reminders: FakeReminders = FakeReminders(),
    analytics: FakeAnalytics = FakeAnalytics(),
    louaneMemory: LouaneMemoryProviding = InMemoryLouaneMemory()
) -> OnboardingViewModel {
    let backend = backend ?? FakeBackend()
    return OnboardingViewModel(
        preferences: preferences,
        catalog: SessionCatalog(),
        subscriptions: subscriptions ?? FakeSubscriptions(),
        auth: auth ?? FakeAuth(),
        account: backend,
        health: health ?? FakeHealth(),
        reminders: reminders,
        analytics: analytics,
        louaneMemory: louaneMemory
    )
}
