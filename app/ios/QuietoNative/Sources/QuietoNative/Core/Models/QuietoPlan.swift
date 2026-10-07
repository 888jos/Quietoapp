import Foundation

/// The six goal plans (decision of 6 October 2026): 28 days in four weeks,
/// five main sessions and two free days a week. The plan replaces the old
/// 7-session programme built by the onboarding.
enum QuietoPlanID: String, CaseIterable, Codable, Identifiable {
    case sleep, anxiety, stress, mind
    case selfKindness = "self"
    case relationships

    var id: String { rawValue }
}

/// Where a day sits in the plan. Week 1 explains, weeks 2-3 practise, week 4
/// anchors with less guidance. The discovery week comes before, for beginners.
enum QuietoPlanPhase: String, Codable {
    case discovery, understand, practice, anchor

    var title: String {
        switch self {
        case .discovery: "Découvrir"
        case .understand: "Comprendre"
        case .practice: "Pratiquer"
        case .anchor: "Ancrer"
        }
    }

    /// Louane's word for the phase, shown with the session of the day.
    var louaneNote: String {
        switch self {
        case .discovery: "On pose les bases, sans rien réussir. Reviens au souffle chaque fois que l’esprit part."
        case .understand: "Cette semaine, on apprend les gestes. Des séances courtes, pour sentir ce qui t’aide."
        case .practice: "Tu connais les gestes : on les pratique plus longtemps. Répéter fait partie du chemin."
        case .anchor: "Dernière ligne droite : moins de guidage, plus de toi. Garde ce qui marche pour toi."
        }
    }
}

struct QuietoPlanDay: Equatable {
    enum Kind: String, Codable { case discovery, main, free }

    /// Position in the plan (1-28, or 1-35 with the discovery week).
    let number: Int
    let kind: Kind
    let phase: QuietoPlanPhase
    let sessionID: String
    /// Shorter version, for people who chose 2 or 5 minutes a day.
    let shortSessionID: String?
    /// A session chosen for what weighs on the person (`PlanSituations`).
    var isSituation = false
}

struct QuietoPlan: Identifiable, Equatable {
    let id: QuietoPlanID
    /// Bumped when the days change, so a plan in progress keeps its own list.
    let version: Int
    let title: String
    let promise: String
    let symbol: String
    /// Short sessions used for the long days when the person has little time.
    let shortSessions: [String]
    /// The 28 days, in order.
    let days: [QuietoPlanDay]

    var weeks: Int { days.count / 7 }
}

enum PlanCatalog {
    static let version = 1

