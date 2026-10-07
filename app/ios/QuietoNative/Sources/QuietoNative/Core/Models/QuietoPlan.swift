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

    init(planID: QuietoPlanID, startedAt: Date, rhythm: ProgramRhythm, prefersShort: Bool, includesDiscovery: Bool) {
        self.planID = planID
        self.version = PlanCatalog.version
        self.startedAt = startedAt
        self.rhythm = rhythm
        self.prefersShort = prefersShort
        self.includesDiscovery = includesDiscovery
    }

    var plan: QuietoPlan { PlanCatalog.plan(planID) }
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
        days += plan.days.map { QuietoPlanDay(number: $0.number + offset, kind: $0.kind, phase: $0.phase, sessionID: $0.sessionID, shortSessionID: $0.shortSessionID) }
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
        guard state.prefersShort, day.kind == .main, main.durationMinutes > 8 else { return main }
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
