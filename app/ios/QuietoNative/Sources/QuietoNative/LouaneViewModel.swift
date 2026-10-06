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

    let backend: LouaneBackendProviding
    let memory: LouaneMemoryProviding
    let audioPlayer: QuietoAudioPlayer
    let catalog: SessionCatalog
    private let defaults: UserDefaults
    private let draftKey = "quieto.native.louane.draft"
    private var conversationID = UUID()
    private var responseTask: Task<Void, Never>?

    init(backend: LouaneBackendProviding = URLSessionLouaneBackend(), memory: LouaneMemoryProviding = LouaneMemoryStore(), audioPlayer: QuietoAudioPlayer, catalog: SessionCatalog = SessionCatalog(), defaults: UserDefaults = .standard) {
        self.backend = backend; self.memory = memory; self.audioPlayer = audioPlayer; self.catalog = catalog; self.defaults = defaults
        draft = defaults.string(forKey: "quieto.native.louane.draft") ?? ""
        messages = []
    }

    var isSending: Bool { if case .sending = status { return true }; return false }
    func saveDraft() { defaults.set(draft, forKey: draftKey) }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        draft = ""; saveDraft()
        let message = LouaneMessage(author: .user, text: text)
        messages.append(message); status = .sending; persist()
        responseTask = Task { await requestReply(for: message) }
    }

    func retry(_ message: LouaneMessage) { guard !isSending else { return }; status = .sending; responseTask = Task { await requestReply(for: message) } }
    func cancelResponse() { responseTask?.cancel(); responseTask = nil; status = .idle }
    func newConversation() { cancelResponse(); messages.removeAll(); conversationID = UUID(); status = .idle; temporaryConversation = false; persist() }
    func deleteConversation() {
        let deletedID = conversationID
        cancelResponse()
        isDeleteConfirmationPresented = false
        guard QuietoSupabaseService.shared.client != nil else {
            messages.removeAll(); conversationID = UUID(); status = .idle
            deletionError = "Conversation supprimée de cet iPhone. Aucun effacement distant n’a été annoncé."
            return
        }
        Task {
            do {
                try await QuietoSupabaseService.shared.deleteConversation(deletedID)
                messages.removeAll(); conversationID = UUID(); status = .idle; deletionError = nil
            } catch {
                deletionError = error.localizedDescription
            }
        }
    }
    func play(_ recommendation: LouaneRecommendation) {
        guard let session = catalog.sessions.first(where: { $0.id == recommendation.sessionID }) else { return }
        let action: () -> Void = { [weak audioPlayer] in audioPlayer?.play(session) }
        if session.isPremium { QuietoSuperwallService.shared.register("louane_session_\(session.id)", feature: action) } else { action() }
    }
    func session(for recommendation: LouaneRecommendation) -> QuietoSession? { catalog.sessions.first { $0.id == recommendation.sessionID } }

    func loadHistory() async {
        do { history = try await QuietoSupabaseService.shared.conversationHistory(); historyError = nil }
        catch { historyError = error.localizedDescription }
    }

    func openConversation(_ summary: QuietoConversationSummary) async {
        do {
            messages = try await QuietoSupabaseService.shared.messages(conversationID: summary.id)
            conversationID = summary.id
            status = .idle
            isHistoryPresented = false
        } catch { historyError = error.localizedDescription }
    }

    func saveMemory(_ value: String) {
        memory.update(value)
        Task { try? await QuietoSupabaseService.shared.saveMemory(value) }
    }

    func deleteMemory() {
        memory.remove()
        Task { try? await QuietoSupabaseService.shared.deleteMemory() }
    }

    func reportLatestResponse() {
        guard messages.last(where: { $0.author == .louane }) != nil else {
            reportMessage = "Aucune réponse à signaler pour le moment."
            return
        }
        Task {
            await QuietoSupabaseService.shared.track("louane_response_reported", properties: ["conversation": conversationID.uuidString])
            reportMessage = "Merci. Le signalement a été enregistré sans ajouter le contenu du message aux analytics."
        }
    }

    func refreshMemory() async {
        if let remote = try? await QuietoSupabaseService.shared.loadMemory() { memory.update(remote) }
    }

    private func requestReply(for message: LouaneMessage) async {
        do {
            let reply = try await backend.send(message: message.text, history: messages, temporary: temporaryConversation)
            guard !Task.isCancelled else { return }
            let validatedRecommendation = reply.recommendation.flatMap { recommendation in
                catalog.sessions.contains(where: { $0.id == recommendation.sessionID }) ? recommendation : nil
            }
            let response = LouaneMessage(author: .louane, text: reply.text, recommendation: validatedRecommendation)
            messages.append(response); status = .idle; persist()
        } catch is CancellationError {
            status = .idle
        } catch {
            status = .failed(error.localizedDescription); persist()
        }
        responseTask = nil
    }

    private func persist() {
        guard !temporaryConversation else { return }
        let title = messages.first(where: { $0.author == .user })?.text ?? "Nouvel échange"
        let pending = messages
        let currentID = conversationID
        Task {
            for message in pending {
                try? await QuietoSupabaseService.shared.saveConversationMessage(conversationID: currentID, title: title, message: message, temporary: false)
            }
        }
    }
}