    /// French on purpose: stored and sent to the server, localized when displayed.
    static let all: [QuietoPlan] = [
        plan(.sleep, "Mieux dormir", "Retrouver des soirées et des nuits plus calmes.", "moon.stars.fill",
             short: ["express_4", "stress_2", "screen_off"],
             weeks: [
                ["screen_off", "express_4", "stress_2", "sleep_3", "sleep_cognitive_shuffle", "breath_sleep_descent", "sleep_1"],
                ["sleep_5", "middle_of_night", "new_long_exhale", "new_body_scan_sleep", "sleep_3", "stress_2", "sleep_2"],
                ["actualite_5", "sleep_4", "breath_sleep_descent", "night_sky", "stress_5", "stress_2", "sleep_cognitive_shuffle"],
                ["new_nidra_pause", "middle_of_night", "new_long_exhale", "night_watch", "sleep_5", "breath_sleep_descent", "sleep_1"]
             ]),
        plan(.anxiety, "Apaiser l’anxiété", "Traverser les vagues d’angoisse avec des outils simples.", "heart.circle.fill",
             short: ["express_7", "meditation_15", "breath_sigh"],
             weeks: [
                ["decouverte_3", "express_7", "breath_sigh", "meditation_15", "new_sensory_shelter", "breathing_1", "emotion_3"],
                ["emo_uncertainty", "new_safe_place", "breathing_5", "new_thoughts_on_clouds", "meditation_10", "breathing_1", "emotion_3"],
                ["emotion_4", "rel_worry_for_someone", "breath_sigh", "body_tension", "sunday_reset", "new_long_exhale", "new_safe_place"],
                ["decouverte_2", "new_sensory_shelter", "breathing_1", "emo_uncertainty", "meditation_08", "breathing_5", "discover_open_sitting"]
             ]),
        plan(.stress, "Souffler face au stress", "Décompresser au quotidien et au travail.", "wind",
             short: ["express_5", "between_calls", "doorstep_pause", "meditation_09"],
             weeks: [
                ["express_5", "between_calls", "breath_sigh", "meditation_09", "doorstep_pause", "new_long_exhale", "after_work"],
                ["express_2", "new_focus_reset", "breathing_3", "commute_home", "rel_before_hard_talk", "breath_sigh", "stress_3"],
                ["express_1", "body_tension", "breathing_1", "friday_release", "blue_hour", "breathing_3", "stress_5"],
                ["express_8", "new_walking_pause", "breath_sigh", "gentle_recovery", "after_work", "breathing_3", "new_nidra_pause"]
             ]),
        plan(.mind, "Apaiser le mental", "Moins ruminer, mieux te concentrer.", "sparkles",
             short: ["actualite_3", "daybreak_stillness", "breath_counting"],
             weeks: [
                ["discover_counting", "decouverte_2", "breath_counting", "actualite_3", "new_focus_reset", "new_box_breathing", "meditation_10"],
                ["new_thoughts_on_clouds", "daybreak_stillness", "breathing_2", "decision_pause", "creative_block", "breath_triangle", "afternoon_reframe"],
                ["actualite_1", "meditation_06", "new_box_breathing", "new_walking_pause", "sleep_cognitive_shuffle", "breath_counting", "discover_open_sitting"],
                ["rel_deep_listening", "meditation_10", "breathing_2", "new_thoughts_on_clouds", "decision_pause", "new_box_breathing", "meditation_08"]
             ]),
        plan(.selfKindness, "Être bien avec soi", "Accueillir tes émotions, te parler avec plus de douceur.", "leaf.fill",
             short: ["small_joy", "express_3", "new_long_exhale"],
             weeks: [
                ["small_joy", "meditation_05", "new_long_exhale", "discover_rain", "morning_kind_start", "breathing_5", "emo_inner_critic"],
                ["emo_sadness", "emo_anger", "breath_cooling", "emotion_1", "work_impostor", "new_long_exhale", "gentle_recovery"],
                ["express_3", "new_soft_reset", "breathing_5", "emotion_4", "work_after_criticism", "breath_cooling", "emotion_5"],
                ["rel_gratitude_someone", "lonely_evening", "new_long_exhale", "emo_inner_critic", "small_joy", "breathing_5", "emotion_1"]
             ]),
        plan(.relationships, "Des relations plus apaisées", "Rester toi-même avec les autres, même quand c’est tendu.", "person.2.fill",
             short: ["express_6", "rel_gratitude_someone", "breath_sigh"],
             weeks: [
                ["rel_gratitude_someone", "rel_deep_listening", "breathing_1", "express_6", "rel_before_hard_talk", "breath_sigh", "emotion_5"],
                ["new_after_conflict", "rel_worry_for_someone", "breath_cooling", "lonely_evening", "emo_anger", "breathing_1", "rel_letting_go_grudge"],
                ["work_after_criticism", "emo_inner_critic", "breath_sigh", "meditation_05", "rel_deep_listening", "breath_cooling", "emotion_1"],
                ["express_6", "rel_before_hard_talk", "breathing_1", "small_joy", "rel_letting_go_grudge", "breath_cooling", "emotion_5"]
             ])
    ]

    /// Seven days to learn the basics, before the plan, for beginners.
    static let discoveryWeek = ["decouverte_1", "breathing_1", "discover_counting", "decouverte_2", "new_long_exhale", "discover_body_scan", "decouverte_3"]

    static func plan(_ id: QuietoPlanID) -> QuietoPlan { all.first { $0.id == id }! }

    /// Days 3 and 6 of each week are free days (a breathing exercise); the
    /// other five are the main sessions.
    static let freeDaysOfWeek: Set<Int> = [3, 6]

    private static func plan(_ id: QuietoPlanID, _ title: String, _ promise: String, _ symbol: String, short: [String], weeks: [[String]]) -> QuietoPlan {
        var days: [QuietoPlanDay] = []
        for (weekIndex, week) in weeks.enumerated() {
            let phase: QuietoPlanPhase = weekIndex == 0 ? .understand : (weekIndex == weeks.count - 1 ? .anchor : .practice)
            for (dayIndex, sessionID) in week.enumerated() {
                let isFree = freeDaysOfWeek.contains(dayIndex + 1)
                days.append(QuietoPlanDay(number: days.count + 1, kind: isFree ? .free : .main, phase: phase, sessionID: sessionID, shortSessionID: nil))
            }
        }
        return QuietoPlan(id: id, version: version, title: title, promise: promise, symbol: symbol, shortSessions: short, days: days)
    }
}

