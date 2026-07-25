import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';

/// VIGIE — mesure d'usage interne, pour adapter Quieto et Louane.
///
/// Enregistre des ÉVÉNEMENTS de parcours (écran vu, étape d'onboarding,
/// paywall affiché, achat, séance lancée, message à Louane…) et les envoie
/// par petits lots à la Cloud Function `trace`, qui les range dans Firestore.
///
/// ANONYME PAR CONSTRUCTION : l'identifiant est un tirage aléatoire fait sur
/// ce téléphone (aucun lien avec le prénom, l'e-mail ou quoi que ce soit),
/// et on n'envoie JAMAIS de texte libre (ni prénom, ni contenu de message).
///
/// NE DOIT JAMAIS GÊNER L'APP : tout est silencieux. Pas de réseau ? Les
/// événements attendent en mémoire et repartiront plus tard. Erreur ? On
/// laisse tomber sans bruit. La Vigie observe, elle ne se voit pas.
class VigieService {
  VigieService(this._prefs) {
    _id = _prefs.getString(_prefVigieId) ?? _genereId('v');
    if (!_prefs.containsKey(_prefVigieId)) {
      _prefs.setString(_prefVigieId, _id);
    }
    _session = _genereId('s');
  }

  static const _prefVigieId = 'vigie_id';

  /// Au-delà, le lot part tout de suite (sinon, le minuteur s'en charge).
  static const _seuilEnvoi = 20;

  /// File plafonnée : si le réseau est coupé longtemps, on oublie le surplus
  /// (perdre quelques événements est sans gravité, gonfler la mémoire non).
  static const _fileMax = 400;

  final SharedPreferences _prefs;
  late final String _id;
  late final String _session;

  final List<Map<String, dynamic>> _file = [];
  Timer? _minuteur;
  bool _envoiEnCours = false;

  /// Dernier écran « signifiant » vu (déduit des événements). Sert à savoir
  /// OÙ était la personne quand l'app est partie en arrière-plan : c'est ce
  /// qui distingue « a quitté l'app sur cet écran » de « est restée bloquée ».
  String _dernierEcran = 'inconnu';

  /// ID d'installation anonyme (stable) — joint aux appels `louane` pour
  /// relier les stats de conversation au parcours, sans identité réelle.
  String get id => _id;

  /// ID de session (change à chaque lancement de l'app).
  String get session => _session;

  String _genereId(String prefixe) {
    final alea = Random.secure();
    final hex =
        List.generate(16, (_) => alea.nextInt(16).toRadixString(16)).join();
    return '${prefixe}_$hex';
  }

  /// Enregistre un événement. [props] : uniquement des valeurs courtes et
  /// non sensibles (identifiants de séance, booléens, compteurs) — jamais de
  /// texte tapé par la personne.
  void log(String type, [Map<String, Object?> props = const {}]) {
    try {
      _retiensEcran(type, props);
      if (_file.length >= _fileMax) return;
      _file.add({
        'type': type,
        'props': Map<String, Object?>.from(props)
          ..removeWhere((_, v) => v == null),
        'tsc': DateTime.now().millisecondsSinceEpoch,
      });
      if (_file.length >= _seuilEnvoi) {
        flush();
      } else {
        _minuteur ??= Timer(const Duration(seconds: 20), flush);
      }
    } catch (e) {
      debugPrint('[Vigie] log échoué (ignoré) : $e');
    }
  }

  void _retiensEcran(String type, Map<String, Object?> props) {
    switch (type) {
      case 'onboarding_etape':
        _dernierEcran = 'onboarding_${props['etape'] ?? '?'}';
      case 'paywall_affiche':
        _dernierEcran = 'paywall';
      case 'home_vue':
        _dernierEcran = 'home';
      case 'louane_ouverte':
        _dernierEcran = 'louane';
      case 'seance_lancee':
        _dernierEcran = 'seance';
      case 'onglet':
        _dernierEcran = '${props['nom'] ?? '?'}';
    }
  }

  /// À appeler quand l'app part en arrière-plan : note SUR QUEL ÉCRAN la
  /// personne était (départ volontaire vs blocage), puis pousse le lot.
  void logFond() {
    log('app_fond', {'ecran': _dernierEcran});
    flush();
  }

  /// Envoie ce qui attend. Appelé automatiquement (seuil ou minuteur) et au
  /// passage de l'app en arrière-plan (dernier wagon avant la fermeture).
  Future<void> flush() async {
    _minuteur?.cancel();
    _minuteur = null;
    if (_envoiEnCours || _file.isEmpty) return;
    _envoiEnCours = true;
    final lot = List<Map<String, dynamic>>.from(_file);
    _file.clear();
    try {
      await FirebaseFunctions.instance.httpsCallable('trace').call({
        'vigie': _id,
        'session': _session,
        'version': AppConstants.appVersion,
        'evenements': lot,
      });
    } catch (e) {
      // Échec (réseau…) : on remet le lot en tête de file pour plus tard.
      debugPrint('[Vigie] envoi échoué, lot conservé : $e');
      _file.insertAll(0, lot.take(_fileMax - _file.length));
    } finally {
      _envoiEnCours = false;
    }
  }
}
