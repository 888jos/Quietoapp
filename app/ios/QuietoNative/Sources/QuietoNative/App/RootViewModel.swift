import Combine
import SwiftUI

/// App-level state above the tabs: hard paywall gate and lifecycle.
@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var access: QuietoAccessState

    private let subscriptions: SubscriptionServicing
    private let audioPlayer: QuietoAudioPlayer
    private let achievements: AchievementCenter?
    private var cancellables = Set<AnyCancellable>()

    init(subscriptions: SubscriptionServicing, audioPlayer: QuietoAudioPlayer, achievements: AchievementCenter? = nil) {
        self.subscriptions = subscriptions
        self.audioPlayer = audioPlayer
        self.achievements = achievements
        access = subscriptions.access
        subscriptions.accessPublisher
            .removeDuplicates()
            .sink { [weak self] access in self?.accessChanged(access) }
            .store(in: &cancellables)
    }

    /// Hard paywall: nothing behind it is reachable without an entitlement.
    var isLocked: Bool { access != .subscribed }

    func scenePhaseChanged(_ phase: ScenePhase) {
        if phase == .background { audioPlayer.keepAudioSessionAlive() }
        // Renewals, refunds and expirations that happened while away.
        if phase == .active {
            subscriptions.syncWithServer()
            // A new day may have started since the last visit.
            achievements?.refresh()
        }
    }

    private func accessChanged(_ value: QuietoAccessState) {
        access = value
        if value == .locked {
            audioPlayer.close()
            audioPlayer.isFullPlayerPresented = false
        }
    }
}
