import Foundation

/// Every value Quieto keeps in `UserDefaults`, behind typed accessors. The raw
/// keys are unchanged so existing installs keep their data.
final class QuietoPreferences {
    enum Key {
        static let firstName = "quieto.profile.firstName"
        static let remindersEnabled = "quieto.profile.remindersEnabled"
        static let reminderHour = "quieto.profile.reminderHour"
        static let reminderMinute = "quieto.profile.reminderMinute"
        static let reminderDays = "quieto.profile.reminderDays"
        static let ambientMusic = "quieto.profile.ambientMusic"
        static let reduceMotion = "quieto.profile.reduceMotion"
        static let largerText = "quieto.profile.largerText"
        static let ambienceVolume = "quieto.profile.ambienceVolume"
        static let programRhythm = "quieto.program.rhythm"
        static let programAdjustmentRequested = "quieto.program.adjustmentRequested"
        static let favorites = "quieto.native.session.favorites"
        static let recentSessions = "quieto.native.session.recent"
        static let louaneDraft = "quieto.native.louane.draft"
        static let onboardingCompletedAt = "quieto.onboarding.completedAt"
        static let onboardingAnswers = "quieto.onboarding.answers"
        static let onboardingStep = "quieto.onboarding.step"
        static let onboardingStartedAt = "quieto.onboarding.startedAt"
        static let onboardingActiveSeconds = "quieto.onboarding.activeSeconds"
        static let planState = "quieto.plan.state"
        static func playbackPosition(_ sessionID: String) -> String { "quieto.native.audio.position.\(sessionID)" }
    }

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Profile

    var firstName: String {
        get { defaults.string(forKey: Key.firstName) ?? "" }
        set { defaults.set(newValue, forKey: Key.firstName) }
    }

    var reminder: ReminderSettings {
        get {
            ReminderSettings(
                isEnabled: defaults.bool(forKey: Key.remindersEnabled),
                hour: defaults.object(forKey: Key.reminderHour) as? Int ?? 21,
                minute: defaults.object(forKey: Key.reminderMinute) as? Int ?? 30,
                weekdays: Set(defaults.array(forKey: Key.reminderDays) as? [Int] ?? Array(1...7))
            )
        }
        set {
            defaults.set(newValue.isEnabled, forKey: Key.remindersEnabled)
            defaults.set(newValue.hour, forKey: Key.reminderHour)
            defaults.set(newValue.minute, forKey: Key.reminderMinute)
            defaults.set(newValue.weekdays.sorted(), forKey: Key.reminderDays)
        }
    }

    var ambientMusic: Bool {
        get { defaults.bool(forKey: Key.ambientMusic) }
        set { defaults.set(newValue, forKey: Key.ambientMusic) }
    }

    /// Volume of background sounds, 0...1.
    var ambienceVolume: Double {
        get { defaults.object(forKey: Key.ambienceVolume) as? Double ?? QuietoPreferences.defaultAmbienceVolume }
        set { defaults.set(min(1, max(0, newValue)), forKey: Key.ambienceVolume) }
    }
    static let defaultAmbienceVolume = 0.28

    var reduceMotion: Bool {
        get { defaults.bool(forKey: Key.reduceMotion) }
        set { defaults.set(newValue, forKey: Key.reduceMotion) }
    }

    var largerText: Bool {
        get { defaults.bool(forKey: Key.largerText) }
        set { defaults.set(newValue, forKey: Key.largerText) }
    }

    // MARK: Programme

    var programRhythm: String? {
        get { defaults.string(forKey: Key.programRhythm) }
        set { defaults.set(newValue, forKey: Key.programRhythm) }
    }

    var programAdjustmentRequested: Bool {
        get { defaults.bool(forKey: Key.programAdjustmentRequested) }
        set { defaults.set(newValue, forKey: Key.programAdjustmentRequested) }
    }

    // MARK: Sessions

    var favoriteSessionIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.favorites) ?? []) }
        set { defaults.set(Array(newValue), forKey: Key.favorites) }
    }

    var recentSessionIDs: [String] {
        get { defaults.stringArray(forKey: Key.recentSessions) ?? [] }
        set { defaults.set(newValue, forKey: Key.recentSessions) }
    }

    func playbackPosition(for sessionID: String) -> Double {
        defaults.double(forKey: Key.playbackPosition(sessionID))
    }

    func setPlaybackPosition(_ position: Double?, for sessionID: String) {
        if let position { defaults.set(position, forKey: Key.playbackPosition(sessionID)) }
        else { defaults.removeObject(forKey: Key.playbackPosition(sessionID)) }
    }

    // MARK: Louane

    var louaneDraft: String {
        get { defaults.string(forKey: Key.louaneDraft) ?? "" }
        set { defaults.set(newValue, forKey: Key.louaneDraft) }
    }

    // MARK: Onboarding

    var isOnboardingCompleted: Bool { defaults.object(forKey: Key.onboardingCompletedAt) != nil }

    func markOnboardingCompleted(at date: Date = .now) {
        defaults.set(date.timeIntervalSince1970, forKey: Key.onboardingCompletedAt)
        defaults.removeObject(forKey: Key.onboardingStep)
        defaults.removeObject(forKey: Key.onboardingStartedAt)
        defaults.removeObject(forKey: Key.onboardingActiveSeconds)
    }

    /// First onboarding screen shown on this install (survives the app being killed).
    var onboardingStartedAt: Date? {
        get { defaults.object(forKey: Key.onboardingStartedAt).flatMap { $0 as? Double }.map(Date.init(timeIntervalSince1970:)) }
        set { defaults.set(newValue?.timeIntervalSince1970, forKey: Key.onboardingStartedAt) }
    }

    /// Time actually spent on onboarding screens, across launches.
    var onboardingActiveSeconds: Double {
        get { defaults.double(forKey: Key.onboardingActiveSeconds) }
        set { defaults.set(newValue, forKey: Key.onboardingActiveSeconds) }
    }

    var onboardingStep: String? {
        get { defaults.string(forKey: Key.onboardingStep) }
        set { defaults.set(newValue, forKey: Key.onboardingStep) }
    }

    /// The goal plan in progress (or finished), nil before one is chosen.
    var planState: QuietoPlanState? {
        get { defaults.data(forKey: Key.planState).flatMap { try? JSONDecoder().decode(QuietoPlanState.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.planState) }
    }

    var onboardingAnswers: OnboardingAnswers? {
        get { defaults.data(forKey: Key.onboardingAnswers).flatMap { try? JSONDecoder().decode(OnboardingAnswers.self, from: $0) } }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.onboardingAnswers) }
    }

    /// Profile sent to Louane once subscribed.
    var louaneServerProfile: [String: String] { onboardingAnswers?.serverProfile ?? [:] }

    // MARK: Wipe

    func removeAll() {
        if defaults === UserDefaults.standard, let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        } else {
            defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("quieto.") }.forEach(defaults.removeObject(forKey:))
        }
    }
}

struct ReminderSettings: Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    var weekdays: Set<Int>

    static let `default` = ReminderSettings(isEnabled: false, hour: 21, minute: 30, weekdays: Set(1...7))
}