// MARK: - Recommendation

/// Deterministic: the same answers always give the same plan, and ties follow
/// a fixed order. The safety question never enters the score.
enum PlanRecommender {
    struct Recommendation: Equatable {
        let plan: QuietoPlanID
        /// The two next plans by score, offered under « Ce n’est pas tout à fait ça ? ».
        let alternatives: [QuietoPlanID]
        /// Beginners start with the discovery week.
        let includesDiscovery: Bool
        /// 2 or 5 minutes a day: the long days get a short version.
        let prefersShort: Bool
        let rhythm: ProgramRhythm
    }

    /// Tie order (after the score): goal first, then this order.
    static let order: [QuietoPlanID] = [.sleep, .anxiety, .stress, .mind, .selfKindness, .relationships]

    static func plan(forGoal goal: String?) -> QuietoPlanID? {
        switch goal {
        case "sleep": .sleep
        case "anxiety": .anxiety
        case "calm", "stress": .stress
        case "focus", "mind": .mind
        case "self": .selfKindness
        case "relationships": .relationships
        default: nil
        }
    }

    static func scores(for answers: OnboardingAnswers) -> [QuietoPlanID: Int] {
        var scores = Dictionary(uniqueKeysWithValues: QuietoPlanID.allCases.map { ($0, 0) })
        if let goal = plan(forGoal: answers.single(.goal)) { scores[goal, default: 0] += 5 }
        for reason in answers.multiple(.reasons) {
            switch reason {
            case "sleep": scores[.sleep, default: 0] += 2
            case "anxiety": scores[.anxiety, default: 0] += 2
            case "stress": scores[.stress, default: 0] += 2
            case "thoughts", "focus": scores[.mind, default: 0] += 2
            case "emotions", "self": scores[.selfKindness, default: 0] += 2
            default: break
            }
        }
        let sources = answers.multiple(.stressSources)
        if sources.contains("couple") || sources.contains("family") { scores[.relationships, default: 0] += 2 }
        if sources.contains("work") || sources.contains("studies") || sources.contains("money") { scores[.stress, default: 0] += 1 }
        if answers.multiple(.sleep).contains(where: { $0 != "fine" }) { scores[.sleep, default: 0] += 1 }
        if answers.single(.hardestTime) == "night" { scores[.sleep, default: 0] += 1 }
        return scores
    }

    static func recommend(_ answers: OnboardingAnswers) -> Recommendation {
        let scores = scores(for: answers)
        let goal = plan(forGoal: answers.single(.goal))
        let ranked = order.sorted { lhs, rhs in
            let left = scores[lhs] ?? 0, right = scores[rhs] ?? 0
            if left != right { return left > right }
            if lhs == goal || rhs == goal { return lhs == goal }
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
        let minutes = Int(answers.single(.minutes) ?? "5") ?? 5
        return Recommendation(
            plan: ranked[0],
            alternatives: Array(ranked.dropFirst().prefix(2)),
            includesDiscovery: ["never", "tried"].contains(answers.single(.experience) ?? "never"),
            prefersShort: minutes <= 5,
            rhythm: answers.multiple(.blockers).contains("time") ? .gentle : .regular
        )
    }
}

// MARK: - Situation days

/// Two or three days of weeks 2-3 replaced by sessions matching the « Qu’est-ce
/// qui pèse le plus ? » answers of the onboarding (work, news, couple…).
/// Deterministic: the same answers always give the same days.
enum PlanSituations {
    /// Main days of weeks 2 and 3 (practice phase) that may be replaced.
    static let slots = [12, 16, 19]

    /// Candidates per answer, in order of preference. « unknown » has none.
    static let sessions: [(source: String, sessionIDs: [String])] = [
        ("work", ["work_after_criticism", "after_work", "work_impostor", "express_5"]),
        ("studies", ["new_focus_reset", "express_8", "work_impostor"]),
        ("couple", ["rel_before_hard_talk", "new_after_conflict", "rel_letting_go_grudge"]),
        ("family", ["rel_worry_for_someone", "new_after_conflict", "rel_gratitude_someone"]),
        ("money", ["emo_uncertainty", "decision_pause"]),
        ("health", ["emo_uncertainty", "body_tension", "gentle_recovery"]),
        ("news", ["actualite_5", "actualite_1", "actualite_2"])
    ]

