import XCTest
@testable import QuietoNative

final class LocalizationTests: XCTestCase {
    override func tearDown() {
        QuietoLocalization.setLanguage(nil)
        super.tearDown()
    }

    /// A translation with other placeholders than its French key crashes `String(format:)`.
    func testEveryTranslationKeepsThePlaceholdersOfItsKey() throws {
        for localization in QuietoLanguage.allCases.map(\.rawValue) where localization != "fr" {
            for table in QuietoLocalizedBundle.tables {
                for (key, value) in try localizationDictionary(table: table, localization: localization) {
                    XCTAssertEqual(placeholders(in: value), placeholders(in: key), "\(localization) · \(table) · \(key)")
                }
            }
        }
    }

    func testChosenLanguageAppliesRightAwayAcrossTables() {
        QuietoLocalization.install()
        QuietoLocalization.setLanguage(.en)
        XCTAssertEqual("Accueil".quietoLocalized, "Home")
        XCTAssertNotEqual("Ma première méditation".quietoLocalized, "Ma première méditation", "Catalog table is searched")
        XCTAssertEqual(Bundle.main.localizedString(forKey: "Accueil", value: nil, table: nil), "Home")

        QuietoLocalization.setLanguage(.fr)
        XCTAssertEqual("Accueil".quietoLocalized, "Accueil")
        XCTAssertEqual(QuietoLocalization.format("Jour %d", 3), "Jour 3")
    }

    private func placeholders(in text: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "%(?:(\\d+)\\$)?(@|lld|ld|d|\\.\\d+f|f)")
        let cleaned = text.replacingOccurrences(of: "%%", with: "")
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        var position = 0
        return pattern.matches(in: cleaned, range: range).map { match -> String in
            position += 1
            let swiftRange = { (index: Int) in Range(match.range(at: index), in: cleaned).map { String(cleaned[$0]) } }
            let type = (swiftRange(2) ?? "").replacingOccurrences(of: "lld", with: "d").replacingOccurrences(of: "ld", with: "d")
            return "\(swiftRange(1).flatMap(Int.init) ?? position):\(type)"
        }
        .sorted()
    }

    private func localizationDictionary(table: String, localization: String) throws -> [String: String] {
        let bundle = Bundle(for: QuietoLocalizedBundle.self)
        let url = try XCTUnwrap(bundle.url(forResource: table, withExtension: "strings", subdirectory: nil, localization: localization))
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }
}
