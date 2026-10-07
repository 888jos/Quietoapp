import Foundation

@MainActor
final class LouaneViewModel: ObservableObject {
    @Published private(set) var messages: [LouaneMessage]
    @Published var draft: String
    @Published private(set) var status: LouaneConversationStatus = .idle
    @Published var isMenuPresented = false
    @Published var isMemoryPresented = false
    @Published var isInfoPresented = false
    @Published var isHistoryPresented = false
    @Published var isReportPresented = false
    @Published var isDeleteConfirmationPresented = false
    @Published var reportMessage: String?
    @Published var temporaryConversation = false
    @Published private(set) var history: [QuietoConversationSummary] = []
    @Published private(set) var historyError: String?
    @Published var deletionError: String?
    /// A crisis sign in what the person wrote: the listening line shows at once,
    /// whatever the server answers (or if it never answers). Never tracked.
    @Published private(set) var showsCrisisSupport = false

    let memory: LouaneMemoryProviding
    private let backend: LouaneBackendProviding
    /// Nil when Supabase is not configured: conversations stay on this iPhone.
    private let repository: LouaneRepository?
    private let playback: QuietoPlaybackProviding
    private let subscriptions: SubscriptionServicing?
    private let analytics: QuietoAnalyticsProviding
    private let catalog: SessionCatalog
    private let preferences: QuietoPreferences
    /// Sounds bundled in the app (`QuietoAmbience.all`), injectable for tests.
    private let ambiences: [QuietoAmbience]
    private var conversationID = UUID()
    private var responseTask: Task<Void, Never>?
    private var responseToken = UUID()

    init(backend: LouaneBackendProviding, memory: LouaneMemoryProviding, repository: LouaneRepository?, playback: QuietoPlaybackProviding, subscriptions: SubscriptionServicing?, analytics: QuietoAnalyticsProviding, catalog: SessionCatalog, preferences: QuietoPreferences, ambiences: [QuietoAmbience] = QuietoAmbience.all) {
        self.backend = backend
        self.memory = memory
        self.repository = repository
        self.playback = playback
        self.subscriptions = subscriptions
        self.analytics = analytics
        self.catalog = catalog
        self.preferences = preferences
        self.ambiences = ambiences
        draft = preferences.louaneDraft
        messages = []
    }

