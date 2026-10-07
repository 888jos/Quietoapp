import Combine
import Foundation

@MainActor
final class ProgramViewModel: ObservableObject {
    @Published var feedback: String?
    @Published var rhythm: ProgramRhythm
    @Published private(set) var sessions: [QuietoSession]
    @Published private(set) var completedIDs: Set<String> = []
    @Published private(set) var title = "Découvrir la méditation en 7 jours"
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?
    @Published private(set) var hasProgram = true

    enum ProgramRhythm: String, CaseIterable, Identifiable {
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
    }

    private let preferences: QuietoPreferences
    private let activity: ActivityStore
    private let catalog: SessionCatalog
    /// Nil when the backend is not configured: the programme stays local.
    private let repository: ProgramRepository?
    private var remoteProgramID: UUID?
    private var preferredIDs = ["decouverte_1", "breathing_1", "discover_counting", "decouverte_2", "new_long_exhale", "discover_body_scan", "decouverte_3"]
    private var cancellables = Set<AnyCancellable>()

    init(catalog: SessionCatalog, preferences: QuietoPreferences, activity: ActivityStore, repository: ProgramRepository?, completions: AnyPublisher<String, Never>) {
        self.preferences = preferences
        self.activity = activity
        self.catalog = catalog
        self.repository = repository
        // The programme built during onboarding replaces the generic one.
        if !preferences.onboardingPlanIDs.isEmpty {
            preferredIDs = preferences.onboardingPlanIDs
            if let planTitle = preferences.onboardingPlanTitle { title = planTitle }
        }
        sessions = preferredIDs.compactMap { id in catalog.sessions.first { $0.id == id } }
        rhythm = ProgramRhythm(rawValue: preferences.programRhythm ?? "") ?? .regular
        refreshLocalProgress()
        completions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                refreshLocalProgress()
                Task { await self.load() }
            }
            .store(in: &cancellables)
    }

    func refreshLocalProgress() {
        completedIDs = activity.completedSessionIDs
    }

    func sessions(in category: QuietoCategory) -> [QuietoSession] {
        catalog.sessions.filter { $0.category == category }
    }

    var completedCount: Int { sessions.filter { completedIDs.contains($0.id) }.count }
    var nextSession: QuietoSession? { sessions.first { !completedIDs.contains($0.id) } }

    func load() async {
        refreshLocalProgress()
        guard let repository else {
            hasProgram = true
            loadError = "Programme disponible hors ligne. La synchronisation reprendra automatiquement."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            if let remote = try await repository.loadActiveProgram(catalog: catalog) {
                remoteProgramID = remote.id
                title = remote.title
                sessions = remote.sessions
                completedIDs.formUnion(remote.completedSessionIDs)
                if let raw = remote.rhythm, let value = ProgramRhythm(rawValue: raw) { rhythm = value }
                hasProgram = !sessions.isEmpty
            } else {
                remoteProgramID = nil
                sessions = []
                hasProgram = false
            }
            loadError = nil
        } catch {
            hasProgram = true
            sessions = preferredIDs.compactMap { id in catalog.sessions.first { $0.id == id } }
            loadError = "Le programme local reste disponible ; la synchronisation a échoué."
        }
    }

    func createProgram() async {
        sessions = preferredIDs.compactMap { id in catalog.sessions.first { $0.id == id } }
        hasProgram = true
        guard let repository else {
            feedback = "Programme créé sur cet iPhone. Il sera synchronisé plus tard."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            remoteProgramID = try await repository.createProgram(title: title, sessionIDs: sessions.map(\.id), rhythm: rhythm.rawValue)
            feedback = "Programme créé"
        } catch {
            feedback = "Programme créé sur cet iPhone ; la synchronisation reprendra plus tard."
        }
    }

    func saveRhythm(_ value: ProgramRhythm) {
        rhythm = value
        preferences.programRhythm = value.rawValue
        // German nouns keep their capital letter.
        let detail = QuietoLocalization.languageCode == "de" ? value.localizedDetail : value.localizedDetail.lowercased(with: QuietoLocalization.locale)
        feedback = QuietoLocalization.format("Rythme enregistré : %@.", detail)
        if let remoteProgramID, let repository {
            Task {
                do { try await repository.updateProgramRhythm(programID: remoteProgramID, rhythm: value.rawValue) }
                catch { feedback = "Rythme enregistré sur cet iPhone ; la synchronisation reprendra plus tard." }
            }
        }
    }
}
