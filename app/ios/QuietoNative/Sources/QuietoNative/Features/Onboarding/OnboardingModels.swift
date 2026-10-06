import Foundation

/// Every screen of the onboarding, in order. Conditional screens (crisis
/// support, Apple Health, the paywall relaunch) are filtered by the view model.
enum OnboardingStep: String, CaseIterable, Codable {
    // Acte 1 · Accroche
    case splash, promise, offer, firstName
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
        let name = firstName.isEmpty ? "" : ", \(firstName)"
        switch step {
        case .reasons:
            return .init(title: "Qu’est-ce qui t’amène\(name) ?", subtitle: "Choisis tout ce qui te parle.", options: [
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
            return .init(title: "Dans 30 jours, tu aimerais…", subtitle: nil, options: [
                .init("sleep", "Mieux dormir"), .init("calm", "Me sentir plus calme"),
                .init("anxiety", "Moins de moments d’angoisse"), .init("focus", "Mieux me concentrer"),
                .init("habit", "Avoir pris l’habitude de souffler")
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

/// Builds the 7-day programme from the answers, using only catalogue sessions.
enum OnboardingPlanBuilder {
    struct Plan: Equatable {
        let title: String
        let sessions: [QuietoSession]
    }

    static func pillars(for answers: OnboardingAnswers) -> [QuietoPillar] {
        var weights: [QuietoPillar: Int] = [:]
        let add = { (pillar: QuietoPillar, weight: Int) in weights[pillar, default: 0] += weight }
        for reason in answers.multiple(.reasons) {
            switch reason {
            case "sleep": add(.sleep, 3)
            case "stress", "anxiety": add(.stress, 3)
            case "thoughts", "focus": add(.thoughts, 3)
            case "emotions", "self": add(.emotions, 3)
            default: break
            }
        }
        switch answers.single(.goal) {
        case "sleep": add(.sleep, 4)
        case "calm", "anxiety": add(.stress, 4)
        case "focus": add(.thoughts, 4)
        default: break
        }
        if answers.multiple(.sleep).contains(where: { $0 != "fine" }) { add(.sleep, 1) }
        let ranked = weights.sorted { $0.value > $1.value }.map(\.key)
        return ranked.isEmpty ? [.stress, .thoughts] : ranked
    }

    static func build(from answers: OnboardingAnswers, catalog: SessionCatalog = SessionCatalog()) -> Plan {
        let minutes = Int(answers.single(.minutes) ?? "5") ?? 5
        let maxDuration = minutes >= 15 ? 30 : minutes + 4
        let pillars = pillars(for: answers)
        let wantsBreathing = answers.multiple(.formats).contains("breathing")
        let beginner = ["never", "tried"].contains(answers.single(.experience) ?? "never")

        var picked: [QuietoSession] = []
        func take(_ candidates: [QuietoSession], count: Int) {
            var added = 0
            for session in candidates where picked.count < 7 && added < count && !picked.contains(where: { $0.id == session.id }) {
                picked.append(session)
                added += 1
            }
        }
        let fitting = catalog.sessions.filter { $0.durationMinutes <= maxDuration }
        // Day 1 is always short and gentle.
        if beginner, let first = catalog.sessions.first(where: { $0.id == "decouverte_1" }) { picked.append(first) }
        else if let first = fitting.filter({ $0.pillar == pillars.first }).min(by: { $0.durationMinutes < $1.durationMinutes }) { picked.append(first) }
        if wantsBreathing { take(fitting.filter { $0.practiceType == .breathing }, count: 2) }
        for (index, pillar) in pillars.enumerated() {
            take(fitting.filter { $0.pillar == pillar && $0.practiceType != .breathing }, count: index == 0 ? 4 : 2)
        }
        take(fitting, count: 7)
        take(catalog.sessions, count: 7)

        let title: String
        switch answers.single(.goal) ?? "" {
        case "sleep": title = "Retrouver le sommeil en 7 jours"
        case "anxiety": title = "Apaiser l’angoisse en 7 jours"
        case "focus": title = "Retrouver le calme pour se concentrer"
        case "habit": title = "7 jours pour prendre l’habitude"
        default: title = "7 jours pour retrouver ton calme"
        }
        return Plan(title: title, sessions: Array(picked.prefix(7)))
    }
}

/// Mirrors the server's lexical safety net: a crisis sign in free text routes
/// to the 3114 screen before anything else.
enum OnboardingSafety {
    private static let patterns = [
        "suicid", "me tuer", "me foutre en l", "en finir", "plus envie de vivre", "envie de mourir", "veux mourir",
        "me faire du mal", "me scarifier", "scarification", "automutil", "kill myself", "end my life", "want to die", "self harm"
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
        let name = answers.firstName.isEmpty ? "" : " \(answers.firstName)"
        let weight: String
        switch OnboardingPlanBuilder.pillars(for: answers).first {
        case .sleep: weight = "Le soir, la tête continue de tourner alors que le corps voudrait s’arrêter."
        case .stress: weight = "Ça pousse toute la journée, et ça ne redescend jamais vraiment."
        case .thoughts: weight = "Les pensées partent dans tous les sens, et la journée file sans toi."
        default: weight = "Tu passes souvent après tout le reste."
        }
        return ["Bonjour\(name), moi c’est Louane.", "J’ai lu tes réponses. \(weight)", "Je suis là pour en parler, quand tu veux. Pas de jugement, à ton rythme."]
    }

    static func reply(to text: String, answers: OnboardingAnswers, firstSession: QuietoSession?) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var bubbles = [trimmed.isEmpty
            ? "Pas de souci, on parlera quand tu en auras envie."
            : "Merci de me l’avoir dit. Ce n’est pas rien de mettre des mots dessus."]
        bubbles.append("On va y aller doucement, un petit pas par jour.")
        if let firstSession {
            bubbles.append("Pour commencer, je te propose « \(firstSession.title.quietoLocalized) », \(firstSession.durationMinutes) min. Elle sera ta première séance.")
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
