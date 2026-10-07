import Foundation
import HealthKit
import StoreKit
import UserNotifications

/// Apple Health: Quieto writes its sessions as mindful minutes and reads
/// mindful minutes and sleep to show them in the profile. Nothing read from
/// Health leaves the device.
@MainActor
final class QuietoHealthService: HealthServicing {
    private let store = HKHealthStore()
    private let mindful = HKCategoryType(.mindfulSession)
    private let sleep = HKCategoryType(.sleepAnalysis)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Apple only tells whether writing was allowed; reading stays private.
    var isConnected: Bool {
        isAvailable && store.authorizationStatus(for: mindful) == .sharingAuthorized
    }

    /// True once the permission sheet was shown, whatever the answer.
    func wasAsked() async -> Bool {
        guard isAvailable else { return false }
        let status = try? await store.statusForAuthorizationRequest(toShare: [mindful], read: [mindful, sleep])
        return status == .unnecessary
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [mindful], read: [mindful, sleep])
            return isConnected
        } catch {
            return false
        }
    }

    func recordMindfulSession(seconds: Int, endingAt end: Date = .now) {
        guard isConnected, seconds > 0 else { return }
        let sample = HKCategorySample(
            type: mindful,
            value: HKCategoryValue.notApplicable.rawValue,
            start: end.addingTimeInterval(-Double(seconds)),
            end: end,
            metadata: [HKMetadataKeyWasUserEntered: false]
        )
        store.save(sample) { _, _ in }
    }

    func summary(now: Date = .now, calendar: Calendar = .autoupdatingCurrent) async -> QuietoHealthSummary {
        guard isAvailable else { return QuietoHealthSummary() }
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let mindfulSamples = await samples(of: mindful, from: weekStart, to: now)
        let mindfulSeconds = HealthIntervals.unionDuration(mindfulSamples.map { ($0.startDate, $0.endDate) })
        let quietoSeconds = HealthIntervals.unionDuration(
            mindfulSamples.filter { $0.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier }.map { ($0.startDate, $0.endDate) }
        )

        // Last night: from 18:00 the day before until noon (or now, if earlier).
        let today = calendar.startOfDay(for: now)
        let nightStart = calendar.date(byAdding: .hour, value: -6, to: today) ?? today
        let nightEnd = min(now, calendar.date(byAdding: .hour, value: 12, to: today) ?? now)
        let asleep: Set<Int> = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let sleepSamples = await samples(of: sleep, from: nightStart, to: nightEnd).filter { asleep.contains($0.value) }
        let clipped = sleepSamples.map { (max($0.startDate, nightStart), min($0.endDate, nightEnd)) }
        let sleepSeconds = HealthIntervals.unionDuration(clipped)

        return QuietoHealthSummary(
            mindfulMinutesThisWeek: Int(mindfulSeconds / 60),
            quietoMinutesThisWeek: Int(quietoSeconds / 60),
            lastNightSleepMinutes: sleepSeconds > 0 ? Int(sleepSeconds / 60) : nil
        )
    }

    private func samples(of type: HKCategoryType, from start: Date, to end: Date) async -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }
}

/// Health data is often recorded twice (iPhone and Apple Watch): overlapping
/// intervals are merged before adding them up.
enum HealthIntervals {
    static func unionDuration(_ intervals: [(Date, Date)]) -> TimeInterval {
        let sorted = intervals.filter { $0.1 > $0.0 }.sorted { $0.0 < $1.0 }
        var total: TimeInterval = 0
        var current: (Date, Date)?
        for interval in sorted {
            if let open = current, interval.0 <= open.1 {
                current = (open.0, max(open.1, interval.1))
            } else {
                if let open = current { total += open.1.timeIntervalSince(open.0) }
                current = interval
            }
        }
        if let open = current { total += open.1.timeIntervalSince(open.0) }
        return total
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

    func authorizationStatus() async -> QuietoNotificationStatus {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorized, .provisional, .ephemeral: .allowed
        default: .denied
        }
    }

    func schedule(hour: Int, minute: Int, weekdays: [Int], firstName: String) {
        let center = UNUserNotificationCenter.current()
        removeAll()
        let content = UNMutableNotificationContent()
        content.title = "Quieto"
        content.body = firstName.isEmpty ? "Une pause quand tu en as besoin.".quietoLocalized : QuietoLocalization.format("%@, une pause quand tu en as besoin.", firstName)
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

    func schedule(_ reminders: [PlannedReminder]) {
        let center = UNUserNotificationCenter.current()
        removeAll()
        let calendar = Calendar.autoupdatingCurrent
        for (index, reminder) in reminders.prefix(Self.maxPlanReminders).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Quieto"
            content.body = reminder.body
            content.sound = .default
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            components.calendar = calendar
            components.timeZone = .autoupdatingCurrent
            center.add(UNNotificationRequest(identifier: "\(Self.identifierPrefix).plan.\(index)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
        }
    }

    /// Room left for the trial reminder under the 64 pending requests of iOS.
    static let maxPlanReminders = PlanReminders.horizonDays

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
        content.body = "Ton essai gratuit se termine dans 2 jours. Tu peux gérer ton abonnement depuis ton profil.".quietoLocalized
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: Self.trialEndingIdentifier, content: content, trigger: trigger))
    }

    static let trialEndingIdentifier = "quieto.trial.ending"

    func refreshTrialEndingReminder(body: String) async {
        let center = UNUserNotificationCenter.current()
        guard let pending = await center.pendingNotificationRequests().first(where: { $0.identifier == Self.trialEndingIdentifier }),
              let content = pending.content.mutableCopy() as? UNMutableNotificationContent,
              content.body != body,
              // A time-interval trigger counts from when it is added: keep the original date.
              let fireDate = (pending.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate(),
              fireDate.timeIntervalSinceNow > 1 else { return }
        content.body = body
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
        // Same identifier: the new request replaces the pending one.
        try? await center.add(UNNotificationRequest(identifier: Self.trialEndingIdentifier, content: content, trigger: trigger))
    }

    func removeAll() {
        let identifiers = [Self.identifierPrefix] + (1...7).map { "\(Self.identifierPrefix).\($0)" }
            + (0..<Self.maxPlanReminders).map { "\(Self.identifierPrefix).plan.\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
