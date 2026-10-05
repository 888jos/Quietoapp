import AVFoundation
import MediaPlayer

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

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var timer: Timer?
    private var ambiencePlayer: AVAudioPlayer?
    private let speechRenderer = QuietoSpeechRenderer()
    private var playbackTask: Task<Void, Never>?
    private var routeObserver: NSObjectProtocol?

    override init() {
        super.init()
        setupRemoteCommands()
    }

    func play(_ session: QuietoSession, localURL: URL? = nil) {
        if currentSession?.id == session.id, let player { player.play(); isPlaying = true; updateNowPlaying(); return }
        stop()
        currentSession = session
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
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func toggle() { guard let player else { return }; if isPlaying { player.pause() } else { player.play() }; isPlaying.toggle(); savePosition(); updateNowPlaying() }
    func seek(to value: Double) { player?.seek(to: CMTime(seconds: value, preferredTimescale: 600)); position = value; savePosition() }
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
        player?.pause(); savePosition()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }; timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }; interruptionObserver = nil
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }; routeObserver = nil
        player = nil; isPlaying = false; isLoading = false
        timer?.invalidate(); timer = nil; timerRemaining = nil
        stopAmbience()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func tickTimer() { guard let left = timerRemaining else { return }; if left <= 1 { player?.pause(); isPlaying = false; stopAmbience(); setSleepTimer(minutes: nil); updateNowPlaying() } else { timerRemaining = left - 1 } }

    private func configureAudioSession() throws {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothA2DP, .allowAirPlay])
        try audio.setActive(true)
    }

    private func startPlayer(url: URL, session: QuietoSession) {
        do {
            try configureAudioSession()
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            observe(item: item, session: session)
            let saved = UserDefaults.standard.double(forKey: "quieto.native.audio.position.\(session.id)")
            if saved > 0 { player?.seek(to: CMTime(seconds: saved, preferredTimescale: 600)) }
            player?.play()
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
                savePosition()
                updateNowPlaying()
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = false
                let key = "quieto.native.activity.\(session.id)"
                let old = UserDefaults.standard.integer(forKey: key)
                UserDefaults.standard.set(old + max(1, session.durationMinutes * 60), forKey: key)
                var events = UserDefaults.standard.array(forKey: "quieto.native.activity.events") as? [[String: Any]] ?? []
                events.append(["id": session.id, "seconds": max(1, session.durationMinutes * 60), "date": Date().timeIntervalSince1970])
                UserDefaults.standard.set(events, forKey: "quieto.native.activity.events")
            }
        }
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let info = note.userInfo, let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt, let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            Task { @MainActor [weak self] in
                if type == .began { self?.player?.pause(); self?.isPlaying = false; self?.updateNowPlaying() }
            }
        }
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            Task { @MainActor in self?.player?.pause(); self?.isPlaying = false; self?.updateNowPlaying() }
        }
    }

    private func setupRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.player?.play(); self?.isPlaying = true }; return .success }
        commands.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.player?.pause(); self?.isPlaying = false }; return .success }
        commands.skipForwardCommand.preferredIntervals = [15]
        commands.skipForwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(by: 15) }; return .success }
        commands.skipBackwardCommand.preferredIntervals = [15]
        commands.skipBackwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(by: -15) }; return .success }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func savePosition() { guard let id = currentSession?.id else { return }; UserDefaults.standard.set(position, forKey: "quieto.native.audio.position.\(id)") }
    private func updateNowPlaying() {
        guard let session = currentSession else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: session.title,
            MPMediaItemPropertyArtist: "Quieto · \(session.practiceType.rawValue)",
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
