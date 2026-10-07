import Foundation
import SwiftUI

enum QuietoTab: String, CaseIterable, Identifiable {
    case home = "Accueil"
    case programme = "Programme"
    case sessions = "Séances"
    case louane = "Louane"
    case profile = "Profil"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .programme: "calendar"
        case .sessions: "headphones"
        case .louane: "link"
        case .profile: "person"
        }
    }
}

struct QuietoSession: Identifiable, Equatable {
    let id: String
    let title: String
    let durationMinutes: Int
    let subtitle: String
    let imageName: String
    let isPremium: Bool
    let audioFile: String
    let categoryID: String
    let category: QuietoCategory
    let goal: QuietoGoal
    let pillar: QuietoPillar
    let practiceType: QuietoPracticeType
    let intention: String
    let keywords: [String]
    let themes: [QuietoTheme]
    let situations: [QuietoSituation]
    let longDescription: String
    /// One or two sentences on what the session does, without the generic suffix.
    let summary: String
    let preparation: String
    let steps: [String]
    let transcript: String
    let breathingPattern: QuietoBreathingPattern?

    init(
        id: String,
        title: String,
        durationMinutes: Int,
        subtitle: String,
        imageName: String,
        isPremium: Bool,
        audioFile: String = "",
        categoryID: String = "",
        category: QuietoCategory = .daily,
        goal: QuietoGoal = .relax,
        pillar: QuietoPillar = .thoughts,
        practiceType: QuietoPracticeType = .meditation,
        intention: String = "Une pause simple, à ton rythme.",
        keywords: [String] = [],
        themes: [QuietoTheme] = [],
        situations: [QuietoSituation] = [],
        longDescription: String? = nil,
        summary: String = "",
        preparation: String = "Installe-toi dans une position stable et confortable. Tu peux garder les yeux ouverts ou les fermer.",
        steps: [String]? = nil,
        transcript: String? = nil,
        breathingPattern: QuietoBreathingPattern? = nil
    ) {
        self.id = id
        self.title = title
        self.durationMinutes = durationMinutes
        self.subtitle = subtitle
        self.imageName = imageName
        self.isPremium = isPremium
        self.audioFile = audioFile
        self.categoryID = categoryID
        self.category = category
        self.goal = goal
        self.pillar = pillar
        self.practiceType = practiceType
        self.intention = intention
        self.keywords = keywords
        self.themes = themes
        self.situations = situations
        self.longDescription = longDescription ?? "« \(title) » est une pause guidée de \(durationMinutes) minutes. \(intention) La pratique avance sans objectif de performance : tu peux l’adapter, bouger ou t’arrêter à tout moment."
        self.summary = summary
        self.preparation = preparation
        self.transcript = transcript ?? QuietoTranscript.make(title: title, intention: intention, practice: practiceType)
        let pattern = breathingPattern ?? (practiceType == .breathing ? .coherence : nil)
        self.breathingPattern = pattern
        if let pattern {
            self.steps = steps ?? [
                "Installe-toi le dos droit, les épaules relâchées.",
                pattern == .counting ? "Compte chaque expiration de un à dix, puis recommence." : "Suis la courbe : elle monte quand tu inspires, reste plate quand tu retiens, descend quand tu expires.",
                pattern == .counting ? "Touche l’écran à chaque expiration." : "Si le rythme devient inconfortable, reviens à ton souffle naturel."
            ]
        } else {
            self.steps = steps ?? [
                "Prendre contact avec le corps et le souffle.",
                "Explorer la pratique de \(practiceType.rawValue.lowercased()) à ton rythme.",
                "Revenir progressivement à ce qui t’entoure."
            ]
        }
    }

    var readerMode: QuietoReaderMode { practiceType == .breathing ? .breathing : .guidedVoice }
    var isDownloadAvailable: Bool { readerMode == .guidedVoice && !audioFile.isEmpty }

    var localizedIntention: String {
        let translated = intention.quietoLocalized
        if QuietoLocalization.isFrench || translated != intention { return translated }
        return String(format: "Une pratique de %@ pour créer une pause simple et accessible.".quietoLocalized, practiceType.nameInSentence)
    }

    var localizedLongDescription: String {
        guard !QuietoLocalization.isFrench else { return longDescription }
        if !summary.isEmpty, summary.quietoLocalized != summary {
            let suffix = readerMode == .breathing
                ? "La courbe monte quand tu inspires, reste plate quand tu retiens et descend quand tu expires. Ne force jamais : si le rythme devient inconfortable, reviens à ton souffle naturel."
                : "Une séance guidée, avec des temps de silence pour pratiquer vraiment. Tu peux t’arrêter ou ouvrir les yeux à tout moment."
            return "\(summary.quietoLocalized) \(suffix.quietoLocalized)"
        }
        if readerMode == .breathing {
            return String(
                format: "Cet exercice de %d minutes se pratique sans narration. Le point monte avec l’inspiration, marque les pauses éventuelles et redescend avec l’expiration. Adapte ou arrête le rythme dès qu’il devient inconfortable.".quietoLocalized,
                durationMinutes
            )
        }
        return String(
            format: "Cette séance de %d minutes utilise la %@. Les consignes sont courtes et alternent avec des silences pour te laisser pratiquer à ton rythme.".quietoLocalized,
            durationMinutes,
            practiceType.nameInSentence
        )
    }

