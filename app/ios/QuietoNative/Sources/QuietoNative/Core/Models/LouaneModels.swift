import Foundation

/// What Louane launches with an answer: a session, an ambient sound, or a
/// meditation with a sound under it (`[SEANCE:id]` / `[SON:id]` on the server).
struct LouaneRecommendation: Identifiable, Equatable {
    let id: String
    let sessionID: String?
    let ambienceID: String?
    /// The short "why this one" line of the card (`raison`), may be empty.
    let reason: String

    init(id: String, sessionID: String? = nil, ambienceID: String? = nil, reason: String = "") {
        self.id = id; self.sessionID = sessionID; self.ambienceID = ambienceID; self.reason = reason
    }
}

enum LouaneAuthor: String { case louane, user, system }

struct LouaneMessage: Identifiable, Equatable {
    let id: UUID
    let author: LouaneAuthor
    let text: String
    let recommendation: LouaneRecommendation?
    let date: Date
    var isFailed = false

    init(id: UUID = UUID(), author: LouaneAuthor, text: String, recommendation: LouaneRecommendation? = nil, date: Date = .now, isFailed: Bool = false) {
        self.id = id; self.author = author; self.text = text; self.recommendation = recommendation; self.date = date; self.isFailed = isFailed
    }
}

/// `limited` is not retryable (daily cap, subscription required); `failed` is.
enum LouaneConversationStatus: Equatable { case idle, sending, failed(String), limited(String) }

enum LouaneServiceError: LocalizedError, Equatable {
    case premiumRequired
    case dailyLimit
    case unavailable
    case unreadable
    case empty
    /// The app was built without the Supabase URL or key (Info.plist placeholders).
    case notConfigured
    /// No Supabase session: the anonymous sign-in has not happened or expired.
    case signedOut
    /// The `louane` Edge Function is not deployed (404).
    case notDeployed
    /// The function runs but lacks its secrets (`503 not_configured`).
    case serverNotConfigured

    /// Localized, with the crisis number of the iPhone's country.
    static var crisisLine: String {
        let line = CrisisLine.current
        if let hotline = line.hotline {
            return QuietoLocalization.format("Si tu traverses un moment difficile, le %@ répond 24h/24, gratuitement.", hotline)
        }
        return QuietoLocalization.format("Si tu traverses un moment difficile, appelle le %@ en cas de danger.", line.emergency)
    }

    var errorDescription: String? {
        switch self {
        case .premiumRequired: "Louane fait partie de ton abonnement Quieto. Vérifie qu’il est bien actif.".quietoLocalized
        case .dailyLimit: QuietoLocalization.format("Louane a besoin de se reposer jusqu’à demain. %@", Self.crisisLine)
        case .unavailable: "Le service Louane est momentanément indisponible.".quietoLocalized
        case .unreadable: "La réponse de Louane est illisible.".quietoLocalized
        case .empty: "Louane n’a pas renvoyé de réponse.".quietoLocalized
        case .notConfigured: "Louane n’est pas encore reliée au serveur de Quieto.".quietoLocalized
        case .signedOut: "Ta session a expiré. Ferme puis rouvre Quieto pour reparler à Louane.".quietoLocalized
        case .notDeployed, .serverNotConfigured: "Le service Louane est momentanément indisponible.".quietoLocalized
        }
    }

    /// What is wrong, for the developer (Xcode console), never shown to the person.
    var diagnostic: String {
        switch self {
        case .notConfigured: "SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY are still REPLACE_… in project.yml (Info.plist)"
        case .signedOut: "no Supabase session (anonymous sign-in failed?)"
        case .notDeployed: "404: run `supabase functions deploy louane`"
        case .serverNotConfigured: "503: set OPENAI_API_KEY / SUPABASE_SECRET_KEY secrets on the function"
        case .premiumRequired: "no entitlement (user_has_premium = false)"
        case .dailyLimit: "daily cap reached"
        case .unavailable: "unexpected HTTP status"
        case .unreadable: "response is not {result: {...}}"
        case .empty: "empty answer"
        }
    }
}

/// What the iPhone tells Louane besides the conversation: recent listens and
/// where the person is in the programme. Built on device, nothing from Health.
struct LouaneClientContext: Equatable {
    struct Listen: Equatable { let sessionID: String; let count: Int; let daysAgo: Int }
    struct Programme: Equatable {
        let title: String
        let step: Int
        let isActive: Bool
        let isFinished: Bool
        let doneToday: Bool
        let nextSessionID: String?
    }

    var listens: [Listen] = []
    var programme: Programme?

    static let empty = LouaneClientContext()

    /// Most recent sessions first, at most 20 (the server bound).
    static func make(events: [ActivityEvent], programmeTitle: String, programmeIDs: [String], hasProgram: Bool, now: Date = .now, calendar: Calendar = .current) -> LouaneClientContext {
        let today = calendar.startOfDay(for: now)
        let listens = Dictionary(grouping: events, by: \.sessionID)
            .map { id, items -> (Listen, Date) in
                let last = items.map(\.date).max() ?? now
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day ?? 0
                return (Listen(sessionID: id, count: items.count, daysAgo: max(0, days)), last)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(20)
            .map(\.0)
        var programme: Programme?
        if hasProgram, !programmeIDs.isEmpty {
            let done = Set(events.map(\.sessionID))
            let completed = programmeIDs.filter(done.contains).count
            let doneToday = events.contains { programmeIDs.contains($0.sessionID) && $0.date >= today }
            programme = Programme(
                title: programmeTitle,
                step: min(completed + 1, programmeIDs.count),
                isActive: completed < programmeIDs.count,
                isFinished: completed >= programmeIDs.count,
                doneToday: doneToday,
                nextSessionID: programmeIDs.first { !done.contains($0) }
            )
        }
        return LouaneClientContext(listens: Array(listens), programme: programme)
    }
}

struct LouaneBackendReply {
    let text: String
    let recommendation: LouaneRecommendation?
    /// Louane's memory sheet as updated by the server (`memoire`). Nil when the
    /// server sent none; the caller decides whether to keep it.
    var memory: String? = nil
}

protocol LouaneBackendProviding {
    func send(message: String, history: [LouaneMessage], temporary: Bool) async throws -> LouaneBackendReply
}

protocol LouaneMemoryProviding: AnyObject {
    var text: String { get }
    func update(_ text: String)
    func remove()
}
