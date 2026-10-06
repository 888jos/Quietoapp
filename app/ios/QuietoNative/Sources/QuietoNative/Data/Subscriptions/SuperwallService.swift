import Combine
import Foundation
import StoreKit
import UIKit

#if canImport(SuperwallKit)
import SuperwallKit
#endif

/// Hard paywall: nothing in Quieto is usable without an active entitlement.
enum QuietoAccessState: Equatable {
    case checking
    case subscribed
    case locked
}

/// Single source of truth for access. Superwall presents the paywall and runs
/// StoreKit purchases; the server (Supabase `subscription-sync`) receives the
/// signed StoreKit transactions so audio, Louane and every other server feature
/// see the same entitlement. Access is granted when any of these is true:
/// Superwall reports an active entitlement, StoreKit holds a verified active
/// transaction on this device (works offline), or the server knows an
/// entitlement this device can't see (enterprise access, Android purchase
/// carried over from the Flutter app).
@MainActor
final class QuietoSuperwallService: ObservableObject {
    static let hardPaywallPlacement = "quieto_hard_paywall"
    static let onboardingPlacement = "onboarding_trial"

    @Published private(set) var isConfigured = false
    @Published private(set) var access: QuietoAccessState = .checking
    @Published var lastMessage: String?

    private var superwallActive: Bool?
    private var deviceActive: Bool?
    private var serverPremium = false
    private var identifiedUserID: String?
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: Task<Void, Never>?
    private var bypass = false
    private let server: SubscriptionServerSyncing?

    init(server: SubscriptionServerSyncing?) {
        self.server = server
    }

