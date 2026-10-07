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
    let planID: String?
    let planVersion: Int?
    let rhythm: String?
    let variant: String?
    let includesDiscovery: Bool?
    let startedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, status, rhythm, variant
        case rawProgram = "raw_program"
        case planID = "plan_id"
        case planVersion = "plan_version"
        case includesDiscovery = "includes_discovery"
        case startedAt = "started_at"
    }
}

private struct QuietoProgramStepRow: Codable {
    let sessionID: String
    let stepNumber: Int
    let status: String
    let completedAt: Date?
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case stepNumber = "step_number"
        case status
        case completedAt = "completed_at"
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
    /// The goal plan this programme follows; nil for the 7-session programmes
    /// written before the plans.
    var plan: QuietoPlanState?
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
    let planID: String
    let planVersion: Int
    let rhythm: String
    let variant: String
    let includesDiscovery: Bool
    let startedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, status, source, rhythm, variant
        case userID = "user_id"
        case rawProgram = "raw_program"
        case planID = "plan_id"
        case planVersion = "plan_version"
        case includesDiscovery = "includes_discovery"
        case startedAt = "started_at"
    }
}

private struct QuietoProgramStepInsert: Encodable {
    let programID: UUID
    let stepNumber: Int
    let dayNumber: Int
    let sessionID: String
    let kind: String
    let status: String
    let completedAt: Date?
    let availableOn: String?

    enum CodingKeys: String, CodingKey {
        case status, kind
        case programID = "program_id"
        case stepNumber = "step_number"
        case dayNumber = "day_number"
        case sessionID = "session_id"
        case completedAt = "completed_at"
        case availableOn = "available_on"
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
    func subscriptionState() async throws -> QuietoSubscriptionState {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        let rows: [QuietoSubscriptionRow] = try await client.from("subscription_accounts")
            .select("status,expires_at").eq("user_id", value: userID).limit(1).execute().value
        guard let row = rows.first else { return .inactive }
        if let expiry = row.expiresAt, expiry < .now { return .expired }
        switch row.status {
        case "trial": return .trial
        case "active", "grace_period", "promotional": return .active
        case "billing_issue": return .billingIssue
        case "expired", "revoked": return .expired
        default: return .inactive
        }
    }

    func loadActiveProgram(catalog: SessionCatalog) async throws -> QuietoRemoteProgram? {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        let rows: [QuietoProgramRow] = try await client.from("programs")
            .select("id,title,status,raw_program,plan_id,plan_version,rhythm,variant,includes_discovery,started_at")
            .eq("user_id", value: userID)
            .eq("status", value: "active")
            .limit(1)
            .execute().value
        guard let program = rows.first else { return nil }
        let steps: [QuietoProgramStepRow] = try await client.from("program_steps")
            .select("session_id,step_number,status,completed_at")
            .eq("program_id", value: program.id.uuidString)
            .order("step_number", ascending: true)
            .execute().value
        let sessions = steps.compactMap { step in catalog.sessions.first { $0.id == step.sessionID } }
        let rhythm = program.rhythm ?? program.rawProgram?["rhythm"]
        var plan: QuietoPlanState?
        if let id = program.planID.flatMap(QuietoPlanID.init(rawValue:)) {
            var state = QuietoPlanState(
                planID: id,
                startedAt: program.startedAt ?? .now,
                rhythm: rhythm.flatMap(ProgramRhythm.init(rawValue:)) ?? .regular,
                prefersShort: program.variant == "short",
                includesDiscovery: program.includesDiscovery ?? false
            )
            state.version = program.planVersion ?? PlanCatalog.version
            state.remoteID = program.id
            for step in steps where step.status == "completed" {
                state.completions[step.stepNumber] = step.completedAt ?? .now
            }
            plan = state
        }
        return QuietoRemoteProgram(
            id: program.id,
            title: program.title,
            sessions: sessions,
            completedSessionIDs: Set(steps.filter { $0.status == "completed" }.map(\.sessionID)),
            rhythm: rhythm,
            plan: plan
        )
    }

