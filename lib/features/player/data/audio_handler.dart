import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/models/session_model.dart';
import '../../../core/services/storage_service.dart';

class QuietoAudioHandler extends BaseAudioHandler with SeekHandler {
  final StorageService _storage;
  AudioPlayer? _player;
  SessionModel? _session;

  QuietoAudioHandler({required StorageService storage}) : _storage = storage;

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
    mediaItem.add(MediaItem(
      id: session.id,
      title: session.title,
      duration: duration,
    ));

    // Update MediaItem when actual duration is known
    _player!.durationStream.listen((dur) {
      if (dur != null) {
        mediaItem.add(MediaItem(
          id: session.id,
          title: session.title,
          duration: dur,
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
