import Foundation

enum QuietoLibrary: String, Identifiable { case favorites = "Favoris", downloads = "Téléchargements", recent = "Écoutées récemment"; var id: String { rawValue } }

@MainActor
final class SessionsViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedCategory: QuietoCategory?
    @Published var selectedGoal: QuietoGoal?
    @Published var selectedSituation: QuietoSituation?
    @Published var durationFilter: QuietoDurationFilter = .all
    @Published var practiceFilter: QuietoPracticeType?
    @Published private(set) var favorites: Set<String>
    @Published private(set) var recentIDs: [String]
    @Published var selectedSession: QuietoSession?
    @Published var selectedLibrary: QuietoLibrary?
    @Published var feedback: String?
    /// Length chosen for each breathing exercise before starting it.
    @Published var breathingMinutes: [String: Int] = [:]

    let catalog: SessionCatalog
    let downloads: QuietoDownloadManaging
    /// Playback state shown by the session detail and player views.
    let audioPlayer: QuietoAudioPlayer
    private let preferences: QuietoPreferences
    private let progress: SessionProgressSyncing?

    init(catalog: SessionCatalog, audioPlayer: QuietoAudioPlayer, downloads: QuietoDownloadManaging, preferences: QuietoPreferences, progress: SessionProgressSyncing?) {
        self.catalog = catalog
        self.audioPlayer = audioPlayer
        self.downloads = downloads
        self.preferences = preferences
        self.progress = progress
        favorites = preferences.favoriteSessionIDs
        recentIDs = preferences.recentSessionIDs
    }

    var filteredSessions: [QuietoSession] { sessions(duration: durationFilter, practice: practiceFilter) }

    /// Results the list would show with another duration, everything else unchanged.
    /// The filter menus use it to grey out choices that would lead to an empty list.
    func resultCount(duration: QuietoDurationFilter) -> Int { sessions(duration: duration, practice: practiceFilter).count }

    /// Results the list would show with another practice type (nil = all types).
    func resultCount(practice: QuietoPracticeType?) -> Int { sessions(duration: durationFilter, practice: practice).count }

    private func sessions(duration: QuietoDurationFilter, practice: QuietoPracticeType?) -> [QuietoSession] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: .diacriticInsensitive, locale: QuietoLocalization.locale).lowercased()
        return catalog.sessions.filter { session in
            // Breathing exercises live in their own section; a search or a
            // situation still finds them (« 4-7-8 », « respiration »…).
            if session.readerMode == .breathing, needle.isEmpty, selectedSituation == nil { return false }
            let source = [session.title, session.title.quietoLocalized, session.subtitle, session.intention, session.practiceType.rawValue,
                          session.category.rawValue, session.category.rawValue.quietoLocalized, session.goal.rawValue, session.goal.rawValue.quietoLocalized]
                + session.themes.flatMap { [$0.rawValue, $0.rawValue.quietoLocalized] }
                + session.situations.flatMap { [$0.rawValue, $0.rawValue.quietoLocalized, $0.subtitle, $0.subtitle.quietoLocalized] }
                + session.keywords
            let searchableText = source
                .joined(separator: " ").folding(options: .diacriticInsensitive, locale: QuietoLocalization.locale).lowercased()
            let matchesQuery = needle.isEmpty || searchableText.contains(needle)
            let matchesCategory = selectedCategory.map { session.category == $0 } ?? true
            let matchesGoal = selectedGoal.map { session.goal == $0 } ?? true
            let matchesSituation = selectedSituation.map { session.situations.contains($0) } ?? true
            return matchesQuery && matchesCategory && matchesGoal && matchesSituation
                && duration.includes(session.durationMinutes)
                && (practice == nil || session.practiceType == practice)
        }
    }

    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedGoal != nil || selectedSituation != nil || durationFilter != .all || practiceFilter != nil
    }

    func selectSituation(_ situation: QuietoSituation) {
        selectedSituation = selectedSituation == situation ? nil : situation
        if selectedSituation != nil { selectedCategory = nil; selectedGoal = nil }
    }

    func selectCategory(_ category: QuietoCategory) {
        selectedCategory = selectedCategory == category ? nil : category
        if selectedCategory != nil { selectedSituation = nil }
    }

    func selectGoal(_ goal: QuietoGoal) {
        selectedGoal = selectedGoal == goal ? nil : goal
        if selectedGoal != nil { selectedSituation = nil }
    }

    func resetFilters() {
        selectedCategory = nil
        selectedGoal = nil
        selectedSituation = nil
        durationFilter = .all
        practiceFilter = nil
    }

    // MARK: For you now

    /// Sessions that fit the hour in the person's time zone (see `DayMoment`).
    func recommendation(at date: Date = .now) -> (moment: DayMoment, sessions: [QuietoSession]) {
        let moment = DayMoment(date: date)
        return (moment, SessionRecommender.recommend(from: meditations, moment: moment, recentlyPlayed: recentIDs))
    }

    /// A short session that answers the goal right away: a guided one of about
    /// five minutes, so a tap on « Démarrage rapide » starts something concrete.
    func quickStartSession(for goal: QuietoGoal) -> QuietoSession? {
        let candidates = meditations.filter { $0.goal == goal }
        let guided = candidates.filter { $0.readerMode == .guidedVoice }
        return (guided.isEmpty ? candidates : guided).min { abs($0.durationMinutes - 5) < abs($1.durationMinutes - 5) }
    }

    func quickStart(_ goal: QuietoGoal) {
        guard let session = quickStartSession(for: goal) else { return }
        play(session)
        audioPlayer.presentFullPlayer()
    }

    /// Changes whenever the list of results changes, so the view can fold it back to its first rows.
    var filterKey: String {
        [query, selectedCategory?.rawValue, selectedGoal?.rawValue, selectedSituation?.rawValue, durationFilter.rawValue, practiceFilter?.rawValue]
            .map { $0 ?? "" }.joined(separator: "|")
    }

    /// Everything but the breathing exercises.
    var meditations: [QuietoSession] { catalog.sessions.filter { $0.readerMode != .breathing } }

    /// Breathing exercises grouped by what they help with, calmest first.
    var breathingGroups: [(goal: QuietoGoal, sessions: [QuietoSession])] {
        let exercises = catalog.sessions.filter { $0.readerMode == .breathing }
        let order: [QuietoGoal] = [.calm, .relax, .emotion, .sleep, .focus, .energy, .perspective, .kindness]
        return order.compactMap { goal in
            let sessions = exercises.filter { $0.goal == goal }
            return sessions.isEmpty ? nil : (goal, sessions)
        }
    }

    func sessions(in category: QuietoCategory) -> [QuietoSession] { catalog.sessions.filter { $0.category == category } }
    func sessions(for situation: QuietoSituation) -> [QuietoSession] { catalog.sessions.filter { $0.situations.contains(situation) } }
    var libraryCounts: [QuietoLibrary: Int] { [.favorites: favorites.count, .downloads: catalog.sessions.filter { downloads.isDownloaded($0) }.count, .recent: recentIDs.count] }
    var librarySessions: [QuietoSession] { selectedLibrary.map(sessions(in:)) ?? [] }

    func sessions(in library: QuietoLibrary) -> [QuietoSession] {
        switch library {
        case .favorites: return catalog.sessions.filter { favorites.contains($0.id) }
        case .downloads: return catalog.sessions.filter { downloads.isDownloaded($0) }
        case .recent: return recentIDs.compactMap { id in catalog.sessions.first { $0.id == id } }
        }
    }

    func toggleFavorite(_ session: QuietoSession) {
        let isFavorite: Bool
        if favorites.contains(session.id) { favorites.remove(session.id); isFavorite = false }
        else { favorites.insert(session.id); isFavorite = true }
        preferences.favoriteSessionIDs = favorites
        Task { [progress] in try? await progress?.setFavorite(sessionID: session.id, favorite: isFavorite) }
    }
    // Hard paywall: the whole app sits behind the gate in RootView, so every
    // session plays directly here.
    func play(_ session: QuietoSession) {
        audioPlayer.play(session, localURL: downloads.localURL(for: session), breathingMinutes: breathingMinutes[session.id])
        recentIDs.removeAll { $0 == session.id }
        recentIDs.insert(session.id, at: 0)
        recentIDs = Array(recentIDs.prefix(10))
        preferences.recentSessionIDs = recentIDs
    }
    func toggleDownload(_ session: QuietoSession) {
        guard session.isDownloadAvailable else {
            feedback = "Le fichier audio hors ligne n’est pas encore publié pour cette séance."
            return
        }
        if downloads.isDownloaded(session) { downloads.delete(session); feedback = "Séance supprimée des téléchargements."; return }
        guard downloads.start(session) else { feedback = "Téléchargement indisponible pour cette séance."; return }
        feedback = "Téléchargement commencé."
    }
}
