import Foundation

protocol QuietoDownloadManaging: AnyObject {
    var downloadedIDs: Set<String> { get }
    var progress: [String: Double] { get }
    func isDownloaded(_ session: QuietoSession) -> Bool
    func start(_ session: QuietoSession, isPremium: Bool) -> Bool
    func cancel(_ session: QuietoSession)
    func delete(_ session: QuietoSession)
    func localURL(for session: QuietoSession) -> URL?
    var occupiedBytes: Int64 { get }
}

final class QuietoDownloadStore: NSObject, ObservableObject, QuietoDownloadManaging, URLSessionDownloadDelegate {
    @Published private(set) var downloadedIDs = Set<String>()
    @Published private(set) var progress = [String: Double]()
    @Published private(set) var occupiedBytes: Int64 = 0

    private let fileManager = FileManager.default
    private var tasks = [Int: String]()
    private lazy var session: URLSession = {
        let identifier = "\(Bundle.main.bundleIdentifier ?? "com.quietoapp.app").audio-downloads"
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.allowsCellularAccess = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    private var directory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Quieto/Audio", isDirectory: true)
    }

    override init() {
        super.init()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        refreshIndex()
    }

    func isDownloaded(_ session: QuietoSession) -> Bool { downloadedIDs.contains(session.id) && localURL(for: session) != nil }
    func localURL(for session: QuietoSession) -> URL? {
        let url = directory.appendingPathComponent("\(session.id).mp3")
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    func start(_ session: QuietoSession, isPremium: Bool) -> Bool {
        guard !session.isPremium || isPremium, !session.audioFile.isEmpty else { return false }
        if isDownloaded(session) { return true }
        if let existing = tasks.first(where: { $0.value == session.id }) { self.session.getAllTasks { _ in }; _ = existing; return true }
        progress[session.id] = 0
        Task { [weak self] in
            guard let self else { return }
            let url: URL?
            if QuietoBackendConfiguration.supabaseURL != nil {
                url = try? await QuietoSupabaseService.shared.signedAudioURL(path: session.audioFile)
            } else {
                url = Self.remoteURL(for: session.audioFile)
            }
            await MainActor.run {
                guard let url else { self.progress[session.id] = nil; return }
                self.enqueue(sessionID: session.id, url: url)
            }
        }
        return true
    }

    private func enqueue(sessionID: String, url: URL) {
        let task = self.session.downloadTask(with: url)
        tasks[task.taskIdentifier] = sessionID
        task.resume()
    }

    func cancel(_ session: QuietoSession) {
        for (taskID, id) in tasks where id == session.id { self.session.getAllTasks { tasks in tasks.first { $0.taskIdentifier == taskID }?.cancel() } }
        progress[session.id] = nil
    }

    func delete(_ session: QuietoSession) {
        try? fileManager.removeItem(at: directory.appendingPathComponent("\(session.id).mp3"))
        downloadedIDs.remove(session.id)
        refreshIndex()
    }

    private func refreshIndex() {
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        downloadedIDs = Set(files.filter { $0.pathExtension == "mp3" }.map { $0.deletingPathExtension().lastPathComponent })
        occupiedBytes = files.reduce(0) { total, file in
            guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return total }
            return total + Int64(size)
        }
    }

    static func remoteURL(for file: String) -> URL? {
        guard let encoded = file.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/quieto-06.firebasestorage.app/o/\(encoded)?alt=media")
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = tasks[downloadTask.taskIdentifier], totalBytesExpectedToWrite > 0 else { return }
        DispatchQueue.main.async { self.progress[id] = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = tasks[downloadTask.taskIdentifier] else { return }
        let destination = directory.appendingPathComponent("\(id).mp3")
        try? fileManager.removeItem(at: destination)
        do { try fileManager.moveItem(at: location, to: destination) }
        catch { DispatchQueue.main.async { self.progress[id] = nil } }
        DispatchQueue.main.async { self.tasks[downloadTask.taskIdentifier] = nil; self.progress[id] = 1; self.refreshIndex() }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = tasks[task.taskIdentifier] else { return }
        if error != nil { DispatchQueue.main.async { self.progress[id] = nil } }
        DispatchQueue.main.async { self.tasks[task.taskIdentifier] = nil }
    }
}
