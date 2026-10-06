import AVFoundation
import XCTest
@testable import QuietoNative

final class AudioAndCatalogTests: XCTestCase {
    func testEverySupportedLanguageHasTheSameLocalizationKeys() throws {
        let localizations = ["en", "es", "de", "ja", "ko"]
        let tables = ["Localizable", "Catalog", "Extended"]

        for table in tables {
            let reference = try localizationDictionary(table: table, localization: "en")
            XCTAssertFalse(reference.isEmpty, table)
            for localization in localizations.dropFirst() {
                let candidate = try localizationDictionary(table: table, localization: localization)
                XCTAssertEqual(Set(candidate.keys), Set(reference.keys), "\(table) is incomplete for \(localization)")
            }
        }

        let sessionTitleKeys = Set(SessionCatalog().sessions.map(\.title))
        for localization in localizations {
            let catalog = try localizationDictionary(table: "Catalog", localization: localization)
            XCTAssertTrue(sessionTitleKeys.isSubset(of: Set(catalog.keys)), "Session titles are incomplete for \(localization)")
        }
    }

    func testEveryCatalogSessionHasUniqueArtworkAndDetailedContent() {
        let sessions = SessionCatalog().sessions
        XCTAssertGreaterThanOrEqual(sessions.count, 79)
        XCTAssertGreaterThanOrEqual(sessions.filter { $0.practiceType == .meditation }.count, 40)
        XCTAssertGreaterThanOrEqual(sessions.filter { $0.practiceType == .breathing }.count, 10)
        XCTAssertEqual(Set(sessions.map(\.imageName)).count, sessions.count)
        XCTAssertTrue(sessions.allSatisfy { $0.longDescription.count > 140 })
        XCTAssertTrue(sessions.allSatisfy { $0.transcript.count > 400 })
        XCTAssertTrue(sessions.allSatisfy { $0.steps.count >= 3 })
        XCTAssertTrue(sessions.allSatisfy { Bundle.main.url(forResource: $0.imageName, withExtension: nil) != nil })
    }

    func testAllBundledAmbiencesArePlayableThirtySecondMP3Files() async throws {
        XCTAssertGreaterThanOrEqual(QuietoAmbience.all.count, 10)
        for ambience in QuietoAmbience.all {
            let url = try XCTUnwrap(Bundle.main.url(forResource: ambience.audioResource, withExtension: "mp3"))
            XCTAssertNotNil(Bundle.main.url(forResource: ambience.assetName, withExtension: nil))
            let duration = try await AVURLAsset(url: url).load(.duration).seconds
            XCTAssertEqual(duration, 30, accuracy: 0.2, ambience.id)
        }
    }

    @MainActor
    func testEveryDailyNeedHasValidSessionsSoundsAndArtwork() {
        let model = HomeViewModel()
        let planned = model.snapshot.nextSession?.id
        for need in QuietoNeed.allCases {
            XCTAssertGreaterThanOrEqual(model.sessions(for: need).count, 3, need.rawValue)
            XCTAssertGreaterThanOrEqual(model.ambiences(for: need).count, 2, need.rawValue)
            XCTAssertNotNil(Bundle.main.url(forResource: need.imageName, withExtension: nil), need.rawValue)
        }
        XCTAssertEqual(model.snapshot.nextSession?.id, planned)
    }

    func testAppleSpeechRendererCreatesASeekableAudioFile() async throws {
        let session = QuietoSession(
            id: "test_native_voice_\(UUID().uuidString)",
            title: "Test de narration",
            durationMinutes: 1,
            subtitle: "Test",
            imageName: "FeatureSession",
            isPremium: false,
            transcript: "Bienvenue. Inspire tranquillement. Expire doucement. Cette courte phrase vérifie que la voix Apple produit un vrai fichier audio local."
        )
        let url = try await QuietoSpeechRenderer().render(session)
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        XCTAssertEqual(duration, 60, accuracy: 0.05)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(QuietoSpeechRenderer.isAudibleAudioFile(at: url), "La narration générée ne doit jamais être silencieuse.")
    }

    func testEveryGuidedMeditationHasNarrationContent() {
        let guided = SessionCatalog().sessions.filter { $0.readerMode == .guidedVoice }
        XCTAssertFalse(guided.isEmpty)
        XCTAssertTrue(guided.allSatisfy { $0.transcript.count > 400 })
    }

    func testBreathingExercisesNeverUseSpeechRendering() async throws {
        let breathing = try XCTUnwrap(SessionCatalog().sessions.first { $0.practiceType == .breathing })
        guard case .breathing = breathing.readerMode else {
            return XCTFail("Breathing sessions must use the visual breathing mode")
        }
        do {
            _ = try await QuietoSpeechRenderer().render(breathing)
            XCTFail("A breathing exercise must never generate spoken audio")
        } catch QuietoSpeechRenderError.unavailable {
            // Expected: breathing is driven by the visual cycle, not by speech synthesis.
        }
    }

    private func localizationDictionary(table: String, localization: String) throws -> [String: String] {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: table, ofType: "strings", inDirectory: nil, forLocalization: localization),
            "Missing \(table).strings for \(localization)"
        )
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
    }
}
