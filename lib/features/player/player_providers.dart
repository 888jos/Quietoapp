import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/models/session_model.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/storage_providers.dart';
import '../home/home_providers.dart';
import 'data/player_repository.dart';
import 'data/audio_handler.dart';

// ── Repository ────────────────────────────────────────

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref.watch(homeRepositoryProvider));
});

// ── Active session (mini player) ──────────────────────

/// Holds the sessionId of the currently active session, or null if none.
final activeSessionIdProvider = StateProvider<String?>((ref) => null);

// ── Session completion tick ────────────────────────────
// Incremented each time a session is marked completed.
// Watched by categoryProgressProvider to trigger a re-read of SharedPreferences.
final sessionCompletionTickProvider = StateProvider<int>((ref) => 0);

// ── AudioHandler (singleton par durée de vie de l'app) ────────────

final audioHandlerProvider = Provider<QuietoAudioHandler>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final handler = QuietoAudioHandler(
    storage: storage,
    onCompleted: () {
      ref.read(sessionCompletionTickProvider.notifier).state++;
    },
  );
  ref.onDispose(() => handler.dispose());
  return handler;
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
  final QuietoAudioHandler _handler;
  final StorageService _storage;
  final SessionModel session;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<dynamic>? _stateSub;

  PlayerNotifier({
    required QuietoAudioHandler handler,
    required StorageService storage,
    required this.session,
  })  : _handler = handler,
        _storage = storage,
        super(const PlayerState()) {
    _init();
  }

  /// True while this notifier owns the handler's current audio player.
  /// Guards against stale notifiers (cached by the family) controlling the
  /// wrong player after a different session has been loaded.
  bool get _isActive => _handler.currentSessionId == session.id;

  Future<void> _init() async {
    try {
      state = state.copyWith(status: PlayerStatus.loading);

      await _handler.initSession(session);

      final progress = _storage.loadProgress();
      final savedPos = progress.lastPosition(session.id);
      if (savedPos > 0) {
        await _handler.seek(Duration(seconds: savedPos));
      }

      _posSub = _handler.positionStream.listen((pos) {
        if (_isActive) state = state.copyWith(position: pos);
      });

      _durSub = _handler.durationStream.listen((dur) {
        if (_isActive && dur != null) state = state.copyWith(duration: dur);
      });

      _stateSub = _handler.playerStateStream.listen((s) {
        if (!_isActive) return;
        if (s.processingState == ProcessingState.completed) {
          state = state.copyWith(status: PlayerStatus.paused);
        } else if (s.playing) {
          state = state.copyWith(status: PlayerStatus.playing);
        } else if (s.processingState == ProcessingState.ready) {
          state = state.copyWith(status: PlayerStatus.paused);
        }
      });

      state = state.copyWith(
        status: PlayerStatus.paused,
        duration: _handler.currentDuration ?? Duration.zero,
      );
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: 'Impossible de charger la séance.',
      );
    }
  }

  Future<void> togglePlayPause() async {
    if (!_isActive) return;
    try {
      if (state.status == PlayerStatus.playing) {
        state = state.copyWith(status: PlayerStatus.paused);
        await _handler.pause();
        _savePosition();
      } else {
        state = state.copyWith(status: PlayerStatus.playing);
        await _handler.play();
      }
    } catch (e) {
      state = state.copyWith(
        status: PlayerStatus.error,
        error: 'Erreur de lecture.',
      );
    }
  }

  Future<void> seekTo(Duration position) async {
    if (!_isActive) return;
    try {
      await _handler.seek(position);
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

  Future<void> stop() async {
    if (!_isActive) return;
    try {
      _savePosition();
      await _handler.stop();
      state = state.copyWith(status: PlayerStatus.idle);
    } catch (_) {}
  }

  void _savePosition() {
    try {
      final progress = _storage.loadProgress();
      final updated =
          progress.savePosition(session.id, state.position.inSeconds);
      _storage.saveProgress(updated);
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _savePosition();
    super.dispose();
  }
}

// ── Provider factory ──────────────────────────────────

final playerProvider = StateNotifierProvider.autoDispose
    .family<PlayerNotifier, PlayerState, String>((ref, sessionId) {
  final session = ref.watch(currentSessionProvider(sessionId));
  if (session == null) {
    throw StateError('Session $sessionId introuvable');
  }
  final storage = ref.watch(storageServiceProvider);
  final handler = ref.watch(audioHandlerProvider);
  final notifier = PlayerNotifier(
    handler: handler,
    storage: storage,
    session: session,
  );
  // Mark this session as the active one for the mini player
  Future.microtask(
    () => ref.read(activeSessionIdProvider.notifier).state = sessionId,
  );
  return notifier;
});