    func configure() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["QUIETO_SKIP_PAYWALL"] == "1" {
            bypass = true
            access = .subscribed
            return
        }
        #endif
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPERWALL_API_KEY") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.hasPrefix("REPLACE_") else {
            lastMessage = "Ajoute la clé publique Superwall dans la configuration de la cible."
            superwallActive = false
            syncWithServer()
            return
        }
        #if canImport(SuperwallKit)
        Superwall.configure(apiKey: key)
        isConfigured = true
        Superwall.shared.$subscriptionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.superwallStatusChanged(status) }
            .store(in: &cancellables)
        if let identifiedUserID { Superwall.shared.identify(userId: identifiedUserID) }
        #else
        superwallActive = false
        #endif
        syncWithServer()
    }

    /// Called whenever the Supabase session changes. The Supabase user id is a
    /// UUID, so Superwall uses it as the StoreKit `appAccountToken` and as the
    /// `originalAppUserId` of its webhooks.
    func identify(userID: String) {
        guard identifiedUserID != userID else { return }
        identifiedUserID = userID
        serverPremium = false
        #if canImport(SuperwallKit)
        if isConfigured { Superwall.shared.identify(userId: userID) }
        #endif
        syncWithServer()
    }

    /// Sign-out and account deletion: forget the previous identity everywhere.
    func reset() {
        identifiedUserID = nil
        serverPremium = false
        #if canImport(SuperwallKit)
        if isConfigured { Superwall.shared.reset() }
        #endif
        refresh()
    }

    func presentPaywall() {
        guard isConfigured else {
            lastMessage = lastMessage ?? "Superwall n’est pas configuré pour cette cible."
            return
        }
        #if canImport(SuperwallKit)
        Superwall.shared.register(placement: Self.hardPaywallPlacement) { [weak self] in
            self?.syncWithServer()
        }
        #endif
    }

    /// Onboarding paywall (Superwall placement `onboarding_trial`). `onDeclined`
    /// runs when the person closes it without buying.
    func presentOnboardingPaywall(onDeclined: @escaping () -> Void) {
        guard isConfigured else {
            lastMessage = lastMessage ?? "Superwall n’est pas configuré pour cette cible."
            return
        }
        #if canImport(SuperwallKit)
        let handler = PaywallPresentationHandler()
        handler.onDismiss { _, result in
            Task { @MainActor in
                if case .declined = result { onDeclined() } else { self.syncWithServer() }
            }
        }
        handler.onError { error in
            Task { @MainActor in self.lastMessage = "Le paywall n’a pas pu s’afficher. Réessaie dans un instant." }
        }
        Superwall.shared.register(placement: Self.onboardingPlacement, handler: handler) { [weak self] in
            self?.syncWithServer()
        }
        #endif
    }

    /// Personalises paywall copy in Superwall (`{{ user.firstName }}`, …).
    func setAttributes(_ attributes: [String: Any?]) {
        #if canImport(SuperwallKit)
        if isConfigured { Superwall.shared.setUserAttributes(attributes) }
        #endif
    }

    func restorePurchases() {
        guard isConfigured else {
            lastMessage = "Superwall n’est pas configuré pour cette cible."
            return
        }
        #if canImport(SuperwallKit)
        Task { @MainActor in
            let result = await Superwall.shared.restorePurchases()
            switch result {
            case .restored:
                lastMessage = "Achats restaurés."
            case .failed:
                lastMessage = "Impossible de restaurer les achats."
            }
            await syncNow()
        }
        #endif
    }

    /// Re-reads StoreKit and sends the verified transactions to the server.
    /// Safe to call often (launch, foreground, after purchase or restore).
    func syncWithServer() {
        syncTask?.cancel()
        syncTask = Task { await self.syncNow() }
    }

    func syncNow() async {
        let snapshot = await Self.currentStoreTransactions()
        guard !Task.isCancelled else { return }
        deviceActive = snapshot.isActive
        refresh()
        guard identifiedUserID != nil, let server, server.isConfigured else { return }
        do {
            serverPremium = try await server.syncSubscriptions(signedTransactions: snapshot.signedTransactions)
        } catch {
            // Keep the previous server answer: offline must not lock a paying user.
        }
        guard !Task.isCancelled else { return }
        refresh()
    }

    /// Apple's own subscription management sheet.
    func showManageSubscriptions() async throws {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw QuietoSubscriptionError.noActiveScene
        }
        try await AppStore.showManageSubscriptions(in: scene)
    }

    #if canImport(SuperwallKit)
    private func superwallStatusChanged(_ status: SuperwallKit.SubscriptionStatus) {
        let wasActive = superwallActive == true
        switch status {
        case .unknown: superwallActive = nil
        case .inactive: superwallActive = false
        case .active: superwallActive = status.isActive
        }
        refresh()
        if superwallActive == true, !wasActive { syncWithServer() }
    }
    #endif

    private func refresh() {
        let next: QuietoAccessState
        if bypass || superwallActive == true || deviceActive == true || serverPremium {
            next = .subscribed
        } else if deviceActive == nil {
            // StoreKit is read locally (works offline); Superwall's own status
            // may stay unknown without network and must not block the gate.
            next = .checking
        } else {
            next = .locked
        }
        if next != access { access = next }
    }

    private struct StoreSnapshot {
        let signedTransactions: [String]
        let isActive: Bool
    }

    /// Verified, non-revoked StoreKit entitlements held by this Apple ID.
    private static func currentStoreTransactions() async -> StoreSnapshot {
        var signed: [String] = []
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            signed.append(result.jwsRepresentation)
            if transaction.revocationDate == nil, (transaction.expirationDate ?? .distantFuture) > .now {
                active = true
            }
        }
        return StoreSnapshot(signedTransactions: Array(signed.prefix(20)), isActive: active)
    }
}

extension QuietoSuperwallService: SubscriptionServicing {
    var accessPublisher: AnyPublisher<QuietoAccessState, Never> { $access.eraseToAnyPublisher() }
    var willChange: AnyPublisher<Void, Never> { objectWillChange.eraseToAnyPublisher() }
}

enum QuietoSubscriptionError: Error {
    case noActiveScene
}
