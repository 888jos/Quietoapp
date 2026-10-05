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

enum LouaneConversationStatus: Equatable { case idle, sending, failed(String) }

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
