import Foundation
import Supabase

struct QuietoConversationSummary: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String?
    let isTemporary: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title
        case isTemporary = "is_temporary"
        case updatedAt = "updated_at"
    }
}

private struct QuietoProgressRow: Codable {
    let sessionID: String
    let completedCount: Int
    let lastPlayedAt: Date?
    let isFavorite: Bool
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case completedCount = "completed_count"
        case lastPlayedAt = "last_played_at"
        case isFavorite = "is_favorite"
    }
}

private struct QuietoProgramRow: Codable {
    let id: UUID
    let title: String
    let status: String
}

private struct QuietoProgramStepRow: Codable {
    let sessionID: String
    let stepNumber: Int
    let status: String
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case stepNumber = "step_number"
        case status
    }
}

private struct QuietoSubscriptionRow: Codable {
    let status: String
    let expiresAt: Date?
    enum CodingKeys: String, CodingKey { case status; case expiresAt = "expires_at" }
}

private struct QuietoConversationInsert: Encodable {
    let id: UUID
    let userID: String
    let title: String
    let isTemporary: Bool
    enum CodingKeys: String, CodingKey { case id, title; case userID = "user_id"; case isTemporary = "is_temporary" }
}

private struct QuietoMessageInsert: Encodable {
    let id: UUID
    let conversationID: UUID
    let userID: String
    let role: String
    let content: String
    let status: String
    let clientMessageID: UUID
    let recommendation: [String: String]?
    enum CodingKeys: String, CodingKey {
        case id, role, content, status, recommendation
        case conversationID = "conversation_id"
        case userID = "user_id"
        case clientMessageID = "client_message_id"
    }
}

private struct QuietoMessageRow: Decodable {
    let id: UUID
    let role: String
    let content: String
    let recommendation: [String: String]?
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, role, content, recommendation; case createdAt = "created_at" }
}

private struct QuietoMemoryRow: Codable {
    let userID: String
    let memoryText: String
    let consentedAt: Date?
    enum CodingKeys: String, CodingKey { case userID = "user_id"; case memoryText = "memory_text"; case consentedAt = "consented_at" }
}

extension QuietoSupabaseService {
    func loadHome(catalog: SessionCatalog = SessionCatalog()) async throws -> QuietoHomeSnapshot {
        guard let client else { throw QuietoBackendError.notConfigured }
        let session = try await client.auth.session
        async let progressQuery: [QuietoProgressRow] = client.from("session_progress")
            .select("session_id,completed_count,last_played_at,is_favorite")
            .eq("user_id", value: session.user.id.uuidString)
            .order("last_played_at", ascending: false)
            .execute().value
        async let programQuery: [QuietoProgramRow] = client.from("programs")
            .select("id,title,status")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("status", value: "active").limit(1).execute().value
        let progress = try await progressQuery
        let activePrograms = try await programQuery
        let lastSession = progress.compactMap { row in catalog.sessions.first { $0.id == row.sessionID } }.first
        let completed = Set(progress.filter { $0.completedCount > 0 }.map(\.sessionID))

        var program: QuietoProgram?
        var next = catalog.sessions.first { !completed.contains($0.id) }
        if let active = activePrograms.first {
            let steps: [QuietoProgramStepRow] = try await client.from("program_steps")
                .select("session_id,step_number,status")
                .eq("program_id", value: active.id.uuidString)
                .order("step_number", ascending: true).execute().value
            let completedDays = Set(steps.filter { $0.status == "completed" }.map(\.stepNumber))
            next = steps.first(where: { $0.status != "completed" }).flatMap { step in catalog.sessions.first { $0.id == step.sessionID } }
            program = QuietoProgram(title: active.title, completedDays: completedDays, totalDays: steps.count, currentSession: next, isFinished: !steps.isEmpty && completedDays.count == steps.count)
        }
        return QuietoHomeSnapshot(firstName: profile?.firstName, nextSession: next, program: program, progress: .init(completedSessionIDs: completed, lastListened: lastSession))
    }

    func subscriptionState() async throws -> QuietoSubscriptionState {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        let rows: [QuietoSubscriptionRow] = try await client.from("subscription_accounts")
            .select("status,expires_at").eq("user_id", value: userID).limit(1).execute().value
        guard let row = rows.first else { return .inactive }
        if let expiry = row.expiresAt, expiry < .now { return .expired }
        switch row.status {
        case "trial": return .trial
        case "active", "grace_period", "promotional": return .active
        case "expired": return .expired
        default: return .inactive
        }
    }

