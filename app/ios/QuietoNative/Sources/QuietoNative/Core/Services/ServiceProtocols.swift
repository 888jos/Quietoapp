import Combine
import Foundation

// Contracts between the ViewModels and the outside world. ViewModels only see
// these protocols; `AppContainer` hands them the live implementations
// (Supabase, Superwall, HealthKit, UserNotifications) and tests hand them fakes.

// MARK: Account

@MainActor
protocol AuthServicing: AnyObject {
    var state: QuietoAuthState { get }
    var statePublisher: AnyPublisher<QuietoAuthState, Never> { get }
    var remoteFirstName: String? { get }
    /// False when the Supabase keys are missing from the build.
    var isConfigured: Bool { get }
    func signInWithApple() async throws
    func signOutToAnonymous() async throws
    func resetAfterAccountDeletion() async
    func updateProfile(firstName: String) async throws
}

@MainActor
protocol AccountDataServicing: AnyObject {
    func subscriptionState() async throws -> QuietoSubscriptionState
    func loadPreferences() async throws -> QuietoRemotePreferences?
    func savePreferences(_ preferences: QuietoRemotePreferences) async throws
    func saveOnboarding(answers: OnboardingAnswers) async throws
    func invokeAccountData(method: String) async throws -> Data
}

// MARK: Content

@MainActor
protocol ProgramRepository: AnyObject {
    func loadHome(catalog: SessionCatalog) async throws -> QuietoHomeSnapshot
    func loadActiveProgram(catalog: SessionCatalog) async throws -> QuietoRemoteProgram?
    func createProgram(title: String, sessionIDs: [String], rhythm: String) async throws -> UUID
    func updateProgramRhythm(programID: UUID, rhythm: String) async throws
}

@MainActor
protocol SessionProgressSyncing: AnyObject {
    func setFavorite(sessionID: String, favorite: Bool) async throws
    func recordCompletion(sessionID: String, listenedSeconds: Int) async throws
}

@MainActor
protocol LouaneRepository: AnyObject {
    func saveConversationMessage(conversationID: UUID, title: String, message: LouaneMessage, temporary: Bool) async throws
    func conversationHistory() async throws -> [QuietoConversationSummary]
    func messages(conversationID: UUID) async throws -> [LouaneMessage]
    func deleteConversation(_ id: UUID) async throws
    func loadMemory() async throws -> String
    func saveMemory(_ value: String) async throws
    func deleteMemory() async throws
}

@MainActor
protocol AudioURLSigning: AnyObject {
    func signedAudioURL(path: String) async throws -> URL
}

// MARK: Subscription

@MainActor
protocol SubscriptionServicing: AnyObject {
    var access: QuietoAccessState { get }
    var accessPublisher: AnyPublisher<QuietoAccessState, Never> { get }
    /// Fires before any published value changes, for ViewModels that re-expose them.
    var willChange: AnyPublisher<Void, Never> { get }
    var isConfigured: Bool { get }
    var lastMessage: String? { get }
    func presentPaywall()
    func presentOnboardingPaywall(onDeclined: @escaping () -> Void)
    func setAttributes(_ attributes: [String: Any?])
    func restorePurchases()
    func syncWithServer()
    func syncNow() async
    func showManageSubscriptions() async throws
}

extension SubscriptionServicing {
    var hasActiveEntitlement: Bool { access == .subscribed }
}

/// What the subscription layer needs from the server, without knowing it is Supabase.
@MainActor
protocol SubscriptionServerSyncing: AnyObject {
    var isConfigured: Bool { get }
    func syncSubscriptions(signedTransactions: [String]) async throws -> Bool
}

// MARK: Device

@MainActor
protocol HealthServicing: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorization() async -> Bool
    func recordMindfulSession(seconds: Int, endingAt end: Date)
}

protocol ReminderScheduling {
    func requestAuthorization() async -> Bool
    func schedule(hour: Int, minute: Int, weekdays: [Int], firstName: String)
    func scheduleTrialEndingReminder(trialDays: Int) async
    func removeAll()
}
