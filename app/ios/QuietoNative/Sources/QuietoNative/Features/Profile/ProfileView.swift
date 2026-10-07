import UIKit
import SwiftUI

struct ProfileView: View {
    @ObservedObject var model: ProfileViewModel
    @ObservedObject var journey: AchievementsViewModel
    @ObservedObject var enterprise: EnterpriseCodeViewModel
    @State private var presented: ProfileDestination?
    @State private var showingEnterpriseCode = false
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            QuietoBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: QuietoSpacing.lg) {
                    header
                    weeklyActivity
                    ProfileBadgesCard(journey: journey)
                    preferenceSection
                    accountSection
                    privacySection
                    helpSection
                    if !model.isAnonymous {
                        QuietoOutlineButton(title: "Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right") { model.signOut() }
                    }
                    Text(QuietoLocalization.format("Quieto · Version %@", appVersion)).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary).frame(maxWidth: .infinity)
                }
                .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                .padding(.horizontal, QuietoSpacing.md)
                .padding(.top, QuietoSpacing.sm)
                .padding(.bottom, 128)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 92) }
        .task { await model.refreshLiveStatus() }
        .onChange(of: scenePhase) { _, phase in
            // Back from Settings, Health or the App Store.
            if phase == .active { Task { await model.refreshLiveStatus() } }
        }
        .sheet(item: $presented, onDismiss: { Task { await model.refreshLiveStatus() } }) { destination in
            ProfileDestinationView(destination: destination, model: model)
        }
        .sheet(isPresented: $showingEnterpriseCode, onDismiss: { Task { await model.refreshLiveStatus() } }) { EnterpriseCodeView(model: enterprise) }
        .sheet(isPresented: Binding(get: { model.exportURL != nil }, set: { if !$0 { model.exportURL = nil } })) {
            if let url = model.exportURL { ShareLink(item: url) { Label("Partager mon export", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 52) }.buttonStyle(.borderedProminent).tint(QuietoColor.mint).foregroundStyle(QuietoColor.background).padding() }
        }
        .alert("Quieto", isPresented: Binding(get: { model.feedback != nil }, set: { if !$0 { model.feedback = nil } })) { Button("OK") {} } message: { Text((model.feedback ?? "").quietoLocalized) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ton espace").font(QuietoFont.display).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 14) {
                Text(model.firstName.isEmpty ? "Q" : String(model.firstName.prefix(1)).uppercased()).font(QuietoFont.heading(.title, weight: .semibold)).foregroundStyle(QuietoColor.background).frame(width: QuietoMetrics.playMedium, height: QuietoMetrics.playMedium).background(QuietoColor.mintFill, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.firstName.isEmpty ? model.accountSummary : model.firstName).font(QuietoFont.title)
                    Button("Modifier mon profil") { presented = .profile }.font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.mint)
                }
                Spacer()
            }
        }
    }

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: QuietoSpacing.sm) {
            Text("Cette semaine").quietoSectionTitle()
            Button { journey.present() } label: {
                QuietoCard {
                    VStack(spacing: 14) {
                        HStack {
                            stat("leaf", value: "\(journey.weekPracticeCount)", label: journey.weekPracticeCount == 1 || (journey.weekPracticeCount == 0 && QuietoLocalization.isFrench) ? "pause" : "pauses")
                            Divider().frame(height: 42).overlay(QuietoColor.divider)
                            stat("clock", value: "\(journey.weekMinutes)", label: "min de pause")
                        }
                        WeekDots(practiceDays: journey.summary.stats.practiceDays, today: Date())
                        Text(weekMessage).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                        Divider().overlay(QuietoColor.divider)
                        HStack {
                            Label("Voir mon parcours", systemImage: "chart.bar.xaxis")
                            Spacer()
                            Image(systemName: "chevron.right").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                        }
                        .font(QuietoFont.sans(.callout))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ouvre ta série, ton calendrier et tes badges")
        }
    }

    private var weekMessage: String {
        switch journey.weekPracticeDays {
        case 0: "Ta première pause de la semaine t’attend.".quietoLocalized
        case 1: "1 jour de pratique cette semaine. Chaque moment compte.".quietoLocalized
        default: String(format: "%d jours de pratique cette semaine. Chaque moment compte.".quietoLocalized, journey.weekPracticeDays)
        }
    }

    private func stat(_ icon: String, value: String, label: String) -> some View { HStack { Image(systemName: icon).font(.title2).foregroundStyle(QuietoColor.mint); VStack(alignment: .leading) { Text(value).font(QuietoFont.heading(.title, weight: .semibold)); Text(label.quietoLocalized).font(QuietoFont.sans(.callout)) } }.frame(maxWidth: .infinity) }

    private var preferenceSection: some View {
        section("Tes préférences", rows: [
            .init("Langue", "globe", model.languageSummary) { presented = .language },
            .init("Genre", "person.crop.circle", model.genderSummary) { presented = .gender },
            .init("Rappels", "bell", model.reminderSummary) { presented = .reminders },
            .init("Audio & ambiances", "music.note", model.ambienceSummary) { presented = .audio },
            .init("Accessibilité", "accessibility", model.accessibilitySummary) { presented = .accessibility },
            .init("Apple Santé", "heart", model.healthRowSummary) { presented = .health }
        ])
    }

    private var accountSection: some View {
        section("Compte & abonnement", rows: [
            .init("Mon compte", "person", model.accountSummary) { presented = .account },
            .init("Mon abonnement", "creditcard", model.subscriptionSummary) { presented = .subscription },
            .init("Restaurer les achats", "arrow.clockwise", nil) { model.restorePurchases() },
            .init("Code entreprise", "building.2", nil) { showingEnterpriseCode = true }
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

    private func section(_ title: String, rows: [ProfileRow]) -> some View { VStack(alignment: .leading, spacing: QuietoSpacing.sm) { Text(title.quietoLocalized).quietoSectionTitle(); VStack(spacing: 0) { ForEach(Array(rows.enumerated()), id: \.offset) { index, row in Button(action: row.action) { HStack(spacing: 14) { Image(systemName: row.icon).frame(width: 24).foregroundStyle(row.destructive ? .red : QuietoColor.textPrimary); Text(row.title.quietoLocalized).font(QuietoFont.sans(.callout)); Spacer(); if let detail = row.detail { Text(detail.quietoLocalized).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary).lineLimit(1) }; Image(systemName: "chevron.right").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary) }.frame(minHeight: 52).contentShape(Rectangle()) }.buttonStyle(.plain).foregroundStyle(QuietoColor.textPrimary); if index < rows.count - 1 { Divider().overlay(QuietoColor.divider) } } }.padding(.horizontal, 14).quietoSurface(cornerRadius: QuietoMetrics.cornerRadius) } }
}

/// The seven days of the current week, filled when there was a practice.
private struct WeekDots: View {
    /// Start of every day with a practice.
    let practiceDays: Set<Date>
    let today: Date
    private let calendar = Calendar.autoupdatingCurrent

    private var week: [(date: Date, practiced: Bool, isToday: Bool, isFuture: Bool)] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        let startOfToday = calendar.startOfDay(for: today)
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return (date, practiceDays.contains(date), date == startOfToday, date > startOfToday)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(week, id: \.date) { day in
                VStack(spacing: 6) {
                    Text(day.date.formatted(.dateTime.weekday(.narrow).locale(QuietoLocalization.locale)))
                        .font(QuietoFont.sans(.overline, weight: .semibold))
                        .foregroundStyle(QuietoColor.textSecondary)
                    Circle()
                        .fill(day.practiced ? QuietoColor.mint : QuietoColor.surfaceRaised)
                        .frame(width: 22, height: 22)
                        .overlay { if day.isToday { Circle().stroke(QuietoColor.mint, lineWidth: 1.5) } }
                        .opacity(day.isFuture ? 0.45 : 1)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(day.date.formatted(.dateTime.weekday(.wide).locale(QuietoLocalization.locale))), \((day.practiced ? "pratiqué" : "pas de pratique").quietoLocalized)"))
            }
        }
    }
}

struct ProfileRow { let title: String; let icon: String; let detail: String?; let destructive: Bool; let action: () -> Void; init(_ title: String, _ icon: String, _ detail: String?, destructive: Bool = false, action: @escaping () -> Void) { self.title = title; self.icon = icon; self.detail = detail; self.destructive = destructive; self.action = action } }

enum ProfileDestination: String, Identifiable { case profile, language, gender, reminders, audio, accessibility, health, account, subscription, privacy, louaneMemory, delete, faq, legal; var id: String { rawValue } }

struct ProfileDestinationView: View {
    let destination: ProfileDestination
    @ObservedObject var model: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var name = ""
    @State private var confirmDeletion = false

    var body: some View {
        NavigationStack {
            content
                .buttonStyle(ProfileSheetButtonStyle())
                .font(QuietoFont.sans(.body))
                .scrollContentBackground(.hidden)
                .background(QuietoBackground())
                .navigationTitle(Text(title.quietoLocalized))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .tint(QuietoColor.mint)
    }

    private var title: String { switch destination { case .profile: "Mon profil"; case .language: "Langue"; case .gender: "Genre"; case .reminders: "Rappels"; case .audio: "Audio & ambiances"; case .accessibility: "Accessibilité"; case .health: "Apple Santé"; case .account: "Mon compte"; case .subscription: "Mon abonnement"; case .privacy: "Données & autorisations"; case .louaneMemory: "Mémoire de Louane"; case .delete: "Supprimer mon compte"; case .faq: "Questions fréquentes"; case .legal: "Conditions & confidentialité" } }

    @ViewBuilder private var content: some View {
        switch destination {
        case .profile: Form { Section("Identité") { TextField("Prénom", text: $name); Button("Enregistrer") { model.saveName(name); dismiss() } }.listRowBackground(QuietoColor.surface) }.onAppear { name = model.firstName }
        case .language: language
        case .gender: gender
        case .reminders: reminders
        case .audio: audio
        case .accessibility: accessibility
        case .health: health
        case .account: account
        case .subscription: subscription
        case .privacy: Form { Section { Text("Ta progression, tes préférences, tes conversations avec Louane (hors conversations temporaires) et sa mémoire sont enregistrées sur ton compte Quieto. Les données d’Apple Santé ne quittent jamais ton iPhone."); Button("Préparer mon export") { model.exportData() } } header: { Text("Données et autorisations") }.listRowBackground(QuietoColor.surface) }
        case .louaneMemory: Form { Section("Ce que Louane retient") { TextEditor(text: $model.memoryText).frame(minHeight: 150); Button("Enregistrer") { model.saveMemory() }; Button("Supprimer la mémoire", role: .destructive) { model.deleteMemory() } }.listRowBackground(QuietoColor.surface) }.task { await model.loadMemory() }
        case .delete: delete
        case .faq: Form { Section("Questions fréquentes") { DisclosureGroup("Comment fonctionne un rappel ?") { Text("Un rappel est programmé à l’heure choisie pour chacun des jours sélectionnés, sans doublon.") }; DisclosureGroup("Comment résilier mon abonnement ?") { Text("Ouvre Mon abonnement puis Gérer dans l’App Store. La résiliation prend effet à la fin de la période en cours.") }; DisclosureGroup("Mes données sont-elles supprimées ?") { Text("Supprimer ton compte efface ta progression, tes préférences et tes conversations avec Louane. Ton abonnement Apple, lui, se résilie depuis l’App Store.") } }.listRowBackground(QuietoColor.surface) }
        case .legal: Form { Section { Link("Conditions d’utilisation", destination: URL(string: "https://cofonde.com/quieto-cgu")!); Link("Politique de confidentialité", destination: URL(string: "https://cofonde.com/quieto-confidentialite")!) }.listRowBackground(QuietoColor.surface) }
        }
    }

    // MARK: Preferences

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Calendar.autoupdatingCurrent.date(from: DateComponents(hour: model.reminderHour, minute: model.reminderMinute)) ?? .now },
            set: { value in
                let calendar = Calendar.autoupdatingCurrent
                model.setReminderTime(hour: calendar.component(.hour, from: value), minute: calendar.component(.minute, from: value))
            }
        )
    }

    private var reminders: some View {
        Form {
            if model.remindersEnabled, model.notificationStatus == .denied {
                Section {
                    Label("Les notifications de Quieto sont désactivées dans Réglages : aucun rappel ne peut s’afficher.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(QuietoColor.coral)
                    Button("Ouvrir les Réglages") { openSettings() }
                }.listRowBackground(QuietoColor.surface)
            }
            Section {
                Toggle("Activer les rappels", isOn: Binding(get: { model.remindersEnabled }, set: { value in Task { await model.setReminders(value) } }))
                if model.remindersEnabled {
                    DatePicker("Heure", selection: reminderTime, displayedComponents: .hourAndMinute)
                    if let rhythm = model.planRhythm {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Jours").font(QuietoFont.sans(.callout, weight: .semibold))
                            Text(QuietoLocalization.format("Ton plan fixe les jours : rythme %@ (%@).", rhythm.localizedName, rhythm.localizedDetail))
                                .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Jours").font(QuietoFont.sans(.callout, weight: .semibold))
                            HStack(spacing: 7) {
                                ForEach(orderedWeekdays, id: \.self) { weekday in
                                    Button {
                                        model.toggleReminderDay(weekday)
                                    } label: {
                                        Text(shortWeekday(weekday))
                                            .font(QuietoFont.sans(.caption, weight: .semibold))
                                            .frame(maxWidth: .infinity, minHeight: 34)
                                            .foregroundStyle(model.selectedReminderDays.contains(weekday) ? QuietoColor.background : QuietoColor.textPrimary)
                                            .background(model.selectedReminderDays.contains(weekday) ? QuietoColor.mint : QuietoColor.surfaceRaised, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(fullWeekday(weekday))
                                    .accessibilityAddTraits(model.selectedReminderDays.contains(weekday) ? .isSelected : [])
                                }
                            }
                        }
                    }
                }
            } footer: {
                Text((model.planRhythm == nil ? "Un rappel par jour choisi, à l’heure de ton fuseau horaire actuel." : "Chaque rappel cite l’étape du jour de ton plan, à l’heure de ton fuseau horaire actuel.").quietoLocalized)
            }.listRowBackground(QuietoColor.surface)
        }
    }

    private var audio: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Volume des ambiances")
                        Spacer()
                        Text(model.ambienceSummary).monospacedDigit().foregroundStyle(QuietoColor.textSecondary)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill").foregroundStyle(QuietoColor.textSecondary)
                        Slider(
                            value: Binding(get: { model.ambienceVolume }, set: { model.setAmbienceVolume($0) }),
                            in: 0...1,
                            onEditingChanged: { editing in if !editing { model.saveAmbience() } }
                        )
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(QuietoColor.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text("S’applique aux sons d’ambiance, seuls ou sous une séance, y compris pendant l’écoute.")
            }.listRowBackground(QuietoColor.surface)
        }
    }

    private var language: some View {
        Form {
            Section {
                languageRow(nil, title: "Langue de l’iPhone".quietoLocalized)
                ForEach(QuietoLanguage.allCases) { languageRow($0, title: $0.nativeName) }
            } footer: {
                Text("Toute l’app passe dans la langue choisie, séances et Louane compris.")
            }.listRowBackground(QuietoColor.surface)
        }
    }

    private var gender: some View {
        Form {
            Section {
                ForEach(QuietoGender.allCases) { option in
                    Button {
                        dismiss()
                        model.setGender(option)
                    } label: {
                        HStack {
                            Text((option == .feminine ? "Féminin" : "Masculin").quietoLocalized).foregroundStyle(QuietoColor.textPrimary)
                            Spacer()
                            if model.gender == option { Image(systemName: "checkmark").foregroundStyle(QuietoColor.mint) }
                        }
                    }
                    .accessibilityAddTraits(model.gender == option ? .isSelected : [])
                }
            } footer: {
                Text("Quieto s’adresse à toi au masculin ou au féminin, dans toute l’app.")
            }.listRowBackground(QuietoColor.surface)
        }
    }

    private func languageRow(_ language: QuietoLanguage?, title: String) -> some View {
        Button {
            dismiss()
            model.setLanguage(language)
        } label: {
            HStack {
                Text(verbatim: title).foregroundStyle(QuietoColor.textPrimary)
                Spacer()
                if model.language == language { Image(systemName: "checkmark").foregroundStyle(QuietoColor.mint) }
            }
        }
        .accessibilityAddTraits(model.language == language ? .isSelected : [])
    }

    private var accessibility: some View {
        Form {
            Section {
                Toggle("Texte plus grand dans Quieto", isOn: Binding(get: { model.largerText }, set: { model.largerText = $0; model.saveAccessibility() }))
                Toggle("Réduire les animations", isOn: Binding(get: { model.reduceMotion }, set: { model.reduceMotion = $0; model.saveAccessibility() }))
            } footer: {
                Text("Ces réglages s’ajoutent à ceux de ton iPhone (Réglages › Accessibilité).")
            }.listRowBackground(QuietoColor.surface)
        }
    }

    // MARK: Apple Health

    @ViewBuilder private var health: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill").font(.title3).foregroundStyle(QuietoColor.coral)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.healthRowSummary).font(QuietoFont.sans(.body, weight: .semibold))
                        Text(healthStatusDetail).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                    }
                }
                .padding(.vertical, 4)
                if model.healthAvailable {
                    if !model.healthAsked {
                        Button("Connecter Apple Santé") { Task { await model.connectHealth() } }
                    } else {
                        Button("Ouvrir l’app Santé") { if let url = URL(string: "x-apple-health://") { openURL(url) } }
                    }
                }
            }.listRowBackground(QuietoColor.surface)
            if let summary = model.healthSummary {
                Section("Cette semaine") {
                    LabeledContent("Pleine conscience", value: minutesLabel(summary.mindfulMinutesThisWeek))
                    LabeledContent("Dont avec Quieto", value: minutesLabel(summary.quietoMinutesThisWeek))
                }.listRowBackground(QuietoColor.surface)
                Section {
                    LabeledContent("Sommeil la nuit dernière", value: summary.lastNightSleepMinutes.map(hoursLabel) ?? "Aucune donnée".quietoLocalized)
                } footer: {
                    Text("Le sommeil vient de ton iPhone ou de ta montre. Si rien ne s’affiche, autorise la lecture du sommeil dans Santé › Partage › Apps et services › Quieto.")
                }.listRowBackground(QuietoColor.surface)
            }
            Section {
                EmptyView()
            } footer: {
                Text("Chaque séance terminée est enregistrée en minutes de pleine conscience. Les données d’Apple Santé restent sur ton iPhone et ne sont jamais envoyées à Quieto.")
            }.listRowBackground(QuietoColor.surface)
        }
    }

    private var healthStatusDetail: String {
        if !model.healthAvailable { return "Apple Santé n’est pas disponible sur cet appareil.".quietoLocalized }
        if model.healthConnected { return "Tes séances sont enregistrées dans Apple Santé.".quietoLocalized }
        if model.healthAsked { return "Autorise Quieto dans Santé › Partage › Apps et services › Quieto.".quietoLocalized }
        return "Enregistre tes séances en minutes de pleine conscience.".quietoLocalized
    }

    private func minutesLabel(_ minutes: Int) -> String { String(format: "%d min".quietoLocalized, minutes) }

    private func hoursLabel(_ minutes: Int) -> String { String(format: "%d h %02d".quietoLocalized, minutes / 60, minutes % 60) }

    // MARK: Account

    private var account: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: model.isAnonymous ? "person.crop.circle.badge.questionmark" : "apple.logo").font(.title3).foregroundStyle(QuietoColor.mint).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.accountSummary).font(QuietoFont.sans(.body, weight: .semibold))
                        if let email = model.accountEmail { Text(email).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary) }
                    }
                }
                .padding(.vertical, 4)
                Text(model.accountExplanation).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
            }.listRowBackground(QuietoColor.surface)
            Section {
                if model.canSignInWithApple {
                    Button { model.signInWithApple() } label: { Label("Continuer avec Apple", systemImage: "apple.logo") }
                } else if !model.isAnonymous {
                    Button("Se déconnecter", role: .destructive) { model.signOut(); dismiss() }
                }
            }.listRowBackground(QuietoColor.surface)
        }
    }

    @ViewBuilder private var subscription: some View {
        Form {
            if let details = model.subscription {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(details.planName ?? "Quieto").font(QuietoFont.sans(.body, weight: .semibold))
                        if let price = details.price { Text(price).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary) }
                    }
                    .padding(.vertical, 4)
                    LabeledContent("Statut", value: details.summary)
                    Text(details.explanation).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
                }.listRowBackground(QuietoColor.surface)
                Section {
                    if details.status != .grantedByServer {
                        Button("Gérer dans l’App Store") { model.manageSubscription() }
                    }
                    Button("Restaurer les achats") { model.restorePurchases() }
                } footer: {
                    Text("La résiliation se fait depuis l’App Store et prend effet à la fin de la période en cours.")
                }.listRowBackground(QuietoColor.surface)
            } else {
                Section { HStack { ProgressView(); Text("Lecture de ton abonnement…").foregroundStyle(QuietoColor.textSecondary) } }.listRowBackground(QuietoColor.surface)
            }
        }
        .task { await model.refreshSubscription() }
    }

    private var delete: some View {
        Form {
            Section {
                Text("Cette action supprime ton compte Quieto, ta progression, tes préférences et tes conversations avec Louane. Elle est définitive.")
                Text("Ton abonnement Apple n’est pas résilié automatiquement : fais-le depuis Mon abonnement.").foregroundStyle(QuietoColor.textSecondary)
            }.listRowBackground(QuietoColor.surface)
            Section {
                Button("Supprimer définitivement mon compte", role: .destructive) { confirmDeletion = true }.disabled(model.isSaving)
            }.listRowBackground(QuietoColor.surface)
        }
        .confirmationDialog("Supprimer ton compte Quieto ?", isPresented: $confirmDeletion, titleVisibility: .visible) {
            Button("Supprimer définitivement", role: .destructive) { model.deleteAccount(); dismiss() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ta progression et tes conversations seront effacées. Cette action ne peut pas être annulée.")
        }
    }

    // MARK: Helpers

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    /// Weekdays starting with the locale's first day (Monday in France).
    private var orderedWeekdays: [Int] {
        let first = Calendar.autoupdatingCurrent.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    /// Weekday names in the language displayed by Quieto.
    private var displayCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = QuietoLocalization.locale
        return calendar
    }

    private func shortWeekday(_ weekday: Int) -> String {
        let symbols = displayCalendar.veryShortWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }

    private func fullWeekday(_ weekday: Int) -> String {
        let symbols = displayCalendar.weekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }
}

/// Actions in the profile sheets: mint like the rest of the app, red when destructive.
private struct ProfileSheetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.role == .destructive ? QuietoColor.danger : QuietoColor.mint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}
