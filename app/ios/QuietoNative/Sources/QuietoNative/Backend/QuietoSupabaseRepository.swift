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
    let listenedSeconds: Int?
    let playCount: Int?
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case completedCount = "completed_count"
        case lastPlayedAt = "last_played_at"
        case isFavorite = "is_favorite"
        case listenedSeconds = "listened_seconds"
        case playCount = "play_count"
    }
}

private struct QuietoProgramRow: Codable {
    let id: UUID
    let title: String
    let status: String
    let rawProgram: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case rawProgram = "raw_program"
    }
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

struct QuietoRemoteProgram: Equatable {
    let id: UUID
    let title: String
    let sessions: [QuietoSession]
    let completedSessionIDs: Set<String>
    let rhythm: String?
}

struct QuietoRemotePreferences: Equatable {
    let reminderEnabled: Bool
    let reminderDays: [Int]
    let reminderHour: Int
    let reminderMinute: Int
    let reminderTimezone: String
    let ambientLevel: Double
    let reduceMotion: Bool
    let largerText: Bool
}

private struct QuietoProgramInsert: Encodable {
    let id: UUID
    let userID: String
    let title: String
    let status: String
    let source: String
    let rawProgram: [String: String]

    enum CodingKeys: String, CodingKey {
        case id, title, status, source
        case userID = "user_id"
        case rawProgram = "raw_program"
    }
}

private struct QuietoProgramStepInsert: Encodable {
    let programID: UUID
    let stepNumber: Int
    let sessionID: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case status
        case programID = "program_id"
        case stepNumber = "step_number"
        case sessionID = "session_id"
    }
}

private struct QuietoProgressUpsert: Encodable {
    let userID: String
    let sessionID: String
    let lastPositionSeconds: Int
    let listenedSeconds: Int
    let playCount: Int
    let completedCount: Int
    let lastPlayedAt: Date
    let completedAt: Date?
    let isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case sessionID = "session_id"
        case lastPositionSeconds = "last_position_seconds"
        case listenedSeconds = "listened_seconds"
        case playCount = "play_count"
        case completedCount = "completed_count"
        case lastPlayedAt = "last_played_at"
        case completedAt = "completed_at"
        case isFavorite = "is_favorite"
    }
}

private struct QuietoFavoriteUpsert: Encodable {
    let userID: String
    let sessionID: String
    let isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case sessionID = "session_id"
        case isFavorite = "is_favorite"
    }
}

private struct QuietoPreferenceRow: Codable {
    let userID: String
    let reminderEnabled: Bool
    let reminderDays: [Int]
    let reminderLocalTime: String?
    let reminderTimezone: String?
    let ambientLevel: Double
    let reduceMotion: Bool
    let largerText: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case reminderEnabled = "reminder_enabled"
        case reminderDays = "reminder_days"
        case reminderLocalTime = "reminder_local_time"
        case reminderTimezone = "reminder_timezone"
        case ambientLevel = "ambient_level"
        case reduceMotion = "reduce_motion"
        case largerText = "larger_text"
    }
}

