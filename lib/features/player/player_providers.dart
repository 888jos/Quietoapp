import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/models/session_model.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/storage_providers.dart';
import '../home/home_providers.dart';
import 'data/player_repository.dart';

// ── Repository ────────────────────────────────────────

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref.watch(homeRepositoryProvider));
});

// ── Session courante ──────────────────────────────────

final currentSessionProvider =
    Provider.family<SessionModel?, String>((ref, sessionId) {
  return ref.watch(playerRepositoryProvider).findSession(sessionId);
});

// ── État du lecteur ───────────────────────────────────

enum PlayerStatus { idle, loading, playing, paused, error }

class PlayerState {
  final PlayerStatus status;
  final Duration position;
  final Duration duration;
  final String? error;

  const PlayerState({
    this.status = PlayerStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  double get progress => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;

  PlayerState copyWith({
    PlayerStatus? status,
    Duration? position,
    Duration? duration,
    String? error,
  }) =>
      PlayerState(
        status: status ?? this.status,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        error: error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────

class PlayerNotifier extends StateNotifier<PlayerState> {
  final AudioPlayer _audio;
  final StorageService _storage;
  final SessionModel session;

  PlayerNotifier({
    required AudioPlayer audio,
    required StorageService storage,
    required this.session,
  })  : _audio = audio,
        _storage = storage,
        super(const PlayerState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      state = state.copyWith(status: PlayerStatus.loading);
      final path = 'assets/audio/${session.audioFile}';
      await _audio.setAsset(path);

      final progress = _storage.loadProgress();
      final savedPos = progress.lastPosition(session.id);
      if (savedPos > 0) {
        await _audio.seek(Duration(seconds: savedPos));
      }

      _audio.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
      });

      _audio.durationStream.listen((dur) {
        if (dur != null) state = state.copyWith(duration: dur);
      });

      _audio.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) {
          _onCompleted();
        }
      });

      state = state.copyWith(
        status: PlayerStatus.paused,
        duration: _audio.duration ?? Duration.zero,
      );
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: 'Impossible de charger la séance.',
      );
    }
  }

  Future<void> togglePlayPause() async {
    try {
      if (state.status == PlayerStatus.playing) {
        await _audio.pause();
        state = state.copyWith(status: PlayerStatus.paused);
        _savePosition();
      } else {
        await _audio.play();
        state = state.copyWith(status: PlayerStatus.playing);
      }
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: 'Erreur de lecture.',
      );
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _audio.seek(position);
      state = state.copyWith(position: position);
    } catch (_) {}
  }

  Future<void> skipForward() async {
    final next = state.position + const Duration(seconds: 15);
    await seekTo(next < state.duration ? next : state.duration);
  }

  Future<void> skipBackward() async {
    final prev = state.position - const Duration(seconds: 15);
    await seekTo(prev > Duration.zero ? prev : Duration.zero);
  }

  void _savePosition() {
    final progress = _storage.loadProgress();
    final updated =
        progress.savePosition(session.id, state.position.inSeconds);
    _storage.saveProgress(updated);
  }

  void _onCompleted() {
    final progress = _storage.loadProgress();
    final updated =
        progress.markCompleted(session.id, session.durationMinutes);
    _storage.saveProgress(updated);
    state = state.copyWith(status: PlayerStatus.paused);
  }

  @override
  void dispose() {
    _savePosition();
    _audio.dispose();
    super.dispose();
  }
}

// ── Provider factory ──────────────────────────────────

final playerProvider = StateNotifierProvider.family<PlayerNotifier,
    PlayerState, String>((ref, sessionId) {
  final session = ref.watch(currentSessionProvider(sessionId));
  if (session == null) {
    throw StateError('Session $sessionId introuvable');
  }
  final storage = ref.watch(storageServiceProvider);
  return PlayerNotifier(
    audio: AudioPlayer(),
    storage: storage,
    session: session,
  );
});
