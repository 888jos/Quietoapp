import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var snapshot: QuietoHomeSnapshot
    @Published var selectedTab: QuietoTab = .home
    /// Debug builds only: replays the onboarding (wired by AppContainer).
    var onReplayOnboarding: (() -> Void)?
    @Published var feeling: CheckInFeeling?
    @Published var need: CheckInNeed?
    @Published private(set) var isRefreshing = false
    /// Short confirmation shown at the top of the home, cleared after a few seconds.
    @Published var lastAction: String? {
        didSet {
            guard lastAction != nil else { return }
            clearActionTask?.cancel()
            clearActionTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                self?.lastAction = nil
            }
        }
    }
    private var clearActionTask: Task<Void, Never>?

    let services: QuietoServices
    private let catalog: SessionCatalog
    private let achievements: AchievementCenter?
    private var cancellables = Set<AnyCancellable>()

    /// `changes` fires when the programme or the journal changed: the home is
    /// rebuilt from the iPhone, without network.
    init(services: QuietoServices = .preview, catalog: SessionCatalog = SessionCatalog(), achievements: AchievementCenter? = nil, changes: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher()) {
        self.services = services
        self.catalog = catalog
        self.achievements = achievements
        snapshot = services.home.localSnapshot()
        changes
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.reloadLocal() }
            .store(in: &cancellables)
    }

    func reloadLocal() {
        snapshot = services.home.localSnapshot()
    }

    /// Naming what one is going through counts as a check-in.
    func checkIn(_ situation: QuietoSituation) {
        achievements?.recordCheckIn(situation)
        services.analytics.track("check_in", properties: ["situation": situation.id])
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            snapshot = try await services.home.loadHome()
        } catch {
            snapshot.errorMessage = "Impossible de charger ton accueil."
        }
    }

    func play(_ session: QuietoSession, source: String) {
        services.playback.play(session)
        services.analytics.track("session_played", properties: ["session": session.id, "source": source])
        lastAction = QuietoLocalization.format("Lecture de « %@ »", session.title.quietoLocalized)
    }

    func sessions(for need: QuietoNeed) -> [QuietoSession] {
        need.sessionIDs.compactMap { id in catalog.sessions.first { $0.id == id } }
    }

    func ambiences(for need: QuietoNeed) -> [QuietoAmbience] {
        need.ambienceIDs.compactMap { id in QuietoAmbience.all.first { $0.id == id } }
    }

    func sessions(for situation: QuietoSituation) -> [QuietoSession] {
        situation.sessionIDs.compactMap { id in catalog.sessions.first { $0.id == id } }
    }

    func ambiences(for situation: QuietoSituation) -> [QuietoAmbience] {
        situation.ambienceIDs.compactMap { id in QuietoAmbience.all.first { $0.id == id } }
    }

    func play(_ ambience: QuietoAmbience, source: String) {
        services.playback.playAmbience(ambience)
        services.analytics.track("ambience_played", properties: ["ambience": ambience.id, "source": source])
        lastAction = QuietoLocalization.format("Ambiance « %@ »", ambience.title.quietoLocalized)
    }

    func openProgram() {
        selectedTab = .programme
        services.analytics.track("program_opened", properties: [:])
    }

    func openLouane() {
        selectedTab = .louane
        services.ai.openLouane()
        services.analytics.track("louane_opened", properties: ["source": "home"])
    }
}