    var localizedPreparation: String {
        QuietoLocalization.isFrench ? preparation : "Installe-toi dans une position stable et confortable. Tu peux garder les yeux ouverts ou les fermer.".quietoLocalized
    }

    var localizedSteps: [String] {
        guard !QuietoLocalization.isFrench else { return steps }
        if readerMode == .breathing { return steps.map(\.quietoLocalized) }
        return [
            "Prendre contact avec le corps et le souffle.".quietoLocalized,
            "Explorer la pratique à ton rythme.".quietoLocalized,
            "Revenir progressivement à ce qui t’entoure.".quietoLocalized
        ]
    }

    var localizedTranscript: String {
        QuietoLocalization.isFrench ? transcript : QuietoTranscript.make(title: title.quietoLocalized, intention: localizedIntention, practice: practiceType)
    }
}

/// The context of life a session belongs to.
enum QuietoCategory: String, CaseIterable, Identifiable, Hashable {
    case discovery = "Découverte"
    case work = "Travail"
    case relationships = "Relations"
    case innerSelf = "Soi & émotions"
    case daily = "Quotidien & transitions"
    case morning = "Matin & énergie"
    case screens = "Écrans & actualité"
    case night = "Nuit & sommeil"
    case body = "Corps & récupération"

    var id: String { String(describing: self) }
    var symbol: String {
        switch self {
        case .discovery: "sparkles"
        case .work: "briefcase"
        case .relationships: "person.2"
        case .innerSelf: "heart"
        case .daily: "arrow.left.arrow.right"
        case .morning: "sunrise"
        case .screens: "iphone.slash"
        case .night: "moon.stars"
        case .body: "figure.mind.and.body"
        }
    }
    /// Dedicated collection artwork. Unlike the former implementation, these
    /// covers never borrow the artwork of an individual session.
    var collectionArtwork: String {
        switch self {
        case .discovery: "moment-getting-started.png"
        case .work: "moment-work.png"
        case .relationships: "moment-relationships.png"
        case .innerSelf: "moment-self-emotions.png"
        case .daily: "moment-everyday-life.png"
        case .morning: "moment-morning-energy.png"
        case .screens: "moment-screens-news.png"
        case .night: "moment-night-sleep.png"
        case .body: "moment-body-recovery.png"
        }
    }
    var summary: String {
        switch self {
        case .discovery: "Apprendre les bases pas à pas, sans prérequis, jusqu’à méditer en autonomie."
        case .work: "Garder ton calme et ta concentration au travail, sans y laisser toute ton énergie."
        case .relationships: "Traverser les conflits, l’inquiétude et la solitude avec plus de douceur."
        case .innerSelf: "Accueillir ce que tu ressens et te parler avec plus de bienveillance."
        case .daily: "Des pauses pour les transports, le seuil de la porte et les fins de semaine."
        case .morning: "Commencer la journée avec de l’élan, même quand l’énergie manque."
        case .screens: "Retrouver une juste distance avec ton téléphone et le flot des nouvelles."
        case .night: "Déposer la journée, apaiser les pensées et glisser vers le sommeil."
        case .body: "Relâcher les tensions et récupérer en profondeur, par le corps."
        }
    }
    /// The illustration that stands for the category throughout the app.
    var artwork: String { collectionArtwork }
}

/// What the person is looking for when they open a session.
enum QuietoGoal: String, CaseIterable, Identifiable, Hashable {
    case sleep = "S’endormir"
    case relax = "Se relaxer"
    case calm = "Calmer le stress"
    case focus = "Se concentrer"
    case energy = "Retrouver de l’énergie"
    case emotion = "Accueillir une émotion"
    case perspective = "Prendre du recul"
    case kindness = "Bienveillance envers soi"

