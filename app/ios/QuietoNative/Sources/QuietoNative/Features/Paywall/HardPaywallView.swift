import SwiftUI

/// Shown over the whole app while there is no active entitlement. The
/// purchase UI itself is the Superwall paywall attached to the
/// `quieto_hard_paywall` placement in the Superwall dashboard.
struct HardPaywallView: View {
    @ObservedObject var subscriptions: QuietoSuperwallService
    @ObservedObject var backend: QuietoSupabaseService
    @State private var isSigningIn = false
    @State private var message: String?

    var body: some View {
        ZStack {
            QuietoColor.background.ignoresSafeArea()
            if subscriptions.access == .checking {
                ProgressView().tint(QuietoColor.mint).accessibilityLabel("Vérification de ton abonnement")
            } else {
                content
            }
        }
        .foregroundStyle(QuietoColor.textPrimary)
        .onAppear { if subscriptions.access == .locked { subscriptions.presentPaywall() } }
        .onChange(of: subscriptions.access) { _, access in if access == .locked { subscriptions.presentPaywall() } }
        .alert("Quieto", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text((message ?? "").quietoLocalized) }
    }

    private var content: some View {
        VStack(spacing: QuietoSpacing.lg) {
            Spacer()
            Text("quieto").font(QuietoFont.serif(30, weight: .semibold))
            VStack(spacing: QuietoSpacing.sm) {
                Text("Ta pause commence ici.").font(QuietoFont.serif(32, weight: .semibold)).multilineTextAlignment(.center)
                Text("Séances guidées, respirations et Louane : tout Quieto est inclus dans l’abonnement.")
                    .font(QuietoFont.sans(16)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 12) {
                Button { subscriptions.presentPaywall() } label: {
                    Text("Découvrir l’abonnement").font(QuietoFont.sans(17, weight: .semibold)).foregroundStyle(QuietoColor.background)
                        .frame(maxWidth: .infinity).padding(.vertical, 16).background(QuietoColor.mint, in: Capsule())
                }
                Button("Restaurer mes achats") {
                    subscriptions.restorePurchases()
                    message = subscriptions.lastMessage ?? "Restauration en cours…"
                }
                .font(QuietoFont.sans(15, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                if case .authenticated = backend.state {} else if backend.client != nil {
                    Button(isSigningIn ? "Connexion…" : "J’ai déjà un compte (Apple)") {
                        isSigningIn = true
                        Task {
                            defer { isSigningIn = false }
                            do { try await backend.signInWithApple() } catch { message = error.localizedDescription }
                        }
                    }
                    .disabled(isSigningIn)
                    .font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary)
                }
                if let note = subscriptions.lastMessage, !subscriptions.isConfigured {
                    Text(note.quietoLocalized).font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, QuietoSpacing.md)
            Text("Besoin d’aide tout de suite ? Le 3114 répond 24h/24, gratuitement.")
                .font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center)
                .padding(.horizontal, 28).padding(.bottom, QuietoSpacing.md)
        }
        .frame(maxWidth: QuietoMetrics.contentMaxWidth)
    }
}