private struct QuietoListeningEventInsert: Encodable {
    let userID: String
    let sessionID: String
    let eventType: String
    let positionSeconds: Int
    let listenedDeltaSeconds: Int
    let clientEventID: UUID
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case sessionID = "session_id"
        case eventType = "event_type"
        case positionSeconds = "position_seconds"
        case listenedDeltaSeconds = "listened_delta_seconds"
        case clientEventID = "client_event_id"
        case occurredAt = "occurred_at"
    }
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

    func loadActiveProgram(catalog: SessionCatalog = SessionCatalog()) async throws -> QuietoRemoteProgram? {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        let rows: [QuietoProgramRow] = try await client.from("programs")
            .select("id,title,status,raw_program")
            .eq("user_id", value: userID)
            .eq("status", value: "active")
            .limit(1)
            .execute().value
        guard let program = rows.first else { return nil }
        let steps: [QuietoProgramStepRow] = try await client.from("program_steps")
            .select("session_id,step_number,status")
            .eq("program_id", value: program.id.uuidString)
            .order("step_number", ascending: true)
            .execute().value
        let sessions = steps.compactMap { step in catalog.sessions.first { $0.id == step.sessionID } }
        return QuietoRemoteProgram(
            id: program.id,
            title: program.title,
            sessions: sessions,
            completedSessionIDs: Set(steps.filter { $0.status == "completed" }.map(\.sessionID)),
            rhythm: program.rawProgram?["rhythm"]
        )
    }

    func createProgram(title: String, sessionIDs: [String], rhythm: String) async throws -> UUID {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        let id = UUID()
        let program = QuietoProgramInsert(id: id, userID: userID, title: String(title.prefix(120)), status: "active", source: "catalog", rawProgram: ["rhythm": rhythm])
        try await client.from("programs").insert(program).execute()
        do {
            let steps = sessionIDs.enumerated().map { index, sessionID in
                QuietoProgramStepInsert(programID: id, stepNumber: index + 1, sessionID: sessionID, status: index == 0 ? "available" : "planned")
            }
            try await client.from("program_steps").insert(steps).execute()
            return id
        } catch {
            try? await client.from("programs").delete().eq("id", value: id.uuidString).execute()
            throw error
        }
    }

    func updateProgramRhythm(programID: UUID, rhythm: String) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        try await client.from("programs").update(["raw_program": ["rhythm": rhythm]]).eq("id", value: programID.uuidString).execute()
    }

    func setFavorite(sessionID: String, favorite: Bool) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        let row = QuietoFavoriteUpsert(userID: userID, sessionID: sessionID, isFavorite: favorite)
        try await client.from("session_progress").upsert(row, onConflict: "user_id,session_id").execute()
    }

    func recordCompletion(sessionID: String, listenedSeconds: Int) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        let existing: [QuietoProgressRow] = try await client.from("session_progress")
            .select("session_id,completed_count,last_played_at,is_favorite,listened_seconds,play_count")
            .eq("user_id", value: userID).eq("session_id", value: sessionID).limit(1).execute().value
        let now = Date()
        let row = QuietoProgressUpsert(userID: userID, sessionID: sessionID, lastPositionSeconds: 0, listenedSeconds: (existing.first?.listenedSeconds ?? 0) + max(0, listenedSeconds), playCount: (existing.first?.playCount ?? 0) + 1, completedCount: (existing.first?.completedCount ?? 0) + 1, lastPlayedAt: now, completedAt: now, isFavorite: existing.first?.isFavorite ?? false)
        try await client.from("session_progress").upsert(row, onConflict: "user_id,session_id").execute()
        let event = QuietoListeningEventInsert(userID: userID, sessionID: sessionID, eventType: "completed", positionSeconds: max(0, listenedSeconds), listenedDeltaSeconds: max(0, listenedSeconds), clientEventID: UUID(), occurredAt: now)
        try await client.from("listening_events").insert(event).execute()

        let programs: [QuietoProgramRow] = try await client.from("programs").select("id,title,status,raw_program").eq("user_id", value: userID).eq("status", value: "active").limit(1).execute().value
        if let program = programs.first {
            try await client.from("program_steps")
                .update(["status": "completed", "completed_at": ISO8601DateFormatter().string(from: now)])
                .eq("program_id", value: program.id.uuidString)
                .eq("session_id", value: sessionID)
                .execute()
            let steps: [QuietoProgramStepRow] = try await client.from("program_steps")
                .select("session_id,step_number,status")
                .eq("program_id", value: program.id.uuidString)
                .order("step_number", ascending: true)
                .execute().value
            if !steps.isEmpty && steps.allSatisfy({ $0.status == "completed" || $0.sessionID == sessionID }) {
                try await client.from("programs").update(["status": "completed", "completed_at": ISO8601DateFormatter().string(from: now)]).eq("id", value: program.id.uuidString).execute()
            } else if let next = steps.first(where: { $0.status == "planned" }) {
                try await client.from("program_steps").update(["status": "available"]).eq("program_id", value: program.id.uuidString).eq("step_number", value: next.stepNumber).execute()
            }
        }
    }

    func loadPreferences() async throws -> QuietoRemotePreferences? {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        let rows: [QuietoPreferenceRow] = try await client.from("user_preferences")
            .select("user_id,reminder_enabled,reminder_days,reminder_local_time,reminder_timezone,ambient_level,reduce_motion,larger_text")
            .eq("user_id", value: userID).limit(1).execute().value
        guard let row = rows.first else { return nil }
        let parts = (row.reminderLocalTime ?? "21:30").split(separator: ":").compactMap { Int($0) }
        return QuietoRemotePreferences(reminderEnabled: row.reminderEnabled, reminderDays: row.reminderDays, reminderHour: parts.first ?? 21, reminderMinute: parts.dropFirst().first ?? 30, reminderTimezone: row.reminderTimezone ?? TimeZone.autoupdatingCurrent.identifier, ambientLevel: row.ambientLevel, reduceMotion: row.reduceMotion, largerText: row.largerText)
    }

    func savePreferences(_ preferences: QuietoRemotePreferences) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.uuidString
        let row = QuietoPreferenceRow(userID: userID, reminderEnabled: preferences.reminderEnabled, reminderDays: preferences.reminderDays, reminderLocalTime: String(format: "%02d:%02d:00", preferences.reminderHour, preferences.reminderMinute), reminderTimezone: preferences.reminderTimezone, ambientLevel: preferences.ambientLevel, reduceMotion: preferences.reduceMotion, largerText: preferences.largerText)
        try await client.from("user_preferences").upsert(row, onConflict: "user_id").execute()
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