    var id: String { String(describing: self) }
    var artwork: String { "quick-\(id).png" }
    var symbol: String {
        switch self {
        case .sleep: "moon"
        case .relax: "leaf"
        case .calm: "waveform.path.ecg"
        case .focus: "scope"
        case .energy: "bolt"
        case .emotion: "drop"
        case .perspective: "cloud"
        case .kindness: "hands.sparkles"
        }
    }
    /// Two hues for the quick-start tile, kept in the app's muted night palette.
    var tint: (top: Color, bottom: Color) {
        switch self {
        case .sleep: (Color(red: 0.55, green: 0.48, blue: 0.93), Color(red: 0.38, green: 0.30, blue: 0.80))
        case .relax: (Color(red: 0.45, green: 0.80, blue: 0.62), Color(red: 0.24, green: 0.62, blue: 0.47))
        case .calm: (Color(red: 0.42, green: 0.67, blue: 0.98), Color(red: 0.25, green: 0.47, blue: 0.88))
        case .focus: (Color(red: 0.96, green: 0.52, blue: 0.62), Color(red: 0.85, green: 0.33, blue: 0.47))
        case .energy: (Color(red: 0.99, green: 0.72, blue: 0.40), Color(red: 0.95, green: 0.53, blue: 0.27))
        case .emotion: (Color(red: 0.40, green: 0.78, blue: 0.86), Color(red: 0.22, green: 0.58, blue: 0.70))
        case .perspective: (Color(red: 0.70, green: 0.76, blue: 0.86), Color(red: 0.50, green: 0.57, blue: 0.70))
        case .kindness: (Color(red: 0.95, green: 0.62, blue: 0.78), Color(red: 0.82, green: 0.42, blue: 0.62))
        }
    }

    /// Legacy pillar, still used by the programme and the Louane recommendations.
    var pillar: QuietoPillar {
        switch self {
        case .sleep: .sleep
        case .relax, .calm: .stress
        case .focus, .perspective: .thoughts
        case .energy, .emotion, .kindness: .emotions
        }
    }
    var theme: QuietoTheme {
        switch self {
        case .sleep: .sleep
        case .relax: .rest
        case .calm: .stress
        case .focus: .focus
        case .energy: .energy
        case .emotion, .kindness: .emotions
        case .perspective: .uncertainty
        }
    }
}

enum QuietoTheme: String, CaseIterable, Identifiable, Hashable {
    case work = "Travail"
    case sleep = "Sommeil"
    case energy = "Énergie"
    case relationships = "Relations"
    case solitude = "Solitude"
    case stress = "Stress"
    case emotions = "Émotions"
    case focus = "Concentration"
    case digital = "Écrans et actualité"
    case transitions = "Transitions"
    case confidence = "Confiance en soi"
    case uncertainty = "Incertitude"
    case rest = "Repos"
    case dailyLife = "Quotidien"

    var id: String { String(describing: self) }
    var symbol: String {
        switch self {
        case .work: "briefcase"
        case .sleep: "moon"
        case .energy: "bolt"
        case .relationships: "person.2"
        case .solitude: "person"
        case .stress: "waveform.path.ecg"
        case .emotions: "heart"
        case .focus: "scope"
        case .digital: "rectangle.slash"
        case .transitions: "arrow.left.arrow.right"
        case .confidence: "figure.arms.open"
        case .uncertainty: "ellipsis"
        case .rest: "bed.double"
        case .dailyLife: "sun.max"
        }
    }
}

enum QuietoSituation: String, CaseIterable, Identifiable, Hashable {
    case tiredButAwake = "Je suis fatigué·e, mais je n’arrive pas à dormir"
    case awakeAtNight = "Je me réveille au milieu de la nuit"
    case exhaustedMorning = "Je me sens épuisé·e dès le réveil"
    case importantEvent = "J’appréhende un événement important"
    case difficultConversation = "Je viens de vivre une conversation difficile"
    case racingThoughts = "Je pense trop et je n’arrive pas à décrocher"
    case overwhelmed = "Je me sens débordé·e"
    case lowEnergy = "Je manque d’énergie ou de motivation"
    case afterWork = "Ma journée est finie, mais mon esprit travaille encore"
    case lonely = "Je me sens seul·e ou déconnecté·e"
    case selfCritical = "Je suis dur·e avec moi-même"
    case uncertainty = "J’attends une réponse et je suis dans l’incertitude"
    case newsOverload = "L’actualité et les réseaux m’épuisent"
    case strongEmotion = "Je ressens une émotion forte"
    case quickPause = "J’ai besoin d’une pause très courte"

    var id: String { String(describing: self) }

    /// The eight situations offered to choose from (home, programme). The others
    /// overlap with one of these; they still tag sessions in the catalogue.
    static let featured: [QuietoSituation] = [
        .overwhelmed, .racingThoughts, .importantEvent, .strongEmotion,
        .tiredButAwake, .lowEnergy, .selfCritical, .quickPause,
    ]

    var subtitle: String {
        switch self {
        case .tiredButAwake: "Retirer la pression de devoir dormir."
        case .awakeAtNight: "Revenir au repos sans regarder l’heure."
        case .exhaustedMorning: "Commencer sans demander trop d’énergie."
        case .importantEvent: "Faire une place au trac avant d’entrer."
        case .difficultConversation: "Laisser retomber l’intensité avant de répondre."
        case .racingThoughts: "Créer de l’espace sans combattre les pensées."
        case .overwhelmed: "Revenir à une seule chose possible maintenant."
        case .lowEnergy: "Retrouver un élan doux, sans se brusquer."
        case .afterWork: "Créer une frontière entre le travail et le reste."
        case .lonely: "Retrouver une présence intérieure accueillante."
        case .selfCritical: "Remplacer le jugement par une parole plus juste."
        case .uncertainty: "Habiter l’attente sans inventer la réponse."
        case .newsOverload: "Retrouver une juste distance avec le flux."
        case .strongEmotion: "Observer le ressenti avant de décider quoi faire."
        case .quickPause: "Revenir à soi en cinq minutes ou moins."
        }
    }

