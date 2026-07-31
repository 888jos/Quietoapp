import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
import '../models/parcours_model.dart';
import '../models/user_progress_model.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // ── Onboarding ───────────────────────────────────────

  bool get isOnboardingDone =>
      _prefs.getBool(AppConstants.prefOnboardingDone) ?? false;

  Future<void> setOnboardingDone() async {
    await _prefs.setBool(AppConstants.prefOnboardingDone, true);
  }

  Future<void> saveOnboardingAnswers(Map<String, String> answers) async {
    try {
      await _prefs.setString(
          AppConstants.prefOnboardingAnswers, jsonEncode(answers));
    } catch (e, st) {
      debugPrint('[Storage] saveOnboardingAnswers failed: $e\n$st');
    }
  }

  Map<String, String> getOnboardingAnswers() {
    try {
      final raw = _prefs.getString(AppConstants.prefOnboardingAnswers);
      if (raw == null) return {};
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (e, st) {
      debugPrint('[Storage] getOnboardingAnswers failed: $e\n$st');
      return {};
    }
  }

  // ── Apple Santé ──────────────────────────────────────

  /// Vrai dès que la proposition de connexion à Apple Santé a été faite
  /// (page d'onboarding « Connecter », ou filet au premier play). Évite de
  /// redemander à quelqu'un qui a déjà vu la feuille d'autorisation iOS.
  bool get isHealthPromptSeen =>
      _prefs.getBool(AppConstants.prefHealthPromptSeen) ?? false;

  Future<void> setHealthPromptSeen() async {
    await _prefs.setBool(AppConstants.prefHealthPromptSeen, true);
  }

  // ── User profile ─────────────────────────────────────

  String get firstName =>
      _prefs.getString(AppConstants.prefUserFirstName) ?? '';

  Future<void> setFirstName(String name) async {
    await _prefs.setString(AppConstants.prefUserFirstName, name);
  }

  // ── Mémoire de Louane (locale) ───────────────────────

  /// Ce que Louane retient de l'utilisateur entre les sessions. Vide au début.
  String get louaneMemoire =>
      _prefs.getString(AppConstants.prefLouaneMemoire) ?? '';

  Future<void> setLouaneMemoire(String fiche) async {
    try {
      await _prefs.setString(AppConstants.prefLouaneMemoire, fiche);
    } catch (e, st) {
      debugPrint('[Storage] setLouaneMemoire failed: $e\n$st');
    }
  }

  // ── Quotas Louane (locaux, jamais affichés) ──────────

  /// Messages envoyés à Louane depuis toujours (sert à la limite des gratuits).
  int get louaneCompteurTotal =>
      _prefs.getInt(AppConstants.prefLouaneCompteurTotal) ?? 0;

  /// Messages envoyés aujourd'hui, au sens du jour [jour] (date heure de
  /// Paris). Si le jour enregistré est différent, le compteur est reparti à
  /// zéro — c'est le reset de minuit.
  int louaneCompteurJour(String jour) {
    if (_prefs.getString(AppConstants.prefLouaneJour) != jour) return 0;
    return _prefs.getInt(AppConstants.prefLouaneCompteurJour) ?? 0;
  }

  Future<void> incrementeLouaneCompteurs(String jour) async {
    try {
      await _prefs.setInt(
          AppConstants.prefLouaneCompteurTotal, louaneCompteurTotal + 1);
      await _prefs.setInt(
          AppConstants.prefLouaneCompteurJour, louaneCompteurJour(jour) + 1);
      await _prefs.setString(AppConstants.prefLouaneJour, jour);
    } catch (e, st) {
      debugPrint('[Storage] incrementeLouaneCompteurs failed: $e\n$st');
    }
  }

  // ── Intro Louane (animée une seule fois) ─────────────

  /// Non-null dès que l'accueil animé a été joué (l'entier est un vestige
  /// des variantes tirées au sort ; seul null / non-null compte).
  int? get louaneIntroVariante =>
      _prefs.getInt(AppConstants.prefLouaneIntroVariante);

  Future<void> setLouaneIntroVariante(int index) async {
    try {
      await _prefs.setInt(AppConstants.prefLouaneIntroVariante, index);
    } catch (e, st) {
      debugPrint('[Storage] setLouaneIntroVariante failed: $e\n$st');
    }
  }

  // ── Disclaimer Louane (montré une seule fois) ────────

  bool get louaneDisclaimerVu =>
      _prefs.getBool(AppConstants.prefLouaneDisclaimerVu) ?? false;

  Future<void> setLouaneDisclaimerVu() async {
    try {
      await _prefs.setBool(AppConstants.prefLouaneDisclaimerVu, true);
    } catch (e, st) {
      debugPrint('[Storage] setLouaneDisclaimerVu failed: $e\n$st');
    }
  }

  // ── Subscription ─────────────────────────────────

  bool get isPremium =>
      _prefs.getBool(AppConstants.prefIsPremium) ?? false;

  Future<void> setIsPremium(bool value) async {
    try {
      await _prefs.setBool(AppConstants.prefIsPremium, value);
    } catch (e, st) {
      debugPrint('[Storage] setIsPremium failed: $e\n$st');
    }
  }

  // ── Progress ─────────────────────────────────────────

  UserProgressModel loadProgress() {
    try {
      final raw = _prefs.getString(AppConstants.prefSessionProgress);
      if (raw == null) return const UserProgressModel();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserProgressModel.fromJson(json);
    } catch (e, st) {
      debugPrint('[Storage] loadProgress failed: $e\n$st');
      return const UserProgressModel();
    }
  }

  Future<void> saveProgress(UserProgressModel progress) async {
    try {
      final raw = jsonEncode(progress.toJson());
      await _prefs.setString(AppConstants.prefSessionProgress, raw);
    } catch (e, st) {
      debugPrint('[Storage] saveProgress failed: $e\n$st');
    }
  }

  // ── Parcours (programme 7 jours créé par Louane) ──────

  /// Le programme en cours, ou null s'il n'y en a pas (jamais créé, abandonné,
  /// ou sauvegarde illisible — dans ce cas Louane pourra en re-proposer un).
  ParcoursModel? loadParcours() {
    try {
      final raw = _prefs.getString(AppConstants.prefParcours);
      if (raw == null) return null;
      final parcours =
          ParcoursModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      // Sauvegarde incohérente (pas 7 jours) → on repart de zéro.
      if (parcours.jours.length != 7) return null;
      return parcours;
    } catch (e, st) {
      debugPrint('[Storage] loadParcours failed: $e\n$st');
      return null;
    }
  }

  Future<void> saveParcours(ParcoursModel parcours) async {
    try {
      await _prefs.setString(
          AppConstants.prefParcours, jsonEncode(parcours.toJson()));
    } catch (e, st) {
      debugPrint('[Storage] saveParcours failed: $e\n$st');
    }
  }

  Future<void> clearParcours() async {
    try {
      await _prefs.remove(AppConstants.prefParcours);
    } catch (e, st) {
      debugPrint('[Storage] clearParcours failed: $e\n$st');
    }
  }

  // ── Historique d'écoutes (pour Louane) ────────────────

  /// Compteurs d'écoute par séance : {id: {fois, ts}} (ts = dernière écoute,
  /// millisecondes epoch). Alimenté à chaque lancement de séance.
  Map<String, dynamic> _lireEcoutes() {
    try {
      final raw = _prefs.getString(AppConstants.prefEcoutesSeances);
      if (raw == null) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e, st) {
      debugPrint('[Storage] _lireEcoutes failed: $e\n$st');
      return {};
    }
  }

  Future<void> enregistreEcouteSeance(String sessionId) async {
    try {
      final ecoutes = _lireEcoutes();
      final actuel = ecoutes[sessionId];
      final fois = (actuel is Map ? (actuel['fois'] as num?)?.toInt() : 0) ?? 0;
      ecoutes[sessionId] = {
        'fois': fois + 1,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
      await _prefs.setString(
          AppConstants.prefEcoutesSeances, jsonEncode(ecoutes));
    } catch (e, st) {
      debugPrint('[Storage] enregistreEcouteSeance failed: $e\n$st');
    }
  }

  /// Résumé compact envoyé au serveur Louane : [{id, fois, jours}], les plus
  /// récentes d'abord, 20 max (jours = depuis la dernière écoute).
  List<Map<String, Object>> ecoutesPourLouane() {
    final maintenant = DateTime.now().millisecondsSinceEpoch;
    final liste = <Map<String, Object>>[];
    _lireEcoutes().forEach((id, valeur) {
      if (valeur is! Map) return;
      final fois = (valeur['fois'] as num?)?.toInt() ?? 0;
      final ts = (valeur['ts'] as num?)?.toInt() ?? 0;
      if (fois <= 0 || ts <= 0) return;
      liste.add({
        'id': id,
        'fois': fois,
        'jours': ((maintenant - ts) / Duration.millisecondsPerDay).floor(),
        '_ts': ts,
      });
    });
    liste.sort((a, b) => (b['_ts'] as int).compareTo(a['_ts'] as int));
    return liste.take(20).map((e) {
      e.remove('_ts');
      return e;
    }).toList();
  }

  // ── Notifications ─────────────────────────────────────

  bool get notificationsEnabled =>
      _prefs.getBool(AppConstants.prefNotificationsEnabled) ?? false;

  Future<void> setNotificationsEnabled(bool value) async {
    try {
      await _prefs.setBool(AppConstants.prefNotificationsEnabled, value);
    } catch (e, st) {
      debugPrint('[Storage] setNotificationsEnabled failed: $e\n$st');
    }
  }

  /// Heure du rappel quotidien. Null si jamais choisie (on calcule alors un
  /// défaut depuis la réponse Q4 de l'onboarding, cf. defaultReminderTime).
  int? get reminderHour => _prefs.getInt(AppConstants.prefReminderHour);
  int? get reminderMinute => _prefs.getInt(AppConstants.prefReminderMinute);

  Future<void> setReminderTime(int hour, int minute) async {
    try {
      await _prefs.setInt(AppConstants.prefReminderHour, hour);
      await _prefs.setInt(AppConstants.prefReminderMinute, minute);
    } catch (e, st) {
      debugPrint('[Storage] setReminderTime failed: $e\n$st');
    }
  }

  /// La proposition de rappel après la première séance ne se fait qu'une fois.
  bool get notificationPromptShown =>
      _prefs.getBool(AppConstants.prefNotificationPromptShown) ?? false;

  Future<void> setNotificationPromptShown() async {
    try {
      await _prefs.setBool(AppConstants.prefNotificationPromptShown, true);
    } catch (e, st) {
      debugPrint('[Storage] setNotificationPromptShown failed: $e\n$st');
    }
  }

  // ── Musique d'ambiance ────────────────────────────────

  /// Position du curseur de volume (0..1). 0 = musique coupée.
  /// 0.5 par défaut : correspond au volume doux historique.
  double get ambientLevel =>
      _prefs.getDouble(AppConstants.prefAmbientLevel) ?? 0.5;

  Future<void> setAmbientLevel(double value) async {
    try {
      await _prefs.setDouble(AppConstants.prefAmbientLevel, value);
    } catch (e, st) {
      debugPrint('[Storage] setAmbientLevel failed: $e\n$st');
    }
  }

  // ── Reset ─────────────────────────────────────────────

  Future<void> resetOnboarding() async {
    try {
      await _prefs.setBool(AppConstants.prefOnboardingDone, false);
      await _prefs.remove(AppConstants.prefOnboardingAnswers);
    } catch (e, st) {
      debugPrint('[Storage] resetOnboarding failed: $e\n$st');
    }
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