    /// Plan day → session. One answer gives 2 days, several give 3, taken in
    /// turn from each answer (in the order of the question, not of the taps).
    /// A session already in the plan is skipped.
    static func days(for planID: QuietoPlanID, sources: [String]) -> [Int: String] {
        let plan = PlanCatalog.plan(planID)
        var used = Set(plan.days.map(\.sessionID))
        var queues = sessions.filter { sources.contains($0.source) }.map { $0.sessionIDs }
        guard !queues.isEmpty else { return [:] }
        let target = queues.count == 1 ? 2 : slots.count
        var picks: [String] = []
        while picks.count < target, queues.contains(where: { !$0.isEmpty }) {
            for index in queues.indices where picks.count < target {
                while let candidate = queues[index].first {
                    queues[index].removeFirst()
                    if used.insert(candidate).inserted { picks.append(candidate); break }
                }
            }
        }
        let chosenSlots = picks.count == 2 ? [slots[0], slots[2]] : Array(slots.prefix(picks.count))
        return Dictionary(uniqueKeysWithValues: zip(chosenSlots, picks))
    }

    /// The situation days of a plan restored from the server: its days whose
    /// session differs from the catalogue (day numbers include the discovery week).
    static func restore(planID: QuietoPlanID, includesDiscovery: Bool, sessionIDs: [Int: String]) -> [Int: String]? {
        let offset = includesDiscovery ? PlanCatalog.discoveryWeek.count : 0
        let found = PlanCatalog.plan(planID).days.reduce(into: [Int: String]()) { result, day in
            if let id = sessionIDs[day.number + offset], id != day.sessionID, slots.contains(day.number) { result[day.number] = id }
        }
        return found.isEmpty ? nil : found
    }
}

// MARK: - Rhythm

enum ProgramRhythm: String, CaseIterable, Identifiable, Codable {
    case gentle = "Doux"
    case regular = "Régulier"
    case sustained = "Soutenu"
    var id: String { rawValue }
    var detail: String {
        switch self {
        case .gentle: "3 séances par semaine"
        case .regular: "5 séances par semaine"
        case .sustained: "Une séance par jour"
        }
    }
    var localizedName: String { rawValue.quietoLocalized }
    var localizedDetail: String { detail.quietoLocalized }

    /// Days of the reminders (1 = Sunday, as `Calendar`): Monday, Wednesday
    /// and Friday for « Doux », weekdays for « Régulier », every day for « Soutenu ».
    var reminderWeekdays: Set<Int> {
        switch self {
        case .gentle: [2, 4, 6]
        case .regular: [2, 3, 4, 5, 6]
        case .sustained: Set(1...7)
        }
    }

    /// Free days are part of the path only every day; otherwise they stay
    /// optional and are left out of the count.
    var includesFreeDays: Bool { self == .sustained }
    /// Days to wait after a step before the next one opens.
    var gapDays: Int { self == .gentle ? 2 : 1 }
}

// MARK: - A plan in progress

/// The plan of the person, kept on the iPhone (the source of truth) and copied
/// to Supabase when possible.
struct QuietoPlanState: Codable, Equatable {
    var planID: QuietoPlanID
    var version: Int
    var startedAt: Date
    var rhythm: ProgramRhythm
    var prefersShort: Bool
    var includesDiscovery: Bool
    /// Completed day numbers and when.
    var completions: [Int: Date] = [:]
    var remoteID: UUID?
    /// Plan day (discovery week left out) → session matching what weighs on
    /// the person, fixed when the plan starts (`PlanSituations`).
    var situations: [Int: String]?
    /// The 0-10 stress slider of the onboarding, asked again during the plan.
    /// Stays on the iPhone: never sent to analytics nor to the server.
    var stressLevels: [StressCheckpoint: Int]?

    init(planID: QuietoPlanID, startedAt: Date, rhythm: ProgramRhythm, prefersShort: Bool, includesDiscovery: Bool) {
        self.planID = planID
        self.version = PlanCatalog.version
        self.startedAt = startedAt
        self.rhythm = rhythm
        self.prefersShort = prefersShort
        self.includesDiscovery = includesDiscovery
    }

    var plan: QuietoPlan { PlanCatalog.plan(planID) }

    /// Days of the discovery week before day 1 of the plan.
    var discoveryOffset: Int { includesDiscovery ? PlanCatalog.discoveryWeek.count : 0 }

    func stressLevel(at checkpoint: StressCheckpoint) -> Int? { stressLevels?[checkpoint] }

