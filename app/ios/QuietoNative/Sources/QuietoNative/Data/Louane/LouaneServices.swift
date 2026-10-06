import Foundation

struct URLSessionLouaneBackend: LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        guard let base = QuietoBackendConfiguration.supabaseURL,
              let client = await QuietoSupabaseService.shared.client else { throw QuietoBackendError.notConfigured }
        let auth = try await client.auth.session
        let endpoint = base.appendingPathComponent("functions/v1/louane-proxy")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("QuietoNative/1", forHTTPHeaderField: "X-Quieto-Client")
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(QuietoBackendConfiguration.publishableKey, forHTTPHeaderField: "apikey")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE"
        let now = Date()
        let recentHistory: [[String: String]] = history.suffix(20).compactMap { item in
            guard item.author != .system else { return nil }
            return ["role": item.author == .user ? "user" : "assistant", "content": String(item.text.prefix(2_000))]
        }
        let payload: [String: Any] = [
            "message": String(message.prefix(2_000)),
            "historique": recentHistory,
            "heure": DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .short),
            "jour": formatter.string(from: now),
            "accueil": "",
            "prenom": UserDefaults.standard.string(forKey: "quieto.profile.firstName") ?? "",
            "memoire": temporary ? "" : LouaneMemoryStore.storedText(),
            "profil": OnboardingViewModel.storedServerProfile(),
            "sante": "",
            "santeDispo": false,
            "ecoutes": [],
            "parcours": NSNull(),
            "compteurTotal": 0,
            "compteurJour": 0,
            "vigie": "native",
            "session": UUID().uuidString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": payload])

        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LouaneServiceError.unavailable }
        if http.statusCode == 402 { throw LouaneServiceError.premiumRequired }
        guard (200..<300).contains(http.statusCode) else { throw LouaneServiceError.unavailable }
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
        var recommendation: LouaneRecommendation?
        if let session = data["seance"] as? [String: Any], let id = session["id"] as? String, !id.isEmpty {
            recommendation = LouaneRecommendation(id: id, sessionID: id, reason: session["raison"] as? String ?? "")
        }
        return LouaneBackendReply(text: text, recommendation: recommendation)
    }
}

struct UnavailableLouaneBackend: LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        throw NSError(domain: "QuietoNative.Louane", code: 1, userInfo: [NSLocalizedDescriptionKey: "Le service Louane n’est pas encore relié à cette cible native."])
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
        return LouaneBackendReply(text: "Merci de me le dire. On peut prendre une pause et regarder ce qui t’aiderait maintenant.", recommendation: nil)
    }
}
