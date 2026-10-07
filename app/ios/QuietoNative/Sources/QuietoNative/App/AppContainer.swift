import Combine
import Foundation
import UIKit

/// Composition root: the only place that creates live services and wires them
/// into ViewModels. Created once by the app delegate; every long-lived object
/// (audio player, background download session, subscription state) exists once.
@MainActor
final class AppContainer {
    // MARK: Storage
    let preferences: QuietoPreferences
    let activity: ActivityStore
    let practiceJournal: PracticeJournal
    let catalog = SessionCatalog()
    let louaneMemory: LouaneMemoryStore

    // MARK: Services
    let backend: QuietoSupabaseService
    let subscriptions: QuietoSuperwallService
    let health = QuietoHealthService()
    let reminders = QuietoReminderScheduler()
    let downloads: QuietoDownloadStore
    let audioPlayer: QuietoAudioPlayer
    let playback: NativePlaybackService
    let playbackTracker: PlaybackTracker
    let amplitude = QuietoAmplitude()
    let analytics: NativeAnalyticsService
    let achievements: AchievementCenter
    let sessionCoordinator: SessionCoordinator

    init(defaults: UserDefaults = .standard) {
        preferences = QuietoPreferences(defaults: defaults)
        activity = ActivityStore(defaults: defaults)
        louaneMemory = LouaneMemoryStore(defaults: defaults)
        backend = QuietoSupabaseService(preferences: preferences)
        subscriptions = QuietoSuperwallService(server: backend)
        analytics = NativeAnalyticsService(backend: backend, amplitude: amplitude)
        subscriptions.onAnalyticsEvent = { [analytics] event, properties in
            analytics.track(event, properties: properties)
        }
        practiceJournal = PracticeJournal(defaults: defaults)
        achievements = AchievementCenter(
            journal: practiceJournal,
            defaults: defaults,
            catalog: catalog,
            analytics: analytics,
            sync: backend.isConfigured ? backend : nil,
            reminders: reminders
        )
        sessionCoordinator = SessionCoordinator(backend: backend, subscriptions: subscriptions, achievements: achievements, amplitude: amplitude)
        downloads = QuietoDownloadStore(signer: backend.isConfigured ? backend : nil)
        audioPlayer = QuietoAudioPlayer(preferences: preferences)
        if backend.isConfigured {
            audioPlayer.remoteAudioURL = { [backend] path in try await backend.signedAudioURL(path: path) }
        }
        playback = NativePlaybackService(audioPlayer: audioPlayer, downloads: downloads)
        playbackTracker = PlaybackTracker(activity: activity, health: health, progress: backend, achievements: achievements)
        audioPlayer.onSessionCompleted = { [playbackTracker] session, seconds in
            playbackTracker.sessionCompleted(session, listenedSeconds: seconds)
        }
        audioPlayer.onSessionFeedback = { [analytics] session, feeling in
            analytics.track("session_feedback", properties: ["session": session.id, "feeling": feeling, "practice": session.practiceType.rawValue])
        }
        audioPlayer.onAmbienceListened = { [playbackTracker] ambience, seconds in
            playbackTracker.ambienceListened(ambience, seconds: seconds)
        }
        achievements.programSessionIDs = { [weak self] in self?.program.sessions.map(\.id) ?? [] }
        achievements.programProgress = { [weak self] in
            guard let program = self?.program, program.hasProgram else { return nil }
            return (program.completedCount, program.totalCount)
        }
        achievements.onAttributesChanged = { [subscriptions] in subscriptions.setAttributes($0) }
        achievements.start(legacyActivity: activity.events)
    }

    private var remoteRepository: QuietoSupabaseService? { backend.isConfigured ? backend : nil }

    // MARK: ViewModels (one per screen, kept for the app's lifetime)

    lazy var root = RootViewModel(subscriptions: subscriptions, audioPlayer: audioPlayer, achievements: achievements)

