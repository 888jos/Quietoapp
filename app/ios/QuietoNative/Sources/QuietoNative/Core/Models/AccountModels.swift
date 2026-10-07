import Foundation

enum QuietoSubscriptionState: String {
    case unavailable = "Vérification indisponible"
    case inactive = "Aucun abonnement actif"
    case active = "Abonnement actif"
    case trial = "Essai en cours"
    case expired = "Accès expiré"
    case billingIssue = "Problème de paiement : mets à jour ton moyen de paiement Apple"
}

/// The subscription read from StoreKit on this device, for the profile.
struct QuietoSubscriptionDetails: Equatable {
    enum Status: Equatable {
        /// Free trial running.
        case trial
        /// Paid and renewing.
        case active
        /// Still active, but auto-renewal was turned off.
        case cancelled
        /// Apple could not charge: access kept for a few days.
        case gracePeriod
        /// Apple could not charge: access suspended until payment is fixed.
        case billingRetry
        case expired
        /// Access granted by the server (company plan, purchase on Android).
        case grantedByServer
        case none
    }

    var status: Status
    /// Localized product name from App Store Connect, e.g. "Quieto annuel".
    var planName: String?
    /// "89,99 € / an"
    var price: String?
    /// End of the trial, next renewal, or end of access.
    var date: Date?

    static let none = QuietoSubscriptionDetails(status: .none)

    var hasAccess: Bool {
        switch status {
        case .trial, .active, .cancelled, .gracePeriod, .grantedByServer: true
        case .billingRetry, .expired, .none: false
        }
    }

    /// One line for the profile row.
    var summary: String {
        let day = date?.formatted(.dateTime.day().month(.abbreviated).locale(QuietoLocalization.locale))
        switch status {
        case .trial: return day.map { String(format: "Essai jusqu’au %@".quietoLocalized, $0) } ?? "Essai gratuit".quietoLocalized
        case .active: return day.map { String(format: "Renouvelé le %@".quietoLocalized, $0) } ?? "Actif".quietoLocalized
        case .cancelled: return day.map { String(format: "Se termine le %@".quietoLocalized, $0) } ?? "Résilié".quietoLocalized
        case .gracePeriod, .billingRetry: return "Problème de paiement".quietoLocalized
        case .expired: return day.map { String(format: "Expiré le %@".quietoLocalized, $0) } ?? "Expiré".quietoLocalized
        case .grantedByServer: return "Accès offert".quietoLocalized
        case .none: return "Aucun abonnement".quietoLocalized
        }
    }

    /// Longer explanation for the account sheet.
    var explanation: String {
        let day = date?.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(QuietoLocalization.locale))
        switch status {
        case .trial:
            return day.map { String(format: "Ton essai gratuit se termine le %@. Sans résiliation, l’abonnement démarre ce jour-là.".quietoLocalized, $0) } ?? "Ton essai gratuit est en cours.".quietoLocalized
        case .active:
            return day.map { String(format: "Ton abonnement se renouvelle automatiquement le %@.".quietoLocalized, $0) } ?? "Ton abonnement est actif.".quietoLocalized
        case .cancelled:
            return day.map { String(format: "Le renouvellement automatique est désactivé : ton accès reste ouvert jusqu’au %@.".quietoLocalized, $0) } ?? "Le renouvellement automatique est désactivé.".quietoLocalized
        case .gracePeriod:
            return "Apple n’a pas pu prélever le renouvellement. Ton accès est maintenu quelques jours : mets à jour ton moyen de paiement.".quietoLocalized
        case .billingRetry:
            return "Apple n’a pas pu prélever le renouvellement. Mets à jour ton moyen de paiement pour retrouver l’accès.".quietoLocalized
        case .expired:
            return day.map { String(format: "Ton abonnement a pris fin le %@.".quietoLocalized, $0) } ?? "Ton abonnement a pris fin.".quietoLocalized
        case .grantedByServer:
            return "Ton accès est fourni par ton entreprise ou par un achat fait sur un autre appareil.".quietoLocalized
        case .none:
            return "Aucun abonnement n’est associé à ton identifiant Apple sur cet appareil.".quietoLocalized
        }
    }
}
