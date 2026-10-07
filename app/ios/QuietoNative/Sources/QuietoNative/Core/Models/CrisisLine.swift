import Foundation

/// Where to call in a crisis, for the country the iPhone is set to. The
/// onboarding safety screen and the paywall use it; Quieto never shows a
/// French number to someone who cannot reach it.
struct CrisisLine: Equatable {
    /// Free listening line, 24/7 where it exists. Nil: only the emergency number.
    let hotline: String?
    /// Emergency services.
    let emergency: String

    static var current: CrisisLine { forRegion(Locale.current.region?.identifier) }

    static func forRegion(_ region: String?) -> CrisisLine {
        switch region?.uppercased() {
        case "FR", "MC", "GP", "MQ", "GF", "RE", "YT": CrisisLine(hotline: "3114", emergency: "112")
        case "BE": CrisisLine(hotline: "0800 32 123", emergency: "112")
        case "CH": CrisisLine(hotline: "143", emergency: "144")
        case "LU": CrisisLine(hotline: "45 45 45", emergency: "112")
        case "CA", "US": CrisisLine(hotline: "988", emergency: "911")
        case "GB", "IE": CrisisLine(hotline: "116 123", emergency: "112")
        case "DE": CrisisLine(hotline: "0800 111 0 111", emergency: "112")
        case "AT": CrisisLine(hotline: "142", emergency: "112")
        case "ES": CrisisLine(hotline: "024", emergency: "112")
        case "JP": CrisisLine(hotline: "0570 783 556", emergency: "119")
        case "KR": CrisisLine(hotline: "109", emergency: "119")
        default: CrisisLine(hotline: nil, emergency: "112")
        }
    }

    var hotlineURL: URL? { hotline.flatMap { Self.telURL($0) } }
    var emergencyURL: URL { Self.telURL(emergency) ?? URL(string: "tel:112")! }

    /// Short sentence for the bottom of the paywall and of the onboarding.
    var helpLine: String {
        if let hotline {
            return String(format: "Besoin d’aide tout de suite ? Le %@ répond 24h/24, gratuitement.".quietoLocalized, hotline)
        }
        return String(format: "Besoin d’aide tout de suite ? En cas de danger, appelle le %@.".quietoLocalized, emergency)
    }

    /// Main number to call: the listening line, or emergency services.
    var primaryNumber: String { hotline ?? emergency }
    var primaryURL: URL { hotlineURL ?? emergencyURL }

    var explanation: String {
        if let hotline {
            return String(format: "%@ : ligne d’écoute gratuite, 24h/24. En cas de danger immédiat, appelle le %@.".quietoLocalized, hotline, emergency)
        }
        return String(format: "En cas de danger immédiat, appelle le %@.".quietoLocalized, emergency)
    }

    private static func telURL(_ number: String) -> URL? {
        URL(string: "tel:" + number.filter(\.isNumber))
    }
}
