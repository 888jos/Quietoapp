import Foundation
import ObjectiveC

/// A language Quieto is translated into. French is the source language: the
/// keys of every `.strings` table are the French text itself.
enum QuietoLanguage: String, CaseIterable, Identifiable {
    case fr, en, es, de, ja, ko

    var id: String { rawValue }

    /// Name of the language written in that language, as language pickers show it.
    var nativeName: String {
        switch self {
        case .fr: "Français"
        case .en: "English"
        case .es: "Español"
        case .de: "Deutsch"
        case .ja: "日本語"
        case .ko: "한국어"
        }
    }
}

/// Grammatical gender the person chose in onboarding (Profil → Genre). Quieto
/// never uses inclusive spellings: every « fatigué·e » of the copy resolves to
/// « fatigué » or « fatiguée », and Spanish « tenso/a » to « tenso » or « tensa ».
enum QuietoGender: String, CaseIterable, Identifiable {
    case feminine, masculine

    static let preferenceKey = "quieto.profile.gender"
    var id: String { rawValue }

    /// Masculine until the person answers.
    static var current: QuietoGender {
        UserDefaults.standard.string(forKey: preferenceKey).flatMap(QuietoGender.init(rawValue:)) ?? .masculine
    }

    static var isChosen: Bool { UserDefaults.standard.string(forKey: preferenceKey) != nil }

    static func set(_ gender: QuietoGender) {
        UserDefaults.standard.set(gender.rawValue, forKey: preferenceKey)
        NotificationCenter.default.post(name: QuietoLocalization.didChange, object: nil)
    }

    /// Label shown in the pickers, already agreed.
    var title: String { self == .feminine ? "Au féminin" : "Au masculin" }

    private static let irregular: [String: (masculine: String, feminine: String)] = [
        "léger·e": ("léger", "légère"),
        "Léger·e": ("Léger", "Légère"),
    ]
    private static let inclusive = try! NSRegularExpression(pattern: "([\\p{L}’']+)·e\\b")
    private static let spanish = try! NSRegularExpression(pattern: "(\\p{L}+)o/a\\b")

    /// The text with every inclusive form agreed in this gender.
    func resolve(_ text: String) -> String {
        guard text.contains("·") || text.contains("o/a") || text.contains(" ou prête") else { return text }
        var result = text
        for (form, agreed) in Self.irregular where result.contains(form) {
            result = result.replacingOccurrences(of: form, with: self == .feminine ? agreed.feminine : agreed.masculine)
        }
        result = result.replacingOccurrences(of: "prêt ou prête", with: self == .feminine ? "prête" : "prêt")
        let range = NSRange(result.startIndex..., in: result)
        result = Self.inclusive.stringByReplacingMatches(in: result, range: range, withTemplate: self == .feminine ? "$1e" : "$1")
        let spanishRange = NSRange(result.startIndex..., in: result)
        result = Self.spanish.stringByReplacingMatches(in: result, range: spanishRange, withTemplate: self == .feminine ? "$1a" : "$1o")
        return result
    }
}

enum QuietoLocalization {
    static let preferenceKey = "quieto.profile.language"
    /// Posted after the language changes, so non-SwiftUI state (narrations,
    /// Now Playing, notifications) can refresh.
    static let didChange = Notification.Name("QuietoLocalizationDidChange")

    /// Language chosen in the profile. Nil follows the iPhone.
    static var chosenLanguage: QuietoLanguage? {
        UserDefaults.standard.string(forKey: preferenceKey).flatMap(QuietoLanguage.init(rawValue:))
    }

    /// Language actually displayed: the chosen one, else the iPhone's first
    /// language Quieto supports, else English.
    static var language: QuietoLanguage {
        if let chosenLanguage { return chosenLanguage }
        for identifier in Locale.preferredLanguages {
            if let code = Locale(identifier: identifier).language.languageCode?.identifier,
               let language = QuietoLanguage(rawValue: code) { return language }
        }
        return .en
    }

    static var languageCode: String { language.rawValue }
    static var isFrench: Bool { language == .fr }

    /// Locale for dates and numbers: the displayed language with the iPhone's region.
    static var locale: Locale {
        guard let region = Locale.current.region?.identifier else { return Locale(identifier: languageCode) }
        return Locale(identifier: "\(languageCode)_\(region)")
    }

    /// Installs the lookup once, at launch. Every string of the app then
    /// resolves in `language`, whatever the iPhone language is.
    static func install() {
        guard !(Bundle.main is QuietoLocalizedBundle) else { return }
        object_setClass(Bundle.main, QuietoLocalizedBundle.self)
    }

    /// Switches the language right away. `AppleLanguages` also follows, so the
    /// system texts (permission dialogs) match from the next launch.
    static func setLanguage(_ language: QuietoLanguage?) {
        let defaults = UserDefaults.standard
        if let language {
            defaults.set(language.rawValue, forKey: preferenceKey)
            defaults.set([language.rawValue], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: preferenceKey)
            defaults.removeObject(forKey: "AppleLanguages")
        }
        QuietoLocalizedBundle.reset()
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// Translates a French key, then fills in its `%@` / `%d` placeholders.
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: key.quietoLocalized, locale: locale, arguments: arguments)
    }
}

/// `Bundle.main` takes this class at launch. SwiftUI `Text("…")`, `String(localized:)`
/// and `quietoLocalized` all go through `localizedString(forKey:value:table:)`,
/// which reads the chosen language and searches the three tables of the app.
final class QuietoLocalizedBundle: Bundle, @unchecked Sendable {
    static let tables = ["Localizable", "Catalog", "Extended"]
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: (code: String, bundle: Bundle?)?

    static func reset() {
        lock.lock(); cached = nil; lock.unlock()
    }

    private static var languageBundle: Bundle? {
        let code = QuietoLocalization.languageCode
        lock.lock(); defer { lock.unlock() }
        if let cached, cached.code == code { return cached.bundle }
        // `path(forResource:)` is not overridden, so this is the real main bundle lookup.
        let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
        cached = (code, bundle)
        return bundle
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        QuietoGender.current.resolve(lookup(forKey: key, value: value, table: tableName))
    }

    private func lookup(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = Self.languageBundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        let missing = "\u{1}quieto-missing"
        let tables = tableName.map { Self.tables.contains($0) ? Self.tables : [$0] } ?? Self.tables
        for table in tables {
            let found = bundle.localizedString(forKey: key, value: missing, table: table)
            if found != missing { return found }
        }
        if let value, !value.isEmpty { return value }
        return key
    }
}

extension String {
    /// The text in the displayed language. French keys come back unchanged in French.
    var quietoLocalized: String {
        Bundle.main.localizedString(forKey: self, value: nil, table: nil)
    }
}