    var themes: [QuietoTheme] {
        switch self {
        case .tiredButAwake, .awakeAtNight: [.sleep, .rest]
        case .exhaustedMorning: [.energy, .rest, .dailyLife]
        case .importantEvent: [.stress, .confidence, .work]
        case .difficultConversation: [.relationships, .emotions]
        case .racingThoughts: [.stress, .focus]
        case .overwhelmed: [.stress, .work, .focus]
        case .lowEnergy: [.energy, .dailyLife]
        case .afterWork: [.work, .transitions, .rest]
        case .lonely: [.solitude, .relationships, .emotions]
        case .selfCritical: [.confidence, .emotions]
        case .uncertainty: [.uncertainty, .stress]
        case .newsOverload: [.digital, .stress]
        case .strongEmotion: [.emotions, .relationships]
        case .quickPause: [.dailyLife, .transitions]
        }
    }

    /// Six sessions for every situation (breathing included). A session can
    /// answer several situations.
    var sessionIDs: [String] {
        switch self {
        case .tiredButAwake: ["sleep_5", "sleep_cognitive_shuffle", "new_body_scan_sleep", "sleep_3", "breath_sleep_descent", "stress_2"]
        case .awakeAtNight: ["middle_of_night", "night_watch", "sleep_cognitive_shuffle", "sleep_4", "night_sky", "breath_sleep_descent"]
        case .exhaustedMorning: ["new_soft_reset", "morning_wake_body", "express_3", "daybreak_stillness", "morning_kind_start", "breathing_4"]
        case .importantEvent: ["express_8", "express_1", "rel_before_hard_talk", "emotion_4", "breath_sigh", "breathing_1"]
        case .difficultConversation: ["express_6", "new_after_conflict", "emo_anger", "rel_letting_go_grudge", "between_calls", "breath_cooling"]
        case .racingThoughts: ["new_thoughts_on_clouds", "decouverte_2", "sleep_cognitive_shuffle", "afternoon_reframe", "meditation_10", "discover_counting"]
        case .overwhelmed: ["new_sensory_shelter", "new_focus_reset", "express_5", "emotion_3", "actualite_5", "breath_sigh"]
        case .lowEnergy: ["afternoon_fog", "body_mindful_stretch", "small_joy", "rel_gratitude_someone", "new_soft_reset", "breathing_4"]
        case .afterWork: ["after_work", "commute_home", "doorstep_pause", "friday_release", "sleep_1", "new_long_exhale"]
        case .lonely: ["lonely_evening", "emotion_5", "rel_gratitude_someone", "small_joy", "emo_sadness", "meditation_15"]
        case .selfCritical: ["emo_inner_critic", "emotion_1", "work_impostor", "work_after_criticism", "gentle_recovery", "morning_kind_start"]
        case .uncertainty: ["emo_uncertainty", "rel_worry_for_someone", "decision_pause", "meditation_08", "sunday_reset", "breathing_1"]
        case .newsOverload: ["actualite_1", "actualite_2", "actualite_3", "actualite_5", "screen_off", "meditation_16"]
        case .strongEmotion: ["meditation_05", "emo_sadness", "emo_anger", "emotion_3", "express_6", "breath_cooling"]
        case .quickPause: ["express_5", "between_calls", "express_2", "meditation_09", "breath_sigh", "new_long_exhale"]
        }
    }

    /// Background sounds suggested with this situation, chosen from its themes.
    var ambienceIDs: [String] {
        if themes.contains(.sleep) { return ["rain", "pink-noise", "night-train", "ocean"] }
        if themes.contains(.energy) { return ["forest", "river"] }
        if themes.contains(.work) || themes.contains(.focus) { return ["cafe", "brown-noise", "river"] }
        if themes.contains(.relationships) || themes.contains(.solitude) { return ["campfire", "ocean"] }
        if themes.contains(.digital) { return ["forest", "rain"] }
        return ["forest", "ocean"]
    }
}

enum QuietoReaderMode { case guidedVoice, breathing }

/// One step of a breathing cycle. `level` is the height the curve reaches at
/// the end of the step (0 = empty lungs, 1 = full): an inhale climbs, a hold
/// stays flat, an exhale goes down.
struct QuietoBreathPhase: Equatable {
    enum Kind: Equatable { case inhale, hold, exhale }
    enum Side: Equatable { case left, right }
    let kind: Kind
    let seconds: Double
    let level: Double
    var side: Side? = nil

    var label: String {
        switch kind {
        case .inhale: "Inspire"
        case .hold: "Retiens"
        case .exhale: "Expire"
        }
    }
    var sideLabel: String? {
        switch side {
        case .left?: "Narine gauche"
        case .right?: "Narine droite"
        case nil: nil
        }
    }
}

