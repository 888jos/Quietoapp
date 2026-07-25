import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'storage_providers.dart';
import 'storage_service.dart';

/// Musique de fond de TOUTE l'app (onboarding, home, exploration, profil…).
/// Démarre à chaque lancement de l'app et tourne en boucle. Elle se coupe dès
/// qu'une séance démarre (le curseur du profil descend à zéro pour le montrer)
/// et revient UNIQUEMENT si la personne arrête la séance (bouton stop) ; une
/// séance qui va au bout laisse la musique coupée jusqu'au prochain lancement.
/// Piloté par [activeSessionIdProvider] au niveau racine.
/// L'utilisateur règle le niveau depuis le profil (curseur, 0 = coupée),
/// mais la coupure ne survit PAS à une fermeture complète de l'app : la
/// musique d'accueil fait partie de l'identité de Quieto (choix produit
/// 2026-07-18), elle revient à chaque lancement, au dernier volume audible
/// choisi. Couper reste possible à tout moment, pour la session en cours.
final ambientMusicProvider = Provider<AmbientMusic>((ref) {
  return AmbientMusic(
    initialLevel: _levelAtLaunch(ref.read(storageServiceProvider)),
  );
});

/// Niveau au lancement : le volume mémorisé, jamais 0. Un 0 stocké (coupure
/// faite avec une ancienne version de l'app) est ignoré au profit du défaut.
double _levelAtLaunch(StorageService storage) {
  final stored = storage.ambientLevel;
  return stored > 0 ? stored : 0.5;
}

/// Position du curseur de volume (0..1), réactive pour l'UI du profil.
final ambientLevelProvider =
    StateNotifierProvider<AmbientLevelNotifier, double>((ref) {
  return AmbientLevelNotifier(
    ref.read(storageServiceProvider),
    ref.read(ambientMusicProvider),
  );
});

class AmbientLevelNotifier extends StateNotifier<double> {
  AmbientLevelNotifier(this._storage, this._music)
      : super(_levelAtLaunch(_storage)) {
    _lastAudible = state;
  }

  final StorageService _storage;
  final AmbientMusic _music;

  /// Dernier volume audible, pour que le bouton stop/lecture retrouve le
  /// réglage de l'utilisateur au lieu de repartir d'une valeur arbitraire.
  double _lastAudible = 0.5;

  /// Applique le niveau en direct pendant le glissement du curseur.
  /// Marche AUSSI pendant une séance : remonter le curseur est un choix
  /// explicite, la musique se mêle alors à la voix de la séance.
  void set(double level) {
    state = level.clamp(0.0, 1.0);
    if (state > 0) _lastAudible = state;
    // La personne a pris la main : plus rien à restaurer au stop de la
    // séance, c'est SON réglage qui fait foi désormais.
    _avantSeance = 0;
    _music.setLevel(state);
  }

  /// Bouton stop/lecture : coupe la musique, ou la relance au dernier volume.
  Future<void> toggleMute() async {
    set(state == 0 ? _lastAudible : 0.0);
    await commit();
  }

  /// Persiste le choix (appelé en fin de glissement, pas à chaque pixel).
  /// La coupure (0) n'est volontairement PAS persistée : on mémorise le
  /// dernier volume audible, et la musique revient au prochain lancement.
  Future<void> commit() =>
      state > 0 ? _storage.setAmbientLevel(state) : Future.value();

  /// Volume affiché au moment où une séance a coupé la musique : rendu au
  /// stop. Reste à 0 si la personne l'avait déjà coupée elle-même (on
  /// respecte son choix, la musique ne revient pas toute seule).
  double _avantSeance = 0;

  /// Une séance démarre : la musique se coupe et le curseur descend à zéro
  /// pour le montrer. Le réglage MÉMORISÉ n'est pas touché : ce n'est pas un
  /// choix de l'utilisateur, donc au prochain lancement la musique revient.
  Future<void> sessionStarted() async {
    if (state > 0) {
      _avantSeance = state;
      _lastAudible = state;
      state = 0;
    }
    await _music.pause();
  }

  /// La personne a ARRÊTÉ la séance (bouton stop) : le curseur remonte au
  /// volume d'avant et la musique repart. Si elle a bougé le curseur PENDANT
  /// la séance, son réglage reste tel quel (rien à restaurer). Une fin
  /// naturelle de séance ne passe jamais par ici : la musique reste dans
  /// l'état choisi jusqu'au prochain lancement de l'app.
  Future<void> sessionStopped() async {
    if (state == 0 && _avantSeance > 0) state = _avantSeance;
    _avantSeance = 0;
    // Recale le niveau interne sur le curseur (ils peuvent différer si le
    // curseur a bougé pendant la séance), puis relance avec le fondu doux.
    _music.syncLevel(state);
    await _music.play();
  }
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
      // ⚠️ Une séance a pu démarrer PENDANT le chargement du fichier : son
      // ordre de pause est alors passé dans le vide (rien ne jouait encore).
      // Sans ce re-contrôle, la musique démarrait par-dessus la séance.
      if (_suspended || _level == 0) return;
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

  /// Recale le niveau SANS jouer ni couper : utilisé juste avant [play]
  /// quand le curseur affiché et le niveau interne peuvent différer
  /// (retour de séance), pour que le fondu d'entrée vise le bon volume.
  void syncLevel(double level) {
    _level = level.clamp(0.0, 1.0);
  }

  /// Réglage utilisateur, appliqué immédiatement (sans fondu, pour que le
  /// curseur réponde en direct). À 0 la musique se coupe ; en remontant elle
  /// repart, MÊME pendant une séance : la main de l'utilisateur prime sur
  /// la suspension automatique.
  Future<void> setLevel(double level) async {
    _level = level.clamp(0.0, 1.0);
    _fadeId++; // annule un éventuel fondu en cours
    try {
      if (_level == 0) {
        if (_player.playing) await _player.pause();
        return;
      }
      _suspended = false;
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
