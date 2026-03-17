import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';
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
    } catch (_) {}
  }

  Map<String, String> getOnboardingAnswers() {
    try {
      final raw = _prefs.getString(AppConstants.prefOnboardingAnswers);
      if (raw == null) return {};
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  // ── User profile ─────────────────────────────────────

  String get firstName =>
      _prefs.getString(AppConstants.prefUserFirstName) ?? '';

  Future<void> setFirstName(String name) async {
    await _prefs.setString(AppConstants.prefUserFirstName, name);
  }

  // ── Subscription ─────────────────────────────────

  bool get isPremium =>
      _prefs.getBool(AppConstants.prefIsPremium) ?? false;

  Future<void> setIsPremium(bool value) async {
    try {
      await _prefs.setBool(AppConstants.prefIsPremium, value);
    } catch (_) {}
  }

  // ── Progress ─────────────────────────────────────────

  UserProgressModel loadProgress() {
    try {
      final raw = _prefs.getString(AppConstants.prefSessionProgress);
      if (raw == null) return const UserProgressModel();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return UserProgressModel.fromJson(json);
    } catch (_) {
      return const UserProgressModel();
    }
  }

  Future<void> saveProgress(UserProgressModel progress) async {
    try {
      final raw = jsonEncode(progress.toJson());
      await _prefs.setString(AppConstants.prefSessionProgress, raw);
    } catch (_) {
      // Silently ignore write errors
    }
  }

  // ── Notifications ─────────────────────────────────────

  bool get notificationsEnabled =>
      _prefs.getBool(AppConstants.prefNotificationsEnabled) ?? false;

  Future<void> setNotificationsEnabled(bool value) async {
    try {
      await _prefs.setBool(AppConstants.prefNotificationsEnabled, value);
    } catch (_) {}
  }

  // ── Reset ─────────────────────────────────────────────

  Future<void> resetOnboarding() async {
    try {
      await _prefs.setBool(AppConstants.prefOnboardingDone, false);
      await _prefs.remove(AppConstants.prefOnboardingAnswers);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
