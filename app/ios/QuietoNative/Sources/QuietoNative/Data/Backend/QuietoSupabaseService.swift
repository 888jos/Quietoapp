import AuthenticationServices
import Combine
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

/// Session changes other services react to (wired by `SessionCoordinator`).
enum QuietoIdentityEvent: Equatable {
    case identified(userID: String)
    case signedOut
    case legacyAccountLinked
}

enum QuietoAuthState: Equatable {
    case unavailable
    case loading
    case anonymous(userID: String)
    case authenticated(userID: String, email: String?)
    case failed(message: String)
}

private struct SupabaseProfileWrite: Encodable {
    let userID: String
    let firstName: String?
    let locale: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case firstName = "first_name"
        case locale
    }
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
    @Published private(set) var state: QuietoAuthState = .loading
    @Published var profile: SupabaseProfile?

    /// Notified on sign-in, sign-out and legacy account linking.
    var onIdentityEvent: ((QuietoIdentityEvent) -> Void)?

    private(set) var client: SupabaseClient?
    /// Analytics events tracked before the first session exists (the start of
    /// the onboarding), sent once `apply(session:)` has created the profile.
    var pendingAnalyticsEvents: [QuietoAnalyticsEvent] = []
    private let preferences: QuietoPreferences
    private var rawNonce: String?
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    init(preferences: QuietoPreferences) {
        self.preferences = preferences
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
        } catch let error where Self.isNetworkFailure(error) {
            // Offline while the token needed a refresh: keep the stored identity
            // (an Apple account must never be swapped for a new anonymous one
            // because of a bad connection). The SDK refreshes it once online.
            if let stored = client.auth.currentSession {
                await apply(session: stored)
            } else {
                state = .failed(message: "Connexion impossible pour le moment.".quietoLocalized)
            }
        } catch {
            // No session at all, or one the server rejected for good.
            do {
                let session = try await client.auth.signInAnonymously()
                await apply(session: session)
            } catch {
                state = .failed(message: "Impossible d’ouvrir une session sécurisée.".quietoLocalized)
            }
        }
    }

    private static func isNetworkFailure(_ error: Error) -> Bool {
        if error is URLError { return true }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
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
        let credentials = OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        let session: Session
        if let current = try? await client.auth.session, current.user.isAnonymous {
            // Keep the anonymous account (and everything already saved under it)
            // by attaching Apple to it. If this Apple ID already owns a Quieto
            // account, switch to that account instead.
            do {
                session = try await client.auth.linkIdentityWithIdToken(credentials: credentials)
            } catch {
                session = try await client.auth.signInWithIdToken(credentials: credentials)
            }
        } else {
            session = try await client.auth.signInWithIdToken(credentials: credentials)
        }
        await apply(session: session)
        // Former Flutter users: inherit the Firebase account behind the same
        // Apple ID (Louane memory, enterprise access, Android subscription).
        if (try? await linkLegacyAccount()) == true {
            onIdentityEvent?(.legacyAccountLinked)
        }
        if let firstName = credential.fullName?.givenName, !firstName.isEmpty {
            try await updateProfile(firstName: firstName)
        }
    }

    func appleAuthorizationCodeForDeletion() async throws -> String? {
        guard let client, let user = try? await client.auth.session.user,
              user.identities?.contains(where: { $0.provider == "apple" }) == true else { return nil }
        let credential = try await requestAppleCredential(hashedNonce: Self.sha256(Self.randomNonce()))
        return credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
    }

    func signOutToAnonymous() async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        try await client.auth.signOut()
        onIdentityEvent?(.signedOut)
        profile = nil
        let session = try await client.auth.signInAnonymously()
        await apply(session: session)
    }

    /// After a server-side account deletion: drop the local session without
    /// calling the server again, then start a fresh anonymous identity.
    func resetAfterAccountDeletion() async {
        guard let client else { return }
        try? await client.auth.signOut(scope: .local)
        onIdentityEvent?(.signedOut)
        profile = nil
        await bootstrap()
    }

    func updateProfile(firstName: String) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        let session = try await client.auth.session
        let clean = String(firstName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        // Only cosmetic columns: `firebase_uid` and `is_anonymous` are server-owned.
        let value = SupabaseProfileWrite(
            userID: session.user.id.quietoUserID,
            firstName: clean.isEmpty ? nil : clean,
            locale: Self.supportedLocale
        )
        try await client.from("profiles").upsert(value, onConflict: "user_id").execute()
        profile = SupabaseProfile(
            userID: value.userID,
            firebaseUID: profile?.firebaseUID,
            firstName: value.firstName,
            locale: value.locale,
            isAnonymous: session.user.isAnonymous
        )
    }

    /// Bearer token for Edge Functions called outside the SDK (Louane).
    func accessToken() async throws -> String {
        guard let client else { throw QuietoBackendError.notConfigured }
        return try await client.auth.session.accessToken
    }

    private static var supportedLocale: String {
        QuietoLocalization.languageCode
    }

    private func apply(session: Session) async {
        let id = session.user.id.quietoUserID
        onIdentityEvent?(.identified(userID: id))
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
                try await updateProfile(firstName: preferences.firstName)
            }
        } catch {
            // Auth remains usable if profile synchronisation is temporarily offline.
        }
        await flushPendingAnalytics()
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
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in characters.randomElement(using: &generator)! })
    }
}

extension QuietoSupabaseService: AuthServicing {
    var statePublisher: AnyPublisher<QuietoAuthState, Never> { $state.eraseToAnyPublisher() }
    var remoteFirstName: String? { profile?.firstName }
    var isConfigured: Bool { client != nil }
}

extension QuietoSupabaseService: AccountDataServicing, ProgramRepository, SessionProgressSyncing, LouaneRepository, AudioURLSigning, SubscriptionServerSyncing {}

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
        case .notConfigured: "Supabase n’est pas encore configuré.".quietoLocalized
        case .missingAppleToken: "Apple n’a pas fourni de jeton d’identité valide.".quietoLocalized
        case .requestRejected: "Le serveur a refusé cette opération. Réessaie plus tard.".quietoLocalized
        }
    }
}

extension UUID {
    /// The account id as Postgres and the JWT `sub` claim write it. Swift's
    /// `uuidString` is upper-case, and every `user_id` column is text compared
    /// with `auth.jwt()->>'sub'` by the row level security policies.
    var quietoUserID: String { uuidString.lowercased() }
}
