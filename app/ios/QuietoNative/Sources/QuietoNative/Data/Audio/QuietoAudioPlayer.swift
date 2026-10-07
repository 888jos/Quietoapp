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
    @Published var ambienceVolume: Double = QuietoPreferences.defaultAmbienceVolume {
        didSet {
            ambiencePlayer?.volume = Float(ambienceVolume)
            preferences.ambienceVolume = ambienceVolume
        }
    }
    @Published var isFullPlayerPresented = false
    /// Bumped each time a breathing exercise starts, and each time one runs to
    /// its end: the full-screen guide opens and shows its closing screen on these.
    @Published private(set) var breathingStarts = 0
    @Published private(set) var breathingCompletions = 0
    /// Bumped when a guided session is really listened to its end; the
    /// feedback screen opens on it for `lastCompletedSession`.
    @Published private(set) var guidedCompletions = 0
    private(set) var lastCompletedSession: QuietoSession?
    /// How the person feels after a session (« calmer », « same »…), for analytics.
    var onSessionFeedback: ((QuietoSession, String) -> Void)?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var timer: Timer?
    private var ambiencePlayer: AVQueuePlayer?
    /// Keeps the loop alive: gapless, unlike `AVAudioPlayer.numberOfLoops` on compressed files.
    private var ambienceLooper: AVPlayerLooper?
    /// The ambience plays on its own clock, like a music app: it can be paused,
    /// survives the app going to the background and stops at the chosen time.
    @Published private(set) var isAmbiencePlaying = false
    /// When the sound fades out and stops. Nil = until the person stops it.
    @Published private(set) var ambienceEndsAt: Date?
    /// Time left when the sound was paused, so a pause does not eat the timer.
    private var ambiencePausedRemaining: TimeInterval?
    @Published var isAmbiencePlayerPresented = false
    private var ambienceTimer: Timer?
    private var ambienceInterruptionObserver: NSObjectProtocol?
    private var resumeAmbienceAfterInterruption = false
    private let speechRenderer = QuietoSpeechRenderer()
    private var playbackTask: Task<Void, Never>?
    private var routeObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
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
    /// Called when a background sound stops, with how long it played.
    var onAmbienceListened: ((QuietoAmbience, Int) -> Void)?
    /// Signs a `session-audio` path so a narration can stream without being
    /// downloaded first. Nil when the backend is not configured.
    var remoteAudioURL: ((String) async throws -> URL)?
    private var ambienceStartedAt: Date?
    private var languageObserver: NSObjectProtocol?

    init(preferences: QuietoPreferences = QuietoPreferences()) {
        self.preferences = preferences
        super.init()
        ambienceVolume = preferences.ambienceVolume
        UIApplication.shared.beginReceivingRemoteControlEvents()
        setupRemoteCommands()
        // Lock screen texts follow a language change made in the profile.
        languageObserver = NotificationCenter.default.addObserver(forName: QuietoLocalization.didChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else { return }
                self.updateNowPlaying()
            }
        }
    }

    func presentFullPlayer() { isFullPlayerPresented = true }

    /// Called when the scene resigns active. It intentionally does not pause playback:
    /// the AVAudioSession + UIBackgroundModes audio configuration owns continuation.
    func keepAudioSessionAlive() {
        guard player != nil || ambiencePlayer != nil else { return }
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        updateNowPlaying()
    }

    /// `breathingMinutes` overrides the default length of a breathing exercise.
    func play(_ session: QuietoSession, localURL: URL? = nil, breathingMinutes: Int? = nil) {
        if currentSession?.id == session.id, session.readerMode == .breathing {
            if duration > 0, position >= duration - 3 { seek(to: 0) }
            resumeBreathing()
            breathingStarts += 1
            return
        }
        if currentSession?.id == session.id, let player {
            if duration > 0, position >= duration - 3 { seek(to: 0) }
            player.playImmediately(atRate: 1)
            isPlaying = true
            updateNowPlaying()
            return
        }
        // The ambience chosen on the session sheet keeps playing under the voice.
        stopSession()
        currentSession = session
        if session.readerMode == .breathing {
            startBreathing(session, minutes: breathingMinutes)
            return
        }
        isLoading = true
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Downloaded copy first, then the published narration streamed from
                // Supabase, and Apple's on-device voice as the last resort (offline,
                // or no narration generated yet).
                let url: URL
                var isRemote = false
                if let localURL {
                    url = localURL
                } else if let remote = await signedNarrationURL(for: session) {
                    url = remote
                    isRemote = true
                } else {
                    url = try await speechRenderer.render(session)
                }
                guard !Task.isCancelled else { return }
                startPlayer(url: url, session: session, fallbackToSpeech: isRemote)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func signedNarrationURL(for session: QuietoSession) async -> URL? {
        guard !session.audioFile.isEmpty, let remoteAudioURL else { return nil }
        return try? await remoteAudioURL(session.audioFile)
    }

    /// The streamed file could not be read (missing object, network): read the
    /// script with the on-device voice instead of leaving the player silent.
    private func fallBackToSpeech(_ session: QuietoSession) {
        guard currentSession?.id == session.id else { return }
        releasePlayer()
        isLoading = true
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await speechRenderer.render(session)
                guard !Task.isCancelled else { return }
                startPlayer(url: url, session: session, fallbackToSpeech: false)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    /// Explicit play/pause used by remote commands, interruptions and the sleep timer.
    func resume() {
        guard currentSession != nil else { resumeAmbience(); return }
        guard !isPlaying else { return }
        if currentSession?.readerMode == .breathing { resumeBreathing() }
        else if let player { player.play(); isPlaying = true }
        updateNowPlaying()
    }

    func pause() {
        guard currentSession != nil else { pauseAmbience(); return }
        guard isPlaying else { return }
        if currentSession?.readerMode == .breathing { pauseBreathing() }
        else { player?.pause(); isPlaying = false; savePosition(force: true) }
        updateNowPlaying()
    }

    func toggle() {
        guard currentSession != nil else { toggleAmbience(); return }
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

    /// `duration` nil keeps the current choice (or plays until stopped).
    func playAmbience(_ ambience: QuietoAmbience, duration: TimeInterval? = nil) {
        do {
            try configureAudioSession()
            guard let url = ambience.audioURL else { throw QuietoSpeechRenderError.unavailable }
            finishAmbienceListening()
            ambiencePlayer?.pause()
            let player = AVQueuePlayer()
            ambienceLooper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            player.volume = Float(ambienceVolume)
            player.play()
            ambiencePlayer = player
            selectedAmbience = ambience
            ambienceStartedAt = .now
            isAmbiencePlaying = true
            if let duration { setAmbienceDuration(duration) }
            else if let remaining = ambienceRemaining { setAmbienceDuration(remaining) }
            observeAmbienceInterruptions()
            startAmbienceTimer()
            updateNowPlaying()
        } catch { errorMessage = "Cette ambiance n’est pas disponible.".quietoLocalized }
    }

    func stopAmbience() {
        finishAmbienceListening()
        ambiencePlayer?.pause(); ambienceLooper = nil; ambiencePlayer = nil
        selectedAmbience = nil
        isAmbiencePlaying = false
        isAmbiencePlayerPresented = false
        ambienceEndsAt = nil; ambiencePausedRemaining = nil
        ambienceTimer?.invalidate(); ambienceTimer = nil
        if let ambienceInterruptionObserver { NotificationCenter.default.removeObserver(ambienceInterruptionObserver) }
        ambienceInterruptionObserver = nil
        if currentSession == nil { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil }
    }

    func pauseAmbience() {
        guard isAmbiencePlaying, let ambiencePlayer else { return }
        ambiencePausedRemaining = ambienceEndsAt.map { max(0, $0.timeIntervalSinceNow) }
        ambienceEndsAt = nil
        ambiencePlayer.pause()
        isAmbiencePlaying = false
        updateNowPlaying()
    }

    func resumeAmbience() {
        guard !isAmbiencePlaying, let ambiencePlayer else { return }
        try? configureAudioSession()
        if let remaining = ambiencePausedRemaining { ambienceEndsAt = .now.addingTimeInterval(remaining) }
        ambiencePausedRemaining = nil
        ambiencePlayer.volume = Float(ambienceVolume)
        ambiencePlayer.play()
        isAmbiencePlaying = true
        startAmbienceTimer()
        updateNowPlaying()
    }

    func toggleAmbience() { isAmbiencePlaying ? pauseAmbience() : resumeAmbience() }

    /// Seconds before the sound stops; nil = no limit.
    var ambienceRemaining: TimeInterval? {
        if let ambienceEndsAt { return max(0, ambienceEndsAt.timeIntervalSinceNow) }
        return ambiencePausedRemaining
    }

    /// nil plays until the person stops the sound.
    func setAmbienceDuration(_ seconds: TimeInterval?) {
        ambiencePlayer?.volume = Float(ambienceVolume)
        if isAmbiencePlaying {
            ambienceEndsAt = seconds.map { Date.now.addingTimeInterval($0) }
            ambiencePausedRemaining = nil
        } else {
            ambienceEndsAt = nil
            ambiencePausedRemaining = seconds
        }
        updateNowPlaying()
    }

    /// Runs while the app is in the background too: audio keeps the process alive.
    private func startAmbienceTimer() {
        ambienceTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tickAmbience() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ambienceTimer = timer
    }

    private func tickAmbience() {
        guard isAmbiencePlaying, let ambiencePlayer, let ambienceEndsAt else { return }
        let left = ambienceEndsAt.timeIntervalSinceNow
        let fade: TimeInterval = 8
        if left <= 0 {
            stopAmbience()
        } else if left < fade {
            ambiencePlayer.volume = Float(ambienceVolume * left / fade)
        }
    }

    /// A phone call pauses the sound; it comes back afterwards, like music.
    private func observeAmbienceInterruptions() {
        guard ambienceInterruptionObserver == nil else { return }
        ambienceInterruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo, let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt).map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
            Task { @MainActor [weak self] in
                guard let self, self.currentSession == nil else { return }
                if type == .began {
                    self.resumeAmbienceAfterInterruption = self.isAmbiencePlaying
                    self.pauseAmbience()
                } else if type == .ended, shouldResume, self.resumeAmbienceAfterInterruption {
                    self.resumeAmbienceAfterInterruption = false
                    self.resumeAmbience()
                }
            }
        }
    }

    /// Wall-clock time: a sound keeps playing with the screen locked.
    private func finishAmbienceListening() {
        defer { ambienceStartedAt = nil }
        guard let ambience = selectedAmbience, let startedAt = ambienceStartedAt else { return }
        onAmbienceListened?(ambience, Int(Date().timeIntervalSince(startedAt)))
    }

    /// Stops everything: the session, the sleep timer and the ambience.
    func stop() {
        stopSession()
        stopAmbience()
    }

    /// Closes the mini player: playback stops and the session is forgotten.
    func close() {
        stop()
        currentSession = nil
        position = 0
        duration = 0
        isFullPlayerPresented = false
    }

    func recordFeedback(_ session: QuietoSession, feeling: String) { onSessionFeedback?(session, feeling) }

    /// Ends the current session but keeps the ambience playing (closing the
    /// full-screen breathing guide).
    func endSession() {
        stopSession()
        currentSession = nil
        position = 0
        duration = 0
        isFullPlayerPresented = false
    }

    private func stopSession() {
        playbackTask?.cancel(); playbackTask = nil
        breathingTimer?.invalidate(); breathingTimer = nil; breathingStartedAt = nil
        player?.pause(); savePosition(force: true)
        listenedSeconds = 0; lastTickPosition = nil; resumeAfterInterruption = false
        releasePlayer()
        isLoading = false
        timer?.invalidate(); timer = nil; timerRemaining = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func releasePlayer() {
        player?.pause()
        statusObservation = nil
        if let timeObserver { player?.removeTimeObserver(timeObserver) }; timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }; interruptionObserver = nil
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }; routeObserver = nil
        player = nil; isPlaying = false
    }

    private func startBreathing(_ session: QuietoSession, minutes: Int?) {
        let pattern = session.breathingPattern ?? .coherence
        duration = pattern.totalSeconds(minutes: minutes ?? session.durationMinutes)
        let saved = preferences.playbackPosition(for: session.id)
        position = saved > 0 && saved < duration - 5 ? saved : 0
        isLoading = false
        resumeBreathing()
        breathingStarts += 1
    }

    /// Elapsed time of the breathing exercise at `date`, finer than `position`
    /// (updated every 0.1 s) so the curve scrolls smoothly.
    func breathingElapsed(at date: Date) -> Double {
        guard isPlaying, let breathingStartedAt else { return position }
        return min(duration, date.timeIntervalSince(breathingStartedAt))
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
            breathingCompletions += 1
        }
    }

    private func tickTimer() { guard let left = timerRemaining else { return }; if left <= 1 { pause(); stopAmbience(); setSleepTimer(minutes: nil) } else { timerRemaining = left - 1 } }

    private func configureAudioSession() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothA2DP, .allowAirPlay])
        try audio.setPreferredIOBufferDuration(0.023)
        try audio.setActive(true)
    }

    private func startPlayer(url: URL, session: QuietoSession, fallbackToSpeech: Bool) {
        do {
            try configureAudioSession()
            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 1
            player = AVPlayer(playerItem: item)
            player?.isMuted = false
            player?.volume = 1
            player?.automaticallyWaitsToMinimizeStalling = false
            observe(item: item, session: session)
            if fallbackToSpeech {
                statusObservation = item.observe(\.status) { [weak self] item, _ in
                    guard item.status == .failed else { return }
                    Task { @MainActor [weak self] in self?.fallBackToSpeech(session) }
                }
            }
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
            errorMessage = "Cette séance n’est pas disponible pour le moment.".quietoLocalized
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
        let required = (duration > 0 ? duration : Double(max(1, session.durationMinutes * 60))) * 0.5
        guard Double(heard) >= required else { return }
        onSessionCompleted?(session, max(1, heard))
        if session.readerMode == .guidedVoice {
            lastCompletedSession = session
            guidedCompletions += 1
        }
    }
    private static func audioDuration(at url: URL) -> Double? {
        guard let file = try? AVAudioFile(forReading: url), file.processingFormat.sampleRate > 0 else { return nil }
        return Double(file.length) / file.processingFormat.sampleRate
    }
    /// Lock screen and Control Center when only a sound is playing.
    private func updateAmbienceNowPlaying() {
        guard let ambience = selectedAmbience else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: ambience.title.quietoLocalized,
            MPMediaItemPropertyArtist: "Quieto · \("Son d’ambiance".quietoLocalized)",
            MPNowPlayingInfoPropertyPlaybackRate: isAmbiencePlaying ? 1 : 0,
            MPNowPlayingInfoPropertyIsLiveStream: ambienceRemaining == nil
        ]
        if let remaining = ambienceRemaining, let startedAt = ambienceStartedAt {
            let elapsed = Date.now.timeIntervalSince(startedAt)
            info[MPMediaItemPropertyPlaybackDuration] = elapsed + remaining
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }
        if let path = Bundle.main.path(forResource: ambience.assetName, ofType: nil), let image = UIImage(contentsOfFile: path) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlaying() {
        guard let session = currentSession else { updateAmbienceNowPlaying(); return }
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
