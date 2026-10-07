import Foundation
import HealthKit

struct URLSessionLouaneBackend: LouaneBackendProviding {
    let backend: QuietoSupabaseService
    let preferences: QuietoPreferences
    let memory: LouaneMemoryProviding
    /// Listens and programme, read on the main actor at each message.
    var context: @MainActor () -> LouaneClientContext = { .empty }
    /// Anonymous id of this app launch for the server stats (`s_` + 16 hex).
    private static let statsSessionID: String = "s_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(16)

    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        do {
            return try await request(message: message, history: history, temporary: temporary)
        } catch let error as LouaneServiceError {
            #if DEBUG
            print("[Louane] \(error): \(error.diagnostic)")
            #endif
            throw error
        }
    }

    private func request(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        guard let base = QuietoBackendConfiguration.supabaseURL, let apiKey = QuietoBackendConfiguration.publishableKey else {
            throw LouaneServiceError.notConfigured
        }
        let accessToken: String
        do { accessToken = try await backend.accessToken() } catch QuietoBackendError.notConfigured {
            throw LouaneServiceError.notConfigured
        } catch {
            throw LouaneServiceError.signedOut
        }
        let endpoint = base.appendingPathComponent("functions/v1/louane")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("QuietoNative/1", forHTTPHeaderField: "X-Quieto-Client")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "fr_FR")
        dayFormatter.dateFormat = "EEEE"
        // 24-hour "HH:mm" whatever the iPhone's settings: the server keeps five
        // characters, so "11:47 PM" would have lost the PM.
        let hourFormatter = DateFormatter()
        hourFormatter.locale = Locale(identifier: "en_US_POSIX")
        hourFormatter.dateFormat = "HH:mm"
        let now = Date()
        let recentHistory: [[String: String]] = history.suffix(20).compactMap { item in
            guard item.author != .system else { return nil }
            return ["role": item.author == .user ? "user" : "assistant", "content": String(item.text.prefix(2_000))]
        }
        let context = await context()
        let payload: [String: Any] = [
            "message": String(message.prefix(2_000)),
            "historique": recentHistory,
            "heure": hourFormatter.string(from: now),
            "jour": dayFormatter.string(from: now),
            "accueil": "",
            "prenom": preferences.firstName,
            // Language of the app, so Louane answers in it.
            "langue": QuietoLocalization.languageCode,
            "memoire": temporary ? "" : memory.text,
            "profil": preferences.louaneServerProfile,
            // Health data never leaves the iPhone: no wellbeing summary is sent,
            // only whether Apple Health exists on this device (an iPhone, not
            // Android), so Louane never claims a missing integration.
            "sante": "",
            "santeDispo": HKHealthStore.isHealthDataAvailable(),
            // A temporary conversation tells nothing about the person's habits.
            "ecoutes": temporary ? [] : context.listens.map { ["id": $0.sessionID, "fois": $0.count, "jours": $0.daysAgo] as [String: Any] },
            "parcours": temporary ? NSNull() : Self.programmePayload(context.programme),
            "compteurTotal": 0,
            "compteurJour": 0,
            "session": Self.statsSessionID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": payload])

        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LouaneServiceError.unavailable }
        switch http.statusCode {
        case 200..<300: break
        case 401: throw LouaneServiceError.signedOut
        case 402: throw LouaneServiceError.premiumRequired
        case 404: throw LouaneServiceError.notDeployed
        case 429: throw LouaneServiceError.tooFast
        case 503 where String(decoding: body, as: UTF8.self).contains("not_configured"): throw LouaneServiceError.serverNotConfigured
        default: throw LouaneServiceError.unavailable
        }
        return try Self.parse(body, temporary: temporary)
    }

    static func programmePayload(_ programme: LouaneClientContext.Programme?) -> Any {
        guard let programme else { return NSNull() }
        var payload: [String: Any] = [
            "actif": programme.isActive,
            "termine": programme.isFinished,
            "titre": programme.title.quietoLocalized,
            "jour": programme.step,
            "seanceDuJourFaite": programme.doneToday,
            "prochaine": programme.nextSessionID ?? ""
        ]
        if let plan = programme.planID { payload["plan"] = plan.rawValue }
        if let total = programme.totalSteps { payload["etapes"] = total }
        if let phase = programme.phase { payload["phase"] = phase.rawValue }
        return payload
    }

    /// `{"result": {...}}` → the reply, its launch card and the memory sheet.
    static func parse(_ body: Data, temporary: Bool) throws -> LouaneBackendReply {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = (root["result"] ?? root["data"]) as? [String: Any] else {
            throw LouaneServiceError.unreadable
        }
        // A crisis answer (3114) always wins over quota flags.
        if data["securite"] as? Bool != true {
            if data["paywall"] as? Bool == true { throw LouaneServiceError.premiumRequired }
            if data["plafond"] as? Bool == true { throw LouaneServiceError.dailyLimit }
        }
        let bubbles = (data["bulles"] as? [String])?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
        let text = bubbles.isEmpty ? (data["reponse"] as? String ?? "") : bubbles.joined(separator: "\n\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LouaneServiceError.empty
        }
        let session = data["seance"] as? [String: Any]
        let sound = data["son"] as? [String: Any]
        let sessionID = (session?["id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let ambienceID = (sound?["id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        var recommendation: LouaneRecommendation?
        if sessionID != nil || ambienceID != nil {
            let reason = [session?["raison"], sound?["raison"]].compactMap { $0 as? String }.first { !$0.isEmpty } ?? ""
            recommendation = LouaneRecommendation(
                id: [sessionID, ambienceID].compactMap { $0 }.joined(separator: "+"),
                sessionID: sessionID,
                ambienceID: ambienceID,
                reason: reason
            )
        }
        // A temporary conversation must not feed the long-term memory.
        let updatedMemory = temporary ? nil : (data["memoire"] as? String)
        return LouaneBackendReply(text: text, recommendation: recommendation, memory: updatedMemory)
    }
}

struct UnavailableLouaneBackend: LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        throw NSError(domain: "QuietoNative.Louane", code: 1, userInfo: [NSLocalizedDescriptionKey: "Le service Louane n’est pas encore relié à cette cible native.".quietoLocalized])
    }
}

/// Louane's memory is sensitive: it lives in a file protected with
/// `.complete` data protection, not in UserDefaults (which ends up in plain
/// backups and preference plists).
final class LouaneMemoryStore: LouaneMemoryProviding, ObservableObject {
    @Published private(set) var text: String
    private static let legacyDefaultsKey = "quieto.native.louane.memory"

    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Quieto/Private/louane-memory.txt")
    }

    init(defaults: UserDefaults = .standard) {
        if let legacy = defaults.string(forKey: Self.legacyDefaultsKey) {
            Self.write(legacy)
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
        }
        text = Self.storedText()
    }

    static func storedText() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    private static func write(_ value: String) {
        let url = fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if value.isEmpty {
            try? FileManager.default.removeItem(at: url)
        } else {
            try? Data(value.utf8).write(to: url, options: [.atomic, .completeFileProtection])
        }
    }

    func update(_ text: String) { self.text = text; Self.write(text) }
    func remove() { update("") }
}

struct LouanePreviewBackend: LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        try await Task.sleep(nanoseconds: 180_000_000)
        return LouaneBackendReply(text: "Merci de me le dire. On peut prendre une pause et regarder ce qui t’aiderait maintenant.".quietoLocalized, recommendation: nil)
    }
}
