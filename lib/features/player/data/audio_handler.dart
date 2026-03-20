import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/session_model.dart';
import '../../../core/services/storage_service.dart';

class QuietoAudioHandler extends BaseAudioHandler with SeekHandler {
  final StorageService _storage;
  final void Function()? _completionCallback;
  AudioPlayer? _player;
  SessionModel? _session;

  QuietoAudioHandler({
    required StorageService storage,
    void Function()? onCompleted,
  })  : _storage = storage,
        _completionCallback = onCompleted;

  // ── Streams ───────────────────────────────────────

  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream.empty();

  Stream<PlayerState> get playerStateStream =>
      _player?.playerStateStream ?? const Stream.empty();

  Stream<Duration?> get durationStream =>
      _player?.durationStream ?? const Stream.empty();

  Duration? get currentDuration => _player?.duration;

  // ── Init ──────────────────────────────────────────

  Future<void> initSession(SessionModel session) async {
    _session = session;

    // Dispose previous player if any
    await _player?.dispose();
    _player = AudioPlayer();

    final path = 'assets/audio/${session.audioFile}';
    await _player!.setAsset(path);

    // Set MediaItem for lock screen / notification
    final duration = _player!.duration ?? Duration(minutes: session.durationMinutes);
    const artUri = 'asset:///assets/images/hf_20260314_214439_a9a1fd51-1280-41ae-bf86-7548b618d776.jpeg';
    mediaItem.add(MediaItem(
      id: session.id,
      title: session.title,
      artist: AppConstants.appName,
      album: '',
      duration: duration,
      artUri: Uri.parse(artUri),
    ));

    // Update MediaItem when actual duration is known
    _player!.durationStream.listen((dur) {
      if (dur != null) {
        mediaItem.add(MediaItem(
          id: session.id,
          title: session.title,
          artist: AppConstants.appName,
          album: '',
          duration: dur,
          artUri: Uri.parse(artUri),
        ));
      }
    });

    // Forward position updates to playbackState
    _player!.positionStream.listen((pos) {
      _broadcastState();
    });

    // Handle playback state changes
    _player!.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _onCompleted();
      } else {
        _broadcastState();
      }
    });

    _broadcastState();
  }

  // ── Playback controls ─────────────────────────────

  @override
  Future<void> play() async {
    try {
      await _player?.play();
      _broadcastState();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _player?.pause();
      _broadcastState();
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player?.seek(position);
      _broadcastState();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
      _broadcastState();
      await super.stop();
    } catch (_) {}
  }

  // ── Internal ──────────────────────────────────────

  void _broadcastState() {
    final player = _player;
    if (player == null) return;

    final processingState = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[player.processingState] ?? AudioProcessingState.idle;

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    ));
  }

  void _onCompleted() {
    final session = _session;
    if (session == null) return;

    try {
      final progress = _storage.loadProgress();
      final updated = progress.markCompleted(session.id, session.durationMinutes);
      _storage.saveProgress(updated);
    } catch (_) {}

    // Notify external listeners (e.g. Riverpod tick provider) that a session completed
    _completionCallback?.call();

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.play,
      ],
      androidCompactActionIndices: const [0],
      processingState: AudioProcessingState.completed,
      playing: false,
      updatePosition: _player?.duration ?? Duration.zero,
    ));
  }

  // ── Dispose ───────────────────────────────────────

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
