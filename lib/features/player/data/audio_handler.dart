import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/session_model.dart';
import '../../../core/models/user_progress_model.dart';
import '../../../core/services/storage_service.dart';

class QuietoAudioHandler extends BaseAudioHandler with SeekHandler {
  final StorageService _storage;
  void Function()? completionCallback;
  /// Appelé après chaque sauvegarde de temps écouté, pour rafraîchir les
  /// stats affichées (minutes méditées) sans attendre un redémarrage.
  void Function()? progressCallback;
  AudioPlayer? _player;
  SessionModel? _session;

  // ── Comptage du temps réellement écouté ──────────────
  // On additionne uniquement la progression "naturelle" de la lecture :
  // les petits incréments de position pendant que l'audio joue. Les sauts
  // (skip ±15s), les retours en arrière et les pauses ne comptent pas.
  Duration _lastCountedPosition = Duration.zero;
  double _pendingSeconds = 0; // temps écouté pas encore sauvegardé
  static const _flushThresholdSeconds = 10; // sauvegarde tous les ~10s
  static const _maxNaturalDeltaMs = 2000; // au-delà = saut, on ignore

  // File d'écriture : toutes les modifs du progress (temps écouté ET statut
  // "complétée") passent par là, l'une après l'autre. Ça empêche deux
  // lectures-modifications-écritures de se chevaucher et de s'écraser.
  Future<void> _writeQueue = Future.value();

  Future<void> _mutateProgress(
      UserProgressModel Function(UserProgressModel) update) {
    final result = _writeQueue.then((_) async {
      final progress = _storage.loadProgress();
      await _storage.saveProgress(update(progress));
    });
    // La file survit même si une opération échoue (sinon tout se bloquerait).
    _writeQueue = result.catchError((_) {});
    return result;
  }
  // On stocke les subscriptions des streams du player pour pouvoir les
  // annuler explicitement au prochain initSession (évite les listeners
  // résiduels qui pourraient mettre à jour le mediaItem avec d'anciennes
  // données).
  final List<StreamSubscription<dynamic>> _playerSubs = [];

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
    // Sauvegarde le temps écouté de la séance précédente avant d'en changer.
    await _flushListening();
    _session = session;
    _lastCountedPosition = Duration.zero;
    _pendingSeconds = 0;

    // Annule les subscriptions des streams de l'ancien player AVANT de le
    // disposer, pour qu'aucun listener résiduel ne tente de mettre à jour
    // mediaItem ou playbackState avec d'anciennes données.
    for (final sub in _playerSubs) {
      await sub.cancel();
    }
    _playerSubs.clear();

    // Dispose previous player and null it out immediately so that any
    // in-flight play() call sees null and bails out cleanly.
    await _player?.dispose();
    _player = null;

    final newPlayer = AudioPlayer();
    // On extrait juste le nom de fichier (les MP3 sont à plat sur Firebase,
    // pas dans des sous-dossiers par catégorie).
    final filename = session.audioFile.split('/').last;
    final url = '${AppConstants.audioBaseUrl}'
        '${Uri.encodeComponent(filename)}?alt=media';
    try {
      await newPlayer.setUrl(url);
    } catch (e) {
      // setUrl failed (e.g. network error, 404). Clean up and rethrow so
      // PlayerNotifier._init()'s catch sets the error state.
      await newPlayer.dispose();
      rethrow;
    }

    // Asset loaded — commit the player.
    _player = newPlayer;

    // Détermine l'artwork : image de la session si disponible, sinon logo
    final imageFile = session.imageFile;
    final artworkAssetPath = imageFile != null
        ? 'assets/images/$imageFile'
        : 'assets/images/Logo 1.jpeg';

    ByteData byteData;
    try {
      byteData = await rootBundle.load(artworkAssetPath);
    } catch (e) {
      debugPrint(
          '[Audio] Artwork load failed for $artworkAssetPath, fallback logo: $e');
      byteData = await rootBundle.load('assets/images/Logo 1.jpeg');
    }
    final tempFile = File('${Directory.systemTemp.path}/quieto_artwork.png');
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
    _playerSubs.add(newPlayer.durationStream.listen((dur) {
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
    }));

    // Forward position updates to playbackState + compte le temps écouté
    _playerSubs.add(newPlayer.positionStream.listen((pos) {
      _accumulateListening(pos);
      _broadcastState();
    }));

    // Handle playback state changes
    _playerSubs.add(newPlayer.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _onCompleted();
      } else {
        _broadcastState();
      }
    }));

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
      await _flushListening();
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

  // Flèches ⏪ ⏩ de l'écran verrouillé / centre de contrôle : +/- 15 s,
  // comme les boutons dans l'app. (Sans ces overrides, les boutons système
  // ne faisaient rien.)
  @override
  Future<void> skipToNext() async {
    final player = _player;
    if (player == null) return;
    final target = player.position + const Duration(seconds: 15);
    final dur = player.duration;
    await seek(dur != null && target > dur ? dur : target);
  }

  @override
  Future<void> skipToPrevious() async {
    final player = _player;
    if (player == null) return;
    final target = player.position - const Duration(seconds: 15);
    await seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
      await _flushListening();
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

  Future<void> _onCompleted() async {
    final session = _session;
    if (session == null) return;

    // Sauvegarde les dernières secondes écoutées, puis marque comme complétée.
    // Les deux passent par la file d'écriture → exécutées l'une après l'autre,
    // jamais en même temps, donc aucune ne peut écraser l'autre.
    await _flushListening();
    try {
      await _mutateProgress((p) => p.markCompleted(session.id));
    } catch (e, st) {
      debugPrint('[Audio] _onCompleted markCompleted failed: $e\n$st');
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

  // ── Comptage du temps écouté ──────────────────────

  /// Additionne la progression naturelle de la lecture. Ignore les pauses,
  /// les sauts (skip ±15s) et les retours en arrière.
  void _accumulateListening(Duration pos) {
    final player = _player;
    if (player == null || !player.playing) {
      _lastCountedPosition = pos;
      return;
    }
    final deltaMs = pos.inMilliseconds - _lastCountedPosition.inMilliseconds;
    _lastCountedPosition = pos;
    if (deltaMs <= 0 || deltaMs > _maxNaturalDeltaMs) return; // saut/retour
    _pendingSeconds += deltaMs / 1000.0;
    if (_pendingSeconds >= _flushThresholdSeconds) {
      _flushListening();
    }
  }

  /// Persiste les secondes écoutées accumulées dans le total cumulé.
  Future<void> _flushListening() async {
    final whole = _pendingSeconds.floor();
    if (whole <= 0) return;
    // On retire les secondes tout de suite (pour ne pas les recompter si un
    // autre flush part en parallèle), mais on les remet si la sauvegarde
    // échoue → aucune minute perdue.
    _pendingSeconds -= whole;
    try {
      await _mutateProgress((p) => p.addListenedSeconds(whole));
      progressCallback?.call();
    } catch (e, st) {
      _pendingSeconds += whole; // échec → on réessaiera au prochain flush
      debugPrint('[Audio] _flushListening failed: $e\n$st');
    }
  }

  // ── Dispose ───────────────────────────────────────

  Future<void> dispose() async {
    await _flushListening();
    for (final sub in _playerSubs) {
      await sub.cancel();
    }
    _playerSubs.clear();
    await _player?.dispose();
    _player = null;
  }
}
