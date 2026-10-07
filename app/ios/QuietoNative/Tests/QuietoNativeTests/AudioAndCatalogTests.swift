import AVFoundation
import XCTest
@testable import QuietoNative

final class AudioAndCatalogTests: XCTestCase {
    /// The catalog checks read the French scripts, whatever the simulator language.
    override func setUp() {
        super.setUp()
        QuietoLocalization.setLanguage(.fr)
    }

    override func tearDown() {
        QuietoLocalization.setLanguage(nil)
        super.tearDown()
    }

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
        XCTAssertEqual(sessions.filter { $0.readerMode == .guidedVoice }.count, 81)
        XCTAssertEqual(sessions.filter { $0.readerMode == .breathing }.count, 13)
        XCTAssertEqual(Set(sessions.map(\.id)).count, sessions.count)
        XCTAssertEqual(Set(sessions.map(\.imageName)).count, sessions.count)
        XCTAssertTrue(sessions.allSatisfy { $0.longDescription.count > 140 })
        XCTAssertTrue(sessions.allSatisfy { $0.transcript.count > 400 })
        XCTAssertTrue(sessions.allSatisfy { $0.steps.count >= 3 })
        XCTAssertTrue(sessions.allSatisfy { Bundle.main.url(forResource: $0.imageName, withExtension: nil) != nil })
    }

    func testBundledFrenchNarrationsAreWrittenScripts() throws {
        let entries = NarrationCatalog.load(languageCode: "fr")
        XCTAssertGreaterThanOrEqual(entries.count, 8)
        for (id, entry) in entries {
            XCTAssertFalse(entry.transcript.contains("[pause"), "\(id) keeps a pause marker in its transcript")
            XCTAssertFalse(entry.transcript.hasPrefix("Bienvenue dans"), "\(id) still reads the generic template")
            XCTAssertGreaterThan(entry.targetSeconds, 0)
            if let path = entry.audioPath { XCTAssertEqual(path, "fr/\(id).m4a") }
        }
        // Each script is its own text: no two sessions may share it.
        XCTAssertEqual(Set(entries.values.map(\.transcript)).count, entries.count)
    }

    func testSessionWithAScriptReadsItInsteadOfTheTemplate() throws {
        guard let entry = NarrationCatalog.entries["express_1"] else { throw XCTSkip("No narration for this language") }
        let session = try XCTUnwrap(SessionCatalog().sessions.first { $0.id == "express_1" })
        XCTAssertEqual(session.transcript, entry.transcript)
        XCTAssertEqual(session.audioFile, entry.audioPath ?? "")
        XCTAssertEqual(session.durationMinutes, (entry.durationSeconds ?? entry.targetSeconds) / 60)
    }

    func testAmbiencesHaveArtworkAndPlayableLoops() async throws {
        XCTAssertEqual(QuietoAmbience.catalog.count, 16)
        XCTAssertEqual(Set(QuietoAmbience.catalog.map(\.id)).count, 16)
        for ambience in QuietoAmbience.catalog {
            XCTAssertNotNil(Bundle.main.url(forResource: ambience.assetName, withExtension: nil), ambience.id)
        }
        // The generated noises are always bundled; recordings appear once imported.
        XCTAssertTrue(Set(QuietoAmbience.all.map(\.id)).isSuperset(of: ["white-noise", "pink-noise", "brown-noise"]))
        for ambience in QuietoAmbience.all {
            let url = try XCTUnwrap(ambience.audioURL)
            let duration = try await AVURLAsset(url: url).load(.duration).seconds
            // Short seamless loops (about 30 s) keep the app light; the player repeats them.
            XCTAssertGreaterThanOrEqual(duration, 10, ambience.id)
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

    @MainActor
    func testEverySituationCanDriveTheHomeExplorer() {
        let model = HomeViewModel()
        for situation in QuietoSituation.allCases {
            XCTAssertEqual(model.sessions(for: situation).count, 6, situation.rawValue)
            XCTAssertGreaterThanOrEqual(model.ambiences(for: situation).count, 2, situation.rawValue)
        }
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

    func testEverySituationAndNeedPointsToExistingSessions() {
        let sessions = SessionCatalog().sessions
        let byID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        for situation in QuietoSituation.allCases {
            XCTAssertEqual(Set(situation.sessionIDs).count, 6, situation.rawValue)
            XCTAssertEqual(situation.sessionIDs.compactMap { byID[$0] }.count, 6, situation.rawValue)
        }
        for need in QuietoNeed.allCases {
            XCTAssertEqual(need.sessionIDs.compactMap { byID[$0] }.count, need.sessionIDs.count, need.rawValue)
        }
        XCTAssertTrue(sessions.allSatisfy { !$0.themes.isEmpty })
    }

    func testEveryCategoryAndGoalOffersSeveralSessions() {
        let sessions = SessionCatalog().sessions
        for category in QuietoCategory.allCases {
            XCTAssertGreaterThanOrEqual(sessions.filter { $0.category == category }.count, 6, category.rawValue)
        }
        for goal in QuietoGoal.allCases {
            XCTAssertGreaterThanOrEqual(sessions.filter { $0.goal == goal }.count, 6, goal.rawValue)
        }
    }

    func testEveryWrittenScriptIsUniqueAndUsedBySessions() {
        let guided = SessionCatalog().sessions.filter { $0.readerMode == .guidedVoice }
        let scripted = guided.filter { NarrationCatalog.entries[$0.id] != nil }
        XCTAssertEqual(Set(scripted.map(\.transcript)).count, scripted.count, "Two sessions read the same script")
        XCTAssertTrue(scripted.allSatisfy { !$0.transcript.hasPrefix("Bienvenue dans") })
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

    // MARK: Breathing

    func testBreathingCurveClimbsHoldsAndGoesDown() {
        let box = QuietoBreathingPattern.box
        let total = box.totalSeconds(minutes: 4)
        let lead = QuietoBreathingPattern.leadIn
        XCTAssertNil(box.moment(at: 1, total: total).phase, "Lead-in before the first inhale")
        XCTAssertEqual(box.moment(at: lead + 2, total: total).phase?.kind, .inhale)
        XCTAssertEqual(box.moment(at: lead + 4, total: total).level, 1, accuracy: 0.01)
        XCTAssertEqual(box.moment(at: lead + 6, total: total).phase?.kind, .hold)
        XCTAssertEqual(box.moment(at: lead + 6, total: total).level, 1, accuracy: 0.001, "A hold stays flat")
        XCTAssertEqual(box.moment(at: lead + 10, total: total).phase?.kind, .exhale)
        XCTAssertEqual(box.moment(at: lead + 14, total: total).level, 0, accuracy: 0.001)
        XCTAssertEqual(box.moment(at: lead + 16.5, total: total).cycle, 2)
    }

    func testFourSevenEightStopsAfterFourCycles() {
        let pattern = QuietoBreathingPattern.fourSevenEight
        let total = pattern.totalSeconds(minutes: 5)
        XCTAssertEqual(total, QuietoBreathingPattern.leadIn + 4 * 19, accuracy: 0.001)
        XCTAssertNil(pattern.moment(at: total + 1, total: total).phase)
    }

    func testSleepDescentLengthensTheExhale() {
        let pattern = QuietoBreathingPattern.sleepDescent
        XCTAssertEqual(pattern.phases(progress: 0).last?.seconds ?? 0, 4, accuracy: 0.001)
        XCTAssertEqual(pattern.phases(progress: 1).last?.seconds ?? 0, 8, accuracy: 0.001)
        let total = pattern.totalSeconds(minutes: 10)
        XCTAssertNotNil(pattern.moment(at: total - 5, total: total).phase)
    }

    func testStaircaseAndAlternatePatternsGuideEachStep() {
        let stairs = QuietoBreathingPattern.staircase.phases().filter { $0.kind == .inhale }.map(\.level)
        XCTAssertEqual(stairs.count, 3)
        XCTAssertEqual(stairs, stairs.sorted(), "Each step climbs higher")
        let sides = QuietoBreathingPattern.alternate.phases().compactMap(\.side)
        XCTAssertEqual(sides, [.left, .right, .right, .left])
    }

    func testEveryBreathingSessionHasItsOwnRhythm() {
        let breathing = SessionCatalog().sessions.filter { $0.readerMode == .breathing }
        XCTAssertEqual(Set(breathing.compactMap(\.breathingPattern)).count, breathing.count)
        XCTAssertEqual(breathing.first { $0.id == "stress_2" }?.breathingPattern, .fourSevenEight)
    }

    // MARK: Account and health helpers

    func testSupabaseUserIDIsLowercasedLikeTheJWTSubject() {
        let id = UUID(uuidString: "A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF")!
        XCTAssertEqual(id.quietoUserID, "a1b2c3d4-e5f6-4711-8899-aabbccddeeff")
    }

    func testHealthIntervalsAreMergedBeforeBeingAdded() {
        let start = Date(timeIntervalSince1970: 0)
        let intervals = [
            (start, start.addingTimeInterval(3_600)),
            (start.addingTimeInterval(1_800), start.addingTimeInterval(5_400)), // overlaps (Watch + iPhone)
            (start.addingTimeInterval(7_200), start.addingTimeInterval(7_800))
        ]
        XCTAssertEqual(HealthIntervals.unionDuration(intervals), 6_000)
    }

    func testSubscriptionSummaryNamesTheRightDate() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let day = date.formatted(.dateTime.day().month(.abbreviated))
        XCTAssertTrue(QuietoSubscriptionDetails(status: .cancelled, date: date).summary.contains(day))
        XCTAssertTrue(QuietoSubscriptionDetails(status: .grantedByServer).hasAccess)
        XCTAssertFalse(QuietoSubscriptionDetails(status: .billingRetry).hasAccess)
    }
}
