import Combine
import Foundation

/// Records every practice in the journal, keeps badges and the streak up to
/// date, and announces new badges. Created once by `AppContainer`; the player,
/// the check-in and the account sync feed it, the screens observe `summary`.
@MainActor
final class AchievementCenter: ObservableObject {
    @Published private(set) var summary = AchievementSummary.empty
    /// Badges unlocked by something the person just did, for the celebration.
    let unlocks = PassthroughSubject<[Badge], Never>()

    /// A background sound shorter than this is not counted.
    static let minimumSoundSeconds = 60
    /// A sound left on all night counts as one long pause, not as hours of practice.
    static let maximumSoundSeconds = 30 * 60

    enum Key {
        static let unlocked = "quieto.gamification.unlocked"
    }

    /// Session ids of the current programme, read at each evaluation.
    var programSessionIDs: () -> [String] = { [] }
    /// Steps done in the goal plan and how many it has: a plan repeats some
    /// sessions, so its progress is not the share of its sessions heard.
    var programProgress: (() -> (completed: Int, total: Int)?)?
    /// Streak and badge figures for paywall and campaign targeting.
    var onAttributesChanged: (([String: Any?]) -> Void)?

    private let journal: PracticeJournal
    private let defaults: UserDefaults
    private let catalog: QuietoSessionCatalogProviding
    private let analytics: QuietoAnalyticsProviding
    private let sync: PracticeSyncing?
    private let reminders: ReminderScheduling?
    private let now: () -> Date
    private let calendar: Calendar
    private var isSyncing = false
    private var lastAttributes: [String: Int] = [:]

    init(
        journal: PracticeJournal,
        defaults: UserDefaults = .standard,
        catalog: QuietoSessionCatalogProviding,
        analytics: QuietoAnalyticsProviding,
        sync: PracticeSyncing? = nil,
        reminders: ReminderScheduling? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.journal = journal
        self.defaults = defaults
        self.catalog = catalog
        self.analytics = analytics
        self.sync = sync
        self.reminders = reminders
        self.calendar = calendar
        self.now = now
    }

    /// First evaluation at launch. Badges already deserved by past practice are
    /// unlocked silently: celebrations are only for what happens from now on.
    func start(legacyActivity: [ActivityEvent] = []) {
        journal.importLegacyActivity(legacyActivity, catalog: catalog)
        evaluate(announce: false)
    }

    // MARK: Recording

    func recordSession(_ session: QuietoSession, seconds: Int) {
        record(kind: PracticeKind(session: session), contentID: session.id, seconds: seconds)
    }

    func recordAmbience(_ ambience: QuietoAmbience, seconds: Int) {
        guard seconds >= Self.minimumSoundSeconds else { return }
        record(kind: .sound, contentID: ambience.id, seconds: min(seconds, Self.maximumSoundSeconds))
    }

    func recordCheckIn(_ situation: QuietoSituation) {
        record(kind: .checkIn, contentID: situation.id, seconds: 0)
    }

    /// Recomputes the streak, e.g. when the app comes back on a new day.
    func refresh() {
        evaluate(announce: true)
    }

    /// After local data was wiped (sign-out, account deletion).
    func reloadAfterWipe() {
        journal.reload()
        lastAttributes = [:]
        evaluate(announce: false)
    }

    // MARK: Account

    /// Brings back the practice of this account (reinstall, other iPhone) and
    /// sends what was practised offline.
    func synchronize() async {
        guard let sync, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        if let remote = try? await sync.fetchPractice(), journal.merge(remote) {
            evaluate(announce: false)
        }
        await uploadPending()
    }

    // MARK: Private

    private func record(kind: PracticeKind, contentID: String, seconds: Int) {
        let before = summary.streak
        journal.record(kind: kind, contentID: contentID, seconds: seconds, at: now())
        analytics.track("practice_recorded", properties: ["kind": kind.rawValue, "content": contentID])
        evaluate(announce: true)
        trackStreak(before: before, after: summary.streak, kind: kind)
        Task { [weak self] in
            await self?.uploadPending()
            await self?.refreshTrialReminder()
        }
    }

    private func evaluate(announce: Bool) {
        var stats = PracticeStats.make(
            entries: journal.entries,
            catalog: catalog,
            programSessionIDs: programSessionIDs(),
            now: now(),
            calendar: calendar
        )
        if let progress = programProgress?() {
            stats.programCompleted = progress.completed
            stats.programTotal = progress.total
        }
        var unlocked = unlockedBadges
        let new = AchievementEngine.newlyMet(stats: stats, unlocked: unlocked)
        if !new.isEmpty {
            let date = now()
            new.forEach { unlocked[$0.id] = date }
            defaults.set(unlocked.mapValues(\.timeIntervalSince1970), forKey: Key.unlocked)
        }
        summary = AchievementEngine.summary(stats: stats, unlocked: unlocked)
        if announce, !new.isEmpty {
            new.forEach { analytics.track("badge_unlocked", properties: ["badge": $0.id, "category": $0.category.rawValue]) }
            unlocks.send(new)
        }
        publishAttributes()
    }

    private var unlockedBadges: [String: Date] {
        let raw = defaults.dictionary(forKey: Key.unlocked) as? [String: Double] ?? [:]
        return raw.mapValues { Date(timeIntervalSince1970: $0) }
    }

    private func trackStreak(before: StreakStatus, after: StreakStatus, kind: PracticeKind) {
        guard kind.countsAsPractice, !before.practicedToday, after.practicedToday else { return }
        analytics.track("streak_day", properties: ["days": "\(after.current)"])
        let today = calendar.startOfDay(for: now())
        if after.current > 1,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           !summary.stats.practiceDays.contains(yesterday) {
            analytics.track("streak_saved_by_rest_day", properties: ["days": "\(after.current)"])
        }
    }

    private func publishAttributes() {
        let stats = summary.stats
        let values = [
            "streak_days": stats.streak.current,
            "best_streak_days": stats.streak.best,
            "badges_unlocked": summary.unlockedCount,
            "practice_count": stats.practiceCount,
            "practice_minutes": stats.totalMinutes
        ]
        guard values != lastAttributes else { return }
        lastAttributes = values
        onAttributesChanged?(values.mapValues { $0 as Any? })
    }

    private func uploadPending() async {
        guard let sync else { return }
        let pending = journal.pendingUpload
        guard !pending.isEmpty else { return }
        do {
            try await sync.uploadPractice(pending)
            journal.markUploaded(Set(pending.map(\.id)))
        } catch {
            // Kept pending; retried after the next practice or at the next launch.
        }
    }

    /// The reminder sent two days before the end of the trial shows what was
    /// already built, which is what makes people keep their subscription.
    private func refreshTrialReminder() async {
        guard let reminders, let body = trialReminderBody else { return }
        await reminders.refreshTrialEndingReminder(body: body)
    }

    var trialReminderBody: String? {
        let stats = summary.stats
        guard stats.practiceCount > 0 else { return nil }
        var body = String(
            format: "Ton essai se termine dans 2 jours. Tu as déjà fait %d pauses (%d min) et débloqué %d badges.".quietoLocalized,
            stats.practiceCount, stats.totalMinutes, summary.unlockedCount
        )
        if stats.streak.current >= 2 {
            body += " " + String(format: "Ta série : %d jours.".quietoLocalized, stats.streak.current)
        }
        return body
    }
}