enum QuietoBreathingPattern: String, CaseIterable, Codable {
    case coherence, sigh, longExhale, box, triangle, fourSevenEight, sleepDescent, lowPause, alternate, staircase, energizing, cooling, counting

    /// Seconds of "get ready" before the first inhale.
    static let leadIn: Double = 3

    var rhythm: String {
        switch self {
        case .coherence: "5,5 – 5,5"
        case .sigh: "2 + 1 – 6"
        case .longExhale: "4 – 6"
        case .box: "4 – 4 – 4 – 4"
        case .triangle: "4 – 4 – 4"
        case .fourSevenEight: "4 – 7 – 8"
        case .sleepDescent: "4 – 4 → 4 – 8"
        case .lowPause: "4 – 6 – 2"
        case .alternate: "4 – 4"
        case .staircase: "1,5 × 3 – 6"
        case .energizing: "4 – 2"
        case .cooling: "4 – 6"
        case .counting: "libre"
        }
    }

    /// Durations offered before starting, in minutes. The first is the default.
    var durationOptions: [Int] {
        switch self {
        case .coherence: [5, 3, 10]
        case .sigh: [1, 2, 3]
        case .longExhale: [3, 5, 10]
        case .box, .triangle: [4, 2, 8]
        case .fourSevenEight: []
        case .sleepDescent: [10, 15, 20]
        case .lowPause, .alternate, .counting: [5, 3, 10]
        case .staircase, .cooling: [3, 5]
        case .energizing: [2, 3]
        }
    }

    /// 4-7-8 is limited to four cycles; the others run for a chosen duration.
    var fixedCycles: Int? { self == .fourSevenEight ? 4 : nil }

    /// Phases of one cycle. `progress` (0…1, through the exercise) only matters
    /// for `sleepDescent`, whose exhale lengthens from 4 to 8 seconds.
    func phases(progress: Double = 0) -> [QuietoBreathPhase] {
        switch self {
        case .coherence: [.init(kind: .inhale, seconds: 5.5, level: 1), .init(kind: .exhale, seconds: 5.5, level: 0)]
        case .sigh: [.init(kind: .inhale, seconds: 2, level: 0.75), .init(kind: .inhale, seconds: 1, level: 1), .init(kind: .exhale, seconds: 6, level: 0), .init(kind: .hold, seconds: 1, level: 0)]
        case .longExhale, .cooling: [.init(kind: .inhale, seconds: 4, level: 1), .init(kind: .exhale, seconds: 6, level: 0)]
        case .box: [.init(kind: .inhale, seconds: 4, level: 1), .init(kind: .hold, seconds: 4, level: 1), .init(kind: .exhale, seconds: 4, level: 0), .init(kind: .hold, seconds: 4, level: 0)]
        case .triangle: [.init(kind: .inhale, seconds: 4, level: 1), .init(kind: .hold, seconds: 4, level: 1), .init(kind: .exhale, seconds: 4, level: 0)]
        case .fourSevenEight: [.init(kind: .inhale, seconds: 4, level: 1), .init(kind: .hold, seconds: 7, level: 1), .init(kind: .exhale, seconds: 8, level: 0)]
        case .sleepDescent:
            [.init(kind: .inhale, seconds: 4, level: 1), .init(kind: .exhale, seconds: 4 + 4 * min(1, max(0, progress) / 0.7), level: 0)]
        case .lowPause: [.init(kind: .inhale, seconds: 4, level: 1), .init(kind: .exhale, seconds: 6, level: 0), .init(kind: .hold, seconds: 2, level: 0)]
        case .alternate: [
            .init(kind: .inhale, seconds: 4, level: 1, side: .left), .init(kind: .exhale, seconds: 4, level: 0, side: .right),
            .init(kind: .inhale, seconds: 4, level: 1, side: .right), .init(kind: .exhale, seconds: 4, level: 0, side: .left)
        ]
        case .staircase: [
            .init(kind: .inhale, seconds: 1.5, level: 1.0 / 3), .init(kind: .hold, seconds: 0.5, level: 1.0 / 3),
            .init(kind: .inhale, seconds: 1.5, level: 2.0 / 3), .init(kind: .hold, seconds: 0.5, level: 2.0 / 3),
            .init(kind: .inhale, seconds: 1.5, level: 1), .init(kind: .exhale, seconds: 6, level: 0)
        ]
        case .energizing: [.init(kind: .inhale, seconds: 4, level: 1), .init(kind: .exhale, seconds: 2, level: 0)]
        // No imposed rhythm: the player shows a tap counter instead of a curve.
        case .counting: []
        }
    }

    var cycleDuration: Double { phases().reduce(0) { $0 + $1.seconds } }

    /// Total length in seconds, lead-in included.
    func totalSeconds(minutes: Int) -> Double {
        if let fixedCycles { return Self.leadIn + Double(fixedCycles) * cycleDuration }
        return Self.leadIn + Double(minutes * 60)
    }

