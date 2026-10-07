import SwiftUI

/// Shown over the whole app while there is no active entitlement. The
/// purchase UI itself is the Superwall paywall attached to the
/// `quieto_hard_paywall` placement in the Superwall dashboard.
struct HardPaywallView: View {
    @ObservedObject var model: PaywallViewModel
    /// Account actions Apple requires to stay reachable without a subscription
    /// (guidelines 3.1.2 and 5.1.1(v)): manage, legal pages, account deletion.
    @ObservedObject var profile: ProfileViewModel
    /// Employees whose company offers Quieto get in with the HR code.
    @ObservedObject var enterprise: EnterpriseCodeViewModel
    @State private var presented: ProfileDestination?
    @State private var showingEnterpriseCode = false

    var body: some View {
        ZStack {
            QuietoBackground()
            if model.isChecking {
                ProgressView().tint(QuietoColor.mint).accessibilityLabel("Vérification de ton abonnement")
            } else {
                content
            }
        }
        .foregroundStyle(QuietoColor.textPrimary)
        .onAppear { model.presentIfLocked() }
        .onChange(of: model.access) { _, _ in model.presentIfLocked() }
        .sheet(item: $presented) { destination in ProfileDestinationView(destination: destination, model: profile) }
        .sheet(isPresented: $showingEnterpriseCode) { EnterpriseCodeView(model: enterprise) }
        .alert("Quieto", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK") { model.message = nil }
        } message: { Text((model.message ?? "").quietoLocalized) }
    }

    private var content: some View {
        VStack(spacing: QuietoSpacing.lg) {
            Spacer()
            moon
            Text("quieto").font(QuietoFont.heading(.title, weight: .semibold))
            VStack(spacing: QuietoSpacing.sm) {
                Text("Ta pause commence ici.").font(QuietoFont.heading(.display, weight: .semibold)).multilineTextAlignment(.center)
                Text("Séances guidées, respirations et Louane : tout Quieto est inclus dans l’abonnement.")
                    .font(QuietoFont.sans(.body)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            benefits
            Spacer()
            VStack(spacing: 12) {
                QuietoPrimaryButton(title: "Découvrir l’abonnement", systemImage: nil) { model.presentPaywall() }
                Button("Restaurer mes achats") { model.restorePurchases() }
                .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                if model.canSignIn {
                    Button((model.isSigningIn ? "Connexion…" : "J’ai déjà un compte (Apple)").quietoLocalized) { model.signInWithApple() }
                    .disabled(model.isSigningIn)
                    .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                }
                if enterprise.isAvailable {
                    Button("J’ai un code entreprise") { showingEnterpriseCode = true }
                        .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                }
                if let note = model.configurationNote {
                    Text(note.quietoLocalized).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, QuietoSpacing.md)
            accountLinks
            Link(destination: CrisisLine.current.primaryURL) {
                Text(CrisisLine.current.helpLine)
                    .font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary).multilineTextAlignment(.center)
                    .underline()
            }
            .accessibilityHint(QuietoLocalization.format("Appeler le %@", CrisisLine.current.primaryNumber))
            .padding(.horizontal, 28).padding(.bottom, QuietoSpacing.md)
        }
        .frame(maxWidth: QuietoMetrics.contentMaxWidth)
    }

    /// A soft moon rising over the night sky, the brand's quiet signature.
    private var moon: some View {
        Circle()
            .fill(RadialGradient(colors: [QuietoColor.mintLight, QuietoColor.mint.opacity(0.85), QuietoColor.aurora.opacity(0.6)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: 52))
            .frame(width: 72, height: 72)
            .background { Circle().fill(QuietoColor.mint.opacity(0.35)).frame(width: 140, height: 140).blur(radius: 40) }
            .accessibilityHidden(true)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("headphones", "Séances guidées et programmes jour après jour")
            benefit("bubble.left.and.text.bubble.right", "Louane, un espace de parole disponible à toute heure")
            benefit("moon.stars", "Ambiances pour t’endormir et te concentrer")
        }
        .padding(QuietoSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .quietoSurface(cornerRadius: QuietoRadius.card)
        .padding(.horizontal, QuietoSpacing.md)
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                .frame(width: 32, height: 32).background(QuietoColor.mint.opacity(0.12), in: Circle())
            Text(text.quietoLocalized).font(QuietoFont.sans(.callout, weight: .medium)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accountLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button("Gérer mon abonnement") { profile.manageSubscription() }
                Button("Supprimer mon compte") { presented = .delete }
            }
            HStack(spacing: 16) {
                Link("Conditions d’utilisation", destination: URL(string: "https://cofonde.com/quieto-cgu")!)
                Link("Politique de confidentialité", destination: URL(string: "https://cofonde.com/quieto-confidentialite")!)
            }
        }
        .font(QuietoFont.sans(.caption))
        .foregroundStyle(QuietoColor.textSecondary)
        .buttonStyle(.plain)
        // Result of a deletion or of the subscription sheet.
        .alert("Quieto", isPresented: Binding(get: { profile.feedback != nil }, set: { if !$0 { profile.feedback = nil } })) {
            Button("OK") { profile.feedback = nil }
        } message: { Text((profile.feedback ?? "").quietoLocalized) }
    }
}
