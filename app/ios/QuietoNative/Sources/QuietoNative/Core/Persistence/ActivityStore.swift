import Foundation

struct ActivityEvent: Equatable {
    let sessionID: String
    let seconds: Int
    let date: Date
}

/// Completed listening sessions kept on this iPhone. They feed the weekly
/// statistics of the profile and the local progress of the programme.
/// The storage format (`[[String: Any]]`) is the one already on devices.
final class ActivityStore {
    private static let eventsKey = "quieto.native.activity.events"
    private static func totalKey(_ sessionID: String) -> String { "quieto.native.activity.\(sessionID)" }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var events: [ActivityEvent] {
        let raw = defaults.array(forKey: Self.eventsKey) as? [[String: Any]] ?? []
        return raw.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return ActivityEvent(
                sessionID: id,
                seconds: item["seconds"] as? Int ?? 0,
                date: Date(timeIntervalSince1970: item["date"] as? Double ?? 0)
            )
        }
    }

    var completedSessionIDs: Set<String> { Set(events.map(\.sessionID)) }

    func events(since start: Date) -> [ActivityEvent] {
        events.filter { $0.date >= start }
    }

    func record(sessionID: String, seconds: Int, at date: Date = .now) {
        let key = Self.totalKey(sessionID)
        defaults.set(defaults.integer(forKey: key) + seconds, forKey: key)
        // Only the recent weeks feed the profile statistics.
        let cutoff = date.addingTimeInterval(-60 * 86_400)
        let kept = (events + [ActivityEvent(sessionID: sessionID, seconds: seconds, date: date)])
            .filter { $0.date >= cutoff }
            .suffix(500)
        defaults.set(kept.map { ["id": $0.sessionID, "seconds": $0.seconds, "date": $0.date.timeIntervalSince1970] }, forKey: Self.eventsKey)
    }
}
