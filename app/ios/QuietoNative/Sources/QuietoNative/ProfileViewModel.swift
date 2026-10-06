import Foundation
import UserNotifications
import StoreKit
import UIKit

enum QuietoSubscriptionState: String {
    case unavailable = "Vérification indisponible"
    case inactive = "Aucun abonnement actif"
    case active = "Abonnement actif"
    case trial = "Essai en cours"
    case expired = "Accès expiré"
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var firstName: String
    @Published var remindersEnabled: Bool
    @Published var reminderHour: Int
    @Published var reminderMinute: Int
    @Published var selectedReminderDays: Set<Int>
    @Published var ambientMusic = false
    @Published var reduceMotion: Bool
    @Published var largerText: Bool
    @Published var feedback: String?
    @Published var isSaving = false
    @Published private(set) var authState: QuietoAuthState = .loading
    @Published private(set) var remoteSubscriptionState: QuietoSubscriptionState = .unavailable
    @Published var exportURL: URL?
    @Published var memoryText = ""

    private let defaults = UserDefaults.standard
    private let reminderID = "quieto.daily.reminder"
    private let backend = QuietoSupabaseService.shared

    init() {
        firstName = defaults.string(forKey: "quieto.profile.firstName") ?? "Léa"
        remindersEnabled = defaults.bool(forKey: "quieto.profile.remindersEnabled")
        reminderHour = defaults.object(forKey: "quieto.profile.reminderHour") as? Int ?? 21
        reminderMinute = defaults.object(forKey: "quieto.profile.reminderMinute") as? Int ?? 30
        let storedDays = defaults.array(forKey: "quieto.profile.reminderDays") as? [Int] ?? Array(1...7)
        selectedReminderDays = Set(storedDays)
        ambientMusic = defaults.bool(forKey: "quieto.profile.ambientMusic")
        reduceMotion = defaults.bool(forKey: "quieto.profile.reduceMotion")
        largerText = defaults.bool(forKey: "quieto.profile.largerText")
        authState = backend.state
        Task { await refreshAuthState() }
    }

