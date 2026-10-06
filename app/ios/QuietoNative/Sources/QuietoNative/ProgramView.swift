import SwiftUI

@MainActor
final class ProgramViewModel: ObservableObject {
    @Published var feedback: String?
    @Published var rhythm: ProgramRhythm
    @Published private(set) var sessions: [QuietoSession]
    @Published private(set) var completedIDs: Set<String> = []
    @Published private(set) var title = "Laisser la journée derrière soi"
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

    private let defaults: UserDefaults
    private let catalog: SessionCatalog
    private let backend: QuietoSupabaseService
    private var remoteProgramID: UUID?
    private let preferredIDs = ["decouverte_1", "breathing_1", "decouverte_2", "stress_4", "emotion_1", "sleep_2", "decouverte_3"]

    init(catalog: SessionCatalog = SessionCatalog(), defaults: UserDefaults = .standard, backend: QuietoSupabaseService = .shared) {
        self.defaults = defaults
        self.catalog = catalog
        self.backend = backend
        sessions = preferredIDs.compactMap { id in catalog.sessions.first { $0.id == id } }
        rhythm = ProgramRhythm(rawValue: defaults.string(forKey: "quieto.program.rhythm") ?? "") ?? .regular
        refreshLocalProgress()
    }

    func refreshLocalProgress() {
        let events = defaults.array(forKey: "quieto.native.activity.events") as? [[String: Any]] ?? []
        completedIDs = Set(events.compactMap { $0["id"] as? String })
    }

    var completedCount: Int { sessions.filter { completedIDs.contains($0.id) }.count }
    var nextSession: QuietoSession? { sessions.first { !completedIDs.contains($0.id) } }

