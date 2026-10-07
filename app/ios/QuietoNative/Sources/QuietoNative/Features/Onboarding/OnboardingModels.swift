import Foundation

/// Every screen of the onboarding, in order. Conditional screens (crisis
/// support, Apple Health, the paywall relaunch) are filtered by the view model.
enum OnboardingStep: String, CaseIterable, Codable {
    // Acte 1 · Accroche
    case splash, promise, offer, firstName, gender
    // Acte 2 · Comprendre
    case reasons, sinceWhen, hardestTime, sleep, stressBefore, stressSources, notAlone,
         experience, blockers, formats, minutes, moment, goal
    // Acte 3 · Filet de sécurité
    case safety, crisisSupport
    // Acte 4 · Vivre l'app
    case breathIntro, breathing, stressAfter, breathResult, louaneIntro, louaneAsk, louaneReply
    // Acte 5 · Engagement et permissions
    case health, reminders, commitment, account, privacy
    // Acte 6 · Construction du plan
    case building, profileSummary, plan, projection, included
    // Acte 7 · Hard trial
    case trialTimeline, paywall, relaunch, welcome

    /// Screens without a back button.
    var isLocked: Bool {
        [.splash, .breathing, .building, .paywall, .relaunch, .welcome, .crisisSupport].contains(self)
    }

    /// The act (1–7) the screen belongs to, to read drop-off by part.
    var act: Int {
        switch self {
        case .splash, .promise, .offer, .firstName, .gender: 1
        case .reasons, .sinceWhen, .hardestTime, .sleep, .stressBefore, .stressSources, .notAlone,
             .experience, .blockers, .formats, .minutes, .moment, .goal: 2
        case .safety, .crisisSupport: 3
        case .breathIntro, .breathing, .stressAfter, .breathResult, .louaneIntro, .louaneAsk, .louaneReply: 4
        case .health, .reminders, .commitment, .account, .privacy: 5
        case .building, .profileSummary, .plan, .projection, .included: 6
        case .trialTimeline, .paywall, .relaunch, .welcome: 7
        }
    }
}

struct OnboardingOption: Identifiable, Hashable {
    let id: String
    let label: String
    let symbol: String?
    init(_ id: String, _ label: String, symbol: String? = nil) { self.id = id; self.label = label; self.symbol = symbol }
}

struct OnboardingQuestion {
    let title: String
    let subtitle: String?
    let options: [OnboardingOption]
    let multiple: Bool
}

/// Answers kept on the device until the end, then synchronised.
struct OnboardingAnswers: Codable, Equatable {
    var firstName = ""
    var choices: [String: [String]] = [:]
    var stressBefore: Double = 6
    var stressAfter: Double?
    var reminderHour = 21
    var reminderMinute = 30
    var healthAuthorized = false
    var remindersAuthorized = false
    var committed = false
    var relaunchShown = false

    func single(_ step: OnboardingStep) -> String? { choices[step.rawValue]?.first }
    func multiple(_ step: OnboardingStep) -> [String] { choices[step.rawValue] ?? [] }
}

