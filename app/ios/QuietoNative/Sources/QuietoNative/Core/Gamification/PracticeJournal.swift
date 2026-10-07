import Foundation

enum PracticeKind: String, Codable, CaseIterable {
    case meditation
    case breathing
    case sound
    case checkIn = "check_in"

    /// Kinds that make a day a practice day (a check-in alone does not).
    var countsAsPractice: Bool { self != .checkIn }

    init(session: QuietoSession) {
        self = session.readerMode == .breathing ? .breathing : .meditation
    }
}

/// One moment of practice: a session listened to, a background sound, a check-in.
struct PracticeEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: PracticeKind
    let contentID: String
    let seconds: Int
    let date: Date
}

/// Lifetime log of everything practised on this iPhone. Badges and the streak
/// are always recomputed from it, so it is the only source of truth; entries
/// not yet sent to the account are remembered until the upload succeeds.
final class PracticeJournal {
    enum Key {
        static let entries = "quieto.gamification.journal"
        static let pendingUpload = "quieto.gamification.pendingUpload"
        static let legacyImported = "quieto.gamification.legacyImported"
    }

    /// About ten years of daily practice; protects `UserDefaults` from growing forever.
    static let maximumEntries = 6_000

    private let defaults: UserDefaults
    private var cache: [PracticeEntry]?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Sorted from oldest to newest.
    var entries: [PracticeEntry] {
        if let cache { return cache }
        let decoded = defaults.data(forKey: Key.entries)
            .flatMap { try? JSONDecoder().decode([PracticeEntry].self, from: $0) } ?? []
        cache = decoded
        return decoded
    }

    var pendingUpload: [PracticeEntry] {
        let ids = Set((defaults.stringArray(forKey: Key.pendingUpload) ?? []).compactMap(UUID.init(uuidString:)))
        return entries.filter { ids.contains($0.id) }
    }

    @discardableResult
    func record(kind: PracticeKind, contentID: String, seconds: Int, at date: Date = .now) -> PracticeEntry {
        let entry = PracticeEntry(id: UUID(), kind: kind, contentID: contentID, seconds: max(0, seconds), date: date)
        save(entries + [entry])
        setPending(pendingIDs.union([entry.id]))
        return entry
    }

    /// Adds entries coming from the account (another device, a reinstall).
    /// Returns true when something new was added.
    @discardableResult
    func merge(_ remote: [PracticeEntry]) -> Bool {
        let known = Set(entries.map(\.id))
        let new = remote.filter { !known.contains($0.id) }
        guard !new.isEmpty else { return false }
        save(entries + new)
        return true
    }

    /// Forgets the in-memory copy, after the storage was wiped.
    func reload() {
        cache = nil
    }

    func markUploaded(_ ids: Set<UUID>) {
        setPending(pendingIDs.subtracting(ids))
    }

    /// Sessions completed before the journal existed (the activity store keeps
    /// 60 days) become journal entries once, so existing users keep their history.
    func importLegacyActivity(_ events: [ActivityEvent], catalog: QuietoSessionCatalogProviding) {
        guard !defaults.bool(forKey: Key.legacyImported) else { return }
        defaults.set(true, forKey: Key.legacyImported)
        guard entries.isEmpty, !events.isEmpty else { return }
        let imported = events.map { event in
            let kind = catalog.sessions.first { $0.id == event.sessionID }.map(PracticeKind.init(session:)) ?? .meditation
            return PracticeEntry(id: UUID(), kind: kind, contentID: event.sessionID, seconds: event.seconds, date: event.date)
        }
        save(imported)
        setPending(pendingIDs.union(imported.map(\.id)))
    }

    private var pendingIDs: Set<UUID> {
        Set((defaults.stringArray(forKey: Key.pendingUpload) ?? []).compactMap(UUID.init(uuidString:)))
    }

    private func setPending(_ ids: Set<UUID>) {
        defaults.set(ids.map(\.uuidString), forKey: Key.pendingUpload)
    }

    private func save(_ value: [PracticeEntry]) {
        let sorted = Array(value.sorted { $0.date < $1.date }.suffix(Self.maximumEntries))
        cache = sorted
        defaults.set(try? JSONEncoder().encode(sorted), forKey: Key.entries)
    }
}