    func load() async {
        refreshLocalProgress()
        guard backend.client != nil else {
            hasProgram = true
            loadError = "Programme disponible hors ligne. La synchronisation reprendra automatiquement."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            if let remote = try await backend.loadActiveProgram(catalog: catalog) {
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
        guard backend.client != nil else {
            feedback = "Programme créé sur cet iPhone. Il sera synchronisé plus tard."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            remoteProgramID = try await backend.createProgram(title: title, sessionIDs: sessions.map(\.id), rhythm: rhythm.rawValue)
            feedback = "Programme créé"
        } catch {
            feedback = "Programme créé sur cet iPhone ; la synchronisation reprendra plus tard."
        }
    }

    func saveRhythm(_ value: ProgramRhythm) {
        rhythm = value
        defaults.set(value.rawValue, forKey: "quieto.program.rhythm")
        feedback = String(format: "Rythme enregistré : %@.".quietoLocalized, value.localizedDetail.lowercased())
        if let remoteProgramID {
            Task {
                do { try await backend.updateProgramRhythm(programID: remoteProgramID, rhythm: value.rawValue) }
                catch { feedback = "Rythme enregistré sur cet iPhone ; la synchronisation reprendra plus tard." }
            }
        }
    }
}

struct ProgramView: View {
    @StateObject private var model = ProgramViewModel()
    @StateObject private var sessionModel: SessionsViewModel
    @ObservedObject var audioPlayer: QuietoAudioPlayer
    @State private var selectedSession: QuietoSession?
    @State private var showingRhythm = false

    init(audioPlayer: QuietoAudioPlayer) {
        self.audioPlayer = audioPlayer
        _sessionModel = StateObject(wrappedValue: SessionsViewModel(audioPlayer: audioPlayer))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuietoColor.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                        header
                        if model.isLoading && model.sessions.isEmpty {
                            ProgressView("Chargement du programme…".quietoLocalized).tint(QuietoColor.mint).frame(maxWidth: .infinity).padding(.vertical, 80)
                        } else if !model.hasProgram {
                            emptyProgram
                        } else {
                            if let error = model.loadError {
                                Label(error.quietoLocalized, systemImage: "wifi.slash").font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
                            }
                            progressCard
                            sessionsList
                            rhythmCard
                        }
                        Color.clear.frame(height: 128)
                    }
                    .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                    .padding(.horizontal, QuietoSpacing.md)
                    .padding(.top, QuietoSpacing.sm)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 92) }
            .navigationBarHidden(true)
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session, model: sessionModel)
            }
            .confirmationDialog("Adapter mon rythme", isPresented: $showingRhythm, titleVisibility: .visible) {
                ForEach(ProgramViewModel.ProgramRhythm.allCases) { rhythm in
                    Button("\(rhythm.localizedName) · \(rhythm.localizedDetail)") { model.saveRhythm(rhythm) }
                }
                Button("Annuler", role: .cancel) {}
            }
            .overlay(alignment: .top) {
                if let feedback = model.feedback {
                    Text(feedback.quietoLocalized)
                        .font(QuietoFont.sans(13, weight: .medium))
                        .foregroundStyle(QuietoColor.background)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(QuietoColor.mint, in: Capsule())
                        .padding(.top, 8)
                        .onTapGesture { model.feedback = nil }
                }
            }
            .task { await model.load() }
            .onReceive(NotificationCenter.default.publisher(for: .quietoSessionCompleted)) { _ in
                model.refreshLocalProgress()
                Task { await model.load() }
            }
        }
    }

    private var emptyProgram: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "map").font(.system(size: 28)).foregroundStyle(QuietoColor.mint)
                Text("Commencer un parcours").font(QuietoFont.serif(25, weight: .semibold))
                Text("Sept étapes alternent méditation, respiration et relaxation. Tu pourras changer le rythme à tout moment.")
                    .font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary)
                QuietoPrimaryButton(title: "Créer mon programme", systemImage: "plus") {
                    Task { await model.createProgram() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Ton programme").font(QuietoFont.display)
            Text("Une progression claire, à ton rythme.").font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var progressCard: some View {
        QuietoCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.title.quietoLocalized).font(QuietoFont.serif(23, weight: .semibold))
                        Text(String(format: "%d séances terminées sur %d".quietoLocalized, model.completedCount, model.sessions.count))
                            .font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Spacer()
                    Text("\(Int(Double(model.completedCount) / Double(max(model.sessions.count, 1)) * 100)) %")
                        .font(QuietoFont.sans(14, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                }
                ProgressView(value: Double(model.completedCount), total: Double(max(model.sessions.count, 1)))
                    .tint(QuietoColor.mint)
                if let next = model.nextSession {
                    QuietoPrimaryButton(title: String(format: "Continuer · %d min".quietoLocalized, next.durationMinutes), systemImage: "play.fill") { play(next) }
                } else {
                    Label("Programme terminé", systemImage: "checkmark.seal.fill")
                        .font(QuietoFont.sans(15, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                }
            }
        }
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Les étapes").font(QuietoFont.section)
            ForEach(Array(model.sessions.enumerated()), id: \.element.id) { index, session in
                Button { selectedSession = session } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(model.completedIDs.contains(session.id) ? QuietoColor.mint : QuietoColor.surfaceRaised)
                            if model.completedIDs.contains(session.id) {
                                Image(systemName: "checkmark").foregroundStyle(QuietoColor.background)
                            } else {
                                Text("\(index + 1)").foregroundStyle(QuietoColor.textPrimary)
                            }
                        }
                        .font(.system(size: 13, weight: .semibold)).frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.title.quietoLocalized).font(QuietoFont.serif(18, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                            Text("\(session.durationMinutes) min · \(session.practiceType.rawValue.quietoLocalized)")
                                .font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary)
                        }
                        Spacer()
                        Button { play(session) } label: {
                            Image(systemName: audioPlayer.currentSession?.id == session.id && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(QuietoColor.background)
                                .frame(width: 38, height: 38).background(QuietoColor.mint, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Lire \(session.title)")
                    }
                    .padding(13)
                    .background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: QuietoMetrics.cornerRadius))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rhythmCard: some View {
        Button { showingRhythm = true } label: {
            QuietoCard {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(QuietoColor.mint).frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Adapter mon rythme").font(QuietoFont.sans(15, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
                        Text("\(model.rhythm.localizedName) · \(model.rhythm.localizedDetail)").font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(QuietoColor.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func play(_ session: QuietoSession) {
        sessionModel.play(session)
    }
}
