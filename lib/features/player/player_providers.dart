import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/models/session_model.dart';
import '../../core/services/ambient_music.dart';
import '../../core/services/storage_providers.dart';
import '../home/home_providers.dart';
import '../parcours/parcours_providers.dart';
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
// Doit être overridé dans main.dart via AudioService.init().

final audioHandlerProvider = Provider<QuietoAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in ProviderScope');
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
  final SessionModel session;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Libère le `ref.keepAlive()` du provider pour que celui-ci puisse être
  /// détruit par l'autoDispose (appelé sur stop). Défini par le provider.
  void Function()? releaseKeepAlive;

  /// Vigie : appelé quand l'utilisateur ARRÊTE la séance avant la fin
  /// (position, durée) → mesure où les séances sont abandonnées.
  void Function(Duration position, Duration duration)? onArret;

  PlayerNotifier({
    required QuietoAudioHandler handler,
    required this.session,
  })  : _handler = handler,
        super(const PlayerState()) {
    _init();
  }

  Future<void> _cancelSubscriptions() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> _init() async {
    // Annule les subscriptions précédentes (cas retry())
    await _cancelSubscriptions();

    try {
      if (!mounted) return;
      state = state.copyWith(status: PlayerStatus.loading);

      await _handler.initSession(session);
      if (!mounted) return;

      _subscriptions.add(_handler.positionStream.listen((pos) {
        if (!mounted) return;
        state = state.copyWith(position: pos);
      }));

      _subscriptions.add(_handler.durationStream.listen((dur) {
        if (!mounted) return;
        if (dur != null) state = state.copyWith(duration: dur);
      }));

      _subscriptions.add(_handler.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          state = state.copyWith(status: PlayerStatus.idle);
        } else if (s.playing) {
          state = state.copyWith(status: PlayerStatus.playing);
        } else if (s.processingState == ProcessingState.ready) {
          state = state.copyWith(status: PlayerStatus.paused);
        }
      }));

      state = state.copyWith(
        status: PlayerStatus.paused,
        duration: _handler.currentDuration ?? Duration.zero,
      );

      // Auto-play : on lance la lecture dès que le chargement est terminé.
      // L'utilisateur veut entendre la séance immédiatement après avoir
      // tapé sur la carte, sans avoir à appuyer sur play.
      if (mounted) {
        state = state.copyWith(status: PlayerStatus.playing);
        await _handler.play();
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: PlayerStatus.error,
        error: 'Impossible de charger la séance.',
      );
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  Future<void> togglePlayPause() async {
    try {
      if (state.status == PlayerStatus.playing) {
        state = state.copyWith(status: PlayerStatus.paused);
        await _handler.pause();
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

  Future<void> retry() async {
    state = const PlayerState();
    await _init();
  }

  Future<void> stop() async {
    onArret?.call(state.position, state.duration);
    try {
      await _handler.stop();
      state = state.copyWith(status: PlayerStatus.idle);
    } catch (_) {}
    // Libère le keepAlive : une fois que plus aucun widget ne lit le provider
    // (le mini player se cache car status == idle), l'autoDispose détruit ce
    // notifier. La prochaine ouverture de la même séance repart d'un état neuf
    // à 0 — sans avoir à recréer le provider à la main (ce qui relançait
    // l'audio par erreur via l'auto-play de _init).
    releaseKeepAlive?.call();
  }

}

// ── Provider factory ──────────────────────────────────
//
// `.autoDispose` : quand plus aucun widget ne lit playerProvider(sessionId)
// (par ex. après stop sur le mini player → mini player se cache), Riverpod
// détruit le PlayerNotifier. La prochaine ouverture de la même séance crée
// un PlayerNotifier neuf qui repart proprement de zéro (initSession → audio
// rechargé position 0). Sans ça, l'ancien notifier était réutilisé avec son
// état "idle" résiduel, ce qui faisait disparaître la mini-barre et empêchait
// la séance de repartir du début.

final playerProvider = StateNotifierProvider
    .autoDispose
    .family<PlayerNotifier, PlayerState, String>((ref, sessionId) {
  // `ref.keepAlive()` empêche l'autoDispose tant qu'on n'invalide pas
  // explicitement le provider. Sans ça, naviguer du player vers une page
  // hors HomeShell (ex. /category/X) détruisait le notifier, et le retour
  // sur Home recréait un nouveau notifier qui réinitialisait l'audio à 0
  // en pause. Avec keepAlive, le lecteur reste vivant pendant la navigation,
  // et l'audio continue à jouer. Le notifier est explicitement détruit via
  // `ref.invalidate(...)` quand l'utilisateur tape "stop" sur le mini player.
  final keepAliveLink = ref.keepAlive();

  final session = ref.watch(currentSessionProvider(sessionId));
  if (session == null) {
    throw StateError('Session $sessionId introuvable');
  }
  final handler = ref.watch(audioHandlerProvider);
  handler.completionCallback = () {
    // Vigie : séance écoutée jusqu'au bout (l'activation par excellence).
    ref.read(vigieProvider).log('seance_terminee', {
      'seance': session.id,
      'categorie': session.categoryId,
    });
    ref.read(sessionCompletionTickProvider.notifier).state++;
    // L'utilisateur vient de méditer : le rappel du jour n'a plus de raison
    // d'être, on le reprogramme à partir de demain (rappel doux, jamais
    // redondant).
    final storage = ref.read(storageServiceProvider);
    final hour = storage.reminderHour;
    final minute = storage.reminderMinute;
    if (storage.notificationsEnabled && hour != null && minute != null) {
      ref.read(notificationServiceProvider).scheduleDailyReminder(
            hour: hour,
            minute: minute,
            skipToday: true,
          );
    }
  };
  // Rafraîchit les stats (minutes méditées) au fil de l'écoute, sans
  // attendre la fin de la séance ni un redémarrage de l'app.
  handler.progressCallback = () {
    ref.read(sessionCompletionTickProvider.notifier).state++;
  };
  final notifier = PlayerNotifier(
    handler: handler,
    session: session,
  );
  // Permet à stop() de relâcher le keepAlive → le notifier sera détruit par
  // l'autoDispose dès qu'il n'est plus écouté (mini player caché).
  notifier.releaseKeepAlive = keepAliveLink.close;

  // Vigie : un notifier neuf = une séance lancée ; un stop avant la fin =
  // un abandon, avec le pourcentage écouté (où décrochent-ils ?).
  ref.read(vigieProvider).log('seance_lancee', {
    'seance': session.id,
    'categorie': session.categoryId,
    'premium': session.isPremium,
    'duree_min': session.durationMinutes,
  });
  // Programme de Louane : lancer LA séance du jour suffit à cocher le jour
  // (le notifier vérifie tout — id, jour en cours, une fois par jour). Pas
  // besoin de finir l'écoute : le lendemain se débloque quand même. Lancer
  // la même séance depuis le catalogue compte aussi : même id.
  ref.read(parcoursProvider.notifier).seanceLancee(session.id);
  // Historique local d'écoutes : nourrit les suggestions de Louane (varier,
  // reproposer ce qui a plu). Ne quitte jamais le téléphone en clair : seul
  // un résumé {id, fois, jours} part avec ses messages.
  ref.read(storageServiceProvider).enregistreEcouteSeance(session.id);
  notifier.onArret = (position, duration) {
    ref.read(vigieProvider).log('seance_arretee', {
      'seance': session.id,
      'categorie': session.categoryId,
      'pct': duration.inSeconds > 0
          ? (position.inSeconds * 100 ~/ duration.inSeconds)
          : 0,
    });
  };
  // Mark this session as the active one for the mini player
  Future.microtask(() {
    ref.read(activeSessionIdProvider.notifier).state = sessionId;
    // Chaque début de séance coupe la musique d'ambiance (curseur du profil
    // à zéro). Appelé ICI et pas seulement via le listener racine : relancer
    // la MÊME séance ne change pas l'id, le listener ne tirerait pas.
    ref.read(ambientLevelProvider.notifier).sessionStarted();
  });
  return notifier;
});
