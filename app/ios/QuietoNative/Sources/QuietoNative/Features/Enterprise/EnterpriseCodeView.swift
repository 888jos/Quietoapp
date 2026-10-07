import SwiftUI

/// « Accès offert par mon entreprise » : the employee types the code from HR.
struct EnterpriseCodeView: View {
    @ObservedObject var model: EnterpriseCodeViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                QuietoBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                        Image(systemName: "building.2")
                            .font(.system(size: 30, weight: .light)).foregroundStyle(QuietoColor.mint)
                        switch model.step {
                        case .entry: entry
                        case .confirm(let company): confirm(company)
                        case .activated(let company): activated(company)
                        }
                    }
                    .frame(maxWidth: QuietoMetrics.contentMaxWidth, alignment: .leading)
                    .padding(QuietoSpacing.md)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(Text("Code entreprise".quietoLocalized))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.reset(); fieldFocused = true }
    }

    private var entry: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.md) {
            Text("Ton entreprise t’offre Quieto ?").font(QuietoFont.heading(.title, weight: .semibold))
            Text("Saisis le code transmis par ta RH. Il active ton accès complet, sans paiement de ta part.")
                .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            TextField("", text: $model.code, prompt: Text("Code entreprise").foregroundStyle(QuietoColor.textSecondary))
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($fieldFocused)
                .submitLabel(.go)
                .onSubmit { if model.canSubmit { Task { await model.check() } } }
                .padding(14)
                .quietoSurface(cornerRadius: QuietoRadius.card)
                .accessibilityLabel("Code entreprise")
            feedback
            QuietoPrimaryButton(title: model.isWorking ? "Vérification…" : "Vérifier le code", systemImage: "checkmark") {
                Task { await model.check() }
            }
            .disabled(!model.canSubmit)
            .opacity(model.canSubmit ? 1 : 0.5)
        }
    }

    private func confirm(_ company: String) -> some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.md) {
            Text("Accès offert par").font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            Text(verbatim: company).font(QuietoFont.heading(.title, weight: .semibold))
            Text("Ton accès dure tant que ton entreprise renouvelle son abonnement. Ton employeur ne voit ni tes séances ni tes conversations avec Louane.")
                .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            feedback
            QuietoPrimaryButton(title: model.isWorking ? "Activation…" : "Activer mon accès", systemImage: "sparkles") {
                Task { await model.activate() }
            }
            .disabled(model.isWorking)
            Button("Ce n’est pas la bonne entreprise") { model.reset() }
                .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    private func activated(_ company: String) -> some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.md) {
            Label("Accès activé", systemImage: "checkmark.seal.fill")
                .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
            Text(QuietoLocalization.format("Bienvenue ! Quieto t’est offert par %@.", company))
                .font(QuietoFont.heading(.title, weight: .semibold))
            Text("Toutes les séances, les respirations et Louane sont maintenant ouvertes.")
                .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            QuietoPrimaryButton(title: "Commencer", systemImage: "play.fill") { dismiss() }
        }
    }

    @ViewBuilder private var feedback: some View {
        if let message = model.errorMessage {
            Text(message.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.danger)
            if model.needsAppleAccount {
                Button((model.isWorking ? "Connexion…" : "Se connecter avec Apple").quietoLocalized) { Task { await model.signInWithApple() } }
                    .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                    .disabled(model.isWorking)
            }
        }
    }
}