    /// Writes the plan and all its days. The active programme, if any, is
    /// marked 'abandoned' first: one active plan at a time.
    func startPlan(_ state: QuietoPlanState, days: [QuietoPlanDay], title: String) async throws -> UUID {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        try await client.from("programs")
            .update(["status": "abandoned"])
            .eq("user_id", value: userID)
            .eq("status", value: "active")
            .execute()
        let id = UUID()
        let program = QuietoProgramInsert(
            id: id, userID: userID, title: String(title.prefix(120)), status: "active", source: "catalog",
            rawProgram: ["rhythm": state.rhythm.rawValue], planID: state.planID.rawValue, planVersion: state.version,
            rhythm: state.rhythm.rawValue, variant: state.prefersShort ? "short" : "normal",
            includesDiscovery: state.includesDiscovery, startedAt: state.startedAt
        )
        try await client.from("programs").insert(program).execute()
        do {
            let steps = days.map { day in
                QuietoProgramStepInsert(
                    programID: id, stepNumber: day.number, dayNumber: day.number, sessionID: day.sessionID,
                    kind: day.kind.rawValue, status: state.completions[day.number] != nil ? "completed" : (day.number == 1 ? "available" : "planned"),
                    completedAt: state.completions[day.number], availableOn: nil
                )
            }
            try await client.from("program_steps").insert(steps).execute()
            return id
        } catch {
            _ = try? await client.from("programs").delete().eq("id", value: id.uuidString).execute()
            throw error
        }
    }

    func updateProgramRhythm(programID: UUID, rhythm: String) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        try await client.from("programs").update(["rhythm": rhythm]).eq("id", value: programID.uuidString).execute()
    }