    var subscriptionState: QuietoSubscriptionState {
        let service = QuietoSuperwallService.shared
        if service.hasActiveEntitlement { return .active }
        return remoteSubscriptionState
    }
    var isAnonymous: Bool {
        if case .authenticated = authState { return false }
        return true
    }
    private var weekEvents: [[String: Any]] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now.addingTimeInterval(-7 * 86_400)
        return (UserDefaults.standard.array(forKey: "quieto.native.activity.events") as? [[String: Any]] ?? []).filter { ($0["date"] as? Double ?? 0) >= start.timeIntervalSince1970 }
    }
    var completedSessions: Int {
        Set(weekEvents.compactMap { $0["id"] as? String }).count
    }
    var listenedMinutes: Int {
        weekEvents.reduce(0) { $0 + Int(($1["seconds"] as? Int ?? 0) / 60) }
    }

    func saveName(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        firstName = cleaned
        defaults.set(cleaned, forKey: "quieto.profile.firstName")
        Task {
            do {
                if backend.client != nil { try await backend.updateProfile(firstName: cleaned) }
                feedback = "Profil enregistré"
            } catch {
                feedback = "Profil enregistré sur cet iPhone ; la synchronisation reprendra plus tard."
            }
        }
    }

    func setReminderTime(hour: Int, minute: Int) {
        reminderHour = hour; reminderMinute = minute
        defaults.set(hour, forKey: "quieto.profile.reminderHour")
        defaults.set(minute, forKey: "quieto.profile.reminderMinute")
        if remindersEnabled { scheduleReminder() }
        syncPreferences()
        feedback = "Horaire enregistré"
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
        defaults.set(selectedReminderDays.sorted(), forKey: "quieto.profile.reminderDays")
        if remindersEnabled { scheduleReminder() }
        syncPreferences()
    }

    func setReminders(_ enabled: Bool) async {
        if enabled {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let authorized: Bool
            if settings.authorizationStatus == .notDetermined {
                authorized = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            } else {
                authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
            guard authorized else { feedback = "Autorise les notifications dans Réglages pour activer ce rappel."; return }
            remindersEnabled = true
            defaults.set(true, forKey: "quieto.profile.remindersEnabled")
            scheduleReminder()
            syncPreferences()
            feedback = "Rappel activé"
        } else {
            remindersEnabled = false
            defaults.set(false, forKey: "quieto.profile.remindersEnabled")
            removeReminderRequests()
            syncPreferences()
            feedback = "Rappel désactivé"
        }
    }

    func scheduleReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Quieto"
        content.body = "Une pause quand tu en as besoin."
        content.sound = .default
        let center = UNUserNotificationCenter.current()
        removeReminderRequests()
        for weekday in selectedReminderDays.sorted() {
            var components = DateComponents()
            components.calendar = Calendar.autoupdatingCurrent
            components.timeZone = .autoupdatingCurrent
            components.weekday = weekday
            components.hour = reminderHour
            components.minute = reminderMinute
            let request = UNNotificationRequest(identifier: "\(reminderID).\(weekday)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
            center.add(request)
        }
    }

    private func removeReminderRequests() {
        let identifiers = [reminderID] + (1...7).map { "\(reminderID).\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func saveAccessibility() {
        defaults.set(reduceMotion, forKey: "quieto.profile.reduceMotion")
        defaults.set(largerText, forKey: "quieto.profile.largerText")
        syncPreferences()
        feedback = "Accessibilité enregistrée"
    }

    func saveAmbient() {
        defaults.set(ambientMusic, forKey: "quieto.profile.ambientMusic")
        syncPreferences()
        feedback = "Audio enregistré"
    }

    func restorePurchases() {
        QuietoSuperwallService.shared.restorePurchases()
        feedback = QuietoSuperwallService.shared.isConfigured ? "Restauration en cours…" : QuietoSuperwallService.shared.lastMessage
    }
    func manageSubscription() {
        Task { @MainActor in
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }) else {
                feedback = "La gestion de l’abonnement n’est pas disponible pour le moment."
                return
            }
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                feedback = "Impossible d’ouvrir les abonnements Apple."
            }
        }
    }
    func signInWithApple() {
        Task {
            do {
                try await backend.signInWithApple()
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
                try await backend.signOutToAnonymous()
                await refreshAuthState()
                feedback = "Tu continues sans compte."
            } catch {
                feedback = error.localizedDescription
            }
        }
    }

    func refreshAuthState() async {
        authState = backend.state
        if let remoteName = backend.profile?.firstName, !remoteName.isEmpty, remoteName != firstName {
            firstName = remoteName
            defaults.set(remoteName, forKey: "quieto.profile.firstName")
        }
        remoteSubscriptionState = (try? await backend.subscriptionState()) ?? (QuietoSuperwallService.shared.isConfigured ? .inactive : .unavailable)
        if let remote = try? await backend.loadPreferences() {
            remindersEnabled = remote.reminderEnabled
            selectedReminderDays = Set(remote.reminderDays)
            reminderHour = remote.reminderHour
            reminderMinute = remote.reminderMinute
            ambientMusic = remote.ambientLevel > 0
            reduceMotion = remote.reduceMotion
            largerText = remote.largerText
            persistPreferencesLocally()
            if remindersEnabled { scheduleReminder() }
        }
    }

    private func persistPreferencesLocally() {
        defaults.set(remindersEnabled, forKey: "quieto.profile.remindersEnabled")
        defaults.set(reminderHour, forKey: "quieto.profile.reminderHour")
        defaults.set(reminderMinute, forKey: "quieto.profile.reminderMinute")
        defaults.set(selectedReminderDays.sorted(), forKey: "quieto.profile.reminderDays")
        defaults.set(ambientMusic, forKey: "quieto.profile.ambientMusic")
        defaults.set(reduceMotion, forKey: "quieto.profile.reduceMotion")
        defaults.set(largerText, forKey: "quieto.profile.largerText")
    }

    private func syncPreferences() {
        persistPreferencesLocally()
        let value = QuietoRemotePreferences(
            reminderEnabled: remindersEnabled,
            reminderDays: selectedReminderDays.sorted(),
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderTimezone: TimeZone.autoupdatingCurrent.identifier,
            ambientLevel: ambientMusic ? 0.28 : 0,
            reduceMotion: reduceMotion,
            largerText: largerText
        )
        Task { try? await backend.savePreferences(value) }
    }

    func exportData() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let data = try await backend.invokeAccountData(method: "GET")
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
                _ = try await backend.invokeAccountData(method: "DELETE")
                defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
                feedback = "Compte et données Quieto supprimés. Ton abonnement Apple doit être résilié séparément."
                await backend.bootstrap()
                await refreshAuthState()
            } catch { feedback = error.localizedDescription }
        }
    }

    func loadMemory() async {
        memoryText = (try? await backend.loadMemory()) ?? ""
    }

    func saveMemory() {
        Task {
            do { try await backend.saveMemory(memoryText); feedback = "Mémoire enregistrée" }
            catch { feedback = error.localizedDescription }
        }
    }

    func deleteMemory() {
        Task {
            do { try await backend.deleteMemory(); memoryText = ""; feedback = "Mémoire supprimée" }
            catch { feedback = error.localizedDescription }
        }
    }
    func requestHealth() { feedback = "Apple Santé n’est pas disponible dans cette cible : aucun entitlement HealthKit n’est configuré." }
}
