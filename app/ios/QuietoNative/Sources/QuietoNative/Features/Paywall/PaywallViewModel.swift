import Combine
import Foundation

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published private(set) var isSigningIn = false
    @Published var message: String?

    private let subscriptions: SubscriptionServicing
    private let auth: AuthServicing
    private var cancellables = Set<AnyCancellable>()

    init(subscriptions: SubscriptionServicing, auth: AuthServicing) {
        self.subscriptions = subscriptions
        self.auth = auth
        // The computed values below read both services directly.
        subscriptions.willChange
            .merge(with: auth.statePublisher.map { _ in () })
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var access: QuietoAccessState { subscriptions.access }
    var isChecking: Bool { access == .checking }

    /// Former subscribers may own an Apple-linked account with an entitlement.
    var canSignIn: Bool {
        if case .authenticated = auth.state { return false }
        return auth.isConfigured
    }

    /// Configuration problem worth showing (missing Superwall key).
    var configurationNote: String? { subscriptions.isConfigured ? nil : subscriptions.lastMessage }

    func presentIfLocked() {
        if access == .locked { subscriptions.presentPaywall() }
    }

    func presentPaywall() { subscriptions.presentPaywall() }

    func restorePurchases() {
        subscriptions.restorePurchases()
        message = subscriptions.lastMessage ?? "Restauration en cours…"
    }

    func signInWithApple() {
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do { try await auth.signInWithApple() } catch { message = error.localizedDescription }
        }
    }
}
