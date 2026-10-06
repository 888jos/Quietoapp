import SwiftUI

struct ProfileView: View {
    @StateObject private var model = ProfileViewModel()
    @State private var presented: ProfileDestination?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            QuietoColor.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                    header
                    weeklyActivity
                    preferenceSection
                    accountSection
                    privacySection
                    helpSection
                    if !model.isAnonymous {
                        Button { model.signOut() } label: { Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity, minHeight: 46) }
                        .buttonStyle(.bordered).tint(QuietoColor.textPrimary)
                    }
                    Text("Quieto · Version \(appVersion)").font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary).frame(maxWidth: .infinity)
                }
                .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                .padding(.horizontal, QuietoSpacing.md)
                .padding(.top, QuietoSpacing.sm)
                .padding(.bottom, 128)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 92) }
        .sheet(item: $presented) { destination in ProfileDestinationView(destination: destination, model: model) }
        .sheet(isPresented: Binding(get: { model.exportURL != nil }, set: { if !$0 { model.exportURL = nil } })) {
            if let url = model.exportURL { ShareLink(item: url) { Label("Partager mon export", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 52) }.buttonStyle(.borderedProminent).tint(QuietoColor.mint).foregroundStyle(QuietoColor.background).padding() }
        }
        .alert("Quieto", isPresented: Binding(get: { model.feedback != nil }, set: { if !$0 { model.feedback = nil } })) { Button("OK") {} } message: { Text((model.feedback ?? "").quietoLocalized) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ton espace").font(QuietoFont.title).frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 14) {
                Text(model.firstName.isEmpty ? "Q" : String(model.firstName.prefix(1)).uppercased()).font(QuietoFont.serif(25, weight: .semibold)).foregroundStyle(QuietoColor.background).frame(width: 58, height: 58).background(QuietoColor.mint, in: Circle())
                VStack(alignment: .leading, spacing: 4) { Text(model.firstName.isEmpty ? "Sans compte" : model.firstName).font(QuietoFont.title); Button("Modifier mon profil") { presented = .profile } .font(QuietoFont.sans(14)).foregroundStyle(QuietoColor.mint) }
                Spacer()
            }
        }
    }

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            Text("Cette semaine").quietoSectionTitle()
            QuietoCard {
                VStack(spacing: 14) {
                    HStack {
                        stat("leaf", value: "\(model.completedSessions)", label: "séances")
                        Divider().frame(height: 42).overlay(QuietoColor.divider)
                        stat("clock", value: "\(model.listenedMinutes)", label: "min de pause")
                    }
                    Text("Chaque moment compte, même les plus courts.").font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                    Divider().overlay(QuietoColor.divider)
                    Button { presented = .progress } label: { Label("Voir ma progression", systemImage: "chart.bar.xaxis").frame(maxWidth: .infinity, alignment: .leading) }.foregroundStyle(QuietoColor.textPrimary)
                }
            }
        }
    }

    private func stat(_ icon: String, value: String, label: String) -> some View { HStack { Image(systemName: icon).font(.title2).foregroundStyle(QuietoColor.mint); VStack(alignment: .leading) { Text(value).font(QuietoFont.serif(26, weight: .semibold)); Text(label.quietoLocalized).font(QuietoFont.sans(14)) } }.frame(maxWidth: .infinity) }

    private var preferenceSection: some View {
        section("Tes préférences", rows: [
            .init("Rappels", "bell", model.remindersEnabled ? String(format: "%02d:%02d", model.reminderHour, model.reminderMinute) : "Désactivés") { presented = .reminders },
            .init("Audio & ambiances", "music.note", model.ambientMusic ? "Ambiance activée" : "Sans musique") { presented = .audio },
            .init("Accessibilité", "accessibility", nil) { presented = .accessibility },
            .init("Apple Santé", "heart", "Non connecté") { presented = .health }
        ])
    }

    private var accountSection: some View {
        section("Compte & abonnement", rows: [
            .init("Mon compte", "person", model.isAnonymous ? "Sans compte" : "Connecté") { presented = .account },
            .init("Gérer mon abonnement", "creditcard", model.subscriptionState.rawValue) { model.manageSubscription() },
            .init("Restaurer les achats", "arrow.clockwise", nil) { model.restorePurchases() }
        ])
    }

    private var privacySection: some View {
        section("Confidentialité", rows: [
            .init("Données & autorisations", "lock", nil) { presented = .privacy },
            .init("Mémoire de Louane", "text.book.closed", nil) { presented = .louaneMemory },
            .init("Exporter mes données", "square.and.arrow.up", nil) { model.exportData() },
            .init("Supprimer mon compte", "trash", nil, destructive: true) { presented = .delete }
        ])
    }

    private var helpSection: some View { section("Aide & informations", rows: [.init("Questions fréquentes", "questionmark.circle", nil) { presented = .faq }, .init("Nous contacter", "envelope", nil) { if let url = URL(string: "mailto:contact@cofonde.com?subject=Quieto") { openURL(url) } }, .init("Conditions & confidentialité", "doc.text", nil) { presented = .legal }]) }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private func section(_ title: String, rows: [ProfileRow]) -> some View { VStack(alignment: .leading, spacing: QuietoSpacing.sm) { Text(title.quietoLocalized).quietoSectionTitle(); VStack(spacing: 0) { ForEach(Array(rows.enumerated()), id: \.offset) { index, row in Button(action: row.action) { HStack(spacing: 14) { Image(systemName: row.icon).frame(width: 24).foregroundStyle(row.destructive ? .red : QuietoColor.textPrimary); Text(row.title.quietoLocalized).font(QuietoFont.sans(15)); Spacer(); if let detail = row.detail { Text(detail.quietoLocalized).font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary) }; Image(systemName: "chevron.right").font(.caption).foregroundStyle(QuietoColor.textSecondary) }.frame(minHeight: 52).contentShape(Rectangle()) }.buttonStyle(.plain).foregroundStyle(QuietoColor.textPrimary); if index < rows.count - 1 { Divider().overlay(QuietoColor.divider) } } }.padding(.horizontal, 14).background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: QuietoMetrics.cornerRadius, style: .continuous)) } }
}

