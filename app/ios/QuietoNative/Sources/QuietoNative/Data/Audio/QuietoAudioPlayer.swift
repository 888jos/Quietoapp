import AVFoundation
import MediaPlayer
import UIKit

@MainActor
final class QuietoAudioPlayer: NSObject, ObservableObject {
    @Published private(set) var currentSession: QuietoSession?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var timerRemaining: TimeInterval?
    @Published private(set) var selectedAmbience: QuietoAmbience?
    @Published var ambienceVolume: Double = 0.28 { didSet { ambiencePlayer?.volume = Float(ambienceVolume) } }
    @Published var isFullPlayerPresented = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var timer: Timer?
    private var ambiencePlayer: AVAudioPlayer?
    private let speechRenderer = QuietoSpeechRenderer()
    private var playbackTask: Task<Void, Never>?
    private var routeObserver: NSObjectProtocol?
    private var breathingTimer: Timer?
    private var breathingStartedAt: Date?
    private var lastSavedPosition: Double = -1
    /// Seconds actually heard in the current session (seeks don't count).
    private var listenedSeconds: Double = 0
    private var lastTickPosition: Double?
    private var resumeAfterInterruption = false
    private let preferences: QuietoPreferences

    /// Called when a session was really listened to (at least half of it),
    /// with the number of seconds heard. Tracking lives in `PlaybackTracker`.
    var onSessionCompleted: ((QuietoSession, Int) -> Void)?

    init(preferences: QuietoPreferences = QuietoPreferences()) {
        self.preferences = preferences
        super.init()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        setupRemoteCommands()
    }

    func presentFullPlayer() { isFullPlayerPresented = true }

    /// Called when the scene resigns active. It intentionally does not pause playback:
    /// the AVAudioSession + UIBackgroundModes audio configuration owns continuation.
    func keepAudioSessionAlive() {
        guard player != nil || ambiencePlayer != nil else { return }
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        updateNowPlaying()
    }

