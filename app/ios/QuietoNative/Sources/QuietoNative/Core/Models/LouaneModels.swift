import Foundation

struct LouaneRecommendation: Identifiable, Equatable {
    let id: String
    let sessionID: String
    let reason: String
}

enum LouaneAuthor: String { case louane, user, system }

struct LouaneMessage: Identifiable, Equatable {
    let id: UUID
    let author: LouaneAuthor
    let text: String
    let recommendation: LouaneRecommendation?
    let date: Date
    var isFailed = false

    init(id: UUID = UUID(), author: LouaneAuthor, text: String, recommendation: LouaneRecommendation? = nil, date: Date = .now, isFailed: Bool = false) {
        self.id = id; self.author = author; self.text = text; self.recommendation = recommendation; self.date = date; self.isFailed = isFailed
    }
}

/// `limited` is not retryable (daily cap, subscription required); `failed` is.
enum LouaneConversationStatus: Equatable { case idle, sending, failed(String), limited(String) }

enum LouaneServiceError: LocalizedError, Equatable {
    case premiumRequired
    case dailyLimit
    case unavailable
    case unreadable
    case empty

    static let crisisLine = "Si tu traverses un moment difficile, le 3114 répond 24h/24, gratuitement."

    var errorDescription: String? {
        switch self {
        case .premiumRequired: "Louane fait partie de ton abonnement Quieto. Vérifie qu’il est bien actif."
        case .dailyLimit: "Louane a besoin de se reposer jusqu’à demain. \(Self.crisisLine)"
        case .unavailable: "Le service Louane est momentanément indisponible."
        case .unreadable: "La réponse de Louane est illisible."
        case .empty: "Louane n’a pas renvoyé de réponse."
        }
    }
}

struct LouaneBackendReply {
    let text: String
    let recommendation: LouaneRecommendation?
}

protocol LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply
}

protocol LouaneMemoryProviding: AnyObject {
    var text: String { get }
    func update(_ text: String)
    func remove()
}
