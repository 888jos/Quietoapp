import Foundation

/// Written scripts and their recorded narration, produced by `Narration/generate.mjs`
/// and bundled as `narration-<langue>.json`. A session listed here reads its own
/// script instead of the generic template; `audioPath` is set once the voice
/// has been generated and points into the `session-audio` bucket.
struct NarrationEntry: Decodable, Equatable {
    let title: String
    let transcript: String
    let targetSeconds: Int
    let audioPath: String?
    let durationSeconds: Int?
}

enum NarrationCatalog {
    /// Scripts of the displayed language, reloaded when the language changes in the profile.
    static var entries: [String: NarrationEntry] {
        let code = QuietoLocalization.languageCode
        if let cached = cache, cached.code == code { return cached.entries }
        let loaded = load(languageCode: code)
        cache = (code, loaded)
        return loaded
    }
    nonisolated(unsafe) private static var cache: (code: String, entries: [String: NarrationEntry])?

    static func load(languageCode: String, bundle: Bundle = .main) -> [String: NarrationEntry] {
        struct File: Decodable { let sessions: [String: NarrationEntry] }
        guard let url = bundle.url(forResource: "narration-\(languageCode)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [:] }
        return file.sessions
    }
}
