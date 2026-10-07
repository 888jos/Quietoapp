import Foundation

/// Calls the `enterprise-access` Edge Function (see supabase/functions/ENTREPRISE.md):
/// `{code}` previews the company, `{code, confirmer: true}` takes the seat.
@MainActor
final class EnterpriseAccessService: EnterpriseAccessServicing {
    private let backend: QuietoSupabaseService

    init(backend: QuietoSupabaseService) { self.backend = backend }

    var isConfigured: Bool { backend.isConfigured && QuietoBackendConfiguration.supabaseURL != nil }

    func preview(code: String) async throws -> String {
        try await send(code: code, confirm: false)
    }

    func activate(code: String) async throws -> String {
        try await send(code: code, confirm: true)
    }

    private func send(code: String, confirm: Bool) async throws -> String {
        guard let base = QuietoBackendConfiguration.supabaseURL else { throw EnterpriseAccessError.unavailable }
        let token = try await backend.accessToken()
        var request = URLRequest(url: base.appendingPathComponent("functions/v1/enterprise-access"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(QuietoBackendConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        var body: [String: Any] = ["code": code]
        if confirm { body["confirmer"] = true }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EnterpriseAccessError.unavailable }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if (200..<300).contains(http.statusCode), let name = json["nom"] as? String {
            return name
        }
        // The server writes its messages in French: they are keys of the string tables.
        let message = (json["message"] as? String)?.quietoLocalized ?? EnterpriseAccessError.unavailable.errorDescription ?? ""
        switch json["raison"] as? String {
        case "compte"?: throw EnterpriseAccessError.needsAppleAccount(message)
        case "inconnu"?, "inactif"?, "complet"?, "quota"?: throw EnterpriseAccessError.refused(message)
        default: throw EnterpriseAccessError.unavailable
        }
    }
}