    /// Cycle start times of `sleepDescent`, whose cycles lengthen: computed once
    /// per duration because the curve samples this many times per frame.
    private static var descentCache: [Double: [Double]] = [:]
    private static func descentCycleStarts(span: Double) -> [Double] {
        if let cached = descentCache[span] { return cached }
        var starts = [0.0], cursor = 0.0
        while cursor <= span + 20 {
            cursor += QuietoBreathingPattern.sleepDescent.phases(progress: cursor / span).reduce(0) { $0 + $1.seconds }
            starts.append(cursor)
        }
        descentCache[span] = starts
        return starts
    }

    struct Moment {
        let phase: QuietoBreathPhase?   // nil during the lead-in, the free breathing of `counting`, or after the last cycle
        let phaseIndex: Int
        let remaining: Double           // seconds left in the phase (or lead-in)
        let cycle: Int                  // 1-based, 0 during the lead-in
        let level: Double
    }

    /// Where the exercise is at `elapsed` seconds (lead-in included).
    func moment(at elapsed: Double, total: Double) -> Moment {
        let t = elapsed - Self.leadIn
        guard t >= 0 else { return Moment(phase: nil, phaseIndex: -1, remaining: -t, cycle: 0, level: 0) }
        guard self != .counting else { return Moment(phase: nil, phaseIndex: 0, remaining: 0, cycle: 0, level: 0) }
        let span = max(1, total - Self.leadIn)
        // Find the cycle containing t: direct for a constant rhythm, stepped for sleepDescent.
        var cursor = 0.0, cycle = 0
        if self == .sleepDescent {
            let starts = Self.descentCycleStarts(span: span)
            cycle = max(0, (starts.lastIndex { $0 <= t }) ?? 0)
            cursor = starts[cycle]
        } else {
            cycle = Int(t / cycleDuration)
            cursor = Double(cycle) * cycleDuration
        }
        if let fixedCycles, cycle >= fixedCycles { return Moment(phase: nil, phaseIndex: -1, remaining: 0, cycle: cycle, level: 0) }
        let phases = phases(progress: cursor / span)
        var level = phases.last?.level ?? 0
        var start = cursor
        for (index, phase) in phases.enumerated() {
            if t < start + phase.seconds {
                let local = (t - start) / phase.seconds
                let eased = 0.5 - cos(local * .pi) / 2
                return Moment(phase: phase, phaseIndex: index, remaining: start + phase.seconds - t, cycle: cycle + 1, level: level + (phase.level - level) * eased)
            }
            level = phase.level
            start += phase.seconds
        }
        return Moment(phase: phases.last, phaseIndex: phases.count - 1, remaining: 0, cycle: cycle + 1, level: level)
    }
}

private enum QuietoTranscript {
    static func make(title: String, intention: String, practice: QuietoPracticeType) -> String {
        let middle: String
        switch practice {
        case .breathing:
            middle = "Porte maintenant ton attention sur l’air qui entre et qui sort. Laisse l’inspiration venir sans la tirer. Puis accompagne une expiration un peu plus longue. Recommence tranquillement. Si compter t’aide, inspire sur quatre temps et expire sur six. Si ce rythme n’est pas confortable, reviens simplement à ton souffle naturel."
        case .relaxation:
            middle = "Observe les points de contact avec le support. Desserre le front, la mâchoire et les épaules. À chaque expiration, laisse un peu de poids descendre vers le sol. Parcours ensuite le corps sans chercher à tout modifier : le visage, la nuque, les bras, le ventre, le bassin et les jambes."
        case .visualization:
            middle = "Imagine un endroit simple où rien ne te demande d’agir. Remarque une couleur, une température, un son lointain. Tu n’as pas besoin de voir une image parfaite. Laisse seulement cette impression d’espace accompagner quelques respirations lentes."
        case .anchoring:
            middle = "Repère trois choses que tu peux voir, deux sensations physiques et un son. Sens les pieds ou le dos soutenus. Nomme mentalement ce qui est présent, avec des mots simples, puis reviens au mouvement régulier du souffle."
        case .selfCompassion:
            middle = "Reconnais ce qui est là sans le minimiser. Tu peux poser une main là où le geste est confortable et te rappeler que tu n’as pas à résoudre tout maintenant. Adresse-toi les mêmes mots calmes que tu offrirais à une personne qui compte pour toi."
        case .meditation:
            middle = "Laisse les sons, les sensations et les pensées apparaître. Quand l’attention part, remarque-le sans jugement, puis reviens à un point d’appui : le souffle, le contact des pieds ou un son stable. Chaque retour fait partie de la pratique."
        }
        guard !QuietoLocalization.isFrench else {
            return QuietoGender.current.resolve("Bienvenue dans \(title). \(intention) Prends un instant pour ajuster ta posture. Rien à réussir ici. \(middle) Reste encore quelques instants avec ce rythme. Puis élargis l’attention à la pièce autour de toi. Bouge doucement les mains et les pieds. Quand tu es prêt ou prête, termine cette pause en gardant seulement ce qui t’a été utile.")
        }
        let intro = String(format: "Bienvenue dans %@. %@ Prends un instant pour ajuster ta posture. Rien à réussir ici.".quietoLocalized, title, intention)
        let translatedMiddle = middle.quietoLocalized
        let outro = "Reste encore quelques instants avec ce rythme. Puis élargis l’attention à la pièce autour de toi. Bouge doucement les mains et les pieds. Termine cette pause en gardant seulement ce qui t’a été utile.".quietoLocalized
        return "\(intro) \(translatedMiddle) \(outro)"
    }
}