enum OnboardingContent {
    static func question(for step: OnboardingStep, firstName: String) -> OnboardingQuestion? {
        switch step {
        case .gender:
            // Quieto never writes « fatigué·e »: every text agrees with this answer.
            return .init(title: "Tu es…", subtitle: "Pour que Quieto s’adresse à toi correctement.", options: [
                .init(QuietoGender.feminine.rawValue, "Une femme", symbol: "person.fill"),
                .init(QuietoGender.masculine.rawValue, "Un homme", symbol: "person.fill")
            ], multiple: false)
        case .reasons:
            // The title with the first name is already localized; option labels stay French (server values).
            let title = firstName.isEmpty ? "Qu’est-ce qui t’amène ?" : QuietoLocalization.format("Qu’est-ce qui t’amène, %@ ?", firstName)
            return .init(title: title, subtitle: "Choisis tout ce qui te parle.", options: [
                .init("stress", "Le stress au quotidien", symbol: "waveform.path.ecg"),
                .init("sleep", "Le sommeil", symbol: "moon.stars"),
                .init("thoughts", "Les pensées qui tournent", symbol: "tornado"),
                .init("anxiety", "L’anxiété", symbol: "heart.circle"),
                .init("emotions", "Des émotions difficiles", symbol: "cloud.rain"),
                .init("focus", "La concentration", symbol: "scope"),
                .init("self", "Prendre du temps pour moi", symbol: "leaf")
            ], multiple: true)
        case .sinceWhen:
            return .init(title: "Depuis combien de temps tu ressens ça ?", subtitle: nil, options: [
                .init("days", "Quelques jours"), .init("weeks", "Quelques semaines"),
                .init("months", "Plusieurs mois"), .init("always", "Aussi loin que je me souvienne")
            ], multiple: false)
        case .hardestTime:
            return .init(title: "À quel moment c’est le plus dur ?", subtitle: nil, options: [
                .init("morning", "Le matin, au réveil", symbol: "sunrise"),
                .init("day", "En journée", symbol: "sun.max"),
                .init("evening", "Le soir", symbol: "sunset"),
                .init("night", "La nuit", symbol: "moon"),
                .init("random", "Ça dépend, sans prévenir", symbol: "shuffle")
            ], multiple: false)
        case .sleep:
            return .init(title: "Et ton sommeil, en ce moment ?", subtitle: "Plusieurs réponses possibles.", options: [
                .init("falling", "J’ai du mal à m’endormir"),
                .init("waking", "Je me réveille la nuit"),
                .init("tired", "Je suis fatigué·e au réveil"),
                .init("fine", "Je dors plutôt bien")
            ], multiple: true)
        case .stressSources:
            return .init(title: "Qu’est-ce qui pèse le plus ?", subtitle: "Plusieurs réponses possibles.", options: [
                .init("work", "Le travail"), .init("studies", "Les études"), .init("couple", "Le couple"),
                .init("family", "La famille"), .init("money", "L’argent"), .init("health", "La santé"),
                .init("news", "L’actualité"), .init("unknown", "Je ne sais pas trop")
            ], multiple: true)
        case .experience:
            return .init(title: "Où en es-tu avec la méditation ?", subtitle: nil, options: [
                .init("never", "Jamais essayé"), .init("tried", "J’ai essayé quelques fois"),
                .init("sometimes", "J’en fais de temps en temps"), .init("regular", "J’en fais régulièrement")
            ], multiple: false)
        case .blockers:
            return .init(title: "Qu’est-ce qui t’a freiné·e jusqu’ici ?", subtitle: "Plusieurs réponses possibles.", options: [
                .init("time", "Pas le temps"), .init("cantStop", "Je n’arrive pas à arrêter de penser"),
                .init("forget", "J’oublie"), .init("boring", "Je m’ennuie vite"),
                .init("dontKnow", "Je ne sais pas par où commencer"), .init("nothing", "Rien, je me lance")
            ], multiple: true)
        case .formats:
            return .init(title: "Ce qui te fait le plus envie", subtitle: "Plusieurs réponses possibles.", options: [
                .init("voice", "Une voix qui me guide", symbol: "headphones"),
                .init("breathing", "Des exercices de respiration", symbol: "wind"),
                .init("relaxation", "Relâcher le corps", symbol: "figure.mind.and.body"),
                .init("louane", "Parler à quelqu’un (Louane)", symbol: "bubble.left.and.bubble.right")
            ], multiple: true)
        case .minutes:
            return .init(title: "Combien de temps par jour pour toi ?", subtitle: "Même 2 minutes, ça compte.", options: [
                .init("2", "2 minutes"), .init("5", "5 minutes"), .init("10", "10 minutes"), .init("15", "15 minutes ou plus")
            ], multiple: false)
        case .moment:
            return .init(title: "Ton meilleur moment pour souffler ?", subtitle: "On t’enverra un rappel doux à cette heure-là.", options: [
                .init("morning", "Le matin", symbol: "sunrise"),
                .init("lunch", "La pause du midi", symbol: "fork.knife"),
                .init("evening", "En fin de journée", symbol: "sunset"),
                .init("bedtime", "Au coucher", symbol: "bed.double")
            ], multiple: false)
        case .goal:
            // One answer per goal plan (`PlanRecommender.plan(forGoal:)`); « calm »
            // and « focus » keep their ids for the analytics history.
            return .init(title: "Dans 30 jours, tu aimerais…", subtitle: "Ton plan de 4 semaines partira de là.", options: [
                .init("sleep", "Mieux dormir", symbol: "moon.stars"),
                .init("anxiety", "Moins de moments d’angoisse", symbol: "heart.circle"),
                .init("calm", "Mieux gérer le stress", symbol: "wind"),
                .init("focus", "Avoir l’esprit plus clair", symbol: "sparkles"),
                .init("self", "Être plus en paix avec moi-même", symbol: "leaf"),
                .init("relationships", "Des relations plus apaisées", symbol: "person.2")
            ], multiple: false)
        case .safety:
            return .init(title: "Une question importante", subtitle: "En ce moment, t’arrive-t-il d’avoir des pensées de te faire du mal ?", options: [
                .init("no", "Non"), .init("sometimes", "Parfois"), .init("yes", "Oui")
            ], multiple: false)
        default:
            return nil
        }
    }

