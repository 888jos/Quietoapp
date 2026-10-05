import Foundation

enum QuietoLibrary: String, Identifiable { case favorites = "Favoris", downloads = "Téléchargements", recent = "Écoutées récemment"; var id: String { rawValue } }

@MainActor
final class SessionsViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedPillar: QuietoPillar? = .sleep
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
    let isPremium: Bool
    private let defaults: UserDefaults

    init(catalog: SessionCatalog = SessionCatalog(), audioPlayer: QuietoAudioPlayer, downloads: QuietoDownloadManaging = QuietoDownloadStore(), isPremium: Bool = false, defaults: UserDefaults = .standard) {
        self.catalog = catalog; self.audioPlayer = audioPlayer; self.downloads = downloads; self.isPremium = isPremium; self.defaults = defaults
        favorites = Set(defaults.stringArray(forKey: "quieto.native.session.favorites") ?? [])
        recentIDs = defaults.stringArray(forKey: "quieto.native.session.recent") ?? []
    }

    var filteredSessions: [QuietoSession] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return catalog.sessions.filter { session in
            let searchableText = ([session.title, session.subtitle, session.intention, session.pillar.rawValue, session.practiceType.rawValue] + session.keywords)
                .joined(separator: " ").folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let matchesQuery = needle.isEmpty || searchableText.contains(needle)
            return matchesQuery && (selectedPillar == nil || session.pillar == selectedPillar) && durationFilter.includes(session.durationMinutes) && (practiceFilter == nil || session.practiceType == practiceFilter)
        }
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

    func toggleFavorite(_ session: QuietoSession) { if favorites.contains(session.id) { favorites.remove(session.id) } else { favorites.insert(session.id) }; defaults.set(Array(favorites), forKey: "quieto.native.session.favorites") }
    func play(_ session: QuietoSession) {
        let startPlayback = { [weak self] in
            guard let self else { return }
            self.audioPlayer.play(session, localURL: self.downloads.localURL(for: session))
            self.recentIDs.removeAll { $0 == session.id }
            self.recentIDs.insert(session.id, at: 0)
            self.recentIDs = Array(self.recentIDs.prefix(10))
            self.defaults.set(self.recentIDs, forKey: "quieto.native.session.recent")
        }
        if session.isPremium && !isPremium {
            QuietoSuperwallService.shared.register("session_play_\(session.id)", feature: startPlayback)
        } else {
            startPlayback()
        }
    }
    func toggleDownload(_ session: QuietoSession) {
        if downloads.isDownloaded(session) { downloads.delete(session); feedback = "Séance supprimée des téléchargements."; return }
        let startDownload = { [weak self] in
            guard let self else { return }
            guard self.downloads.start(session, isPremium: true) else { self.feedback = "Téléchargement indisponible pour cette séance."; return }
            self.feedback = "Téléchargement commencé."
        }
        if session.isPremium && !isPremium {
            QuietoSuperwallService.shared.register("session_download_\(session.id)", feature: startDownload)
        } else {
            startDownload()
        }
    }
}
