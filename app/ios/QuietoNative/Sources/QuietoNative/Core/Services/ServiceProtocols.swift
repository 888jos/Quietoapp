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
    /// Asks Apple again for a one-time authorization code, which the server
    /// needs to revoke Sign in with Apple when the account is deleted.
    /// Nil when the account is not linked to Apple.
    func appleAuthorizationCodeForDeletion() async throws -> String?
}

@MainActor
protocol AccountDataServicing: AnyObject {
    func subscriptionState() async throws -> QuietoSubscriptionState
    func loadPreferences() async throws -> QuietoRemotePreferences?
    func savePreferences(_ preferences: QuietoRemotePreferences) async throws
    func saveOnboarding(answers: OnboardingAnswers) async throws
    func invokeAccountData(method: String) async throws -> Data
    func deleteAccount(appleAuthorizationCode: String?) async throws
}

// MARK: Content

@MainActor
protocol ProgramRepository: AnyObject {
    func loadActiveProgram(catalog: SessionCatalog) async throws -> QuietoRemoteProgram?
    /// Abandons the active programme, if any, then writes this plan.
    func startPlan(_ state: QuietoPlanState, days: [QuietoPlanDay], title: String) async throws -> UUID
    func updateProgramRhythm(programID: UUID, rhythm: String) async throws
    /// `nextDayNumber` nil: the plan is finished.
    func completePlanStep(programID: UUID, dayNumber: Int, completedAt: Date, nextDayNumber: Int?, nextAvailableOn: Date?) async throws
}

@MainActor
protocol SessionProgressSyncing: AnyObject {
    func setFavorite(sessionID: String, favorite: Bool) async throws
    func recordCompletion(sessionID: String, listenedSeconds: Int) async throws
}

/// The practice journal of the account, so badges and the streak survive a
/// reinstall or a change of iPhone. Uploads are idempotent (entry ids).
@MainActor
protocol PracticeSyncing: AnyObject {
    func uploadPractice(_ entries: [PracticeEntry]) async throws
    func fetchPractice() async throws -> [PracticeEntry]
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
    /// The subscription as Apple sees it on this device (plan, price, dates).
    func subscriptionDetails() async -> QuietoSubscriptionDetails
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

// MARK: Enterprise

/// Free access offered by an employer (Quieto Entreprise), activated with the company code.
@MainActor
protocol EnterpriseAccessServicing: AnyObject {
    var isConfigured: Bool { get }
    /// Name of the company behind the code, without taking a seat.
    func preview(code: String) async throws -> String
    /// Takes a seat; the server then grants Premium until the end of the paid period.
    func activate(code: String) async throws -> String
}

enum EnterpriseAccessError: LocalizedError, Equatable {
    /// Refused by the server, with the sentence to show (unknown code, company full…).
    case refused(String)
    /// An anonymous account would lose the access with the phone.
    case needsAppleAccount(String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .refused(let message), .needsAppleAccount(let message): message
        case .unavailable: "Impossible de vérifier le code pour le moment. Réessaie dans un instant.".quietoLocalized
        }
    }
}

// MARK: Device

@MainActor
protocol HealthServicing: AnyObject {
    var isAvailable: Bool { get }
    /// Quieto may write mindful minutes (the only status Apple discloses).
    var isConnected: Bool { get }
    /// The permission sheet was already shown once.
    func wasAsked() async -> Bool
    func requestAuthorization() async -> Bool
    func recordMindfulSession(seconds: Int, endingAt end: Date)
    func summary(now: Date, calendar: Calendar) async -> QuietoHealthSummary
}

/// What the profile shows from Apple Health. Stays on the device.
struct QuietoHealthSummary: Equatable {
    var mindfulMinutesThisWeek = 0
    var quietoMinutesThisWeek = 0
    /// Nil when Health has no sleep for last night (or reading was refused).
    var lastNightSleepMinutes: Int?
}

protocol ReminderScheduling {
    func requestAuthorization() async -> Bool
    /// The system notification permission, without asking for it.
    func authorizationStatus() async -> QuietoNotificationStatus
    func schedule(hour: Int, minute: Int, weekdays: [Int], firstName: String)
    func scheduleTrialEndingReminder(trialDays: Int) async
    /// Replaces the text of the pending trial reminder, keeping its date.
    func refreshTrialEndingReminder(body: String) async
    func removeAll()
}

enum QuietoNotificationStatus: Equatable {
    case notDetermined
    case allowed
    case denied
}