    static func label(_ step: OnboardingStep, _ id: String?) -> String? {
        guard let id else { return nil }
        return question(for: step, firstName: "")?.options.first { $0.id == id }?.label
    }

    static func defaultReminder(for moment: String?) -> (hour: Int, minute: Int) {
        switch moment {
        case "morning": (8, 0)
        case "lunch": (12, 30)
        case "evening": (18, 30)
        default: (21, 30)
        }
    }
}

/// Turns the answers into a goal plan (`PlanRecommender`), or the plan the
/// person picked among the alternatives.
enum OnboardingPlanBuilder {
    struct Plan: Equatable {
        let recommendation: PlanRecommender.Recommendation
        let state: QuietoPlanState
        /// The first week of steps, shown on the plan screen.
        let firstSteps: [PlanSchedule.Step]
        var sessions: [QuietoSession] { firstSteps.map(\.session) }
        var planID: QuietoPlanID { state.planID }
        var title: String { state.plan.title }
        var promise: String { state.plan.promise }
        var isRecommended: Bool { planID == recommendation.plan }
        /// The other plans offered, the recommended one first when it was not chosen.
        var alternatives: [QuietoPlanID] {
            ([recommendation.plan] + recommendation.alternatives).filter { $0 != planID }.prefix(2).map { $0 }
        }
    }

    /// Kept for Louane's first words: the strongest need, as a pillar.
    static func pillars(for answers: OnboardingAnswers) -> [QuietoPillar] {
        switch PlanRecommender.recommend(answers).plan {
        case .sleep: [.sleep, .stress]
        case .anxiety, .stress: [.stress, .thoughts]
        case .mind: [.thoughts, .stress]
        case .selfKindness, .relationships: [.emotions, .stress]
        }
    }

    static func build(from answers: OnboardingAnswers, catalog: SessionCatalog = SessionCatalog(), choosing chosen: QuietoPlanID? = nil, now: Date = .now) -> Plan {
        let recommendation = PlanRecommender.recommend(answers)
        var state = QuietoPlanState(
            planID: chosen ?? recommendation.plan,
            startedAt: now,
            rhythm: recommendation.rhythm,
            prefersShort: recommendation.prefersShort,
            includesDiscovery: recommendation.includesDiscovery
        )
        // Day 0 of the stress check-in: the slider of the onboarding.
        state.setStressLevel(Int(answers.stressBefore.rounded()), at: .start)
        let schedule = PlanSchedule(state: state, catalog: catalog.sessions, now: now)
        return Plan(recommendation: recommendation, state: state, firstSteps: Array(schedule.steps.prefix(7)))
    }

    /// « Parce que tu as dit… »: the answer that weighs most for this plan.
    static func reason(for planID: QuietoPlanID, answers: OnboardingAnswers) -> String? {
        if PlanRecommender.plan(forGoal: answers.single(.goal)) == planID, let goal = OnboardingContent.label(.goal, answers.single(.goal)) {
            return goal
        }
        let reasons: [String: QuietoPlanID] = ["sleep": .sleep, "anxiety": .anxiety, "stress": .stress, "thoughts": .mind, "focus": .mind, "emotions": .selfKindness, "self": .selfKindness]
        if let reason = answers.multiple(.reasons).first(where: { reasons[$0] == planID }) {
            return OnboardingContent.question(for: .reasons, firstName: "")?.options.first { $0.id == reason }?.label
        }
        if planID == .relationships, let source = answers.multiple(.stressSources).first(where: { ["couple", "family"].contains($0) }) {
            return OnboardingContent.question(for: .stressSources, firstName: "")?.options.first { $0.id == source }?.label
        }
        return nil
    }
}

