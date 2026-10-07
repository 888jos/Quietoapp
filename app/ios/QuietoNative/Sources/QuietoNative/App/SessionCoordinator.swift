import Combine
import Foundation

/// Keeps the subscription identity in step with the Supabase session. The two
/// services never call each other: the Supabase user id is the Superwall user
/// id (StoreKit `appAccountToken`), and this is the only place that says so.
@MainActor
final class SessionCoordinator {
    private let backend: QuietoSupabaseService
    private let subscriptions: QuietoSuperwallService
    private var accessObserver: AnyCancellable?

    init(backend: QuietoSupabaseService, subscriptions: QuietoSuperwallService, achievements: AchievementCenter, amplitude: QuietoAmplitude) {
        self.backend = backend
        self.subscriptions = subscriptions
        backend.onIdentityEvent = { [weak subscriptions, weak achievements] event in
            guard let subscriptions else { return }
            switch event {
            case .identified(let userID):
                subscriptions.identify(userID: userID)
                amplitude.identify(userID: userID)
                // Badges and streak of this account, from another iPhone or a reinstall.
                Task { await achievements?.synchronize() }
            case .signedOut:
                subscriptions.reset()
                amplitude.reset()
            // A former Flutter account may carry an entitlement this device can't see.
            case .legacyAccountLinked: subscriptions.syncWithServer()
            }
        }
        // Lets every chart be split between subscribers and locked users.
        accessObserver = subscriptions.$access
            .removeDuplicates()
            .sink { access in
                switch access {
                case .checking: break
                case .subscribed: amplitude.setUserProperties(["subscribed": "1"])
                case .locked: amplitude.setUserProperties(["subscribed": "0"])
                }
            }
    }

    /// App launch: configure the paywall SDK, then open (or restore) a session.
    func start() {
        subscriptions.configure()
        Task { await backend.bootstrap() }
    }
}
