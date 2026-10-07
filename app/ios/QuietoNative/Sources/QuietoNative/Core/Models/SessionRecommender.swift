import Foundation

/// The part of the day, read in the person's own time zone. It decides what
/// « Pour toi maintenant » suggests: energy in the morning, a way to fall
/// asleep late in the evening, a way back to rest in the middle of the night.
enum DayMoment: Equatable {
    case morning, midday, afternoon, evening, bedtime, night

    init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 12) * 60 + (components.minute ?? 0)
        switch minutes {
        case 5 * 60..<10 * 60: self = .morning
        case 10 * 60..<14 * 60: self = .midday
        case 14 * 60..<18 * 60: self = .afternoon
        case 18 * 60..<(21 * 60 + 30): self = .evening
        case (21 * 60 + 30)..., 0..<60: self = .bedtime
        default: self = .night
        }
    }

    /// One line under « Pour toi maintenant ».
    var reason: String {
        switch self {
        case .morning: "Pour bien commencer la journée."
        case .midday: "Une pause pour souffler au milieu de la journée."
        case .afternoon: "Pour retrouver de l’élan cet après-midi."
        case .evening: "Pour laisser la journée derrière toi."
        case .bedtime: "Il se fait tard : de quoi t’aider à t’endormir."
        case .night: "Tu es réveillé·e : de quoi revenir doucement au repos."
        }
    }

    fileprivate var preference: (situations: Set<QuietoSituation>, goals: Set<QuietoGoal>, categories: Set<QuietoCategory>, maxMinutes: Int) {
        switch self {
        case .morning: ([.exhaustedMorning, .lowEnergy], [.energy, .focus, .kindness], [.morning], 10)
        case .midday: ([.overwhelmed, .quickPause, .importantEvent], [.focus, .calm], [.work], 10)
        case .afternoon: ([.lowEnergy, .racingThoughts, .quickPause], [.energy, .perspective, .calm], [.work, .screens], 10)
        case .evening: ([.afterWork, .racingThoughts, .difficultConversation], [.relax, .perspective], [.daily, .body, .relationships], 15)
        case .bedtime: ([.tiredButAwake, .racingThoughts], [.sleep], [.night], 30)
        case .night: ([.awakeAtNight, .tiredButAwake], [.sleep], [.night], 30)
        }
    }
}

/// Picks a few sessions that fit the moment. Pure and deterministic, so the
/// same hour always gives the same list (ties keep the catalogue order).
enum SessionRecommender {
    static func recommend(
        from sessions: [QuietoSession],
        moment: DayMoment,
        recentlyPlayed: [String] = [],
        limit: Int = 6
    ) -> [QuietoSession] {
        let preference = moment.preference
        let justPlayed = Set(recentlyPlayed.prefix(3))
        let scored = sessions.enumerated().compactMap { index, session -> (score: Int, index: Int, session: QuietoSession)? in
            guard session.durationMinutes <= preference.maxMinutes else { return nil }
            var score = 0
            if !preference.situations.isDisjoint(with: session.situations) { score += 3 }
            if preference.goals.contains(session.goal) { score += 2 }
            if preference.categories.contains(session.category) { score += 1 }
            guard score > 0 else { return nil }
            if justPlayed.contains(session.id) { score -= 2 }
            return (score, index, session)
        }
        .sorted { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }

        // Mostly guided sessions, with at most two breathing exercises.
        var picked: [QuietoSession] = []
        var breathings = 0
        for candidate in scored where picked.count < limit {
            if candidate.session.readerMode == .breathing {
                guard breathings < 2 else { continue }
                breathings += 1
            }
            picked.append(candidate.session)
        }
        return picked
    }
}
