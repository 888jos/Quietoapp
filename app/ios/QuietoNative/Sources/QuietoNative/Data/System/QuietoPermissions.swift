import Foundation
import HealthKit
import StoreKit
import UserNotifications

/// Apple Health: Quieto writes its sessions as mindful minutes and may read
/// sleep and mindful minutes. Nothing read from Health leaves the device.
@MainActor
final class QuietoHealthService: HealthServicing {
    private let store = HKHealthStore()
    private let mindful = HKCategoryType(.mindfulSession)
    private let sleep = HKCategoryType(.sleepAnalysis)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Returns true once the system sheet was answered (Apple never says
    /// whether reading was allowed, only whether writing is).
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [mindful], read: [mindful, sleep])
            return store.authorizationStatus(for: mindful) == .sharingAuthorized
        } catch {
            return false
        }
    }

    func recordMindfulSession(seconds: Int, endingAt end: Date = .now) {
        guard isAvailable, seconds > 0, store.authorizationStatus(for: mindful) == .sharingAuthorized else { return }
        let sample = HKCategorySample(type: mindful, value: HKCategoryValue.notApplicable.rawValue, start: end.addingTimeInterval(-Double(seconds)), end: end)
        store.save(sample) { _, _ in }
    }
}

/// Daily reminders, shared by the onboarding and the profile.
struct QuietoReminderScheduler: ReminderScheduling {
    static let identifierPrefix = "quieto.daily.reminder"

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func schedule(hour: Int, minute: Int, weekdays: [Int], firstName: String) {
        let center = UNUserNotificationCenter.current()
        removeAll()
        let content = UNMutableNotificationContent()
        content.title = "Quieto"
        content.body = firstName.isEmpty ? "Une pause quand tu en as besoin." : "\(firstName), une pause quand tu en as besoin."
        content.sound = .default
        for weekday in weekdays.sorted() {
            var components = DateComponents()
            components.calendar = Calendar.autoupdatingCurrent
            components.timeZone = .autoupdatingCurrent
            components.weekday = weekday
            components.hour = hour
            components.minute = minute
            center.add(UNNotificationRequest(identifier: "\(Self.identifierPrefix).\(weekday)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
        }
    }

    /// The trial timeline promises a reminder two days before the trial ends.
    func scheduleTrialEndingReminder(trialDays: Int) async {
        var trialStart: Date?
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.offerType == .introductory else { continue }
            trialStart = transaction.purchaseDate
        }
        guard let trialStart, await requestAuthorization() else { return }
        let fireDate = trialStart.addingTimeInterval(Double(max(1, trialDays - 2)) * 86_400)
        guard fireDate > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = "Quieto"
        content.body = "Ton essai gratuit se termine dans 2 jours. Tu peux gérer ton abonnement depuis ton profil."
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "quieto.trial.ending", content: content, trigger: trigger))
    }

    func removeAll() {
        let identifiers = [Self.identifierPrefix] + (1...7).map { "\(Self.identifierPrefix).\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
