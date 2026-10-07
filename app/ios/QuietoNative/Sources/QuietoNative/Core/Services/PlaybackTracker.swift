import Combine
import Foundation

/// Everything that happens once a session was really listened to: local
/// activity, Apple Health, server progress, badges. The audio player only reports it.
@MainActor
final class PlaybackTracker {
    /// Session id of every completed listening, for ViewModels showing progress.
    let completions = PassthroughSubject<String, Never>()

    private let activity: ActivityStore
    private let health: HealthServicing
    private let progress: SessionProgressSyncing
    private let achievements: AchievementCenter?

    init(activity: ActivityStore, health: HealthServicing, progress: SessionProgressSyncing, achievements: AchievementCenter? = nil) {
        self.activity = activity
        self.health = health
        self.progress = progress
        self.achievements = achievements
    }

    func sessionCompleted(_ session: QuietoSession, listenedSeconds seconds: Int) {
        activity.record(sessionID: session.id, seconds: seconds)
        completions.send(session.id)
        achievements?.recordSession(session, seconds: seconds)
        health.recordMindfulSession(seconds: seconds, endingAt: .now)
        Task { [progress] in
            try? await progress.recordCompletion(sessionID: session.id, listenedSeconds: seconds)
        }
    }

    func ambienceListened(_ ambience: QuietoAmbience, seconds: Int) {
        achievements?.recordAmbience(ambience, seconds: seconds)
    }
}
