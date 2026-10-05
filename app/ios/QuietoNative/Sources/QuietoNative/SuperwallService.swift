import Foundation

#if canImport(SuperwallKit)
import SuperwallKit
#endif

@MainActor
final class QuietoSuperwallService: ObservableObject {
    static let shared = QuietoSuperwallService()
    @Published private(set) var isConfigured = false
    @Published var lastMessage: String?

    private init() {}

    var hasActiveEntitlement: Bool {
        #if canImport(SuperwallKit)
        return isConfigured && Superwall.shared.subscriptionStatus.isActive
        #else
        return false
        #endif
    }

    func configure() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPERWALL_API_KEY") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.hasPrefix("REPLACE_") else {
            lastMessage = "Ajoute la clé publique Superwall dans la configuration de la cible."
            return
        }
        #if canImport(SuperwallKit)
        Superwall.configure(apiKey: key)
        isConfigured = true
        #endif
    }

    func register(_ placement: String, feature: @escaping () -> Void) {
        guard isConfigured else { lastMessage = "Superwall n’est pas configuré pour cette cible."; return }
        #if canImport(SuperwallKit)
        Superwall.shared.register(placement: placement, feature: feature)
        #else
        feature()
        #endif
    }

    func restorePurchases() {
        guard isConfigured else { lastMessage = "Superwall n’est pas configuré pour cette cible."; return }
        #if canImport(SuperwallKit)
        Task { @MainActor in
            let result = await Superwall.shared.restorePurchases()
            switch result {
            case .restored:
                lastMessage = "Achats restaurés."
            case .failed:
                lastMessage = "Impossible de restaurer les achats."
            }
        }
        #endif
    }
}
