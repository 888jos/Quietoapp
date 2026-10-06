import Foundation

enum QuietoLibrary: String, Identifiable { case favorites = "Favoris", downloads = "Téléchargements", recent = "Écoutées récemment"; var id: String { rawValue } }

@MainActor
final class SessionsViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedPillar: QuietoPillar?
    @Published var selectedTheme: QuietoTheme?
    @Published var selectedSituation: QuietoSituation?
    @Published var durationFilter: QuietoDurationFilter = .all
    @Published var practiceFilter: QuietoPracticeType?
    @Published private(set) var favorites: Set<String>
    @Published private(set) var recentIDs: [String]
    @Published var selectedSession: QuietoSession?
    @Published var selectedLibrary: QuietoLibrary?
    @Published var feedback: String?

    let catalog: SessionCatalog
    let downloads: QuietoDownloadManaging
    let audioPlayer: QuietoAudioPlayer
    private let defaults: UserDefaults

    init(catalog: SessionCatalog = SessionCatalog(), audioPlayer: QuietoAudioPlayer, downloads: QuietoDownloadManaging = QuietoDownloadStore.shared, defaults: UserDefaults = .standard) {
        self.catalog = catalog; self.audioPlayer = audioPlayer; self.downloads = downloads; self.defaults = defaults
        favorites = Set(defaults.stringArray(forKey: "quieto.native.session.favorites") ?? [])
        recentIDs = defaults.stringArray(forKey: "quieto.native.session.recent") ?? []
    }

    var filteredSessions: [QuietoSession] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return catalog.sessions.filter { session in
            let source = [session.title, session.subtitle, session.intention, session.pillar.rawValue, session.practiceType.rawValue]
                + session.themes.flatMap { [$0.rawValue, $0.rawValue.quietoLocalized] }
                + session.situations.flatMap { [$0.rawValue, $0.rawValue.quietoLocalized, $0.subtitle, $0.subtitle.quietoLocalized] }
                + session.keywords
            let searchableText = source
                .joined(separator: " ").folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let matchesQuery = needle.isEmpty || searchableText.contains(needle)
            let matchesPillar = selectedPillar == nil || session.pillar == selectedPillar
            let matchesTheme = selectedTheme.map { session.themes.contains($0) } ?? true
            let matchesSituation = selectedSituation.map { session.situations.contains($0) } ?? true
            return matchesQuery && matchesPillar && matchesTheme && matchesSituation
                && durationFilter.includes(session.durationMinutes)
                && (practiceFilter == nil || session.practiceType == practiceFilter)
        }
    }

    var hasActiveFilters: Bool {
        selectedPillar != nil || selectedTheme != nil || selectedSituation != nil || durationFilter != .all || practiceFilter != nil
    }

    func selectSituation(_ situation: QuietoSituation) {
        selectedSituation = selectedSituation == situation ? nil : situation
        if selectedSituation != nil { selectedPillar = nil }
    }

    func selectTheme(_ theme: QuietoTheme) {
        selectedTheme = selectedTheme == theme ? nil : theme
        if selectedTheme != nil { selectedPillar = nil }
    }

    func resetFilters() {
        selectedPillar = nil
        selectedTheme = nil
        selectedSituation = nil
        durationFilter = .all
        practiceFilter = nil
    }

    var shortSessions: [QuietoSession] { catalog.sessions.filter { $0.durationMinutes <= 3 }.prefix(2).map { $0 } }
    var libraryCounts: [QuietoLibrary: Int] { [.favorites: favorites.count, .downloads: catalog.sessions.filter { downloads.isDownloaded($0) }.count, .recent: recentIDs.count] }
    var librarySessions: [QuietoSession] {
        guard let selectedLibrary else { return [] }
        switch selectedLibrary {
        case .favorites: return catalog.sessions.filter { favorites.contains($0.id) }
        case .downloads: return catalog.sessions.filter { downloads.isDownloaded($0) }
        case .recent: return recentIDs.compactMap { id in catalog.sessions.first { $0.id == id } }
        }
    }

    func toggleFavorite(_ session: QuietoSession) {
        let isFavorite: Bool
        if favorites.contains(session.id) { favorites.remove(session.id); isFavorite = false }
        else { favorites.insert(session.id); isFavorite = true }
        defaults.set(Array(favorites), forKey: "quieto.native.session.favorites")
        Task { try? await QuietoSupabaseService.shared.setFavorite(sessionID: session.id, favorite: isFavorite) }
    }
    // Hard paywall: the whole app sits behind the gate in RootView, so every
    // session plays directly here.
    func play(_ session: QuietoSession) {
        audioPlayer.play(session, localURL: downloads.localURL(for: session))
        recentIDs.removeAll { $0 == session.id }
        recentIDs.insert(session.id, at: 0)
        recentIDs = Array(recentIDs.prefix(10))
        defaults.set(recentIDs, forKey: "quieto.native.session.recent")
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