    func completePlanStep(programID: UUID, dayNumber: Int, completedAt: Date, nextDayNumber: Int?, nextAvailableOn: Date?) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        try await client.from("program_steps")
            .update(["status": "completed", "completed_at": ISO8601DateFormatter().string(from: completedAt)])
            .eq("program_id", value: programID.uuidString)
            .eq("step_number", value: dayNumber)
            .execute()
        if let nextDayNumber, let nextAvailableOn {
            let day = DateFormatter.quietoDay.string(from: nextAvailableOn)
            try await client.from("program_steps")
                .update(["status": "available", "available_on": day])
                .eq("program_id", value: programID.uuidString)
                .eq("step_number", value: nextDayNumber)
                .execute()
        } else if nextDayNumber == nil {
            try await client.from("programs")
                .update(["status": "completed", "completed_at": ISO8601DateFormatter().string(from: completedAt)])
                .eq("id", value: programID.uuidString)
                .execute()
        }
    }

    func setFavorite(sessionID: String, favorite: Bool) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        let row = QuietoFavoriteUpsert(userID: userID, sessionID: sessionID, isFavorite: favorite)
        try await client.from("session_progress").upsert(row, onConflict: "user_id,session_id").execute()
    }

    func recordCompletion(sessionID: String, listenedSeconds: Int) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        let existing: [QuietoProgressRow] = try await client.from("session_progress")
            .select("session_id,completed_count,last_played_at,is_favorite,listened_seconds,play_count")
            .eq("user_id", value: userID).eq("session_id", value: sessionID).limit(1).execute().value
        let now = Date()
        let row = QuietoProgressUpsert(userID: userID, sessionID: sessionID, lastPositionSeconds: 0, listenedSeconds: (existing.first?.listenedSeconds ?? 0) + max(0, listenedSeconds), playCount: (existing.first?.playCount ?? 0) + 1, completedCount: (existing.first?.completedCount ?? 0) + 1, lastPlayedAt: now, completedAt: now, isFavorite: existing.first?.isFavorite ?? false)
        try await client.from("session_progress").upsert(row, onConflict: "user_id,session_id").execute()
        let event = QuietoListeningEventInsert(userID: userID, sessionID: sessionID, eventType: "completed", positionSeconds: max(0, listenedSeconds), listenedDeltaSeconds: max(0, listenedSeconds), clientEventID: UUID(), occurredAt: now)
        try await client.from("listening_events").insert(event).execute()

        // Plan steps are completed by the plan itself (`completePlanStep`), only
        // for the step open that day: a listen elsewhere never moves the plan.
    }

    func loadPreferences() async throws -> QuietoRemotePreferences? {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        let rows: [QuietoPreferenceRow] = try await client.from("user_preferences")
            .select("user_id,reminder_enabled,reminder_days,reminder_local_time,reminder_timezone,ambient_level,reduce_motion,larger_text")
            .eq("user_id", value: userID).limit(1).execute().value
        guard let row = rows.first else { return nil }
        let parts = (row.reminderLocalTime ?? "21:30").split(separator: ":").compactMap { Int($0) }
        return QuietoRemotePreferences(reminderEnabled: row.reminderEnabled, reminderDays: row.reminderDays, reminderHour: parts.first ?? 21, reminderMinute: parts.dropFirst().first ?? 30, reminderTimezone: row.reminderTimezone ?? TimeZone.autoupdatingCurrent.identifier, ambientLevel: row.ambientLevel, reduceMotion: row.reduceMotion, largerText: row.largerText)
    }

    func savePreferences(_ preferences: QuietoRemotePreferences) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        let row = QuietoPreferenceRow(userID: userID, reminderEnabled: preferences.reminderEnabled, reminderDays: preferences.reminderDays, reminderLocalTime: String(format: "%02d:%02d:00", preferences.reminderHour, preferences.reminderMinute), reminderTimezone: preferences.reminderTimezone, ambientLevel: preferences.ambientLevel, reduceMotion: preferences.reduceMotion, largerText: preferences.largerText)
        try await client.from("user_preferences").upsert(row, onConflict: "user_id").execute()
    }

    /// Questionnaire answers in `user_preferences.raw_preferences.onboarding`
    /// and the completion date on the profile.
    func saveOnboarding(answers: OnboardingAnswers) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        struct Row: Encodable {
            let user_id: String
            let raw_preferences: [String: [String: [String]]]
        }
        try await client.from("user_preferences").upsert(Row(user_id: userID, raw_preferences: ["onboarding": answers.choices.filter { $0.key != OnboardingStep.safety.rawValue }]), onConflict: "user_id").execute()
        try await client.from("profiles").update(["onboarding_completed_at": ISO8601DateFormatter().string(from: .now)]).eq("user_id", value: userID).execute()
    }

    func track(_ event: String, properties: [String: String]) async {
        guard let client else { return }
        let value = QuietoAnalyticsEvent(name: String(event.prefix(80)), properties: properties)
        guard let session = try? await client.auth.session else {
            if pendingAnalyticsEvents.count < 200 { pendingAnalyticsEvents.append(value) }
            return
        }
        await insert([value], userID: session.user.id.quietoUserID)
    }

    func flushPendingAnalytics() async {
        guard !pendingAnalyticsEvents.isEmpty, let session = try? await client?.auth.session else { return }
        let batch = pendingAnalyticsEvents
        pendingAnalyticsEvents = []
        await insert(batch, userID: session.user.id.quietoUserID)
    }

    private func insert(_ events: [QuietoAnalyticsEvent], userID: String) async {
        struct Row: Encodable { let user_id: String; let event_name: String; let properties: [String: String]; let client_event_id: UUID; let occurred_at: String }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let rows = events.map { Row(user_id: userID, event_name: $0.name, properties: $0.properties, client_event_id: $0.id, occurred_at: formatter.string(from: $0.occurredAt)) }
        _ = try? await client?.from("analytics_events").insert(rows).execute()
    }

    func saveConversationMessage(conversationID: UUID, title: String, message: LouaneMessage, temporary: Bool) async throws {
        guard !temporary, let client else { return }
        let userID = try await client.auth.session.user.id.quietoUserID
        try await client.from("louane_conversations").upsert(QuietoConversationInsert(id: conversationID, userID: userID, title: String(title.prefix(80)), isTemporary: false), onConflict: "id").execute()
        let recommendation = message.recommendation.map { rec in
            ["session_id": rec.sessionID, "ambience_id": rec.ambienceID, "reason": rec.reason].compactMapValues { $0 }
        }
        let row = QuietoMessageInsert(id: message.id, conversationID: conversationID, userID: userID, role: message.author == .louane ? "assistant" : message.author.rawValue, content: String(message.text.prefix(4_000)), status: message.isFailed ? "failed" : "complete", clientMessageID: message.id, recommendation: recommendation)
        try await client.from("louane_messages").upsert(row, onConflict: "user_id,client_message_id").execute()
    }

    func conversationHistory() async throws -> [QuietoConversationSummary] {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        return try await client.from("louane_conversations").select("id,title,is_temporary,updated_at").eq("user_id", value: userID).is("archived_at", value: nil).order("updated_at", ascending: false).execute().value
    }

    func messages(conversationID: UUID) async throws -> [LouaneMessage] {
        guard let client else { throw QuietoBackendError.notConfigured }
        let rows: [QuietoMessageRow] = try await client.from("louane_messages").select("id,role,content,recommendation,created_at").eq("conversation_id", value: conversationID.uuidString).order("created_at", ascending: true).execute().value
        return rows.map { row in
            let rec = row.recommendation.flatMap { values -> LouaneRecommendation? in
                let sessionID = values["session_id"], ambienceID = values["ambience_id"]
                guard sessionID != nil || ambienceID != nil else { return nil }
                let id = [sessionID, ambienceID].compactMap { $0 }.joined(separator: "+")
                return LouaneRecommendation(id: id, sessionID: sessionID, ambienceID: ambienceID, reason: values["reason"] ?? "")
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
        let userID = try await client.auth.session.user.id.quietoUserID
        let rows: [QuietoMemoryRow] = try await client.from("louane_memory").select("user_id,memory_text,consented_at").eq("user_id", value: userID).limit(1).execute().value
        return rows.first?.memoryText ?? ""
    }

    func saveMemory(_ value: String) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        try await client.from("louane_memory").upsert(QuietoMemoryRow(userID: userID, memoryText: String(value.prefix(4_000)), consentedAt: .now), onConflict: "user_id").execute()
    }

    func deleteMemory() async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        try await client.from("louane_memory").delete().eq("user_id", value: userID).execute()
    }

    /// Calls an Edge Function with the current Supabase session.
    func invokeFunction(_ name: String, method: String, json: [String: Any]? = nil, timeout: TimeInterval = 30) async throws -> Data {
        guard let base = QuietoBackendConfiguration.supabaseURL, let client else { throw QuietoBackendError.notConfigured }
        let session = try await client.auth.session
        var request = URLRequest(url: base.appendingPathComponent("functions/v1/\(name)"))
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(QuietoBackendConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw QuietoBackendError.serverRejected }
        return data
    }

    func invokeAccountData(method: String) async throws -> Data {
        try await invokeFunction("account-data", method: method)
    }

    /// The Apple code lets the server revoke Sign in with Apple, as Apple
    /// requires when an account is deleted.
    func deleteAccount(appleAuthorizationCode: String?) async throws {
        _ = try await invokeFunction("account-data", method: "DELETE", json: appleAuthorizationCode.map { ["apple_authorization_code": $0] })
    }

    /// Sends the StoreKit signed transactions held on this device; the server
    /// verifies them with Apple's certificates and answers with the access it
    /// grants (which also covers enterprise and legacy entitlements).
    func syncSubscriptions(signedTransactions: [String]) async throws -> Bool {
        let data = try await invokeFunction("subscription-sync", method: "POST", json: ["transactions": signedTransactions], timeout: 20)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object?["premium"] as? Bool == true
    }

    /// Links the Firebase account that used the same Apple ID, if any.
    func linkLegacyAccount() async throws -> Bool {
        let data = try await invokeFunction("account-data", method: "POST", json: ["action": "link-legacy"])
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let linked = object?["linked"] as? Bool == true
        if linked, let client, let userID = try? await client.auth.session.user.id.quietoUserID {
            let rows: [SupabaseProfile] = (try? await client.from("profiles").select().eq("user_id", value: userID).limit(1).execute().value) ?? []
            if let row = rows.first { profile = row }
        }
        return linked
    }

    func signedAudioURL(path: String) async throws -> URL {
        guard let client else { throw QuietoBackendError.notConfigured }
        // The SDK builds the full `/storage/v1/object/sign/...` URL itself.
        // One hour: AVPlayer keeps sending range requests with this URL for the
        // whole session (up to 20 min, longer when paused), and a background
        // download may be resumed later.
        return try await client.storage.from("session-audio").createSignedURL(path: path, expiresIn: 3_600)
    }
}

extension QuietoBackendError {
    static var serverRejected: QuietoBackendError { .requestRejected }
}

/// One analytics event as stored in `analytics_events`. `occurredAt` is the
/// device time, so events queued before the session keep their real order.
struct QuietoAnalyticsEvent {
    let name: String
    let properties: [String: String]
    var occurredAt = Date.now
    let id = UUID()
}

extension DateFormatter {
    /// `yyyy-MM-dd` in the iPhone's time zone, for Postgres `date` columns.
    static let quietoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
