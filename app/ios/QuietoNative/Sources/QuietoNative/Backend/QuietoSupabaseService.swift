import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

enum QuietoBackendConfiguration {
    static var supabaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !raw.hasPrefix("REPLACE_"), let url = URL(string: raw) else { return nil }
        return url
    }

    static var publishableKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.hasPrefix("REPLACE_"), !key.isEmpty else { return nil }
        return key
    }
}

enum QuietoAuthState: Equatable {
    case unavailable
    case loading
    case anonymous(userID: String)
    case authenticated(userID: String, email: String?)
    case failed(message: String)
}

struct SupabaseProfile: Codable, Equatable {
    let userID: String
    var firebaseUID: String?
    var firstName: String?
    var locale: String
    var isAnonymous: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case firebaseUID = "firebase_uid"
        case firstName = "first_name"
        case locale
        case isAnonymous = "is_anonymous"
    }
}

@MainActor
final class QuietoSupabaseService: NSObject, ObservableObject {
    static let shared = QuietoSupabaseService()

    @Published private(set) var state: QuietoAuthState = .loading
    @Published private(set) var profile: SupabaseProfile?

    private(set) var client: SupabaseClient?
    private var rawNonce: String?
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    override private init() {
        if let url = QuietoBackendConfiguration.supabaseURL,
           let key = QuietoBackendConfiguration.publishableKey {
            client = SupabaseClient(supabaseURL: url, supabaseKey: key)
        } else {
            state = .unavailable
        }
        super.init()
    }

    func bootstrap() async {
        guard let client else { state = .unavailable; return }
        state = .loading
        do {
            let session = try await client.auth.session
            await apply(session: session)
        } catch {
            do {
                let session = try await client.auth.signInAnonymously()
                await apply(session: session)
            } catch {
                state = .failed(message: "Impossible d’ouvrir une session sécurisée.")
            }
        }
    }

    func signInWithApple() async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let nonce = Self.randomNonce()
        rawNonce = nonce
        let credential = try await requestAppleCredential(hashedNonce: Self.sha256(nonce))
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw QuietoBackendError.missingAppleToken
        }
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
        await apply(session: session)
        if let firstName = credential.fullName?.givenName, !firstName.isEmpty {
            try await updateProfile(firstName: firstName)
        }
    }

    func signOutToAnonymous() async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        try await client.auth.signOut()
        let session = try await client.auth.signInAnonymously()
        await apply(session: session)
    }

    func updateProfile(firstName: String) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let session = try await client.auth.session
        let clean = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = SupabaseProfile(
            userID: session.user.id.uuidString,
            firebaseUID: profile?.firebaseUID,
            firstName: clean.isEmpty ? nil : clean,
            locale: Locale.current.language.languageCode?.identifier ?? "fr",
            isAnonymous: session.user.isAnonymous
        )
        try await client.from("profiles").upsert(value, onConflict: "user_id").execute()
        profile = value
    }

    private func apply(session: Session) async {
        let id = session.user.id.uuidString
        state = session.user.isAnonymous
            ? .anonymous(userID: id)
            : .authenticated(userID: id, email: session.user.email)
        do {
            let rows: [SupabaseProfile] = try await client?.from("profiles")
                .select()
                .eq("user_id", value: id)
                .limit(1)
                .execute().value ?? []
            if let existing = rows.first {
                profile = existing
            } else {
                try await updateProfile(firstName: UserDefaults.standard.string(forKey: "quieto.profile.firstName") ?? "")
            }
        } catch {
            // Auth remains usable if profile synchronisation is temporarily offline.
        }
    }

    private func requestAppleCredential(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in characters.randomElement(using: &generator)! })
    }
}

extension QuietoSupabaseService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                continuation?.resume(throwing: QuietoBackendError.missingAppleToken)
                continuation = nil
                return
            }
            continuation?.resume(returning: credential)
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

enum QuietoBackendError: LocalizedError {
    case notConfigured
    case missingAppleToken
    case requestRejected

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Supabase n’est pas encore configuré."
        case .missingAppleToken: "Apple n’a pas fourni de jeton d’identité valide."
        case .requestRejected: "Le serveur a refusé cette opération. Réessaie plus tard."
        }
    }
}
