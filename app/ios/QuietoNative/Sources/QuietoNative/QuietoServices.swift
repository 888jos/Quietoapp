import Foundation

protocol QuietoHomeProviding {
    func loadHome() async throws -> QuietoHomeSnapshot
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

    @MainActor
    static func native(audioPlayer: QuietoAudioPlayer) -> QuietoServices {
        QuietoServices(
            home: NativeHomeService(),
            playback: NativePlaybackService(audioPlayer: audioPlayer),
            program: NativeProgramService(),
            subscription: NativeSubscriptionService(),
            ai: NativeAIService(),
            analytics: NativeAnalyticsService()
        )
    }
}

struct NativeHomeService: QuietoHomeProviding {
    func loadHome() async throws -> QuietoHomeSnapshot {
        do { return try await QuietoSupabaseService.shared.loadHome() }
        catch {
            var cached = QuietoHomeSnapshot.preview
            cached.firstName = UserDefaults.standard.string(forKey: "quieto.profile.firstName")
            cached.isOffline = true
            cached.errorMessage = nil
            return cached
        }
    }
}

struct NativeProgramService: QuietoProgramProviding {
    func adjustRhythm() {
        UserDefaults.standard.set(true, forKey: "quieto.program.adjustmentRequested")
    }
}

@MainActor struct NativeSubscriptionService: QuietoSubscriptionProviding {
    var isPremium: Bool { QuietoSuperwallService.shared.hasActiveEntitlement }
}

struct NativeAIService: QuietoAIProviding { func openLouane() {} }

struct NativeAnalyticsService: QuietoAnalyticsProviding {
    func track(_ event: String, properties: [String: String]) {
        Task { await QuietoSupabaseService.shared.track(event, properties: properties) }
    }
}

@MainActor
final class NativePlaybackService: QuietoPlaybackProviding {
    private let audioPlayer: QuietoAudioPlayer
    init(audioPlayer: QuietoAudioPlayer) { self.audioPlayer = audioPlayer }
    func play(_ session: QuietoSession) {
        let action: () -> Void = { [weak audioPlayer] in
            audioPlayer?.play(session)
        }
        if session.isPremium {
            QuietoSuperwallService.shared.register("home_session_\(session.id)", feature: action)
        } else {
            action()
        }
    }
    func playAmbience(_ ambience: QuietoAmbience) { audioPlayer.playAmbience(ambience) }
}

struct PreviewHomeService: QuietoHomeProviding {
    func loadHome() async throws -> QuietoHomeSnapshot { .preview }
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

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var snapshot: QuietoHomeSnapshot
    @Published var selectedTab: QuietoTab = .home
    @Published var feeling: CheckInFeeling?
    @Published var need: CheckInNeed?
    @Published private(set) var isRefreshing = false
    @Published var lastAction: String?

    let services: QuietoServices

    init(snapshot: QuietoHomeSnapshot = .preview, services: QuietoServices = .preview) {
        self.snapshot = snapshot
        self.services = services
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await services.home.loadHome()
        } catch {
            snapshot.errorMessage = "Impossible de charger ton accueil."
        }
    }

    func play(_ session: QuietoSession, source: String) {
        services.playback.play(session)
        services.analytics.track("session_played", properties: ["session": session.id, "source": source])
        lastAction = "Lecture de « \(session.title) »"
    }

    func sessions(for need: QuietoNeed) -> [QuietoSession] {
        let catalog = SessionCatalog().sessions
        return need.sessionIDs.compactMap { id in catalog.first { $0.id == id } }
    }

    func ambiences(for need: QuietoNeed) -> [QuietoAmbience] {
        need.ambienceIDs.compactMap { id in QuietoAmbience.all.first { $0.id == id } }
    }

    func play(_ ambience: QuietoAmbience, source: String) {
        services.playback.playAmbience(ambience)
        services.analytics.track("ambience_played", properties: ["ambience": ambience.id, "source": source])
        lastAction = "Ambiance « \(ambience.title) »"
    }

    func openProgram() {
        selectedTab = .programme
        services.analytics.track("program_opened", properties: [:])
    }

    func adjustRhythm() {
        services.program.adjustRhythm()
        services.analytics.track("program_rhythm_adjusted", properties: [:])
        lastAction = "Ton rythme sera ajusté."
    }

    func openLouane() {
        selectedTab = .louane
        services.ai.openLouane()
        services.analytics.track("louane_opened", properties: ["source": "home"])
    }

    var recommendation: QuietoSession? {
        guard feeling != nil || need != nil else { return nil }
        if need == .sleep || feeling == .tired {
            return QuietoHomeSnapshot.preview.progress.lastListened
        }
        return QuietoHomeSnapshot.preview.nextSession
    }
}
