import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/session_model.dart';
import '../../../core/services/storage_service.dart';

class QuietoAudioHandler extends BaseAudioHandler with SeekHandler {
  final StorageService _storage;
  void Function()? completionCallback;
  AudioPlayer? _player;
  SessionModel? _session;

  QuietoAudioHandler({
    required StorageService storage,
    void Function()? onCompleted,
  })  : _storage = storage,
        completionCallback = onCompleted;

  // ── Streams ───────────────────────────────────────

  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream.empty();

  Stream<PlayerState> get playerStateStream =>
      _player?.playerStateStream ?? const Stream.empty();

  Stream<Duration?> get durationStream =>
      _player?.durationStream ?? const Stream.empty();

  Duration? get currentDuration => _player?.duration;

  String? get currentSessionId => _session?.id;

  // ── Init ──────────────────────────────────────────

  Future<void> initSession(SessionModel session) async {
    _session = session;

    // Dispose previous player and null it out immediately so that any
    // in-flight play() call sees null and bails out cleanly.
    await _player?.dispose();
    _player = null;

    final newPlayer = AudioPlayer();
    final path = 'assets/audio/${session.audioFile}';
    try {
      await newPlayer.setAsset(path);
    } catch (e) {
      // setAsset failed (e.g. file not found). Clean up and rethrow so
      // PlayerNotifier._init()'s catch sets the error state.
      await newPlayer.dispose();
      rethrow;
    }

    // Asset loaded — commit the player.
    _player = newPlayer;

    // Écrire le logo dans un fichier temporaire pour que iOS puisse le lire
    final byteData = await rootBundle.load('assets/images/Logo 1.jpeg');
    final tempFile = File('${Directory.systemTemp.path}/quieto_artwork.jpeg');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());
    mediaItem.add(MediaItem(
      id: session.id,
      title: session.title,
      artist: AppConstants.appName,
      album: '',
      duration: newPlayer.duration ?? Duration(minutes: session.durationMinutes),
      artUri: tempFile.uri,
    ));

    // Update MediaItem when actual duration is known
    newPlayer.durationStream.listen((dur) {
      if (dur != null) {
        mediaItem.add(MediaItem(
          id: session.id,
          title: session.title,
          artist: AppConstants.appName,
          album: '',
          duration: dur,
          artUri: tempFile.uri,
        ));
      }
    });

    // Forward position updates to playbackState
    newPlayer.positionStream.listen((_) => _broadcastState());

    // Handle playback state changes
    newPlayer.playerStateStream.listen((s) {
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
      final player = _player;
      if (player == null) return;
      // A completed player needs to seek to 0 before it can play again.
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
      _broadcastState();
    } catch (e, st) {
      debugPrint('[Audio] play() failed: $e\n$st');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player?.pause();
      _broadcastState();
    } catch (e, st) {
      debugPrint('[Audio] pause() failed: $e\n$st');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player?.seek(position);
      _broadcastState();
    } catch (e, st) {
      debugPrint('[Audio] seek() failed: $e\n$st');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
      _broadcastState();
      await super.stop();
    } catch (e, st) {
      debugPrint('[Audio] stop() failed: $e\n$st');
    }
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
    } catch (e, st) {
      debugPrint('[Audio] _onCompleted saveProgress failed: $e\n$st');
    }

    // Notify external listeners (e.g. Riverpod tick provider) that a session completed
    completionCallback?.call();

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
