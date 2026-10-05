import AVFoundation
import XCTest
@testable import QuietoNative

final class AudioAndCatalogTests: XCTestCase {
    func testEveryCatalogSessionHasUniqueArtworkAndDetailedContent() {
        let sessions = SessionCatalog().sessions
        XCTAssertEqual(sessions.count, 48)
        XCTAssertEqual(Set(sessions.map(\.imageName)).count, sessions.count)
        XCTAssertTrue(sessions.allSatisfy { $0.longDescription.count > 140 })
        XCTAssertTrue(sessions.allSatisfy { $0.transcript.count > 400 })
        XCTAssertTrue(sessions.allSatisfy { $0.steps.count >= 3 })
        XCTAssertTrue(sessions.allSatisfy { Bundle.main.url(forResource: $0.imageName, withExtension: nil) != nil })
    }

    func testAllBundledAmbiencesArePlayableThirtySecondMP3Files() async throws {
        XCTAssertEqual(QuietoAmbience.all.count, 8)
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
    }
}