/// Mirrors the server's lexical safety net: a crisis sign in free text routes
/// to the crisis screen (local listening line) before anything else.
enum OnboardingSafety {
    private static let patterns = [
        "suicid", "me tuer", "me foutre en l", "en finir", "plus envie de vivre", "envie de mourir", "veux mourir",
        "me faire du mal", "me scarifier", "scarification", "automutil",
        // English
        "kill myself", "end my life", "want to die", "self harm", "self-harm", "hurt myself",
        // Spanish
        "matarme", "quitarme la vida", "no quiero vivir", "quiero morir", "hacerme dano", "autolesion",
        // German
        "umbringen", "mir das leben nehmen", "nicht mehr leben", "will sterben", "selbstverletz", "mir weh tun",
        // Japanese
        "死にたい", "自殺", "消えたい", "自傷", "リストカット",
        // Korean
        "죽고 싶", "자살", "자해", "사라지고 싶"
    ]

    static func containsCrisisSignal(_ text: String) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "’", with: "'")
        return patterns.contains { normalized.contains($0) }
    }
}

/// What Louane says during the onboarding. Written by hand from the answers:
/// before subscribing, nothing is sent to the AI.
enum OnboardingLouaneScript {
    static func intro(_ answers: OnboardingAnswers) -> [String] {
        // Formatted bubbles are returned localized; plain keys are localized by `OnboardingBubbles`.
        let hello = answers.firstName.isEmpty ? "Bonjour, moi c’est Louane." : QuietoLocalization.format("Bonjour %@, moi c’est Louane.", answers.firstName)
        let weight: String
        switch OnboardingPlanBuilder.pillars(for: answers).first {
        case .sleep: weight = "J’ai lu tes réponses. Le soir, la tête continue de tourner alors que le corps voudrait s’arrêter."
        case .stress: weight = "J’ai lu tes réponses. Ça pousse toute la journée, et ça ne redescend jamais vraiment."
        case .thoughts: weight = "J’ai lu tes réponses. Les pensées partent dans tous les sens, et la journée file sans toi."
        default: weight = "J’ai lu tes réponses. Tu passes souvent après tout le reste."
        }
        return [hello, weight, "Je suis là pour en parler, quand tu veux. Pas de jugement, à ton rythme."]
    }

    static func reply(to text: String, answers: OnboardingAnswers, firstSession: QuietoSession?) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var bubbles = [trimmed.isEmpty
            ? "Pas de souci, on parlera quand tu en auras envie."
            : "Merci de me l’avoir dit. Ce n’est pas rien de mettre des mots dessus."]
        bubbles.append("On va y aller doucement, un petit pas par jour.")
        if let firstSession {
            bubbles.append(QuietoLocalization.format("Pour commencer, je te propose « %@ », %d min. Elle sera ta première séance.", firstSession.title.quietoLocalized, firstSession.durationMinutes))
        }
        return bubbles
    }
}

extension OnboardingAnswers {
    /// The questionnaire as the Louane server expects it (`CLES_PROFIL`).
    var serverProfile: [String: String] {
        var profile: [String: String] = [:]
        let reasons = multiple(.reasons).compactMap { id in OnboardingContent.question(for: .reasons, firstName: "")?.options.first { $0.id == id }?.label }
        if !reasons.isEmpty { profile["goals"] = reasons.joined(separator: "|") }
        if let goal = OnboardingContent.label(.goal, single(.goal)) { profile["q1"] = goal }
        if let focus = OnboardingContent.label(.stressSources, multiple(.stressSources).first) { profile["q_focus"] = focus }
        if let experience = OnboardingContent.label(.experience, single(.experience)) { profile["q2"] = experience }
        if let moment = OnboardingContent.label(.moment, single(.moment)) { profile["q4"] = moment }
        if let minutes = OnboardingContent.label(.minutes, single(.minutes)) { profile["q_minutes"] = minutes }
        return profile
    }
}
