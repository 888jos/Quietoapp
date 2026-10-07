import Foundation
import Supabase

private struct QuietoPracticeEntryRow: Codable {
    let userID: String?
    let clientEntryID: UUID
    let kind: String
    let contentID: String
    let seconds: Int
    let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case clientEntryID = "client_entry_id"
        case kind
        case contentID = "content_id"
        case seconds
        case occurredAt = "occurred_at"
    }
}

extension QuietoSupabaseService: PracticeSyncing {
    func uploadPractice(_ entries: [PracticeEntry]) async throws {
        guard let client else { throw QuietoBackendError.notConfigured }
        guard !entries.isEmpty else { return }
        // RLS compares with the JWT `sub`, which is lowercase.
        let userID = try await client.auth.session.user.id.quietoUserID
        let rows = entries.map {
            QuietoPracticeEntryRow(userID: userID, clientEntryID: $0.id, kind: $0.kind.rawValue, contentID: $0.contentID, seconds: $0.seconds, occurredAt: $0.date)
        }
        for chunk in stride(from: 0, to: rows.count, by: 500).map({ Array(rows[$0..<min($0 + 500, rows.count)]) }) {
            try await client.from("practice_entries")
                .upsert(chunk, onConflict: "user_id,client_entry_id", ignoreDuplicates: true)
                .execute()
        }
    }

    func fetchPractice() async throws -> [PracticeEntry] {
        guard let client else { throw QuietoBackendError.notConfigured }
        let userID = try await client.auth.session.user.id.quietoUserID
        let rows: [QuietoPracticeEntryRow] = try await client.from("practice_entries")
            .select("client_entry_id,kind,content_id,seconds,occurred_at")
            .eq("user_id", value: userID)
            .order("occurred_at", ascending: true)
            .limit(PracticeJournal.maximumEntries)
            .execute().value
        return rows.compactMap { row in
            PracticeKind(rawValue: row.kind).map {
                PracticeEntry(id: row.clientEntryID, kind: $0, contentID: row.contentID, seconds: row.seconds, date: row.occurredAt)
            }
        }
    }
}