    mutating func setStressLevel(_ value: Int, at checkpoint: StressCheckpoint) {
        stressLevels = (stressLevels ?? [:]).merging([checkpoint: min(10, max(0, value))]) { $1 }
    }
}

/// Day 0, day 14 and the last day of the plan: the stress slider comes back.
enum StressCheckpoint: String, Codable, CaseIterable {
    case start, middle, end

    /// Plan day (discovery week left out) after which the middle check-in is asked.
    static let middleDay = 14

    var label: String {
        switch self {
        case .start: "Au départ"
        case .middle: "Mi-parcours"
        case .end: "À la fin"
        }
    }

    var title: String {
        switch self {
        case .start: "Avant de commencer"
        case .middle: "Tu es à mi-parcours"
        case .end: "Dernier jour du plan"
        }
    }
}

/// What the plan looks like today. Pure: built from the state and the date.
struct PlanSchedule: Equatable {
    struct Step: Identifiable, Equatable {
        let day: QuietoPlanDay
        let session: QuietoSession
        let isCompleted: Bool
        var id: Int { day.number }
    }

    enum Today: Equatable {
        /// The step to do now.
        case available(Step)
        /// Today's step is done: the next one opens on this date.
        case locked(next: Step, opensOn: Date)
        case finished
    }

    let state: QuietoPlanState
    /// Every day of the plan, discovery week included, in order.
    let allDays: [QuietoPlanDay]
    /// The days that count with this rhythm.
    let steps: [Step]
    let today: Today

    init(state: QuietoPlanState, catalog: [QuietoSession], now: Date = .now, calendar: Calendar = .current) {
        self.state = state
        let plan = state.plan
        var days: [QuietoPlanDay] = []
        if state.includesDiscovery {
            for (index, id) in PlanCatalog.discoveryWeek.enumerated() {
                days.append(QuietoPlanDay(number: index + 1, kind: .discovery, phase: .discovery, sessionID: id, shortSessionID: nil))
            }
        }
        let offset = days.count
        days += plan.days.map { day in
            let situation = state.situations?[day.number]
            return QuietoPlanDay(number: day.number + offset, kind: day.kind, phase: day.phase, sessionID: situation ?? day.sessionID, shortSessionID: day.shortSessionID, isSituation: situation != nil)
        }
        allDays = days

        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let counted = days.filter { state.rhythm.includesFreeDays || $0.kind != .free }
        steps = counted.compactMap { day in
            Self.session(for: day, state: state, plan: plan, byID: byID).map {
                Step(day: day, session: $0, isCompleted: state.completions[day.number] != nil)
            }
        }

        if let next = steps.first(where: { !$0.isCompleted }) {
            if let last = state.completions.values.max(),
               let opens = calendar.date(byAdding: .day, value: state.rhythm.gapDays, to: calendar.startOfDay(for: last)),
               now < opens {
                today = .locked(next: next, opensOn: opens)
            } else {
                today = .available(next)
            }
        } else {
            today = .finished
        }
    }

    /// The short version of a long day when the person has little time: the
    /// day's own short session, else one of the plan's short sessions.
    private static func session(for day: QuietoPlanDay, state: QuietoPlanState, plan: QuietoPlan, byID: [String: QuietoSession]) -> QuietoSession? {
        guard let main = byID[day.sessionID] else { return nil }
        // A situation day keeps its session: it was chosen for the person.
        guard state.prefersShort, day.kind == .main, !day.isSituation, main.durationMinutes > 8 else { return main }
        if let short = day.shortSessionID.flatMap({ byID[$0] }) { return short }
        let candidates = plan.shortSessions.compactMap { byID[$0] }
        guard !candidates.isEmpty else { return main }
        return candidates[(day.number - 1) % candidates.count]
    }

