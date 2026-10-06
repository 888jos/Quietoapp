import Combine
import Foundation

/// Everything that happens once a session was really listened to: local
/// activity, Apple Health, server progress. The audio player only reports it.
@MainActor
final class PlaybackTracker {
    /// Session id of every completed listening, for ViewModels showing progress.
    let completions = PassthroughSubject<String, Never>()

    private let activity: ActivityStore
    private let health: HealthServicing
    private let progress: SessionProgressSyncing

    init(activity: ActivityStore, health: HealthServicing, progress: SessionProgressSyncing) {
        self.activity = activity
        self.health = health
        self.progress = progress
    }

    func sessionCompleted(_ session: QuietoSession, listenedSeconds seconds: Int) {
        activity.record(sessionID: session.id, seconds: seconds)
        completions.send(session.id)
        health.recordMindfulSession(seconds: seconds, endingAt: .now)
        Task { [progress] in
            try? await progress.recordCompletion(sessionID: session.id, listenedSeconds: seconds)
        }
    }
}