    func play(_ session: QuietoSession, localURL: URL? = nil) {
        if currentSession?.id == session.id, session.readerMode == .breathing {
            if duration > 0, position >= duration - 3 { seek(to: 0) }
            resumeBreathing()
            return
        }
        if currentSession?.id == session.id, let player {
            if duration > 0, position >= duration - 3 { seek(to: 0) }
            player.playImmediately(atRate: 1)
            isPlaying = true
            updateNowPlaying()
            return
        }
        stop()
        currentSession = session
        if session.readerMode == .breathing {
            startBreathing(session)
            return
        }
        isLoading = true
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                // A durable downloaded master takes priority. Otherwise Quieto renders the
                // checked transcript with Apple's on-device voice and caches the result.
                let url: URL
                if let localURL {
                    url = localURL
                } else {
                    url = try await speechRenderer.render(session)
                }
                guard !Task.isCancelled else { return }
                startPlayer(url: url, session: session)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// Explicit play/pause used by remote commands, interruptions and the sleep timer.
    func resume() {
        guard currentSession != nil, !isPlaying else { return }
        if currentSession?.readerMode == .breathing { resumeBreathing() }
        else if let player { player.play(); isPlaying = true }
        updateNowPlaying()
    }

    func pause() {
        guard isPlaying else { return }
        if currentSession?.readerMode == .breathing { pauseBreathing() }
        else { player?.pause(); isPlaying = false; savePosition(force: true) }
        updateNowPlaying()
    }

    func toggle() {
        if currentSession?.readerMode == .breathing {
            isPlaying ? pauseBreathing() : resumeBreathing()
            return
        }
        guard player != nil else { return }
        isPlaying ? pause() : resume()
    }
    func seek(to value: Double) {
        let bounded = max(0, min(duration, value))
        if currentSession?.readerMode == .breathing {
            position = bounded
            breathingStartedAt = isPlaying ? Date().addingTimeInterval(-bounded) : nil
        } else {
            player?.seek(to: CMTime(seconds: bounded, preferredTimescale: 600))
            position = bounded
        }
        lastTickPosition = bounded
        savePosition(force: true)
        updateNowPlaying()
    }
    func skip(by seconds: Double) { seek(to: max(0, min(duration, position + seconds))) }
    func setSleepTimer(minutes: Int?) { timer?.invalidate(); timerRemaining = minutes.map { TimeInterval($0 * 60) }; guard minutes != nil else { return }; timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tickTimer() } } }

    func playAmbience(_ ambience: QuietoAmbience) {
        do {
            try configureAudioSession()
            guard let url = Bundle.main.url(forResource: ambience.audioResource, withExtension: "mp3") else { throw QuietoSpeechRenderError.unavailable }
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Float(ambienceVolume)
            player.prepareToPlay()
            player.play()
            ambiencePlayer?.stop()
            ambiencePlayer = player
            selectedAmbience = ambience
        } catch { errorMessage = "Cette ambiance n’est pas disponible." }
    }

    func stopAmbience() { ambiencePlayer?.stop(); ambiencePlayer = nil; selectedAmbience = nil }

    func stop() {
        playbackTask?.cancel(); playbackTask = nil
        breathingTimer?.invalidate(); breathingTimer = nil; breathingStartedAt = nil
        player?.pause(); savePosition(force: true)
        listenedSeconds = 0; lastTickPosition = nil; resumeAfterInterruption = false
        if let timeObserver { player?.removeTimeObserver(timeObserver) }; timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }; interruptionObserver = nil
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }; routeObserver = nil
        player = nil; isPlaying = false; isLoading = false
        timer?.invalidate(); timer = nil; timerRemaining = nil
        stopAmbience()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func startBreathing(_ session: QuietoSession) {
        duration = Double(session.durationMinutes * 60)
        let saved = preferences.playbackPosition(for: session.id)
        position = saved > 0 && saved < duration - 5 ? saved : 0
        isLoading = false
        resumeBreathing()
    }

    private func resumeBreathing() {
        guard currentSession?.readerMode == .breathing else { return }
        if duration > 0, position >= duration { position = 0 }
        breathingStartedAt = Date().addingTimeInterval(-position)
        lastTickPosition = position
        breathingTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tickBreathing() }
        }
        RunLoop.main.add(timer, forMode: .common)
        breathingTimer = timer
        isPlaying = true
    }

    private func pauseBreathing() {
        tickBreathing()
        breathingTimer?.invalidate(); breathingTimer = nil; breathingStartedAt = nil
        isPlaying = false
        savePosition(force: true)
    }

    private func tickBreathing() {
        guard isPlaying, let startedAt = breathingStartedAt, let session = currentSession else { return }
        position = min(duration, Date().timeIntervalSince(startedAt))
        // Breathing is wall-clock based: time spent with the app suspended still counts.
        accumulateListening(maxStep: .infinity)
        savePosition()
        if position >= duration {
            breathingTimer?.invalidate(); breathingTimer = nil; breathingStartedAt = nil
            isPlaying = false
            position = 0
            preferences.setPlaybackPosition(nil, for: session.id)
            recordCompletion(session)
        }
    }

    private func tickTimer() { guard let left = timerRemaining else { return }; if left <= 1 { pause(); stopAmbience(); setSleepTimer(minutes: nil) } else { timerRemaining = left - 1 } }

    private func configureAudioSession() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothA2DP, .allowAirPlay])
        try audio.setPreferredIOBufferDuration(0.023)
        try audio.setActive(true)
    }

    private func startPlayer(url: URL, session: QuietoSession) {
        do {
            try configureAudioSession()
            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 1
            player = AVPlayer(playerItem: item)
            player?.isMuted = false
            player?.volume = 1
            player?.automaticallyWaitsToMinimizeStalling = false
            observe(item: item, session: session)
            duration = Self.audioDuration(at: url) ?? Double(session.durationMinutes * 60)
            let saved = preferences.playbackPosition(for: session.id)
            if saved > 0, saved < duration - 5 {
                player?.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
                position = saved
            } else {
                preferences.setPlaybackPosition(nil, for: session.id)
                position = 0
            }
            lastTickPosition = position
            player?.playImmediately(atRate: 1)
            isPlaying = true
            isLoading = false
            updateNowPlaying()
        } catch {
            errorMessage = "Cette séance n’est pas disponible pour le moment."
            isLoading = false
        }
    }
    private func observe(item: AVPlayerItem, session: QuietoSession) {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                position = time.seconds.isFinite ? time.seconds : 0
                duration = item.duration.seconds.isFinite ? item.duration.seconds : Double(session.durationMinutes * 60)
                if isPlaying { accumulateListening() }
                savePosition()
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = false
                self.position = 0
                preferences.setPlaybackPosition(nil, for: session.id)
                self.player?.seek(to: .zero)
                self.updateNowPlaying()
                self.recordCompletion(session)
            }
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo, let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt).map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == .began {
                    self.resumeAfterInterruption = self.isPlaying
                    self.pause()
                } else if type == .ended, shouldResume, self.resumeAfterInterruption {
                    self.resumeAfterInterruption = false
                    try? AVAudioSession.sharedInstance().setActive(true)
                    self.resume()
                }
            }
        }
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.pause() }
        }
    }

    private func setupRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.resume() }; return .success }
        commands.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.toggle() }; return .success }
        commands.togglePlayPauseCommand.isEnabled = true
        commands.skipForwardCommand.preferredIntervals = [15]
        commands.skipForwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(by: 15) }; return .success }
        commands.skipBackwardCommand.preferredIntervals = [15]
        commands.skipBackwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(by: -15) }; return .success }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.skipForwardCommand.isEnabled = true
        commands.skipBackwardCommand.isEnabled = true
        commands.changePlaybackPositionCommand.isEnabled = true
    }

    /// Throttled: at most one write every 5 s of playback, plus explicit saves.
    private func savePosition(force: Bool = false) {
        guard let id = currentSession?.id else { return }
        guard force || abs(position - lastSavedPosition) >= 5 else { return }
        lastSavedPosition = position
        preferences.setPlaybackPosition(position, for: id)
    }

    private func accumulateListening(maxStep: Double = 2) {
        defer { lastTickPosition = position }
        guard let last = lastTickPosition else { return }
        let delta = position - last
        if delta > 0, delta <= maxStep { listenedSeconds += delta }
    }

    private func recordCompletion(_ session: QuietoSession) {
        // Jumping to the end is not a completed session: count what was heard.
        let heard = Int(listenedSeconds.rounded())
        listenedSeconds = 0; lastTickPosition = nil
        let required = Double(max(1, session.durationMinutes * 60)) * 0.5
        guard Double(heard) >= required else { return }
        onSessionCompleted?(session, max(1, heard))
    }
    private static func audioDuration(at url: URL) -> Double? {
        guard let file = try? AVAudioFile(forReading: url), file.processingFormat.sampleRate > 0 else { return nil }
        return Double(file.length) / file.processingFormat.sampleRate
    }
    private func updateNowPlaying() {
        guard let session = currentSession else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: session.title.quietoLocalized,
            MPMediaItemPropertyArtist: "Quieto · \(session.practiceType.rawValue.quietoLocalized)",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0
        ]
        if let image = UIImage(named: session.imageName) ?? UIImage(contentsOfFile: Bundle.main.path(forResource: session.imageName, ofType: nil) ?? "") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
