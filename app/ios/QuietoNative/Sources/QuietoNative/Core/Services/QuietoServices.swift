import Foundation

protocol QuietoHomeProviding {
    /// Re-reads the programme from the account, then builds the home.
    func loadHome() async throws -> QuietoHomeSnapshot
    /// What the iPhone knows right now, without network.
    @MainActor func localSnapshot() -> QuietoHomeSnapshot
}

protocol QuietoPlaybackProviding {
    @MainActor func play(_ session: QuietoSession)
    @MainActor func playAmbience(_ ambience: QuietoAmbience)
}

protocol QuietoProgramProviding {
    func adjustRhythm()
}

protocol QuietoSubscriptionProviding {
    @MainActor var isPremium: Bool { get }
}

protocol QuietoAIProviding {
    func openLouane()
}

protocol QuietoAnalyticsProviding {
    func track(_ event: String, properties: [String: String])
    /// Traits kept on the person (goal, subscription…), used to segment events.
    func setUserProperties(_ properties: [String: String])
}

extension QuietoAnalyticsProviding {
    func setUserProperties(_ properties: [String: String]) {}
}

struct QuietoServices {
    let home: any QuietoHomeProviding
    let playback: any QuietoPlaybackProviding
    let program: any QuietoProgramProviding
    let subscription: any QuietoSubscriptionProviding
    let ai: any QuietoAIProviding
    let analytics: any QuietoAnalyticsProviding

    static let preview = QuietoServices(
        home: PreviewHomeService(),
        playback: PreviewPlaybackService(),
        program: PreviewProgramService(),
        subscription: PreviewSubscriptionService(),
        ai: PreviewAIService(),
        analytics: PreviewAnalyticsService()
    )

}

/// The home of the person: their programme, their journal, their name.
/// Built from data on the iPhone, so it is the same online and offline.
@MainActor
final class LocalHomeService: QuietoHomeProviding {
    private let program: ProgramViewModel
    private let journal: PracticeJournal
    private let preferences: QuietoPreferences
    private let catalog: SessionCatalog

    init(program: ProgramViewModel, journal: PracticeJournal, preferences: QuietoPreferences, catalog: SessionCatalog) {
        self.program = program
        self.journal = journal
        self.preferences = preferences
        self.catalog = catalog
    }

    func loadHome() async throws -> QuietoHomeSnapshot {
        await program.load()
        return localSnapshot()
    }

    func localSnapshot() -> QuietoHomeSnapshot {
        let sessionsByID = Dictionary(catalog.sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let listened = journal.entries.filter { $0.kind == .meditation || $0.kind == .breathing }
        let completed = Set(listened.map(\.contentID)).union(program.completedIDs)
        let last = listened.last.flatMap { entry in sessionsByID[entry.contentID].map { (session: $0, date: entry.date) } }

        var programSnapshot: QuietoProgram?
        var next: QuietoSession?
        var nextStep: Int?
        if program.hasProgram, !program.steps.isEmpty {
            let steps = program.steps
            next = program.nextSession
            nextStep = program.currentStepNumber
            let done = Set(steps.indices.filter { steps[$0].isCompleted }.map { $0 + 1 })
            var opensOn: Date?
            if case .locked(_, let date) = program.today { opensOn = date }
            programSnapshot = QuietoProgram(title: program.title, completedDays: done, totalDays: steps.count, currentSession: next, isFinished: program.isFinished, opensOn: opensOn)
        }
        // Outside a programme (or once it is finished): the first session not heard yet.
        let nextSession = next ?? catalog.sessions.first { !completed.contains($0.id) } ?? catalog.sessions.first
        return QuietoHomeSnapshot(
            firstName: preferences.firstName.isEmpty ? nil : preferences.firstName,
            nextSession: nextSession,
            program: programSnapshot,
            progress: QuietoProgress(completedSessionIDs: completed, lastListened: last?.session, lastListenedAt: last?.date),
            nextStep: nextStep
        )
    }
}

struct NativeProgramService: QuietoProgramProviding {
    let preferences: QuietoPreferences
    func adjustRhythm() { preferences.programAdjustmentRequested = true }
}

@MainActor struct NativeSubscriptionService: QuietoSubscriptionProviding {
    let subscriptions: SubscriptionServicing
    var isPremium: Bool { subscriptions.hasActiveEntitlement }
}

struct NativeAIService: QuietoAIProviding { func openLouane() {} }

/// Every event goes to Amplitude (dashboards) and to Supabase
/// `analytics_events` (raw copy the product owns).
struct NativeAnalyticsService: QuietoAnalyticsProviding {
    let backend: QuietoSupabaseService
    let amplitude: QuietoAmplitude
    func track(_ event: String, properties: [String: String]) {
        amplitude.track(event, properties: properties)
        Task { await backend.track(event, properties: properties) }
    }
    func setUserProperties(_ properties: [String: String]) {
        amplitude.setUserProperties(properties)
    }
}

/// Plays a session from its downloaded copy when there is one.
@MainActor
final class NativePlaybackService: QuietoPlaybackProviding {
    let audioPlayer: QuietoAudioPlayer
    private let downloads: QuietoDownloadManaging
    init(audioPlayer: QuietoAudioPlayer, downloads: QuietoDownloadManaging) {
        self.audioPlayer = audioPlayer
        self.downloads = downloads
    }
    func play(_ session: QuietoSession) {
        audioPlayer.play(session, localURL: downloads.localURL(for: session))
    }
    func playAmbience(_ ambience: QuietoAmbience) { audioPlayer.playAmbience(ambience) }
}

struct PreviewHomeService: QuietoHomeProviding {
    func loadHome() async throws -> QuietoHomeSnapshot { .preview }
    func localSnapshot() -> QuietoHomeSnapshot { .preview }
}

struct PreviewPlaybackService: QuietoPlaybackProviding {
    func play(_ session: QuietoSession) {
        #if DEBUG
        print("[Quieto Preview] Play \(session.id)")
        #endif
    }
    func playAmbience(_ ambience: QuietoAmbience) {
        #if DEBUG
        print("[Quieto Preview] Ambience \(ambience.id)")
        #endif
    }
}

struct PreviewProgramService: QuietoProgramProviding {
    func adjustRhythm() {}
}

struct PreviewSubscriptionService: QuietoSubscriptionProviding {
    let isPremium = false
}

struct PreviewAIService: QuietoAIProviding {
    func openLouane() {}
}

struct PreviewAnalyticsService: QuietoAnalyticsProviding {
    func track(_ event: String, properties: [String: String] = [:]) {
        #if DEBUG
        print("[Quieto Preview] \(event) \(properties)")
        #endif
    }
}
