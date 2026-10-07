import Foundation

enum BadgeCategory: String, CaseIterable, Identifiable {
    case firstSteps
    case regularity
    case meditation
    case breathing
    case sounds
    case time
    case program
    case moments
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSteps: "Premiers pas"
        case .regularity: "Régularité"
        case .meditation: "Méditation"
        case .breathing: "Respiration"
        case .sounds: "Sons"
        case .time: "Temps pour soi"
        case .program: "Programme"
        case .moments: "Moments"
        case .hidden: "Surprises"
        }
    }
}

enum BadgeRequirement: Equatable {
    case practices(PracticeKind, Int)
    case allPracticeKinds
    case streak(Int)
    case fullWeeks(Int)
    case totalMinutes(Int)
    case programStarted
    case programHalf
    case programFinished
    case earlySessions(Int)
    case lateSessions(Int)
    case shortSessions(Int)
    case sleepSessions(Int)
    case allSituations
    case distinctAmbiences(Int)
    case comeback

    /// Where the person stands, capped at the target.
    func progress(in stats: PracticeStats) -> (current: Int, target: Int) {
        let value: (Int, Int)
        switch self {
        case .practices(let kind, let target): value = (stats.count(kind), target)
        case .allPracticeKinds:
            value = ([PracticeKind.meditation, .breathing, .sound].filter { stats.count($0) > 0 }.count, 3)
        // The best streak, so a badge never looks lost after a break.
        case .streak(let days): value = (stats.streak.best, days)
        case .fullWeeks(let target): value = (stats.fullWeeks, target)
        case .totalMinutes(let minutes): value = (stats.totalMinutes, minutes)
        case .programStarted: value = (stats.programCompleted, 1)
        case .programHalf: value = (stats.programCompleted, max(1, Int((Double(stats.programTotal) / 2).rounded(.up))))
        case .programFinished: value = (stats.programCompleted, max(1, stats.programTotal))
        case .earlySessions(let target): value = (stats.earlySessions, target)
        case .lateSessions(let target): value = (stats.lateSessions, target)
        case .shortSessions(let target): value = (stats.shortSessions, target)
        case .sleepSessions(let target): value = (stats.sleepSessions, target)
        case .allSituations: value = (stats.situationsCovered.count, QuietoSituation.allCases.count)
        case .distinctAmbiences(let target): value = (stats.distinctAmbiences.count, target)
        case .comeback: value = (stats.comebacks, 1)
        }
        return (min(value.0, value.1), value.1)
    }

    func isMet(by stats: PracticeStats) -> Bool {
        let progress = progress(in: stats)
        return progress.current >= progress.target
    }
}

struct Badge: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let category: BadgeCategory
    let requirement: BadgeRequirement
    /// Shown as a mystery until unlocked.
    var isHidden: Bool { category == .hidden }
    var artworkName: String { "badge-\(id).png" }
}

