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
            "memoire": temporary ? "" : (UserDefaults.standard.string(forKey: "quieto.native.louane.memory") ?? ""),
            "profil": [:],
            "sante": "",
            "santeDispo": false,
            "abonne": false,
            "ecoutes": [],
            "parcours": NSNull(),
            "compteurTotal": 0,
            "compteurJour": 0,
            "vigie": "native",
            "session": UUID().uuidString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": payload])

        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "QuietoNative.Louane", code: 2, userInfo: [NSLocalizedDescriptionKey: "Le service Louane est momentanément indisponible."])
        }
        guard let root = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = (root["result"] ?? root["data"]) as? [String: Any] else {
            throw NSError(domain: "QuietoNative.Louane", code: 3, userInfo: [NSLocalizedDescriptionKey: "La réponse de Louane est illisible."])
        }
        if data["paywall"] as? Bool == true {
            throw NSError(domain: "QuietoNative.Louane", code: 4, userInfo: [NSLocalizedDescriptionKey: "La limite gratuite est atteinte."])
        }
        if data["plafond"] as? Bool == true {
            throw NSError(domain: "QuietoNative.Louane", code: 5, userInfo: [NSLocalizedDescriptionKey: "Louane a atteint sa limite pour aujourd’hui."])
        }
        let bubbles = (data["bulles"] as? [String])?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
        let text = bubbles.isEmpty ? (data["reponse"] as? String ?? "") : bubbles.joined(separator: "\n\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "QuietoNative.Louane", code: 6, userInfo: [NSLocalizedDescriptionKey: "Louane n’a pas renvoyé de réponse."])
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

final class LouaneMemoryStore: LouaneMemoryProviding, ObservableObject {
    @Published private(set) var text: String
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults; text = defaults.string(forKey: "quieto.native.louane.memory") ?? "" }
    func update(_ text: String) { self.text = text; defaults.set(text, forKey: "quieto.native.louane.memory") }
    func remove() { update("") }
}

struct LouanePreviewBackend: LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply {
        try await Task.sleep(nanoseconds: 180_000_000)
        return LouaneBackendReply(text: "Merci de me le dire. On peut prendre une pause et regarder ce qui t’aiderait maintenant.", recommendation: nil)
    }
}