struct QuietoAmbience: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let assetName: String
    let audioResource: String

    init(id: String, title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        assetName = "ambience-\(id).png"
        audioResource = "ambience-\(id)"
    }

    /// Real recordings (Scripts/ambiences/ambiences.json) and generated noises,
    /// all built by `Scripts/ambiences/build_ambiences.py`. A sound whose file is
    /// not bundled yet is simply not offered.
    static let catalog: [QuietoAmbience] = [
        .init(id: "rain", title: "Pluie sur la fenêtre", subtitle: "Pluie régulière, sans tonnerre"),
        .init(id: "rain-tent", title: "Pluie sur la tente", subtitle: "Gouttes proches, sensation d’abri"),
        .init(id: "distant-storm", title: "Orage lointain", subtitle: "Pluie et tonnerre rare"),
        .init(id: "ocean", title: "Océan", subtitle: "Vagues lentes"),
        .init(id: "river", title: "Rivière", subtitle: "Courant et clapotis"),
        .init(id: "forest", title: "Forêt au matin", subtitle: "Oiseaux et air calme"),
        .init(id: "night", title: "Nuit d’été", subtitle: "Grillons au loin"),
        .init(id: "wind", title: "Vent dans les arbres", subtitle: "Rafales lentes dans les feuilles"),
        .init(id: "campfire", title: "Feu de cheminée", subtitle: "Crépitements doux"),
        .init(id: "cafe", title: "Café", subtitle: "Murmures et tasses, pour travailler"),
        .init(id: "night-train", title: "Train de nuit", subtitle: "Roulement régulier"),
        .init(id: "fan", title: "Ventilateur", subtitle: "Souffle mécanique stable"),
        .init(id: "white-noise", title: "Bruit blanc", subtitle: "Masque les bruits alentour"),
        .init(id: "pink-noise", title: "Bruit rose", subtitle: "Plus doux que le blanc"),
        .init(id: "brown-noise", title: "Bruit brun", subtitle: "Grave et enveloppant"),
        .init(id: "singing-bowls", title: "Bols chantants", subtitle: "Résonances longues")
    ]

    static let all: [QuietoAmbience] = catalog.filter { $0.audioURL != nil }

    /// The loop built by the ambience script (M4A), or the former 30-second MP3 until it is replaced.
    var audioURL: URL? {
        Bundle.main.url(forResource: audioResource, withExtension: "m4a")
            ?? Bundle.main.url(forResource: audioResource, withExtension: "mp3")
    }
}

enum QuietoNeed: String, CaseIterable, Identifiable {
    case sleep = "J’ai du mal à dormir"
    case fatigue = "Je suis fatigué·e"
    case eventStress = "Un événement me stresse"
    case racingThoughts = "Mes pensées tournent"
    case overwhelmed = "Je me sens submergé·e"
    case focus = "J’ai besoin de me concentrer"
    case conflict = "Je sors d’un conflit"
    case quickReset = "J’ai seulement deux minutes"

    var id: String { String(describing: self) }
    var imageName: String { "need-\(id).png" }
    var explanation: String {
        switch self {
        case .sleep: "Des pratiques lentes pour préparer le corps au repos."
        case .fatigue: "Une pause qui repose sans te demander plus d’effort."
        case .eventStress: "Des outils courts avant un rendez-vous, un trajet ou une prise de parole."
        case .racingThoughts: "Revenir aux sensations pour créer un peu d’espace."
        case .overwhelmed: "Diminuer les sollicitations et retrouver un point d’appui."
        case .focus: "Clarifier l’attention avant de reprendre une seule chose."
        case .conflict: "Laisser retomber l’intensité avant de décider quoi faire."
        case .quickReset: "Respirer, s’ancrer ou écouter un son sans bouleverser la journée."
        }
    }
    var sessionIDs: [String] {
        switch self {
        case .sleep: ["express_4", "new_body_scan_sleep", "sleep_cognitive_shuffle"]
        case .fatigue: ["new_nidra_pause", "new_soft_reset", "afternoon_fog"]
        case .eventStress: ["express_8", "express_1", "breath_sigh"]
        case .racingThoughts: ["new_thoughts_on_clouds", "decouverte_2", "sleep_3"]
        case .overwhelmed: ["new_sensory_shelter", "emotion_3", "breathing_1"]
        case .focus: ["new_focus_reset", "meditation_06", "new_box_breathing"]
        case .conflict: ["express_6", "new_after_conflict", "breath_cooling"]
        case .quickReset: ["express_5", "express_2", "breath_sigh"]
        }
    }
    var ambienceIDs: [String] {
        switch self {
        case .sleep: ["rain", "pink-noise", "fan"]
        case .fatigue: ["forest", "river"]
        case .eventStress: ["white-noise", "river"]
        case .racingThoughts: ["rain", "ocean"]
        case .overwhelmed: ["pink-noise", "forest"]
        case .focus: ["brown-noise", "cafe", "river"]
        case .conflict: ["campfire", "ocean"]
        case .quickReset: ["forest", "rain"]
        }
    }
}

