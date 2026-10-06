import Foundation

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
    let pillar: QuietoPillar
    let practiceType: QuietoPracticeType
    let intention: String
    let keywords: [String]
    let longDescription: String
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
        pillar: QuietoPillar = .thoughts,
        practiceType: QuietoPracticeType = .meditation,
        intention: String = "Une pause simple, à ton rythme.",
        keywords: [String] = [],
        longDescription: String? = nil,
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
        self.pillar = pillar
        self.practiceType = practiceType
        self.intention = intention
        self.keywords = keywords
        self.longDescription = longDescription ?? "« \(title) » est une pause guidée de \(durationMinutes) minutes. \(intention) La pratique avance sans objectif de performance : tu peux l’adapter, bouger ou t’arrêter à tout moment."
        self.preparation = preparation
        self.steps = steps ?? [
            "Prendre contact avec le corps et le souffle.",
            "Explorer la pratique de \(practiceType.rawValue.lowercased()) à ton rythme.",
            "Revenir progressivement à ce qui t’entoure."
        ]
        self.transcript = transcript ?? QuietoTranscript.make(title: title, intention: intention, practice: practiceType)
        self.breathingPattern = breathingPattern ?? (practiceType == .breathing ? .coherence : nil)
    }

    var readerMode: QuietoReaderMode { practiceType == .breathing ? .breathing : .guidedVoice }

    var localizedIntention: String {
        let translated = intention.quietoLocalized
        if QuietoLocalization.isFrench || translated != intention { return translated }
        return String(format: "Une pratique de %@ pour créer une pause simple et accessible.".quietoLocalized, practiceType.rawValue.quietoLocalized.lowercased())
    }

    var localizedLongDescription: String {
        guard !QuietoLocalization.isFrench else { return longDescription }
        if readerMode == .breathing {
            return String(
                format: "Cet exercice de %d minutes se pratique sans narration. Le point monte avec l’inspiration, marque les pauses éventuelles et redescend avec l’expiration. Adapte ou arrête le rythme dès qu’il devient inconfortable.".quietoLocalized,
                durationMinutes
            )
        }
        return String(
            format: "Cette séance de %d minutes utilise la %@. Les consignes sont courtes et alternent avec des silences pour te laisser pratiquer à ton rythme.".quietoLocalized,
            durationMinutes,
            practiceType.rawValue.quietoLocalized.lowercased()
        )
    }

    var localizedPreparation: String {
        QuietoLocalization.isFrench ? preparation : "Installe-toi dans une position stable et confortable. Tu peux garder les yeux ouverts ou les fermer.".quietoLocalized
    }

    var localizedSteps: [String] {
        guard !QuietoLocalization.isFrench else { return steps }
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

enum QuietoReaderMode { case guidedVoice, breathing }

enum QuietoBreathingPattern: String, CaseIterable, Codable {
    case coherence = "Cohérence 5–5"
    case box = "Carré 4–4–4–4"
    case longExhale = "Expiration 4–6"
    case fourSevenEight = "4–7–8"

    var phases: [(label: String, seconds: Double)] {
        switch self {
        case .coherence: [("Inspire", 5), ("Expire", 5)]
        case .box: [("Inspire", 4), ("Garde", 4), ("Expire", 4), ("Garde", 4)]
        case .longExhale: [("Inspire", 4), ("Expire", 6)]
        case .fourSevenEight: [("Inspire", 4), ("Garde", 7), ("Expire", 8)]
        }
    }

    var cycleDuration: Double { phases.reduce(0) { $0 + $1.seconds } }
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
            return "Bienvenue dans \(title). \(intention) Prends un instant pour ajuster ta posture. Rien à réussir ici. \(middle) Reste encore quelques instants avec ce rythme. Puis élargis l’attention à la pièce autour de toi. Bouge doucement les mains et les pieds. Quand tu es prêt ou prête, termine cette pause en gardant seulement ce qui t’a été utile."
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

    static let all: [QuietoAmbience] = [
        .init(id: "campfire", title: "Feu de camp", subtitle: "Crépitements doux", assetName: "ambience-campfire.png", audioResource: "ambience-campfire"),
        .init(id: "forest", title: "Forêt", subtitle: "Feuilles et air calme", assetName: "ambience-forest.png", audioResource: "ambience-forest"),
        .init(id: "river", title: "Rivière", subtitle: "Courant régulier", assetName: "ambience-river.png", audioResource: "ambience-river"),
        .init(id: "ocean", title: "Océan", subtitle: "Vagues lentes", assetName: "ambience-ocean.png", audioResource: "ambience-ocean"),
        .init(id: "rain", title: "Pluie", subtitle: "Pluie sur la fenêtre", assetName: "ambience-rain.png", audioResource: "ambience-rain"),
        .init(id: "white-noise", title: "Bruit blanc", subtitle: "Souffle uniforme", assetName: "ambience-white-noise.png", audioResource: "ambience-white-noise"),
        .init(id: "pink-noise", title: "Bruit rose", subtitle: "Grave et enveloppant", assetName: "ambience-pink-noise.png", audioResource: "ambience-pink-noise"),
        .init(id: "night", title: "Nuit d’été", subtitle: "Insectes au loin", assetName: "ambience-night.png", audioResource: "ambience-night")
        , .init(id: "wind", title: "Vent doux", subtitle: "Air dans les arbres", assetName: "ambience-wind.png", audioResource: "ambience-wind")
        , .init(id: "distant-storm", title: "Orage lointain", subtitle: "Rumble feutré", assetName: "ambience-distant-storm.png", audioResource: "ambience-distant-storm")
    ]
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
        case .sleep: ["sleep_4", "sleep_3", "new_body_scan_sleep"]
        case .fatigue: ["new_nidra_pause", "express_3", "new_soft_reset"]
        case .eventStress: ["express_8", "express_1", "breathing_1"]
        case .racingThoughts: ["decouverte_2", "new_thoughts_on_clouds", "stress_4"]
        case .overwhelmed: ["new_sensory_shelter", "stress_3", "breathing_3"]
        case .focus: ["new_focus_reset", "decouverte_3", "breathing_2"]
        case .conflict: ["express_6", "emotion_4", "new_after_conflict"]
        case .quickReset: ["express_2", "express_5", "express_7"]
        }
    }
    var ambienceIDs: [String] {
        switch self {
        case .sleep: ["pink-noise", "rain", "ocean"]
        case .fatigue: ["forest", "river"]
        case .eventStress: ["white-noise", "river"]
        case .racingThoughts: ["rain", "ocean"]
        case .overwhelmed: ["pink-noise", "forest"]
        case .focus: ["white-noise", "river"]
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
}

struct QuietoProgress {
    let completedSessionIDs: Set<String>
    let lastListened: QuietoSession?
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