    /// « la suite demain » / « la suite dans 2 jours », after today's step.
    static func waitLabel(until opensOn: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: opensOn)).day ?? 1
        return days <= 1
            ? "Étape du jour faite · la suite demain".quietoLocalized
            : QuietoLocalization.format("Étape du jour faite · la suite dans %d jours", days)
    }

    var completedCount: Int { steps.filter(\.isCompleted).count }
    var isFinished: Bool { today == .finished }

    /// The stress check-in to ask now, if any: before the first step, once
    /// day 14 of the plan is done, and when the plan is finished. The first one
    /// is dropped once a step is done; the middle one waits until the end.
    var dueStressCheckpoint: StressCheckpoint? {
        let offset = state.discoveryOffset
        let reachedMiddle = state.completions.keys.contains { $0 - offset >= StressCheckpoint.middleDay }
        if isFinished { return state.stressLevel(at: .end) == nil ? .end : nil }
        if state.completions.isEmpty { return state.stressLevel(at: .start) == nil ? .start : nil }
        if reachedMiddle { return state.stressLevel(at: .middle) == nil ? .middle : nil }
        return nil
    }

    /// The check-ins answered so far, in order, for the end of the plan.
    var stressProgression: [(checkpoint: StressCheckpoint, level: Int)] {
        StressCheckpoint.allCases.compactMap { checkpoint in state.stressLevel(at: checkpoint).map { (checkpoint, $0) } }
    }

    /// 1-based position of the current step among the counted steps.
    var currentStepNumber: Int? {
        switch today {
        case .available(let step), .locked(let step, _): steps.firstIndex(of: step).map { $0 + 1 }
        case .finished: nil
        }
    }

    var nextStep: Step? {
        switch today {
        case .available(let step), .locked(let step, _): step
        case .finished: nil
        }
    }

    /// The step a completed session counts for: only the step open today, and
    /// only if it is the session of that step. Other listens never move the plan.
    func step(completedBy sessionID: String) -> Step? {
        guard case .available(let step) = today, step.session.id == sessionID || step.day.sessionID == sessionID else { return nil }
        return step
    }
}

// MARK: - Reminders

/// A one-off reminder: with a plan, each one names the step of the day.
struct PlannedReminder: Equatable {
    let date: Date
    let body: String
}

/// Pure: the reminders of the coming weeks, on the days of the rhythm, from
/// the day the next step opens. They all name the next step: a step is only
/// done in the app, and each completion schedules them again.
enum PlanReminders {
    /// Well under the 64 pending notifications iOS keeps per app.
    static let horizonDays = 28

    static func make(schedule: PlanSchedule, hour: Int, minute: Int, firstName: String, now: Date, calendar: Calendar = .autoupdatingCurrent) -> [PlannedReminder] {
        guard let next = schedule.nextStep else { return [] }
        let opens: Date = {
            if case .locked(_, let opensOn) = schedule.today { return opensOn }
            return now
        }()
        let weekdays = schedule.state.rhythm.reminderWeekdays
        let body = body(for: next.session, firstName: firstName)
        let today = calendar.startOfDay(for: now)
        return (0..<horizonDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  date > now, date >= opens else { return nil }
            return PlannedReminder(date: date, body: body)
        }
    }

    static func body(for session: QuietoSession, firstName: String) -> String {
        let title = session.title.quietoLocalized
        return firstName.isEmpty
            ? QuietoLocalization.format("Ton étape du jour t’attend : %@ (%d min).", title, session.durationMinutes)
            : QuietoLocalization.format("%@, ton étape du jour t’attend : %@ (%d min).", firstName, title, session.durationMinutes)
    }
}

/// Schedules the daily reminders: with a plan in progress, on the days of its
/// rhythm and naming the step of the day; otherwise on the days chosen in the
/// profile. Shared by the Programme tab and the profile.
struct PlanReminderPlanner {
    let scheduler: ReminderScheduling
    let preferences: QuietoPreferences
    let catalog: SessionCatalog
    var now: () -> Date = Date.init
    var calendar: Calendar = .autoupdatingCurrent

    /// The rhythm that sets the reminder days, while a plan is in progress.
    var activeRhythm: ProgramRhythm? {
        guard let state = preferences.planState,
              !PlanSchedule(state: state, catalog: catalog.sessions, now: now(), calendar: calendar).isFinished else { return nil }
        return state.rhythm
    }

    /// `settings` and `firstName` default to the saved ones; the profile passes
    /// the values being edited. Does nothing when reminders are off.
    func refresh(settings: ReminderSettings? = nil, firstName: String? = nil) {
        let settings = settings ?? preferences.reminder
        guard settings.isEnabled else { return }
        let name = firstName ?? preferences.firstName
        if let state = preferences.planState {
            let schedule = PlanSchedule(state: state, catalog: catalog.sessions, now: now(), calendar: calendar)
            if !schedule.isFinished {
                scheduler.schedule(PlanReminders.make(schedule: schedule, hour: settings.hour, minute: settings.minute, firstName: name, now: now(), calendar: calendar))
                return
            }
        }
        scheduler.schedule(hour: settings.hour, minute: settings.minute, weekdays: settings.weekdays.sorted(), firstName: name)
    }
}