extension Badge {
    /// The whole collection, in display order. Ids are stored on devices and in
    /// analytics: never rename one. The first steps are meant to be reachable
    /// during the free trial.
    static let all: [Badge] = [
        // Premiers pas
        .init(id: "first_meditation", title: "Première pause", detail: "Termine ta première méditation guidée.", symbol: "leaf", category: .firstSteps, requirement: .practices(.meditation, 1)),
        .init(id: "first_breathing", title: "Premier souffle", detail: "Termine ton premier exercice de respiration.", symbol: "wind", category: .firstSteps, requirement: .practices(.breathing, 1)),
        .init(id: "first_sound", title: "Premier refuge", detail: "Écoute un son d’ambiance pendant au moins une minute.", symbol: "waveform", category: .firstSteps, requirement: .practices(.sound, 1)),
        .init(id: "first_check_in", title: "À l’écoute", detail: "Dis à Quieto ce que tu traverses en ce moment.", symbol: "heart.text.square", category: .firstSteps, requirement: .practices(.checkIn, 1)),
        .init(id: "explorer", title: "Explorer", detail: "Essaie une méditation, une respiration et un son.", symbol: "safari", category: .firstSteps, requirement: .allPracticeKinds),

        // Régularité
        .init(id: "streak_3", title: "Un début de rythme", detail: "Pratique 3 jours de suite.", symbol: "sunrise", category: .regularity, requirement: .streak(3)),
        .init(id: "streak_7", title: "Une semaine de calme", detail: "Pratique 7 jours de suite.", symbol: "sun.max", category: .regularity, requirement: .streak(7)),
        .init(id: "full_week", title: "Semaine complète", detail: "Pratique chaque jour d’une même semaine.", symbol: "calendar.badge.checkmark", category: .regularity, requirement: .fullWeeks(1)),
        .init(id: "streak_14", title: "Deux semaines", detail: "Pratique 14 jours de suite.", symbol: "sun.haze", category: .regularity, requirement: .streak(14)),
        .init(id: "streak_30", title: "Un mois de pauses", detail: "Pratique 30 jours de suite.", symbol: "moon.stars", category: .regularity, requirement: .streak(30)),
        .init(id: "streak_60", title: "Deux mois", detail: "Pratique 60 jours de suite.", symbol: "mountain.2", category: .regularity, requirement: .streak(60)),
        .init(id: "streak_100", title: "Cent jours", detail: "Pratique 100 jours de suite.", symbol: "tree", category: .regularity, requirement: .streak(100)),
        .init(id: "streak_365", title: "Une année", detail: "Pratique 365 jours de suite.", symbol: "infinity", category: .regularity, requirement: .streak(365)),

        // Méditation
        .init(id: "meditation_5", title: "Esprit curieux", detail: "Termine 5 méditations guidées.", symbol: "leaf.fill", category: .meditation, requirement: .practices(.meditation, 5)),
        .init(id: "meditation_25", title: "Esprit posé", detail: "Termine 25 méditations guidées.", symbol: "drop", category: .meditation, requirement: .practices(.meditation, 25)),
        .init(id: "meditation_50", title: "Esprit clair", detail: "Termine 50 méditations guidées.", symbol: "drop.fill", category: .meditation, requirement: .practices(.meditation, 50)),
        .init(id: "meditation_100", title: "Esprit vaste", detail: "Termine 100 méditations guidées.", symbol: "cloud.sun", category: .meditation, requirement: .practices(.meditation, 100)),

        // Respiration
        .init(id: "breathing_5", title: "Souffle régulier", detail: "Termine 5 exercices de respiration.", symbol: "lungs", category: .breathing, requirement: .practices(.breathing, 5)),
        .init(id: "breathing_25", title: "Souffle profond", detail: "Termine 25 exercices de respiration.", symbol: "lungs.fill", category: .breathing, requirement: .practices(.breathing, 25)),
        .init(id: "breathing_100", title: "Souffle apprivoisé", detail: "Termine 100 exercices de respiration.", symbol: "tornado", category: .breathing, requirement: .practices(.breathing, 100)),

        // Sons
        .init(id: "sound_5", title: "Oreille attentive", detail: "Écoute 5 fois un son d’ambiance.", symbol: "ear", category: .sounds, requirement: .practices(.sound, 5)),
        .init(id: "sound_25", title: "Paysage sonore", detail: "Écoute 25 fois un son d’ambiance.", symbol: "headphones", category: .sounds, requirement: .practices(.sound, 25)),
        .init(id: "sound_100", title: "Refuge sonore", detail: "Écoute 100 fois un son d’ambiance.", symbol: "speaker.wave.3", category: .sounds, requirement: .practices(.sound, 100)),
        .init(id: "sound_palette", title: "Palette sonore", detail: "Écoute chacun des sons d’ambiance.", symbol: "paintpalette", category: .sounds, requirement: .distinctAmbiences(QuietoAmbience.all.count)),

        // Temps pour soi
        .init(id: "minutes_60", title: "Une heure pour soi", detail: "Cumule 1 heure de pratique.", symbol: "clock", category: .time, requirement: .totalMinutes(60)),
        .init(id: "minutes_300", title: "Cinq heures", detail: "Cumule 5 heures de pratique.", symbol: "clock.fill", category: .time, requirement: .totalMinutes(300)),
        .init(id: "minutes_600", title: "Dix heures", detail: "Cumule 10 heures de pratique.", symbol: "hourglass", category: .time, requirement: .totalMinutes(600)),
        .init(id: "minutes_1440", title: "Une journée entière", detail: "Cumule 24 heures de pratique.", symbol: "hourglass.bottomhalf.filled", category: .time, requirement: .totalMinutes(1_440)),
        .init(id: "minutes_3000", title: "Cinquante heures", detail: "Cumule 50 heures de pratique.", symbol: "sparkles", category: .time, requirement: .totalMinutes(3_000)),

        // Programme
        .init(id: "program_started", title: "En chemin", detail: "Termine une première étape de ton programme.", symbol: "map", category: .program, requirement: .programStarted),
        .init(id: "program_half", title: "Mi-parcours", detail: "Termine la moitié de ton programme.", symbol: "signpost.right", category: .program, requirement: .programHalf),
        .init(id: "program_finished", title: "Programme terminé", detail: "Termine toutes les étapes de ton programme.", symbol: "flag.checkered", category: .program, requirement: .programFinished),

        // Moments
        .init(id: "early_bird", title: "Lève-tôt", detail: "Pratique avant 8 h.", symbol: "sunrise.fill", category: .moments, requirement: .earlySessions(1)),
        .init(id: "peaceful_nights", title: "Nuits paisibles", detail: "Termine 5 séances pour le sommeil.", symbol: "moon.zzz", category: .moments, requirement: .sleepSessions(5)),
        .init(id: "quick_pauses", title: "Pauses express", detail: "Termine 10 séances de 5 minutes ou moins.", symbol: "bolt", category: .moments, requirement: .shortSessions(10)),
        .init(id: "all_situations", title: "Toutes les situations", detail: "Pratique au moins une séance pour chaque situation.", symbol: "square.grid.3x3", category: .moments, requirement: .allSituations),

        // Surprises
        .init(id: "comeback", title: "De retour", detail: "Reviens pratiquer après une semaine d’absence. Revenir fait partie du chemin.", symbol: "arrow.uturn.backward.circle", category: .hidden, requirement: .comeback),
        .init(id: "night_owl", title: "Veilleur", detail: "Pratique après 22 h.", symbol: "moon", category: .hidden, requirement: .lateSessions(1))
    ]
}
