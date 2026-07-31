import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:health/health.dart';

/// Envoie les minutes d'écoute dans Apple Santé (rubrique « Pleine
/// conscience »). iOS uniquement pour l'instant : le plugin `health` ne prend
/// pas encore en charge la pleine conscience sur Health Connect (Android).
///
/// Tous les appels sont silencieux : si l'utilisateur refuse l'accès Santé ou
/// si l'écriture échoue, la lecture audio et le comptage interne des minutes
/// ne sont jamais affectés.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final Health _health = Health();
  bool _configured = false;
  bool _authRequestedThisRun = false;

  static const _types = [HealthDataType.MINDFULNESS];
  static const _permissions = [HealthDataAccess.WRITE];

  // Canal natif (ios/Runner/SanteMentaleChannel.swift) : lecture des
  // évaluations de bien-être d'Apple Santé (GAD-7 / PHQ-9, iOS 18+), que le
  // plugin `health` ne sait pas lire.
  static const _canalSante = MethodChannel('quieto/sante_mentale');

  String? _resumeSante; // cache session (null = jamais lu)
  Future<String>? _lectureSante; // dédoublonne les lectures concurrentes

  bool get _supported => !kIsWeb && Platform.isIOS;

  /// Vrai si l'appareil peut être relié à Apple Santé (iPhone). Sert à dire
  /// à Louane ce qui est possible ou non sur cet appareil.
  bool get disponible => _supported;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Affiche la demande d'accès à Apple Santé. iOS ne montre la feuille
  /// qu'une seule fois ; les appels suivants ne font rien de visible.
  /// Sur iOS 18+, la feuille combine écriture Pleine conscience et lecture
  /// des évaluations de bien-être ; sinon, repli sur le plugin (écriture).
  Future<void> requestAuthorization() async {
    if (!_supported || _authRequestedThisRun) return;
    _authRequestedThisRun = true;
    try {
      final ok = await _canalSante.invokeMethod<bool>('demanderAutorisation');
      if (ok == true) return;
    } catch (_) {
      // Canal absent (tests, vieille app) → repli plugin.
    }
    try {
      await _ensureConfigured();
      await _health.requestAuthorization(_types, permissions: _permissions);
    } catch (e) {
      debugPrint('[Health] demande d\'autorisation échouée: $e');
    }
  }

  // ── Évaluations de bien-être (questionnaires app Santé) ──

  /// Valeur instantanée pour les payloads Louane/parcours : ne déclenche
  /// rien, ne bloque JAMAIS. Vide tant que [resumeSanteMentale] n'a pas
  /// abouti (ou s'il n'y a rien à voir).
  String get resumeSanteCache => _resumeSante ?? '';

  /// Lit (une fois par session) les dernières évaluations anxiété/humeur de
  /// l'app Santé via le canal natif et fabrique un petit texte français prêt
  /// pour Louane. '' si Android, iOS < 18, refus ou aucune évaluation.
  Future<String> resumeSanteMentale() {
    if (!_supported) return Future.value('');
    final connu = _resumeSante;
    if (connu != null) return Future.value(connu);
    return _lectureSante ??= _lireResumeSante();
  }

  Future<String> _lireResumeSante() async {
    try {
      final brut =
          await _canalSante.invokeListMethod<dynamic>('derniersScores') ??
              const [];
      _resumeSante = _formaterResume(brut);
    } catch (e) {
      debugPrint('[Health] lecture évaluations échouée: $e');
      _resumeSante = '';
    } finally {
      _lectureSante = null;
    }
    return _resumeSante ?? '';
  }

  String _formaterResume(List<dynamic> scores) {
    const libelles = {
      'anxiete': 'questionnaire anxiété (GAD-7)',
      'depression': 'questionnaire humeur (PHQ-9)',
    };
    const niveaux = {'faible': 'faible', 'modere': 'modéré', 'eleve': 'élevé'};
    final phrases = <String>[];
    for (final s in scores) {
      if (s is! Map) continue;
      final libelle = libelles[s['type']];
      final niveau = niveaux[s['niveau']];
      final jours = s['jours'];
      if (libelle == null || niveau == null || jours is! int) continue;
      if (jours > 90) continue; // trop ancien pour guider un programme
      final quand = jours == 0
          ? 'aujourd\'hui'
          : jours == 1
              ? 'hier'
              : 'il y a $jours jours';
      phrases.add('Évaluation Apple Santé ($quand) : $libelle, niveau $niveau.');
    }
    return phrases.join(' ');
  }

  /// Enregistre une période de pleine conscience [start] → [end] dans Santé.
  /// Apple ne retient que l'intervalle : la durée affichée = fin - début.
  Future<void> writeMindfulness(DateTime start, DateTime end) async {
    if (!_supported || !end.isAfter(start)) return;
    try {
      await _ensureConfigured();
      await _health.writeHealthData(
        value: 0,
        type: HealthDataType.MINDFULNESS,
        startTime: start,
        endTime: end,
      );
    } catch (e) {
      debugPrint('[Health] écriture pleine conscience échouée: $e');
    }
  }
}