enum QuietoPillar: String, CaseIterable, Identifiable {
    case sleep = "Sommeil"
    case stress = "Stress"
    case thoughts = "Pensées"
    case emotions = "Émotions"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .sleep: "moon"
        case .stress: "leaf"
        case .thoughts: "cloud"
        case .emotions: "heart"
        }
    }
    var subtitle: String {
        switch self {
        case .sleep: "Décrocher le soir"
        case .stress: "Relâcher la pression"
        case .thoughts: "Prendre du recul"
        case .emotions: "Accueillir son ressenti"
        }
    }
}

enum QuietoPracticeType: String, CaseIterable, Identifiable {
    case meditation = "Méditation"
    case breathing = "Respiration"
    case relaxation = "Relaxation"
    case visualization = "Visualisation"
    case anchoring = "Ancrage"
    case selfCompassion = "Bienveillance"

    var id: String { rawValue }

    /// Translated name for the middle of a sentence: lowercased, except in
    /// German where nouns keep their capital.
    var nameInSentence: String {
        let name = rawValue.quietoLocalized
        return QuietoLocalization.language == .de ? name : name.lowercased(with: QuietoLocalization.locale)
    }
}

enum QuietoDurationFilter: String, CaseIterable, Identifiable {
    case all = "Toutes"
    case underFive = "1–5 min"
    case fiveToTen = "5–10 min"
    case overTen = "10+ min"

    var id: String { rawValue }
    func includes(_ minutes: Int) -> Bool {
        switch self {
        case .all: true
        case .underFive: minutes <= 5
        case .fiveToTen: (5...10).contains(minutes)
        case .overTen: minutes > 10
        }
    }
}

struct QuietoProgram {
    let title: String
    let completedDays: Set<Int>
    let totalDays: Int
    let currentSession: QuietoSession?
    let isFinished: Bool
    /// Today's step is done: the next one opens on this date.
    var opensOn: Date? = nil
}

struct QuietoProgress {
    let completedSessionIDs: Set<String>
    let lastListened: QuietoSession?
    var lastListenedAt: Date? = nil
}

enum CheckInFeeling: String, CaseIterable, Identifiable {
    case good = "Bien"
    case pressure = "Sous pression"
    case tired = "Fatigué"
    case unsure = "Je ne sais pas"

    var id: String { rawValue }
}

enum CheckInNeed: String, CaseIterable, Identifiable {
    case calm = "M’apaiser"
    case sleep = "Mieux dormir"
    case focus = "Retrouver mon attention"
    case release = "Relâcher la pression"

    var id: String { rawValue }
}

struct QuietoHomeSnapshot {
    var firstName: String?
    var nextSession: QuietoSession?
    var program: QuietoProgram?
    var progress: QuietoProgress
    /// Position of `nextSession` in the programme (1-based), nil outside a programme.
    var nextStep: Int? = nil
    var isLoading = false
    var isOffline = false
    var errorMessage: String?

    static let preview = QuietoHomeSnapshot(
        firstName: "Léa",
        nextSession: QuietoSession(
            id: "new_thoughts_on_clouds",
            title: "Les pensées comme des nuages",
            durationMinutes: 8,
            subtitle: "Visualisation",
            imageName: "session-new_thoughts_on_clouds.png",
            isPremium: false,
            pillar: .thoughts,
            practiceType: .visualization,
            intention: "Observer le passage des pensées sans devoir les suivre ni les repousser."
        ),
        program: QuietoProgram(
            title: "Laisser la journée derrière soi",
            completedDays: [1, 2],
            totalDays: 7,
            currentSession: nil,
            isFinished: false
        ),
        progress: QuietoProgress(
            completedSessionIDs: ["sleep_1"],
            lastListened: QuietoSession(
                id: "sleep_1",
                title: "Relâcher le corps",
                durationMinutes: 6,
                subtitle: "Écoutée hier",
                imageName: "session-sleep_1.png",
                isPremium: false,
                pillar: .sleep,
                practiceType: .relaxation,
                intention: "Prépare ton corps et ton esprit au repos."
            )
        )
    )
}