    var isSending: Bool { if case .sending = status { return true }; return false }
    func saveDraft() { preferences.louaneDraft = draft }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        draft = ""; saveDraft()
        let message = LouaneMessage(author: .user, text: text)
        if OnboardingSafety.containsCrisisSignal(text) { showsCrisisSupport = true }
        messages.append(message); persist()
        startReply(for: message)
    }

    func retry(_ message: LouaneMessage) { guard !isSending else { return }; startReply(for: message) }

    private func startReply(for message: LouaneMessage) {
        let token = UUID()
        responseToken = token
        status = .sending
        responseTask = Task { await requestReply(for: message, token: token) }
    }

    /// Stopping is not an error: the pending answer is dropped silently.
    func cancelResponse() { responseToken = UUID(); responseTask?.cancel(); responseTask = nil; status = .idle }
    func newConversation() { cancelResponse(); messages.removeAll(); conversationID = UUID(); status = .idle; temporaryConversation = false; showsCrisisSupport = false; persist() }
    func deleteConversation() {
        let deletedID = conversationID
        cancelResponse()
        isDeleteConfirmationPresented = false
        guard let repository else {
            messages.removeAll(); conversationID = UUID(); status = .idle
            deletionError = "Conversation supprimée de cet iPhone. Aucun effacement distant n’a été annoncé."
            return
        }
        Task {
            do {
                try await repository.deleteConversation(deletedID)
                messages.removeAll(); conversationID = UUID(); status = .idle; deletionError = nil
            } catch {
                deletionError = error.localizedDescription
            }
        }
    }
    /// The sound first, so it keeps playing under the voice of the meditation.
    func play(_ recommendation: LouaneRecommendation) {
        let session = session(for: recommendation), ambience = ambience(for: recommendation)
        if let ambience { playback.playAmbience(ambience) }
        if let session { playback.play(session) }
        guard session != nil || ambience != nil else { return }
        analytics.track("louane_recommendation_played", properties: [
            "session": session?.id ?? "", "ambience": ambience?.id ?? "", "type": session?.readerMode == .breathing ? "breathing" : (session != nil ? "meditation" : "sound")
        ])
    }
    func session(for recommendation: LouaneRecommendation) -> QuietoSession? {
        guard let id = recommendation.sessionID else { return nil }
        return catalog.sessions.first { $0.id == id }
    }
    func ambience(for recommendation: LouaneRecommendation) -> QuietoAmbience? {
        guard let id = recommendation.ambienceID else { return nil }
        return ambiences.first { $0.id == id }
    }

    func loadHistory() async {
        do {
            guard let repository else { throw QuietoBackendError.notConfigured }
            history = try await repository.conversationHistory()
            historyError = nil
        }
        catch { historyError = error.localizedDescription }
    }

    func openConversation(_ summary: QuietoConversationSummary) async {
        // A reply still on its way belongs to the conversation being left.
        cancelResponse()
        do {
            guard let repository else { throw QuietoBackendError.notConfigured }
            messages = try await repository.messages(conversationID: summary.id)
            conversationID = summary.id
            status = .idle
            showsCrisisSupport = false
            isHistoryPresented = false
        } catch { historyError = error.localizedDescription }
    }

    func saveMemory(_ value: String) {
        memory.update(value)
        Task { [repository] in try? await repository?.saveMemory(value) }
    }

    func deleteMemory() {
        memory.remove()
        Task { [repository] in try? await repository?.deleteMemory() }
    }

    func reportLatestResponse() {
        guard messages.last(where: { $0.author == .louane }) != nil else {
            reportMessage = "Aucune réponse à signaler pour le moment."
            return
        }
        analytics.track("louane_response_reported", properties: ["conversation": conversationID.uuidString])
        reportMessage = "Merci. Le signalement a été enregistré sans ajouter le contenu du message aux analytics."
    }

    func refreshMemory() async {
        if let remote = try? await repository?.loadMemory() { memory.update(remote) }
    }

    private func requestReply(for message: LouaneMessage, token: UUID) async {
        // The server appends the current message itself: only send what came before.
        let history = Array(messages.prefix { $0.id != message.id })
        do {
            let reply = try await backend.send(message: message.text, history: history, temporary: temporaryConversation)
            guard !Task.isCancelled, token == responseToken else { return }
            let validatedRecommendation = reply.recommendation.flatMap(validated)
            let response = LouaneMessage(author: .louane, text: reply.text, recommendation: validatedRecommendation)
            messages.append(response); status = .idle; persist()
            // The server returns the memory sheet it updated (`memoire`): keep it
            // locally and on the account, like an edit made from the profile.
            if !temporaryConversation, let updated = reply.memory?.trimmingCharacters(in: .whitespacesAndNewlines),
               !updated.isEmpty, updated != memory.text {
                saveMemory(updated)
            }
        } catch {
            guard token == responseToken else { return }
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                status = .idle
            } else if let serviceError = error as? LouaneServiceError, serviceError == .premiumRequired || serviceError == .dailyLimit || serviceError == .tooFast {
                status = .limited(serviceError.localizedDescription)
                // The server says this account has no entitlement: re-check so
                // the hard paywall reappears if the subscription really ended.
                if serviceError == .premiumRequired { subscriptions?.syncWithServer() }
            } else {
                status = .failed(error.localizedDescription)
            }
        }
        if token == responseToken { responseTask = nil }
    }

    /// Keeps only what the app can really play: an unknown session or a sound
    /// not bundled is dropped, and nothing is left when both are unknown.
    private func validated(_ recommendation: LouaneRecommendation) -> LouaneRecommendation? {
        let sessionID = session(for: recommendation)?.id
        let ambienceID = ambience(for: recommendation)?.id
        guard sessionID != nil || ambienceID != nil else { return nil }
        return LouaneRecommendation(
            id: [sessionID, ambienceID].compactMap { $0 }.joined(separator: "+"),
            sessionID: sessionID,
            ambienceID: ambienceID,
            reason: recommendation.reason
        )
    }

    private func persist() {
        guard !temporaryConversation, let repository else { return }
        let title = messages.first(where: { $0.author == .user })?.text ?? "Nouvel échange"
        let pending = messages
        let currentID = conversationID
        Task {
            for message in pending {
                try? await repository.saveConversationMessage(conversationID: currentID, title: title, message: message, temporary: false)
            }
        }
    }
}