    func track(_ event: String, properties: [String: String]) async {
        guard let client, let session = try? await client.auth.session else { return }
        struct Event: Encodable { let user_id: String; let event_name: String; let properties: [String: String]; let client_event_id: UUID }
        _ = try? await client.from("analytics_events").insert(Event(user_id: session.user.id.uuidString, event_name: String(event.prefix(80)), properties: properties, client_event_id: UUID())).execute()
    }

    func saveConversationMessage(conversationID: UUID, title: String, message: LouaneMessage, temporary: Bool) async throws {
        guard !temporary, let client else { return }
        let userID = try await client.auth.session.user.id.uuidString
        try await client.from("louane_conversations").upsert(QuietoConversationInsert(id: conversationID, userID: userID, title: String(title.prefix(80)), isTemporary: false), onConflict: "id").execute()
        let recommendation = message.recommendation.map { ["session_id": $0.sessionID, "reason": $0.reason] }
        let row = QuietoMessageInsert(id: message.id, conversationID: conversationID, userID: userID, role: message.author == .louane ? "assistant" : message.author.rawValue, content: String(message.text.prefix(4_000)), status: message.isFailed ? "failed" : "complete", clientMessageID: message.id, recommendation: recommendation)
        try await client.from("louane_messages").upsert(row, onConflict: "user_id,client_message_id").execute()
    }

    func conversationHistory() async throws -> [QuietoConversationSummary] {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        return try await client.from("louane_conversations").select("id,title,is_temporary,updated_at").eq("user_id", value: userID).is("archived_at", value: nil).order("updated_at", ascending: false).execute().value
    }

    func messages(conversationID: UUID) async throws -> [LouaneMessage] {
        guard let client else { throw QuietoBackendError.notConfigured }
        let rows: [QuietoMessageRow] = try await client.from("louane_messages").select("id,role,content,recommendation,created_at").eq("conversation_id", value: conversationID.uuidString).order("created_at", ascending: true).execute().value
        return rows.map { row in
            let rec = row.recommendation.flatMap { values -> LouaneRecommendation? in
                guard let sessionID = values["session_id"] else { return nil }
                return LouaneRecommendation(id: sessionID, sessionID: sessionID, reason: values["reason"] ?? "")
            }
            return LouaneMessage(id: row.id, author: row.role == "assistant" ? .louane : .user, text: row.content, recommendation: rec, date: row.createdAt)
        }
    }

    func deleteConversation(_ id: UUID) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        try await client.from("louane_conversations").delete().eq("id", value: id.uuidString).execute()
    }

    func loadMemory() async throws -> String {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        let rows: [QuietoMemoryRow] = try await client.from("louane_memory").select("user_id,memory_text,consented_at").eq("user_id", value: userID).limit(1).execute().value
        return rows.first?.memoryText ?? ""
    }

    func saveMemory(_ value: String) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        try await client.from("louane_memory").upsert(QuietoMemoryRow(userID: userID, memoryText: String(value.prefix(4_000)), consentedAt: .now), onConflict: "user_id").execute()
    }

    func deleteMemory() async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        try await client.from("louane_memory").delete().eq("user_id", value: userID).execute()
    }

    func invokeAccountData(method: String) async throws -> Data {
        guard let base = QuietoBackendConfiguration.supabaseURL, let client else { throw QuietoBackendError.notConfigured }
        let session = try await client.auth.session
        var request = URLRequest(url: base.appendingPathComponent("functions/v1/account-data"))
        request.httpMethod = method
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(QuietoBackendConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw QuietoBackendError.serverRejected }
        return data
    }

    func signedAudioURL(path: String) async throws -> URL {
        guard let base = QuietoBackendConfiguration.supabaseURL, let client else { throw QuietoBackendError.notConfigured }
        let session = try await client.auth.session
        let encoded = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }.joined(separator: "/")
        var request = URLRequest(url: base.appendingPathComponent("storage/v1/object/sign/session-audio/\(encoded)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(QuietoBackendConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["expiresIn": 900])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let signed = object["signedURL"] as? String, let url = URL(string: signed, relativeTo: base)?.absoluteURL else { throw QuietoBackendError.serverRejected }
        return url
    }
}

extension QuietoBackendError {
    static var serverRejected: QuietoBackendError { .requestRejected }
}
