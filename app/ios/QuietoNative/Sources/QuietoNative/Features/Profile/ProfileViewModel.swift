import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var firstName: String
    @Published var remindersEnabled: Bool
    @Published var reminderHour: Int
    @Published var reminderMinute: Int
    @Published var selectedReminderDays: Set<Int>
    @Published var ambienceVolume: Double
    @Published var reduceMotion: Bool
    @Published var largerText: Bool
    @Published var feedback: String?
    @Published var isSaving = false
    @Published private(set) var authState: QuietoAuthState = .loading
    /// Nil while StoreKit is being read.
    @Published private(set) var subscription: QuietoSubscriptionDetails?
    @Published private(set) var notificationStatus: QuietoNotificationStatus = .notDetermined
    @Published private(set) var healthConnected = false
    /// The Health permission sheet was already shown (Apple then only lets
    /// the person change it in the Health app).
    @Published private(set) var healthAsked = false
    @Published private(set) var healthSummary: QuietoHealthSummary?
    @Published var exportURL: URL?
    @Published var memoryText = ""
    /// Language chosen in Quieto. Nil follows the iPhone.
    @Published private(set) var language: QuietoLanguage? = QuietoLocalization.chosenLanguage

    /// Applies a new ambience volume to the player right away.
    var onAmbienceVolumeChanged: ((Double) -> Void)?

    private let preferences: QuietoPreferences
    private let auth: AuthServicing
    private let account: AccountDataServicing
    private let louane: LouaneRepository
    /// The copy sent to Louane with each message: edits and deletion must reach it.
    private let louaneMemory: LouaneMemoryProviding
    private let subscriptions: SubscriptionServicing
    private let reminders: ReminderScheduling
    private let health: HealthServicing
    private let localData: LocalDataWiper
    private var cancellables = Set<AnyCancellable>()

    init(preferences: QuietoPreferences, auth: AuthServicing, account: AccountDataServicing, louane: LouaneRepository, louaneMemory: LouaneMemoryProviding, subscriptions: SubscriptionServicing, reminders: ReminderScheduling, health: HealthServicing, localData: LocalDataWiper) {
        self.preferences = preferences
        self.auth = auth
        self.account = account
        self.louane = louane
        self.louaneMemory = louaneMemory
        self.subscriptions = subscriptions
        self.reminders = reminders
        self.health = health
        self.localData = localData
        firstName = preferences.firstName
        let reminder = preferences.reminder
        remindersEnabled = reminder.isEnabled
        reminderHour = reminder.hour
        reminderMinute = reminder.minute
        selectedReminderDays = reminder.weekdays
        ambienceVolume = preferences.ambienceVolume
        reduceMotion = preferences.reduceMotion
        largerText = preferences.largerText
        authState = auth.state
        healthConnected = health.isConnected
        auth.statePublisher
            .removeDuplicates()
            .sink { [weak self] state in
                guard let self, state != authState else { return }
                authState = state
                Task { await self.refreshAuthState() }
            }
            .store(in: &cancellables)
        // A purchase, a restore or an expiry changes what Apple reports.
        subscriptions.accessPublisher
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.refreshSubscription() } }
            .store(in: &cancellables)
        Task { await refreshAuthState() }
    }

    var isAnonymous: Bool {
        if case .authenticated = authState { return false }
        return true
    }

    /// Email of the Apple account, or nil when Apple hides it.
    var accountEmail: String? {
        guard case .authenticated(_, let email) = authState, let email, !email.isEmpty else { return nil }
        return email.hasSuffix("privaterelay.appleid.com") ? nil : email
    }

    var accountSummary: String {
        switch authState {
        case .authenticated: "Connecté avec Apple".quietoLocalized
        case .anonymous: "Sans compte".quietoLocalized
        case .loading: "Vérification…".quietoLocalized
        case .unavailable: "Indisponible".quietoLocalized
        case .failed: "Hors ligne".quietoLocalized
        }
    }

    var accountExplanation: String {
        switch authState {
        case .authenticated:
            accountEmail == nil
                ? "Ton compte Apple est relié à Quieto. Apple masque ton adresse e-mail.".quietoLocalized
                : "Ton compte Apple est relié à Quieto : ta progression te suit sur tous tes iPhone.".quietoLocalized
        case .anonymous:
            "Ta progression est liée à cet iPhone. Relie ton compte Apple pour la retrouver après une réinstallation ou sur un autre iPhone.".quietoLocalized
        case .loading:
            "Vérification de ton compte…".quietoLocalized
        case .unavailable, .failed:
            "Le compte n’est pas joignable pour le moment. Tes séances restent enregistrées sur cet iPhone.".quietoLocalized
        }
    }

    var canSignInWithApple: Bool { auth.isConfigured && isAnonymous }

    var reminderSummary: String {
        guard remindersEnabled else { return "Désactivés".quietoLocalized }
        if notificationStatus == .denied { return "Bloqués dans Réglages".quietoLocalized }
        let time = String(format: "%02d:%02d", reminderHour, reminderMinute)
        return selectedReminderDays.count == 7 ? time : "\(time) · \(String(format: "%d j/sem.".quietoLocalized, selectedReminderDays.count))"
    }

    var ambienceSummary: String { ambienceVolume.formatted(.percent.precision(.fractionLength(0)).locale(QuietoLocalization.locale)) }

    /// Chosen in onboarding; changing it redraws the whole app agreed in the new gender.
    var gender: QuietoGender { QuietoGender.current }
    var genderSummary: String { (gender == .feminine ? "Féminin" : "Masculin").quietoLocalized }

    func setGender(_ newValue: QuietoGender) {
        guard newValue != gender else { return }
        objectWillChange.send()
        QuietoGender.set(newValue)
        // Pending reminders keep the text they were scheduled with.
        if remindersEnabled { scheduleReminder() }
    }

    var languageSummary: String {
        language?.nativeName ?? "Langue de l’iPhone".quietoLocalized
    }

    /// Applies right away: the whole app is redrawn in the new language.
    func setLanguage(_ newValue: QuietoLanguage?) {
        guard newValue != language else { return }
        QuietoLocalization.setLanguage(newValue)
        language = newValue
        // Pending reminders keep the text they were scheduled with.
        if remindersEnabled { scheduleReminder() }
    }

    var accessibilitySummary: String? {
        switch (largerText, reduceMotion) {
        case (true, true): "Texte agrandi · animations réduites".quietoLocalized
        case (true, false): "Texte agrandi".quietoLocalized
        case (false, true): "Animations réduites".quietoLocalized
        case (false, false): nil
        }
    }

    var healthAvailable: Bool { health.isAvailable }

    var healthRowSummary: String {
        if !health.isAvailable { return "Indisponible".quietoLocalized }
        return (healthConnected ? "Connecté" : "Non connecté").quietoLocalized
    }

    var subscriptionSummary: String { subscription?.summary ?? "Vérification…".quietoLocalized }

    /// Re-reads everything that can change outside the app (Settings, Health,
    /// App Store) each time the profile is shown.
    func refreshLiveStatus() async {
        notificationStatus = await reminders.authorizationStatus()
        await refreshHealth()
        await refreshSubscription()
    }

    func refreshSubscription() async {
        subscription = await subscriptions.subscriptionDetails()
    }

    func refreshHealth() async {
        healthConnected = health.isConnected
        healthAsked = await health.wasAsked()
        healthSummary = health.isAvailable && healthAsked ? await health.summary(now: .now, calendar: .autoupdatingCurrent) : nil
    }

    func saveName(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        firstName = cleaned
        preferences.firstName = cleaned
        Task {
            do {
                if auth.isConfigured { try await auth.updateProfile(firstName: cleaned) }
                feedback = "Profil enregistré"
            } catch {
                feedback = "Profil enregistré sur cet iPhone ; la synchronisation reprendra plus tard."
            }
        }
    }

    func setReminderTime(hour: Int, minute: Int) {
        guard hour != reminderHour || minute != reminderMinute else { return }
        reminderHour = hour; reminderMinute = minute
        if remindersEnabled { scheduleReminder() }
        syncPreferences()
    }

    func toggleReminderDay(_ weekday: Int) {
        if selectedReminderDays.contains(weekday) {
            guard selectedReminderDays.count > 1 else {
                feedback = "Choisis au moins un jour pour le rappel."
                return
            }
            selectedReminderDays.remove(weekday)
        } else {
            selectedReminderDays.insert(weekday)
        }
        if remindersEnabled { scheduleReminder() }
        syncPreferences()
    }

    func setReminders(_ enabled: Bool) async {
        if enabled {
            let granted = await reminders.requestAuthorization()
            notificationStatus = await reminders.authorizationStatus()
            guard granted else { feedback = "Autorise les notifications dans Réglages pour activer ce rappel."; return }
            remindersEnabled = true
            scheduleReminder()
            syncPreferences()
        } else {
            remindersEnabled = false
            reminders.removeAll()
            syncPreferences()
        }
    }

    func scheduleReminder() {
        reminders.schedule(hour: reminderHour, minute: reminderMinute, weekdays: selectedReminderDays.sorted(), firstName: firstName)
    }

    func saveAccessibility() {
        syncPreferences()
    }

    func setAmbienceVolume(_ value: Double) {
        ambienceVolume = min(1, max(0, value))
        preferences.ambienceVolume = ambienceVolume
        onAmbienceVolumeChanged?(ambienceVolume)
    }

    /// Called when the slider is released: one server write, not one per step.
    func saveAmbience() {
        syncPreferences()
    }

    func restorePurchases() {
        subscriptions.restorePurchases()
        feedback = subscriptions.isConfigured ? "Restauration en cours…" : subscriptions.lastMessage
        Task {
            await subscriptions.syncNow()
            await refreshSubscription()
        }
    }
    func manageSubscription() {
        Task {
            do {
                try await subscriptions.showManageSubscriptions()
            } catch QuietoSubscriptionError.noActiveScene {
                feedback = "La gestion de l’abonnement n’est pas disponible pour le moment."
            } catch {
                feedback = "Impossible d’ouvrir les abonnements Apple."
            }
        }
    }
    func signInWithApple() {
        Task {
            do {
                try await auth.signInWithApple()
                await refreshAuthState()
                feedback = "Compte Apple connecté"
            } catch {
                feedback = error.localizedDescription
            }
        }
    }

    func signOut() {
        Task {
            do {
                // Network first: if it fails, the account and its local data stay intact.
                try await auth.signOutToAnonymous()
                localData.wipe()
                reloadLocalState()
                await refreshAuthState()
                feedback = "Tu continues sans compte."
            } catch {
                feedback = error.localizedDescription
            }
        }
    }

    func refreshAuthState() async {
        authState = auth.state
        if let remoteName = auth.remoteFirstName, !remoteName.isEmpty, remoteName != firstName {
            firstName = remoteName
            preferences.firstName = remoteName
        }
        if case .authenticated = authState { await loadMemory() }
        if let remote = try? await account.loadPreferences() {
            remindersEnabled = remote.reminderEnabled
            selectedReminderDays = Set(remote.reminderDays)
            reminderHour = remote.reminderHour
            reminderMinute = remote.reminderMinute
            ambienceVolume = remote.ambientLevel
            onAmbienceVolumeChanged?(ambienceVolume)
            reduceMotion = remote.reduceMotion
            largerText = remote.largerText
            persistPreferencesLocally()
            if remindersEnabled { scheduleReminder() }
        }
    }

    private func persistPreferencesLocally() {
        preferences.reminder = ReminderSettings(isEnabled: remindersEnabled, hour: reminderHour, minute: reminderMinute, weekdays: selectedReminderDays)
        preferences.ambienceVolume = ambienceVolume
        preferences.reduceMotion = reduceMotion
        preferences.largerText = largerText
    }

    private func syncPreferences() {
        persistPreferencesLocally()
        let value = QuietoRemotePreferences(
            reminderEnabled: remindersEnabled,
            reminderDays: selectedReminderDays.sorted(),
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderTimezone: TimeZone.autoupdatingCurrent.identifier,
            ambientLevel: ambienceVolume,
            reduceMotion: reduceMotion,
            largerText: largerText
        )
        Task { [account] in try? await account.savePreferences(value) }
    }

    func exportData() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let data = try await account.invokeAccountData(method: "GET")
                let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                let url = directory.appendingPathComponent("Quieto-export-\(ISO8601DateFormatter().string(from: .now)).json")
                try data.write(to: url, options: .atomic)
                exportURL = url
                feedback = "Export prêt"
            } catch { feedback = error.localizedDescription }
        }
    }

    func deleteAccount() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                // Apple asks the person to confirm with Face ID; cancelling it
                // cancels the deletion (nothing was deleted yet).
                let appleCode: String?
                do { appleCode = try await auth.appleAuthorizationCodeForDeletion() }
                catch { feedback = "Suppression annulée : la confirmation Apple est nécessaire pour supprimer un compte relié à Apple."; return }
                try await account.deleteAccount(appleAuthorizationCode: appleCode)
                localData.wipe()
                await auth.resetAfterAccountDeletion()
                reloadLocalState()
                exportURL = nil
                memoryText = ""
                feedback = "Compte et données Quieto supprimés. Ton abonnement Apple doit être résilié séparément."
                await refreshAuthState()
            } catch { feedback = error.localizedDescription }
        }
    }

    private func reloadLocalState() {
        firstName = ""
        remindersEnabled = false
        reminderHour = 21
        reminderMinute = 30
        selectedReminderDays = Set(1...7)
        ambienceVolume = QuietoPreferences.defaultAmbienceVolume
        onAmbienceVolumeChanged?(ambienceVolume)
        reduceMotion = false
        largerText = false
    }

    /// The iPhone's copy is what Louane receives; the account copy only
    /// fills it when this iPhone has none yet (reinstall, new iPhone).
    func loadMemory() async {
        memoryText = louaneMemory.text
        guard memoryText.isEmpty, let remote = try? await louane.loadMemory(), !remote.isEmpty else { return }
        louaneMemory.update(remote)
        memoryText = remote
    }

    func saveMemory() {
        let value = memoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        louaneMemory.update(value)
        Task {
            do { try await louane.saveMemory(value); feedback = "Mémoire enregistrée" }
            catch { feedback = "Mémoire enregistrée sur cet iPhone ; la synchronisation reprendra plus tard." }
        }
    }

    /// Erased on the iPhone first, so it stops being sent to Louane right away.
    func deleteMemory() {
        louaneMemory.remove()
        memoryText = ""
        Task {
            do { try await louane.deleteMemory(); feedback = "Mémoire supprimée" }
            catch { feedback = "Mémoire supprimée de cet iPhone. La suppression sur ton compte n’a pas abouti : réessaie plus tard." }
        }
    }
    func connectHealth() async {
        guard health.isAvailable else { feedback = "Apple Santé n’est pas disponible sur cet appareil."; return }
        _ = await health.requestAuthorization()
        await refreshHealth()
    }
}
