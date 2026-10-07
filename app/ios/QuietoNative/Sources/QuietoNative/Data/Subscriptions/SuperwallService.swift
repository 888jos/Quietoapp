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
    private var updatesTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private var identifiedUserID: String?
    private var cancellables = Set<AnyCancellable>()
    private var syncTask: Task<Void, Never>?
    private var bypass = false
    private let server: SubscriptionServerSyncing?

    /// Paywall and purchase events from Superwall, renamed for Quieto's analytics.
    var onAnalyticsEvent: ((String, [String: String]) -> Void)?

    init(server: SubscriptionServerSyncing?, defaults: UserDefaults = .standard) {
        self.server = server
        self.defaults = defaults
    }

    // MARK: Server access cache

    /// An access granted by the server only (company plan, Android purchase)
    /// is remembered for a few days, so a cold start without network does not
    /// lock a paying person out. Audio and Louane stay checked by the server.
    private static let serverPremiumKey = "quieto.subscription.serverPremium"
    private static let serverPremiumGrace: TimeInterval = 3 * 86_400

    private func cachedServerPremium(for userID: String) -> Bool {
        guard let cached = defaults.dictionary(forKey: Self.serverPremiumKey),
              cached["user"] as? String == userID,
              let until = cached["until"] as? Double else { return false }
        return Date(timeIntervalSince1970: until) > .now
    }

    private func rememberServerPremium(_ value: Bool) {
        guard value, let identifiedUserID else {
            defaults.removeObject(forKey: Self.serverPremiumKey)
            return
        }
        defaults.set(["user": identifiedUserID, "until": Date.now.addingTimeInterval(Self.serverPremiumGrace).timeIntervalSince1970], forKey: Self.serverPremiumKey)
    }

    func configure() {
        #if DEBUG
        // Unit tests run inside the app: never reach Superwall or StoreKit from them.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            access = .locked
            return
        }
        // Development builds open straight into the app. QUIETO_REAL_PAYWALL=1 in
        // the scheme tests the real paywall; Release builds always use it.
        if ProcessInfo.processInfo.environment["QUIETO_REAL_PAYWALL"] != "1" {
            bypass = true
            access = .subscribed
            return
        }
        #endif
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPERWALL_API_KEY") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.hasPrefix("REPLACE_") else {
            lastMessage = "Ajoute la clé publique Superwall dans la configuration de la cible.".quietoLocalized
            superwallActive = false
            listenForTransactionUpdates()
            syncWithServer()
            return
        }
        #if canImport(SuperwallKit)
        Superwall.configure(apiKey: key)
        Superwall.shared.delegate = self
        isConfigured = true
        Superwall.shared.$subscriptionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.superwallStatusChanged(status) }
            .store(in: &cancellables)
        if let identifiedUserID { Superwall.shared.identify(userId: identifiedUserID) }
        #else
        superwallActive = false
        #endif
        listenForTransactionUpdates()
        syncWithServer()
    }

    /// Called whenever the Supabase session changes. The Supabase user id is a
    /// UUID, so Superwall uses it as the StoreKit `appAccountToken` and as the
    /// `originalAppUserId` of its webhooks.
    func identify(userID: String) {
        guard identifiedUserID != userID else { return }
        identifiedUserID = userID
        serverPremium = cachedServerPremium(for: userID)
        #if canImport(SuperwallKit)
        if isConfigured { Superwall.shared.identify(userId: userID) }
        #endif
        syncWithServer()
    }

    /// Sign-out and account deletion: forget the previous identity everywhere.
    func reset() {
        identifiedUserID = nil
        serverPremium = false
        rememberServerPremium(false)
        #if canImport(SuperwallKit)
        if isConfigured { Superwall.shared.reset() }
        #endif
        refresh()
    }

    func presentPaywall() {
        guard isConfigured else {
            lastMessage = lastMessage ?? "Superwall n’est pas configuré pour cette cible.".quietoLocalized
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
            lastMessage = lastMessage ?? "Superwall n’est pas configuré pour cette cible.".quietoLocalized
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
            Task { @MainActor in self.lastMessage = "Le paywall n’a pas pu s’afficher. Réessaie dans un instant.".quietoLocalized }
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
            lastMessage = "Superwall n’est pas configuré pour cette cible.".quietoLocalized
            return
        }
        #if canImport(SuperwallKit)
        Task { @MainActor in
            let result = await Superwall.shared.restorePurchases()
            switch result {
            case .restored:
                lastMessage = "Achats restaurés.".quietoLocalized
            case .failed:
                lastMessage = "Impossible de restaurer les achats.".quietoLocalized
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
            rememberServerPremium(serverPremium)
        } catch {
            // Keep the previous server answer: offline must not lock a paying user.
        }
        guard !Task.isCancelled else { return }
        refresh()
    }

    /// Renewals, expiries, refunds and purchases made elsewhere (Family
    /// Sharing, another device) arrive here while the app is open.
    private func listenForTransactionUpdates() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.syncNow()
            }
        }
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

    func subscriptionDetails() async -> QuietoSubscriptionDetails {
        guard let transaction = await Self.latestSubscriptionTransaction() else {
            return serverPremium || bypass ? QuietoSubscriptionDetails(status: .grantedByServer) : .none
        }
        let product = try? await StoreKit.Product.products(for: [transaction.productID]).first
        var details = QuietoSubscriptionDetails(
            status: .expired,
            planName: product?.displayName,
            price: product.flatMap(Self.priceLabel),
            date: transaction.expirationDate
        )
        let isTrial = transaction.offerType == .introductory
        let statuses = (try? await product?.subscription?.status) ?? []
        let status = statuses.first { candidate in
            guard case .verified(let current) = candidate.transaction else { return false }
            return current.originalID == transaction.originalID
        } ?? statuses.first
        if let status {
            let renewal: StoreKit.Product.SubscriptionInfo.RenewalInfo? = {
                if case .verified(let info) = status.renewalInfo { return info }
                return nil
            }()
            switch status.state {
            case .subscribed:
                if renewal?.willAutoRenew == false { details.status = .cancelled }
                else { details.status = isTrial ? .trial : .active }
                if details.status == .active, let next = renewal?.renewalDate { details.date = next }
            case .inGracePeriod:
                details.status = .gracePeriod
                details.date = renewal?.gracePeriodExpirationDate ?? details.date
            case .inBillingRetryPeriod:
                details.status = .billingRetry
            default:
                details.status = .expired
            }
        } else if transaction.revocationDate == nil, (transaction.expirationDate ?? .distantFuture) > .now {
            // Offline: Apple's renewal status is unknown, the transaction is not.
            details.status = isTrial ? .trial : .active
        }
        if !details.hasAccess, serverPremium || bypass {
            return QuietoSubscriptionDetails(status: .grantedByServer)
        }
        return details
    }

    /// The most recent auto-renewable subscription of this Apple ID, current
    /// first, otherwise the last one that ended.
    private static func latestSubscriptionTransaction() async -> Transaction? {
        func newest(_ sequence: Transaction.Transactions) async -> Transaction? {
            var latest: Transaction?
            for await result in sequence {
                guard case .verified(let transaction) = result, transaction.productType == .autoRenewable else { continue }
                if (transaction.expirationDate ?? .distantPast) > (latest?.expirationDate ?? .distantPast) { latest = transaction }
            }
            return latest
        }
        if let current = await newest(Transaction.currentEntitlements) { return current }
        return await newest(Transaction.all)
    }

    private static func priceLabel(_ product: StoreKit.Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        let unit: String
        switch (period.unit, period.value) {
        case (.year, 1): unit = "an".quietoLocalized
        case (.month, 1): unit = "mois".quietoLocalized
        case (.week, 1): unit = "semaine".quietoLocalized
        case (.month, let value): unit = String(format: "%d mois".quietoLocalized, value)
        case (.day, let value): unit = String(format: "%d jours".quietoLocalized, value)
        default: return product.displayPrice
        }
        return "\(product.displayPrice) / \(unit)"
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

#if canImport(SuperwallKit)
extension QuietoSuperwallService: SuperwallDelegate {
    /// Client-side funnel only. Renewals, cancellations and revenue happen on
    /// Apple's servers: they reach Amplitude through Superwall's own
    /// integration, not from the app.
    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        let mapped: (name: String, paywall: PaywallInfo, product: StoreProduct?)
        switch eventInfo.event {
        case .paywallOpen(let paywall): mapped = ("paywall_viewed", paywall, nil)
        case .paywallClose(let paywall): mapped = ("paywall_closed", paywall, nil)
        case .paywallDecline(let paywall): mapped = ("paywall_declined", paywall, nil)
        case .transactionStart(let product, let paywall): mapped = ("purchase_started", paywall, product)
        case .transactionAbandon(let product, let paywall): mapped = ("purchase_abandoned", paywall, product)
        case .transactionFail(_, let paywall): mapped = ("purchase_failed", paywall, nil)
        case .transactionComplete(_, let product, _, let paywall): mapped = ("purchase_completed", paywall, product)
        case .freeTrialStart(let product, let paywall): mapped = ("trial_started", paywall, product)
        case .subscriptionStart(let product, let paywall): mapped = ("subscription_started", paywall, product)
        case .transactionRestore(_, let paywall): mapped = ("purchase_restored", paywall, nil)
        default: return
        }
        var properties = ["paywall": mapped.paywall.identifier]
        if let placement = mapped.paywall.presentedByPlacementWithName { properties["placement"] = placement }
        if let product = mapped.product {
            properties["product"] = product.productIdentifier
            properties["price"] = "\(product.price)"
            if let currency = product.currencyCode { properties["currency"] = currency }
        }
        onAnalyticsEvent?(mapped.name, properties)
    }
}
#endif

extension QuietoSuperwallService: SubscriptionServicing {
    var accessPublisher: AnyPublisher<QuietoAccessState, Never> { $access.eraseToAnyPublisher() }
    var willChange: AnyPublisher<Void, Never> { objectWillChange.eraseToAnyPublisher() }
}

enum QuietoSubscriptionError: Error {
    case noActiveScene
}