    lazy var journey = AchievementsViewModel(center: achievements)

    lazy var celebration: BadgeCelebrationViewModel = {
        let model = BadgeCelebrationViewModel(unlocks: achievements.unlocks.eraseToAnyPublisher())
        model.onShow = { badge in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement, argument: String(format: "Nouveau badge : %@".quietoLocalized, badge.title.quietoLocalized))
        }
        return model
    }()

    lazy var home: HomeViewModel = {
        let model = HomeViewModel(
            services: QuietoServices(
                home: LocalHomeService(program: program, journal: practiceJournal, preferences: preferences, catalog: catalog),
                playback: playback,
                program: NativeProgramService(preferences: preferences),
                subscription: NativeSubscriptionService(subscriptions: subscriptions),
                ai: NativeAIService(),
                analytics: analytics
            ),
            catalog: catalog,
            achievements: achievements,
            changes: Publishers.Merge(
                program.objectWillChange.map { _ in () },
                achievements.$summary.map { _ in () }
            ).eraseToAnyPublisher()
        )
        #if DEBUG
        if let requestedTab = ProcessInfo.processInfo.environment["QUIETO_START_TAB"],
           let tab = QuietoTab.allCases.first(where: { $0.rawValue.lowercased() == requestedTab.lowercased() }) {
            model.selectedTab = tab
        }
        #endif
        #if DEBUG
        model.onReplayOnboarding = { [weak self] in self?.onboarding.replayForDebug() }
        #endif
        return model
    }()

    lazy var sessions = SessionsViewModel(
        catalog: catalog,
        audioPlayer: audioPlayer,
        downloads: downloads,
        preferences: preferences,
        progress: remoteRepository
    )

    lazy var program = ProgramViewModel(
        catalog: catalog,
        preferences: preferences,
        activity: activity,
        repository: remoteRepository,
        completions: playbackTracker.completions.eraseToAnyPublisher(),
        analytics: analytics
    )

    lazy var louane = LouaneViewModel(
        backend: URLSessionLouaneBackend(backend: backend, preferences: preferences, memory: louaneMemory) { [unowned self] in
            LouaneClientContext.make(events: activity.events, programme: program.louaneProgramme)
        },
        memory: louaneMemory,
        repository: remoteRepository,
        playback: playback,
        subscriptions: subscriptions,
        analytics: analytics,
        catalog: catalog,
        preferences: preferences
    )

    lazy var profile: ProfileViewModel = {
        let model = ProfileViewModel(
        preferences: preferences,
        auth: backend,
        account: backend,
        louane: backend,
        louaneMemory: louaneMemory,
        subscriptions: subscriptions,
        reminders: reminders,
        health: health,
        localData: LocalDataWiper(preferences: preferences, downloads: downloads, louaneMemory: louaneMemory) { [achievements, weak self] in
            achievements.reloadAfterWipe()
            self?.program.reset()
        }
        )
        model.onAmbienceVolumeChanged = { [audioPlayer] volume in audioPlayer.ambienceVolume = volume }
        return model
    }()

    lazy var onboarding: OnboardingViewModel = {
        let model = OnboardingViewModel(
            preferences: preferences,
            catalog: catalog,
            subscriptions: subscriptions,
            auth: backend,
            account: backend,
            health: health,
            reminders: reminders,
            analytics: analytics,
            louaneMemory: louaneMemory
        )
        model.onPlanChosen = { [weak self] state in self?.program.adopt(state) }
        model.setFinishHandler { [weak self] session in
            guard let self else { return }
            home.selectedTab = .home
            if let session { playback.play(session) }
        }
        return model
    }()

    lazy var paywall = PaywallViewModel(subscriptions: subscriptions, auth: backend)

    lazy var enterpriseCode = EnterpriseCodeViewModel(
        service: EnterpriseAccessService(backend: backend),
        subscriptions: subscriptions,
        auth: backend
    )
}
