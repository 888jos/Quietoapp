import Foundation

protocol QuietoDownloadManaging: AnyObject {
    var downloadedIDs: Set<String> { get }
    var progress: [String: Double] { get }
    func isDownloaded(_ session: QuietoSession) -> Bool
    func start(_ session: QuietoSession) -> Bool
    func cancel(_ session: QuietoSession)
    func delete(_ session: QuietoSession)
    func localURL(for session: QuietoSession) -> URL?
    func deleteAll()
    var occupiedBytes: Int64 { get }
}

/// Offline copies of session audio. One instance for the whole app: iOS allows a
/// single background URLSession per identifier, and the task → session mapping
/// lives in `taskDescription` so downloads finished while the app was not
/// running are still recognised on the next launch.
final class QuietoDownloadStore: NSObject, ObservableObject, QuietoDownloadManaging, URLSessionDownloadDelegate {
    static let sessionIdentifier = "\(Bundle.main.bundleIdentifier ?? "com.quietoapp.app").audio-downloads"

    /// Set by the app delegate when iOS relaunches the app for background events.
    var backgroundEventsCompletion: (() -> Void)?

    @Published private(set) var downloadedIDs = Set<String>()
    @Published private(set) var progress = [String: Double]()
    @Published private(set) var occupiedBytes: Int64 = 0
    @Published private(set) var lastError: String?

    private let fileManager = FileManager.default
    private let signer: AudioURLSigning?
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.allowsCellularAccess = true
        // Main queue: every delegate callback mutates published state.
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Quieto/Audio", isDirectory: true)
    }
    private var directory: URL { Self.directory }

    /// Create exactly one per process (see above): `AppContainer` owns it.
    init(signer: AudioURLSigning?) {
        self.signer = signer
        super.init()
        prepareDirectory()
        refreshIndex()
        // Re-attach to downloads started before a relaunch.
        session.getAllTasks { tasks in
            DispatchQueue.main.async {
                for task in tasks where task.state == .running {
                    guard let id = task.taskDescription else { continue }
                    self.progress[id] = task.progress.fractionCompleted
                }
            }
        }
    }

    private func prepareDirectory() {
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        // Re-downloadable content: keep it out of iCloud backups (App Review 2.23).
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    func isDownloaded(_ session: QuietoSession) -> Bool { downloadedIDs.contains(session.id) && localURL(for: session) != nil }

    func localURL(for session: QuietoSession) -> URL? {
        let url = fileURL(for: session.id)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func fileURL(for sessionID: String) -> URL {
        directory.appendingPathComponent("\(sessionID).mp3")
    }

    @discardableResult
    func start(_ session: QuietoSession) -> Bool {
        guard !session.audioFile.isEmpty, let signer else { return false }
        if isDownloaded(session) || progress[session.id] != nil { return true }
        progress[session.id] = 0
        lastError = nil
        Task { @MainActor [weak self] in
            let url = try? await signer.signedAudioURL(path: session.audioFile)
            do {
                guard let self else { return }
                guard let url else {
                    self.progress[session.id] = nil
                    self.lastError = "Téléchargement impossible pour le moment."
                    return
                }
                let task = self.session.downloadTask(with: url)
                task.taskDescription = session.id
                task.resume()
            }
        }
        return true
    }

    func cancel(_ session: QuietoSession) {
        self.session.getAllTasks { tasks in
            tasks.filter { $0.taskDescription == session.id }.forEach { $0.cancel() }
        }
        progress[session.id] = nil
    }

    func delete(_ session: QuietoSession) {
        try? fileManager.removeItem(at: fileURL(for: session.id))
        refreshIndex()
    }

    /// Account deletion / sign-out: cancel everything and remove the files.
    func deleteAll() {
        session.getAllTasks { tasks in tasks.forEach { $0.cancel() } }
        progress.removeAll()
        try? fileManager.removeItem(at: directory)
        prepareDirectory()
        refreshIndex()
    }

    private func refreshIndex() {
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        downloadedIDs = Set(files.filter { $0.pathExtension == "mp3" }.map { $0.deletingPathExtension().lastPathComponent })
        occupiedBytes = files.reduce(0) { total, file in
            guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return total }
            return total + Int64(size)
        }
    }

    // MARK: URLSessionDownloadDelegate (main queue)

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        progress[id] = min(0.99, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        // A 403/404 body is JSON, not audio: never store it as a session.
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            progress[id] = nil
            lastError = status == 400 || status == 403 ? "Ton abonnement doit être actif pour télécharger." : "Téléchargement impossible pour le moment."
            return
        }
        let destination = fileURL(for: id)
        do {
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: location)
            } else {
                try fileManager.moveItem(at: location, to: destination)
            }
            progress[id] = nil
        } catch {
            progress[id] = nil
            lastError = "Le fichier n’a pas pu être enregistré."
        }
        refreshIndex()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription, let error else { return }
        progress[id] = nil
        if (error as? URLError)?.code != .cancelled { lastError = "Téléchargement interrompu." }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let completion = backgroundEventsCompletion
        backgroundEventsCompletion = nil
        completion?()
    }
}
