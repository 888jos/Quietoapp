#if DEBUG
import SwiftUI

/// Debug builds only: every celebration screen, triggered with sample data,
/// from the home (« Debug · Célébrations ») or at launch with
/// `QUIETO_DEBUG_CELEBRATION=<id>` (ids of `CelebrationDebugCase`).
enum CelebrationDebugCase: String, CaseIterable, Identifiable {
    case session, streak, badge, badges, surprise, back, week, plan, rest, risk, recap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .session: "1-2 · Fin de séance (série +1, étape, badge)"
        case .streak: "3 · Palier de série (7 jours)"
        case .badge: "4 · Badge débloqué"
        case .badges: "4 · Plusieurs badges (paginé)"
        case .surprise: "5 · Badge surprise"
        case .back: "8 · Retour après une pause"
        case .week: "9 · Semaine du plan terminée"
        case .plan: "10 · Plan terminé"
        case .rest: "6 · Accueil : jour de repos utilisé"
        case .risk: "7 · Accueil : série en danger"
        case .recap: "11 · Accueil : récap de la semaine"
        }
    }
}

@MainActor
enum CelebrationDebug {
    static func run(_ item: CelebrationDebugCase, center: CelebrationCenter, player: QuietoAudioPlayer) {
        let catalog = SessionCatalog().sessions
        let session = { (id: String) in catalog.first { $0.id == id }! }
        let badge = { (id: String) in Badge.all.first { $0.id == id }! }
        let state = { (id: String) in BadgeState(badge: badge(id), unlockedAt: .now, current: 1, target: 1) }
        let week = AchievementsViewModel.weekStatuses(
            practiceDays: Set((0...3).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Calendar.current.startOfDay(for: .now)) }),
            now: .now, calendar: .current
        )
        center.debugSetNotice(nil)
        switch item {
        case .session:
            center.debugSetOutcome(SessionOutcome(
                dayAdded: true, streakBefore: 3, streak: StreakStatus(current: 4, best: 9, practicedToday: true),
                week: week,
                planStep: .init(planTitle: "Mieux dormir", number: 6, total: 20, waitLabel: PlanSchedule.waitLabel(until: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)),
                badges: [badge("meditation_5")]
            ))
            let host = SessionFeedbackHostingController(session: session("sleep_3"), player: player)
            topController()?.present(host, animated: true)
        case .streak:
            center.debugShow(.streakMilestone(days: 7, best: 7, badge: badge("streak_7")))
        case .badge:
            center.debugShow(.badges([state("first_meditation")]))
        case .badges:
            center.debugShow(.badges([state("program_started"), state("early_bird"), state("full_week")]))
        case .surprise:
            center.debugShow(.badges([state("night_owl")]))
        case .back:
            center.debugShow(.welcomeBack(best: 12, daysAway: 9))
        case .week:
            center.debugShow(.planWeekDone(PlanWeekRecap(
                planTitle: "Mieux dormir", week: 1,
                sessions: ["screen_off", "express_4", "sleep_3", "sleep_cognitive_shuffle", "sleep_1"].map(session),
                nextPhase: .practice, weeksDone: 1, weeksTotal: 4
            )))
        case .plan:
            center.debugShow(.planFinished(PlanRecap(
                planID: .sleep, planTitle: "Mieux dormir", days: 20, minutes: 214, sessions: 15,
                favourite: session("sleep_3"), stress: [8, 6, 4]
            )))
        case .rest:
            center.debugSetNotice(.restDayUsed(streak: 9))
        case .risk:
            center.debugSetNotice(.streakAtRisk(streak: 12, quick: session("express_5")))
        case .recap:
            center.debugSetNotice(.weeklyRecap(week: week, minutes: 47, practices: 6, next: BadgeState(badge: badge("meditation_25"), unlockedAt: nil, current: 18, target: 25)))
        }
    }

    private static func topController() -> UIViewController? {
        guard var top = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController else { return nil }
        while let next = top.presentedViewController { top = next }
        return top
    }
}

/// The list opened from the home's debug button.
struct CelebrationDebugGallery: View {
    let center: CelebrationCenter
    let player: QuietoAudioPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(CelebrationDebugCase.allCases) { item in
                Button(item.title) {
                    dismiss()
                    // Lets the sheet go away before presenting full screen.
                    Task {
                        try? await Task.sleep(nanoseconds: 450_000_000)
                        CelebrationDebug.run(item, center: center, player: player)
                    }
                }
            }
            .navigationTitle("Célébrations")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