struct ProfileRow { let title: String; let icon: String; let detail: String?; let destructive: Bool; let action: () -> Void; init(_ title: String, _ icon: String, _ detail: String?, destructive: Bool = false, action: @escaping () -> Void) { self.title = title; self.icon = icon; self.detail = detail; self.destructive = destructive; self.action = action } }

enum ProfileDestination: String, Identifiable { case profile, progress, reminders, audio, accessibility, health, account, privacy, louaneMemory, delete, faq, legal; var id: String { rawValue } }

struct ProfileDestinationView: View {
    let destination: ProfileDestination
    @ObservedObject var model: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedTime = Date()

    var body: some View {
        NavigationStack { content.navigationTitle(Text(title.quietoLocalized)).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } } }
    }
    private var title: String { switch destination { case .profile: "Mon profil"; case .progress: "Ma progression"; case .reminders: "Rappels"; case .audio: "Audio & ambiances"; case .accessibility: "Accessibilité"; case .health: "Apple Santé"; case .account: "Mon compte"; case .privacy: "Données & autorisations"; case .louaneMemory: "Mémoire de Louane"; case .delete: "Supprimer mon compte"; case .faq: "Questions fréquentes"; case .legal: "Conditions & confidentialité" } }
    @ViewBuilder private var content: some View {
        switch destination {
        case .profile: Form { Section("Identité") { TextField("Prénom", text: $name); Button("Enregistrer") { model.saveName(name); dismiss() } } }.onAppear { name = model.firstName }
        case .progress: Form { Section("Cette semaine") { Label(String(format: "%d séances terminées".quietoLocalized, model.completedSessions), systemImage: "leaf"); Label(String(format: "%d minutes réellement écoutées".quietoLocalized, model.listenedMinutes), systemImage: "clock"); Text("Ces chiffres proviennent des séances terminées par le lecteur natif.").foregroundStyle(.secondary) } }
        case .reminders: Form { Section { Toggle("Rappel quotidien", isOn: Binding(get: { model.remindersEnabled }, set: { value in Task { await model.setReminders(value) } })); DatePicker("Heure", selection: $selectedTime, displayedComponents: .hourAndMinute).onChange(of: selectedTime) { _, value in let c = Calendar.current; model.setReminderTime(hour: c.component(.hour, from: value), minute: c.component(.minute, from: value)) } } footer: { Text("Un seul rappel par jour, dans ton fuseau horaire. L’autorisation système est demandée uniquement à l’activation.") } }.onAppear { selectedTime = Calendar.current.date(from: DateComponents(hour: model.reminderHour, minute: model.reminderMinute)) ?? .now }
        case .audio: Form { Section { Toggle("Ambiance musicale", isOn: $model.ambientMusic); Button("Enregistrer") { model.saveAmbient(); dismiss() } } footer: { Text("L’ambiance reste désactivée tant qu’un mix audio réel n’est pas disponible.") } }
        case .accessibility: Form { Section { Toggle("Réduire les animations", isOn: $model.reduceMotion); Toggle("Texte plus grand dans Quieto", isOn: $model.largerText); Button("Enregistrer") { model.saveAccessibility(); dismiss() } } }
        case .health: Form { Section("Apple Santé") { Text("Quieto peut écrire les minutes de pleine conscience uniquement si HealthKit et ses autorisations sont configurés."); Button("Vérifier la connexion") { model.requestHealth() } }.foregroundStyle(QuietoColor.textPrimary) }
        case .account: Form {
            Section("État") {
                Text((model.isAnonymous ? "Tu utilises Quieto sans compte." : "Compte connecté").quietoLocalized)
                if model.isAnonymous {
                    Button("Continuer avec Apple") { model.signInWithApple() }
                } else {
                    Button("Se déconnecter", role: .destructive) { model.signOut() }
                }
            }
            Section("Abonnement") { Text(model.subscriptionState.rawValue.quietoLocalized); Button("Gérer mon abonnement") { model.manageSubscription() }; Button("Restaurer les achats") { model.restorePurchases() } }
        }
        case .privacy: Form { Section { Text("Le profil, la progression, les conversations non temporaires et la mémoire sont synchronisés avec Supabase quand il est configuré."); Button("Préparer mon export") { model.exportData() } } header: { Text("Données et autorisations") } footer: { Text("Les données historiques de migration Firebase et RevenueCat restent conservées côté serveur jusqu’à validation de la migration et selon les obligations applicables.") } }
        case .louaneMemory: Form { Section("Ce que Louane retient") { TextEditor(text: $model.memoryText).frame(minHeight: 150); Button("Enregistrer") { model.saveMemory() }; Button("Supprimer la mémoire", role: .destructive) { model.deleteMemory() } } }.task { await model.loadMemory() }
        case .delete: Form { Section { Text("Cette action supprime le compte Supabase et ses données Quieto. Elle ne résilie jamais automatiquement un abonnement Apple et ne supprime pas les preuves techniques de migration soumises à une durée de conservation distincte."); Button("Supprimer définitivement mon compte", role: .destructive) { model.deleteAccount() }.disabled(model.isSaving) } }
        case .faq: Form { Section("Questions fréquentes") { DisclosureGroup("Comment fonctionne un rappel ?") { Text("Un seul rappel quotidien est programmé à l’heure choisie.") }; DisclosureGroup("Mes données sont-elles supprimées ?") { Text("Les garanties dépendent du service réellement connecté ; Quieto ne promet pas une suppression non implémentée.") } } }
        case .legal: Form { Section { Link("Conditions d’utilisation", destination: URL(string: "https://cofonde.com/quieto-cgu")!); Link("Politique de confidentialité", destination: URL(string: "https://cofonde.com/quieto-confidentialite")!) } }
        }
    }
}
