import SwiftUI
import UIKit

/// Shows a celebration full screen above whatever is open (player sheet,
/// collection…), like the end-of-session screen.
@MainActor
enum CelebrationPresenter {
    /// Returns the function that closes it; `onDismissed` runs once it is gone.
    @discardableResult
    static func present(_ content: AnyView, onDismissed: @escaping () -> Void) -> (_ then: (() -> Void)?) -> Void {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController else {
            onDismissed()
            return { $0?() }
        }
        var top = root
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        let controller = UIHostingController(rootView: content)
        controller.modalPresentationStyle = .fullScreen
        controller.modalTransitionStyle = .crossDissolve
        controller.overrideUserInterfaceStyle = .dark
        controller.view.backgroundColor = .clear
        top.present(controller, animated: true)
        return { [weak controller] then in
            guard let controller else { onDismissed(); then?(); return }
            controller.dismiss(animated: true) {
                onDismissed()
                then?()
            }
        }
    }
}

/// What a celebration can lead to.
struct CelebrationActions {
    var openCollection: () -> Void = {}
    var openProgramme: () -> Void = {}
    var choosePlan: () -> Void = {}
}

extension CelebrationMoment {
    /// The screen of this moment. `close` takes what to do once it is gone.
    @MainActor
    func view(summary: AchievementSummary, actions: CelebrationActions, close: @escaping (_ then: (() -> Void)?) -> Void) -> AnyView {
        switch self {
        case .streakMilestone(let days, let best, let badge):
            AnyView(StreakMilestoneView(days: days, best: best, badge: badge) { close(nil) })
        case .badges(let badges):
            AnyView(BadgeUnlockedView(
                badges: badges,
                unlockedCount: summary.unlockedCount,
                totalCount: summary.totalCount,
                next: { badge in summary.badges(in: badge.category).first { !$0.isUnlocked && !$0.badge.isHidden } },
                onCollection: { close(actions.openCollection) },
                onClose: { close(nil) }
            ))
        case .planWeekDone(let recap):
            AnyView(PlanWeekDoneView(recap: recap) { close(actions.openProgramme) })
        case .planFinished(let recap):
            AnyView(PlanFinishedView(recap: recap, onNextPlan: { close(actions.choosePlan) }, onClose: { close(nil) }))
        case .welcomeBack(let best, let days):
            AnyView(WelcomeBackView(best: best, daysAway: days) { close(nil) })
        }
    }
}

/// Lets a screen close itself through the presenter that showed it.
final class CelebrationCloser {
    var close: ((_ then: (() -> Void)?) -> Void)?
    func callAsFunction(_ then: (() -> Void)?) { close?(then) }
}
