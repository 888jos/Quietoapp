import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'storage_providers.dart';
import 'storage_service.dart';

/// Musique de fond de TOUTE l'app (onboarding, home, exploration, profil…).
/// Démarre à chaque lancement de l'app et tourne en boucle. Elle se met en
/// pause dès qu'une séance est active (mini-player compris) et reprend quand
/// la séance est fermée. Piloté par [activeSessionIdProvider] au niveau racine.
/// L'utilisateur règle le niveau depuis la home (curseur, 0 = coupée) ;
/// le choix est mémorisé entre les lancements.
final ambientMusicProvider = Provider<AmbientMusic>((ref) {
  return AmbientMusic(
    initialLevel: ref.read(storageServiceProvider).ambientLevel,
  );
});

/// Position du curseur de volume (0..1), réactive pour l'UI de la home.
final ambientLevelProvider =
    StateNotifierProvider<AmbientLevelNotifier, double>((ref) {
  return AmbientLevelNotifier(
    ref.read(storageServiceProvider),
    ref.read(ambientMusicProvider),
  );
});

class AmbientLevelNotifier extends StateNotifier<double> {
  AmbientLevelNotifier(this._storage, this._music)
      : super(_storage.ambientLevel) {
    if (state > 0) _lastAudible = state;
  }

  final StorageService _storage;
  final AmbientMusic _music;

  /// Dernier volume audible, pour que le bouton stop/lecture retrouve le
  /// réglage de l'utilisateur au lieu de repartir d'une valeur arbitraire.
  double _lastAudible = 0.5;

  /// Applique le niveau en direct pendant le glissement du curseur.
  void set(double level) {
    state = level.clamp(0.0, 1.0);
    if (state > 0) _lastAudible = state;
    _music.setLevel(state);
  }

  /// Bouton stop/lecture : coupe la musique, ou la relance au dernier volume.
  Future<void> toggleMute() async {
    set(state == 0 ? _lastAudible : 0.0);
    await commit();
  }

  /// Persiste le choix (appelé en fin de glissement, pas à chaque pixel).
  Future<void> commit() => _storage.setAmbientLevel(state);
}

class AmbientMusic {
  AmbientMusic({double initialLevel = 0.5})
      : _level = initialLevel.clamp(0.0, 1.0);

  final AudioPlayer _player = AudioPlayer();
  bool _loaded = false;

  /// Curseur utilisateur (0..1). 0 = musique coupée.
  double _level;

  /// True quand la musique est suspendue par l'app elle-même (séance en cours
  /// ou app en arrière-plan) : setLevel ne doit alors PAS la relancer.
  bool _suspended = false;

  /// Un réglage plus récent annule le fondu en cours (sinon le fondu de 840 ms
  /// écraserait le volume choisi au curseur).
  int _fadeId = 0;

  /// Volume réel du player quand le curseur est à fond. Le défaut (curseur à
  /// 0.5) redonne 0.32, le volume doux historique.
  static const _maxVolume = 0.64;

  double get _targetVolume => _level * _maxVolume;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await _player.setAsset('assets/audio/onboarding_ambient.mp3');
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(0.0);
    _loaded = true;
  }

  /// Démarre (ou reprend) la boucle avec un léger fondu d'entrée. Idempotent.
  /// Ne fait rien si l'utilisateur a coupé la musique.
  Future<void> play() async {
    _suspended = false;
    if (_level == 0) return;
    try {
      await _ensureLoaded();
      // ⚠️ Ne PAS await play() : sa future ne se résout qu'à l'arrêt de la
      // lecture (boucle infinie → jamais). L'attendre bloquait le fondu et
      // laissait le volume à 0 → aucun son.
      if (!_player.playing) unawaited(_player.play());
      await _fadeTo(_targetVolume);
      debugPrint('[AmbientMusic] en lecture, volume ${_player.volume}');
    } catch (e) {
      debugPrint('[AmbientMusic] play: $e');
    }
  }

  /// Met en pause (fondu de sortie court) : pour laisser place à une séance,
  /// ou quand l'app part en arrière-plan / le téléphone se verrouille.
  Future<void> pause() async {
    _suspended = true;
    try {
      if (!_player.playing) return;
      await _fadeTo(0.0);
      await _player.pause();
    } catch (e) {
      debugPrint('[AmbientMusic] pause: $e');
    }
  }

  /// Réglage utilisateur, appliqué immédiatement (sans fondu, pour que le
  /// curseur réponde en direct). À 0 la musique se coupe ; en remontant elle
  /// repart, sauf pendant une séance.
  Future<void> setLevel(double level) async {
    _level = level.clamp(0.0, 1.0);
    _fadeId++; // annule un éventuel fondu en cours
    try {
      if (_level == 0) {
        if (_player.playing) await _player.pause();
        return;
      }
      if (_suspended) return;
      await _ensureLoaded();
      if (!_player.playing) unawaited(_player.play());
      await _player.setVolume(_targetVolume);
    } catch (e) {
      debugPrint('[AmbientMusic] setLevel: $e');
    }
  }

  Future<void> _fadeTo(double target) async {
    final id = ++_fadeId;
    final start = _player.volume;
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 70));
      if (id != _fadeId) return; // un réglage manuel a pris la main
      await _player.setVolume(start + (target - start) * i / steps);
    }
  }

  void dispose() => _player.dispose();
}
